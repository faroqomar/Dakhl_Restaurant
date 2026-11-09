import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';

import '../../integration_test/support/c0_import_boundary_fixture.dart';
import '../../integration_test/support/c0_import_boundary_qa_main.dart' as qa;

const _id = '22000000-0000-4000-8000-000000000001';
Future<Directory> _newNamespace() async {
  final directory = await Directory.systemTemp.createTemp(
    'dakhl-boundary-life-',
  );
  return Directory(await directory.resolveSymbolicLinks());
}

Future<void> _fails(Future<void> Function() action, String code) => expectLater(
  Future<void>.sync(action),
  throwsA(isA<C0ImportBoundaryException>().having((e) => e.code, 'code', code)),
);

Future<void> _remove(
  C0ImportBoundaryFixture fixture,
  Directory namespace,
) async {
  try {
    await fixture.cleanup();
  } catch (_) {
    // One-shot failure hooks retain the real owner for an explicit retry.
    await fixture.cleanup();
  }
  await namespace.delete(recursive: true);
}

void main() {
  test(
    'every large archive is identified and same-length changes are detected',
    () async {
      final namespace = await _newNamespace();
      final fixture = await C0ImportBoundaryFixture.open(
        namespace: namespace,
        fixtureId: _id,
        stage: 'cancel-open',
      );
      addTearDown(() => _remove(fixture, namespace));
      final source = File(
        '${fixture.target.path}/sources/large-regression.bin',
      );
      final bytes = Uint8List(70000)..fillRange(0, 70000, 65);
      await source.writeAsBytes(bytes, flush: true);
      await _fails(fixture.assertAuthorityUnchanged, 'authority_changed');
      final first = await fixture.captureAuthority();
      final firstFiles = first['sourceAndAuthorityFiles']! as Map;
      final identity = firstFiles['sources/large-regression.bin']! as Map;
      expect(identity, {
        'bytes': 70000,
        'sha256': sha256.convert(bytes).toString(),
      });
      bytes[69999] = 66;
      await source.writeAsBytes(bytes, flush: true);
      final changed = await fixture.captureAuthority();
      final changedFiles = changed['sourceAndAuthorityFiles']! as Map;
      expect(changedFiles['sources/large-regression.bin'], isNot(identity));
      expect(jsonEncode(changed).length, lessThan(20000));
      await source.delete();
      await fixture.assertAuthorityUnchanged();
    },
  );

  test(
    'failed close preserves a live model and cleanup can retry once',
    () async {
      final namespace = await _newNamespace();
      var attempts = 0;
      final fixture = await C0ImportBoundaryFixture.open(
        namespace: namespace,
        fixtureId: _id,
        stage: 'cancel-open',
        beforeClose: () async {
          if (++attempts == 1) throw StateError('owned close failure');
        },
      );
      addTearDown(() => _remove(fixture, namespace));
      await expectLater(fixture.cleanup(), throwsStateError);
      expect(await fixture.root.exists(), isTrue);
      expect(
        fixture.model.canMutate,
        isTrue,
        reason: 'The model must not be disposed before owner close succeeds.',
      );
      await _fails(() async {
        await fixture.stagePickerFiles();
      }, 'fixture_closed');
      await fixture.cleanup();
      expect(attempts, 2);
      expect(await fixture.root.exists(), isFalse);
      expect(fixture.model.canMutate, isFalse);
    },
  );

  test(
    'partial root removal retries without exclusive-closeout conflict',
    () async {
      final namespace = await _newNamespace();
      var attempts = 0;
      final fixture = await C0ImportBoundaryFixture.open(
        namespace: namespace,
        fixtureId: _id,
        stage: 'cancel-open',
        beforeRootDelete: () async {
          if (++attempts == 1) {
            throw FileSystemException('owned delete failure');
          }
        },
      );
      addTearDown(() => _remove(fixture, namespace));
      await expectLater(fixture.cleanup(), throwsA(isA<FileSystemException>()));
      expect(await fixture.root.exists(), isTrue);
      expect(await fixture.root.list().isEmpty, isTrue);
      final closeout = File('${namespace.path}/$_id.closeout.json');
      expect(await closeout.exists(), isFalse);
      await fixture.cleanup();
      expect(attempts, 2);
      expect(await fixture.root.exists(), isFalse);
      final before = await closeout.readAsBytes();
      await fixture.cleanup();
      expect(await closeout.readAsBytes(), before);
      final intent = jsonDecode(
        await File('${namespace.path}/$_id.intent.json').readAsString(),
      ) as Map;
      expect(intent['status'], 'cleaned');
    },
  );

  test(
    'busy native open refuses cleanup and late operations stay closed',
    () async {
      final namespace = await _newNamespace();
      final fixture = await C0ImportBoundaryFixture.open(
        namespace: namespace,
        fixtureId: _id,
        stage: 'cancel-open',
      );
      final delegate = _ControlledTransfer();
      final selecting = fixture.transferForTest(delegate).open();
      try {
        await delegate.entered.future;
        await _fails(fixture.cleanup, 'native_operation_in_flight');
        expect(await fixture.root.exists(), isTrue);
      } finally {
        delegate.result.complete(const CapabilityCancelled<Uint8List>());
        await selecting;
      }
      await fixture.verify();
      await fixture.cleanup();
      final late = _ControlledTransfer();
      await _fails(() async {
        await fixture.transferForTest(late).open();
      }, 'fixture_closed');
      expect(late.calls, 0);
      await _fails(() async {
        await fixture.stagePickerFiles();
      }, 'fixture_closed');
      await _fails(() async {
        await fixture.verify();
      }, 'fixture_closed');
      await _remove(fixture, namespace);
    },
  );

  test('before-open receipt failure still allows owned cleanup', () async {
    final namespace = await _newNamespace();
    final fixture = await C0ImportBoundaryFixture.open(
      namespace: namespace,
      fixtureId: _id,
      stage: 'cancel-open',
    );
    addTearDown(() => _remove(fixture, namespace));
    final receiptBlocker = Directory(
      '${fixture.root.path}/before-native-open.json',
    );
    await receiptBlocker.create();
    final delegate = _ControlledTransfer();
    await expectLater(
      fixture.transferForTest(delegate).open(),
      throwsA(isA<FileSystemException>()),
    );
    expect(delegate.calls, 0);
    await receiptBlocker.delete();
    await fixture.assertAuthorityUnchanged();
    await fixture.cleanup();
    expect(await fixture.root.exists(), isFalse);
  });

  for (final wrongSelection in [true, false]) {
    test(
      wrongSelection
          ? 'unexpected successful selection still allows owned cleanup'
          : 'throwing picker still allows owned cleanup',
      () async {
        final namespace = await _newNamespace();
        final fixture = await C0ImportBoundaryFixture.open(
          namespace: namespace,
          fixtureId: _id,
          stage: 'cancel-open',
        );
        addTearDown(() => _remove(fixture, namespace));
        final delegate = _ControlledTransfer();
        final selecting = fixture.transferForTest(delegate).open();
        final selected = wrongSelection
            ? expectLater(
                selecting,
                throwsA(
                  isA<C0ImportBoundaryException>().having(
                    (e) => e.code,
                    'code',
                    'selected_unexpected_bytes',
                  ),
                ),
              )
            : expectLater(selecting, throwsStateError);
        await delegate.entered.future;
        if (wrongSelection) {
          delegate.result.complete(
            CapabilitySuccess(Uint8List.fromList([123, 125])),
          );
        } else {
          delegate.result.completeError(StateError('owned picker failure'));
        }
        await selected;
        await fixture.assertAuthorityUnchanged();
        await fixture.cleanup();
        expect(await fixture.root.exists(), isFalse);
      },
    );
  }

  testWidgets(
    'cleanup failure detaches surface but keeps retry button enabled',
    (tester) async {
      final namespace = (await tester.runAsync(() => _newNamespace()))!;
      var attempts = 0;
      final fixture = (await tester.runAsync(
        () => C0ImportBoundaryFixture.open(
          namespace: namespace,
          fixtureId: _id,
          stage: 'cancel-open',
          beforeRootDelete: () async {
            if (++attempts == 1) {
              throw FileSystemException('owned UI deletion failure');
            }
          },
        ),
      ))!;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() => _remove(fixture, namespace));
      });
      await tester.pumpWidget(qa.importBoundaryQaForTest(fixture));
      final button = find.widgetWithText(TextButton, 'Cleanup owned fixture');
      await tester.tap(button);
      await _until(
        tester,
        () =>
            attempts == 1 &&
            tester.widget<TextButton>(button).onPressed != null,
      );
      expect(await tester.runAsync(fixture.root.exists), isTrue);
      await tester.tap(button);
      await _until(
        tester,
        () => find
            .text(
              'Owned root removed; compact closeout and intent tombstone retained.',
            )
            .evaluate()
            .isNotEmpty,
      );
      expect(tester.widget<TextButton>(button).onPressed, isNull);
      expect(await tester.runAsync(fixture.root.exists), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  final clock = Stopwatch()..start();
  while (!ready()) {
    if (clock.elapsed > const Duration(seconds: 15)) {
      fail('Bounded cleanup UI wait');
    }
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pump();
}

final class _ControlledTransfer implements FileTransferCapability {
  final entered = Completer<void>();
  final result = Completer<CapabilityResult<Uint8List>>();
  int calls = 0;
  @override
  Future<CapabilityResult<Uint8List>> open() {
    calls++;
    entered.complete();
    return result.future;
  }

  @override
  Future<CapabilityResult<void>> save(Uint8List bytes) async =>
      const CapabilityFailure(
        'unit_save_disabled',
        'Unit import lifecycle only.',
      );
}
