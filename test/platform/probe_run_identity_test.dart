import 'dart:io';

import 'package:dakhl_restaurant/capabilities/capability_contracts.dart';
import 'package:dakhl_restaurant/capabilities/isolated_probe_repository.dart';
import 'package:dakhl_restaurant/platform/probe_run_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires a bounded caller-provided run nonce', () {
    for (final invalid in [
      '',
      'short',
      ' ',
      'abc/defghijklmnop',
      'abcdefghijklmn!p',
      'abcdefghijklmnop\n',
      'abcdefghijklmnopع',
      'a' * 65,
    ]) {
      expect(
        () => ProbeRunIdentity(invalid),
        throwsFormatException,
        reason: 'Reject missing or unsafe nonce: $invalid',
      );
    }
    expect(ProbeRunIdentity('fresh-run-20261028-A').probe.isValid, isTrue);
  });

  test('matching nonce and payload pass; different nonce or sequence fail', () {
    final first = ProbeRunIdentity('fresh-run-20261028-A');
    final second = ProbeRunIdentity('fresh-run-20261028-B');
    expect(first.validateRead(first.probe), isA<CapabilitySuccess<void>>());
    expect(second.validateRead(first.probe), isA<CapabilityFailure<void>>());
    expect(
      first.validateRead(
        SyntheticProbe(
          message: first.probe.message,
          sequence: (first.probe.sequence + 1) % 1000000,
        ),
      ),
      isA<CapabilityFailure<void>>(),
    );
  });

  test('fresh nonce cannot accept stale committed data and failed check preserves it', () async {
    final temp = await Directory.systemTemp.createTemp('phase00-run-nonce-');
    addTearDown(() => temp.delete(recursive: true));
    final root = Directory('${temp.path}/${IsolatedProbeRepository.rootName}');
    final repository = IsolatedProbeRepository(root);
    final oldRun = ProbeRunIdentity('previous-run-20261028-A');
    final newRun = ProbeRunIdentity('current-run-20261028-B');
    expect(
      await repository.write(oldRun.probe),
      isA<CapabilitySuccess<void>>(),
    );
    final saved =
        (await repository.read() as CapabilitySuccess<SyntheticProbe>).value;
    final before = saved.encode();
    expect(newRun.validateRead(saved), isA<CapabilityFailure<void>>());
    final after =
        (await IsolatedProbeRepository(root).read()
                as CapabilitySuccess<SyntheticProbe>)
            .value;
    expect(after.encode(), before);
    expect(oldRun.validateRead(after), isA<CapabilitySuccess<void>>());
    expect(
      await repository.write(newRun.probe),
      isA<CapabilitySuccess<void>>(),
    );
    final current =
        (await IsolatedProbeRepository(root).read()
                as CapabilitySuccess<SyntheticProbe>)
            .value;
    expect(newRun.validateRead(current), isA<CapabilitySuccess<void>>());
    expect(current.message, contains('current-run-20261028-B'));
    final revisions = await root
        .list()
        .where((entry) => entry.path.contains('/revision-'))
        .toList();
    expect(revisions, hasLength(2));
  });
}
