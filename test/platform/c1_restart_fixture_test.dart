import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_flutter_adapters/madar_flutter_adapters.dart';
import 'package:path/path.dart' as p;

import '../../integration_test/support/c1_restart_fixture.dart';

void main() {
  const id = 'c879c0bd-63bb-4a9d-9ea5-8fcd512df775';
  late Directory namespace;
  setUp(() async {
    final allocated = await Directory.systemTemp.createTemp('c1-restart-test-');
    namespace = Directory(await allocated.resolveSymbolicLinks());
  });
  tearDown(() async {
    if (await namespace.exists()) await namespace.delete(recursive: true);
  });

  test('closed fixture refuses a new import owner before touching its path', () async {
    final fixture = await C1RestartFixture.open(
      namespace: namespace,
      fixtureId: id,
    );
    await fixture.prepare();
    await fixture.close();
    final targetPath = Directory(p.join(fixture.root.path, 'import-target'));
    try {
      await expectLater(
        fixture.ensureImportTarget(),
        throwsA(
          isA<C1QaException>().having((e) => e.code, 'code', 'fixture_closed'),
        ),
      );
      expect(await targetPath.exists(), isFalse);
      expect(fixture.target, isNull);
    } finally {
      // The old implementation can create this owner. Close it explicitly on
      // the red path; never call unsafe recursive cleanup with its handle live.
      fixture.target?.dispose();
      await fixture.target?.repository.store.close();
    }
  });

  test(
    'close drains owners and preserves the root until every close succeeds',
    () async {
      var failOrigin = true;
      final attempts = <String>[];
      final fixture = await C1RestartFixture.open(
        namespace: namespace,
        fixtureId: id,
        closeResource: (owner, close) async {
          attempts.add(owner);
          if (owner == 'origin_store' && failOrigin) {
            throw StateError('Synthetic close retained the origin owner');
          }
          await close();
        },
      );
      await fixture.prepare();
      try {
        await expectLater(fixture.close(), throwsStateError);
        // This assertion fails on the prior early-return implementation before
        // the test can attempt unsafe cleanup with an unreleased owner.
        expect(attempts, ['origin_store', 'target_store', 'preferences']);
        await expectLater(fixture.cleanup(), throwsStateError);
        expect(await fixture.root.exists(), isTrue);
        expect(
          await fixture.originStore.readDocument(),
          isA<CapabilitySuccess<DocumentSnapshot?>>(),
        );
        expect(attempts.where((owner) => owner == 'preferences'), hasLength(1));
        expect(
          attempts.where((owner) => owner == 'target_store'),
          hasLength(1),
        );
        failOrigin = false;
        await fixture.cleanup();
        expect(await fixture.root.exists(), isFalse);
      } finally {
        // Also releases actual handles if the initial red assertion fails.
        failOrigin = false;
        await fixture.originStore.close();
        await fixture.preferences.close();
      }
    },
  );

  test(
    'marked fixture reopens exact state without preparing it again',
    () async {
      final first = await C1RestartFixture.open(
        namespace: namespace,
        fixtureId: id,
      );
      addTearDown(first.close);
      await first.prepare();
      final before = await first.report();
      expect(before['checkpointExact'], isTrue);
      expect(before['products'], hasLength(3));
      expect(before['stockEntries'], 2);
      final revision = first.origin.repository.snapshot!.revision;
      await first.close();

      final reopened = await C1RestartFixture.open(
        namespace: namespace,
        fixtureId: id,
      );
      addTearDown(reopened.close);
      expect(reopened.initializedThisLaunch, isFalse);
      expect((await reopened.report())['checkpointExact'], isTrue);
      expect(reopened.origin.repository.snapshot!.revision, revision);
      await expectLater(reopened.prepare(), throwsA(isA<C1QaException>()));
    },
  );

  test('existing intent cannot reconstruct a missing account store', () async {
    final first = await C1RestartFixture.open(
      namespace: namespace,
      fixtureId: id,
    );
    addTearDown(first.close);
    await first.prepare();
    final accountRoot = first.originDirectory;
    await first.close();
    await accountRoot.delete(recursive: true);
    await expectLater(
      C1RestartFixture.open(namespace: namespace, fixtureId: id),
      throwsA(isA<C1QaException>()),
    );
    expect(await accountRoot.exists(), isFalse);
  });

  test('unknown ownership marker is preserved and refused', () async {
    await File(p.join(namespace.path, '.c1-restart-namespace'))
        .writeAsString('unknown owner');
    await expectLater(
      C1RestartFixture.open(namespace: namespace, fixtureId: id),
      throwsA(isA<C1QaException>()),
    );
    expect(
      await File(p.join(namespace.path, '.c1-restart-namespace'))
          .readAsString(),
      'unknown owner',
    );
  });

  test(
    'real file bytes pass export, preview and separate-store import',
    () async {
      final fixture = await C1RestartFixture.open(
        namespace: namespace,
        fixtureId: id,
      );
      addTearDown(fixture.close);
      await fixture.prepare();
      final file = File(p.join(fixture.root.path, 'test-export.json'));
      final transfer = NativeFileTransfer(
        maxBytes: 20 * 1024 * 1024,
        fileName: 'test-export.json',
        mimeType: 'application/json',
        save: (bytes) async {
          await file.writeAsBytes(bytes, flush: true);
          return file.uri;
        },
        pick: () => file.readAsBytes(),
      );
      expect(await fixture.exportUsing(transfer), 'exported');
      expect(await fixture.selectImportUsing(transfer), 'selected');
      expect(await fixture.confirmImport(), 'imported');
      final report = await fixture.report();
      expect(report['importExact'], isTrue);
      expect(report['checkpointExact'], isTrue);
      expect(report['preImportBackupPresent'], isTrue);
      expect(
        fixture.target!.repository.document!.toJson(),
        fixture.origin.repository.document!.toJson(),
      );
    },
  );
}
