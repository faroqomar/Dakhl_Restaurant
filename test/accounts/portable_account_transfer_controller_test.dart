import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_account_transfer_controller.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';

import 'accounts_view_model_test.dart' show FixtureStore;

final class RecordingTransfer implements FileTransferCapability {
  Uint8List? savedBytes;
  CapabilityResult<Uint8List>? openResult;
  bool throwOnOpen = false;
  bool throwOnSave = false;

  @override
  Future<CapabilityResult<Uint8List>> open() async {
    if (throwOnOpen) throw StateError('Transfer open failure');
    return openResult ?? const CapabilityCancelled();
  }

  @override
  Future<CapabilityResult<void>> save(Uint8List bytes) async {
    if (throwOnSave) throw StateError('Transfer save failure');
    savedBytes = bytes;
    return const CapabilitySuccess(null);
  }
}

final class UnknownRecoveryStore implements LocalDocumentWorkspaceStore {
  UnknownRecoveryStore(this.delegate);
  final FixtureStore delegate;
  int recoveries = 0;
  @override
  Future<CapabilityResult<DocumentSnapshot?>> readDocument() =>
      delegate.readDocument();
  @override
  Future<CapabilityResult<PreviousDocument?>> readPrevious() =>
      delegate.readPrevious();
  @override
  Future<CapabilityResult<String>> preserveSource(List<int> bytes) =>
      delegate.preserveSource(bytes);
  @override
  Future<CapabilityResult<void>> resolvePendingWrite() =>
      delegate.resolvePendingWrite();
  @override
  Future<CapabilityResult<DocumentSnapshot>> recoverPrevious(
    PreviousDocument previous, {
    required String payload,
    required String writeToken,
  }) async {
    recoveries++;
    await delegate.recoverPrevious(
      previous,
      payload: payload,
      writeToken: writeToken,
    );
    return const CapabilityFailure(
      'recovery_publication_unknown',
      'Lost publication acknowledgement',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const codec = PortableJournalCodec();
  late FixtureStore store;
  late PortableAccountTransferController controller;
  late PortableJournalState initialState;
  var writeBlocked = false;

  PortableJournalState createSampleState({
    required String lineage,
    required String restaurantName,
    String? journalId,
  }) {
    final date = DateOnly.parse(
      '2026-11-01',
      minimumYear: 1000,
      maximumYear: 9999,
    );
    final emptyDoc = const LegacyAccountCodec().empty();
    final docJson = Map<String, Object?>.from(emptyDoc.toJson());
    final prefs = Map<String, Object?>.from(docJson['preferences'] as Map);
    final rest = Map<String, Object?>.from(prefs['restaurant'] as Map);
    rest['name'] = restaurantName;
    prefs['restaurant'] = rest;
    docJson['preferences'] = prefs;
    final account = const LegacyAccountCodec().decodeJson(docJson);

    final jId = journalId ?? 'opening-1';
    final opening = RestaurantJournalMapper().mapVerifiedCutoverOpening(
      journalId: jId,
      effectiveDate: date,
      verifiedPhysicalRegisterCash: BigInt.from(50000),
      verifiedCashboxBalance: BigInt.zero,
      verifiedSupplierDebts: {},
    );

    return PortableJournalState(
      accountLineage: lineage,
      account: account,
      sourceProvenance: const PortableJournalSourceProvenance(
        sourceVersion: 11,
        enrolledAt: '2026-11-01T00:00:00Z',
        migrated: false,
      ),
      cutoverState: PortableJournalCutoverState.established(
        cutoverDate: date,
        openingJournalId: jId,
      ),
      journals: [
        PortableJournalEntry(
          journal: opening.journal,
          sourceType: RestaurantJournalSourceType.cutoverOpening.name,
          sourceRecordId: '$jId-src',
          recordedAt: '2026-11-01T00:00:00Z',
        ),
      ],
      receipts: [
        const DurableCommandReceipt(
          identity: DurableCommandIdentity(
            operationId: 'receipt-initial-1',
            payloadVersion: 1,
            canonicalPayloadIdentity: 'hash-initial-1',
          ),
          status: DurableCommandStatus.committed,
          committedRevision: 1,
          fence: StorageFence(storeId: 'test-store', generation: 'gen-init'),
          sequence: 1,
          outcomePayload: '{"status":"ok"}',
        ),
      ],
    );
  }

  setUp(() async {
    writeBlocked = false;
    initialState = createSampleState(
      lineage: 'lineage-alpha',
      restaurantName: 'مطعم الأصالة',
      journalId: 'opening-alpha',
    );
    store = FixtureStore();
    final seed = await store.writeDocument(
      codec.encodeState(initialState),
      writeToken: 'initial-seed',
    );
    final snapshot = (seed as CapabilitySuccess<DocumentSnapshot>).value;
    controller = PortableAccountTransferController(
      store: store,
      snapshot: snapshot,
      isWriteBlocked: () => writeBlocked,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  test(
    'previous recovery preserves complete envelope and creates fresh authority',
    () async {
      final previous = controller.snapshot;
      final successor = createSampleState(
        lineage: 'lineage-beta',
        restaurantName: 'New',
      );
      final saved = await store.writeDocument(
        codec.encodeState(successor),
        writeToken: 'later',
        expected: previous,
      );
      expect(saved, isA<CapabilitySuccess<DocumentSnapshot>>());
      await controller.reload();
      final fence = controller.authorityFence;
      final selected = await controller.preparePrevious();
      expect(selected, isA<CapabilitySuccess<PendingPortableAccountImport>>());
      expect(controller.pendingImport!.isRecovery, isTrue);
      expect(controller.pendingImport!.state.accountLineage, 'lineage-alpha');
      expect(controller.pendingImport!.state.journals.length, 1);
      expect(controller.pendingImport!.state.receipts.length, 1);
      expect(await controller.confirmImport(), isA<CapabilitySuccess<void>>());
      expect(controller.authorityFence, isNot(fence));
      expect(controller.accountLineage, 'lineage-alpha');
      expect(controller.journals.first.journal.id, 'opening-alpha');
      expect(
        controller.receipts.first.identity.operationId,
        'receipt-initial-1',
      );
      expect(controller.hasPendingImport, isFalse);
    },
  );

  test(
    'previous selection refuses legacy bytes and blocks dirty peers',
    () async {
      store.previous = PreviousDocument(
        snapshot: DocumentSnapshot(
          payload: utf8.decode(
            const LegacyAccountCodec().encode(
              const LegacyAccountCodec().empty(),
            ),
          ),
          revision: 1,
          fence: controller.authorityFence,
          writeToken: 'old',
        ),
        identity: 'legacy',
      );
      expect(
        await controller.preparePrevious(),
        isA<CapabilityFailure<PendingPortableAccountImport>>(),
      );
      expect(controller.hasPendingImport, isFalse);
      final writes = store.writes;
      writeBlocked = true;
      expect(
        await controller.preparePrevious(),
        isA<CapabilityFailure<PendingPortableAccountImport>>(),
      );
      expect(store.writes, writes);
    },
  );

  test('unknown previous recovery reconciles exact token without a second publication', () async {
    store.previous = PreviousDocument(
      snapshot: controller.snapshot,
      identity: 'saved-copy',
    );
    final uncertain = UnknownRecoveryStore(store);
    final initial = controller.snapshot;
    controller.dispose();
    controller = PortableAccountTransferController(
      store: uncertain,
      snapshot: initial,
      isWriteBlocked: () => writeBlocked,
    );
    expect(
      await controller.preparePrevious(),
      isA<CapabilitySuccess<PendingPortableAccountImport>>(),
    );
    expect(await controller.confirmImport(), isA<CapabilityFailure<void>>());
    expect(controller.needsReadback, isTrue);
    expect(await controller.confirmImport(), isA<CapabilityFailure<void>>());
    expect(uncertain.recoveries, 1);
    expect(await controller.reconcile(), isA<CapabilitySuccess<void>>());
    expect(controller.needsReadback, isFalse);
    expect(controller.snapshot.fence, store.document!.fence);
    expect(controller.journals.length, 1);
    expect(controller.receipts.length, 1);
    expect(uncertain.recoveries, 1);
  });

  group('Initialization and Export', () {
    test(
      'explicitly binds snapshot, authority fence and complete envelope',
      () {
        expect(controller.accountLineage, 'lineage-alpha');
        expect(
          controller.account.preferences.restaurant['name'],
          'مطعم الأصالة',
        );
        expect(controller.journals.length, 1);
        expect(controller.journals.first.journal.id, 'opening-alpha');
        expect(controller.receipts.length, 1);
        expect(
          controller.receipts.first.identity.operationId,
          'receipt-initial-1',
        );
        expect(controller.cutoverState.isGated, false);
        expect(controller.cutoverState.openingJournalId, 'opening-alpha');
        expect(controller.busy, false);
        expect(controller.needsReadback, false);
        expect(controller.hasPendingImport, false);
        expect(controller.authorityFence, store.document!.fence);
      },
    );

    test('exportBytes produces exact canonical UTF-8 bytes for version 12 envelope', () {
      final bytes = controller.exportBytes();
      expect(bytes, isNotEmpty);
      final decoded = codec.decodeBytes(bytes);
      expect(decoded.version, 12);
      expect(decoded.accountLineage, 'lineage-alpha');
      expect(decoded.journals.length, 1);
      expect(decoded.receipts.length, 1);
      expect(decoded.account.preferences.restaurant['name'], 'مطعم الأصالة');
    });

    test('exportTo saves exact bytes through FileTransferCapability', () async {
      final transfer = RecordingTransfer();
      final result = await controller.exportTo(transfer);
      expect(result, isA<CapabilitySuccess<void>>());
      expect(transfer.savedBytes, isNotNull);
      expect(transfer.savedBytes, controller.exportBytes());
      final decoded = codec.decodeBytes(transfer.savedBytes!);
      expect(decoded.accountLineage, 'lineage-alpha');
    });

    test(
      'exportTo fails when write is blocked or controller is busy',
      () async {
        writeBlocked = true;
        final transfer = RecordingTransfer();
        final result = await controller.exportTo(transfer);
        expect((result as CapabilityFailure<void>).code, 'busy');
        expect(transfer.savedBytes, isNull);
      },
    );
  });

  group('Import Preparation and Bounds', () {
    test(
      'prepareImport validates complete envelope and preserves original bytes',
      () {
        final candidateState = createSampleState(
          lineage: 'lineage-beta',
          restaurantName: 'مطعم النخيل',
          journalId: 'opening-beta',
        );
        final candidateBytes = codec.encodeBytes(candidateState);

        final result = controller.prepareImport(candidateBytes);
        expect(result, isA<CapabilitySuccess<PendingPortableAccountImport>>());
        expect(controller.hasPendingImport, true);
        expect(controller.pendingImport!.state.accountLineage, 'lineage-beta');
        expect(
          controller
              .pendingImport!
              .state
              .account
              .preferences
              .restaurant['name'],
          'مطعم النخيل',
        );
        expect(controller.pendingImport!.originalBytes, candidateBytes);
        expect(controller.pendingImport!.byteLength, candidateBytes.length);

        // Verify current controller state was not mutated
        expect(controller.accountLineage, 'lineage-alpha');
        expect(
          controller.account.preferences.restaurant['name'],
          'مطعم الأصالة',
        );
      },
    );

    test('prepareImport rejects empty and oversized payloads', () {
      final emptyResult = controller.prepareImport(const []);
      expect((emptyResult as CapabilityFailure).code, 'invalid_payload');
      expect(controller.hasPendingImport, false);

      final oversizedBytes = Uint8List(DocumentLimits.accountBytes + 1);
      final oversizedResult = controller.prepareImport(oversizedBytes);
      expect((oversizedResult as CapabilityFailure).code, 'payload_too_large');
      expect(controller.hasPendingImport, false);
    });

    test('prepareImport rejects legacy schema 11 and corrupt payloads', () {
      final legacyDoc = const LegacyAccountCodec().empty();
      final legacyBytes = const LegacyAccountCodec().encode(legacyDoc);

      final legacyResult = controller.prepareImport(legacyBytes);
      expect((legacyResult as CapabilityFailure).code, 'unsupported_fields');
      expect(controller.hasPendingImport, false);

      final corruptBytes = utf8.encode('{ "corrupt": true }');
      final corruptResult = controller.prepareImport(corruptBytes);
      expect((corruptResult as CapabilityFailure).code, 'unsupported_fields');
      expect(controller.hasPendingImport, false);

      final malformedBytes = utf8.encode('not json');
      final malformedResult = controller.prepareImport(malformedBytes);
      expect((malformedResult as CapabilityFailure).code, 'corrupt_state');
      expect(controller.hasPendingImport, false);
    });

    test(
      'pickImport handles transfer open success, cancellation, and error',
      () async {
        final candidateState = createSampleState(
          lineage: 'lineage-picked',
          restaurantName: 'مطعم الشاطئ',
          journalId: 'opening-picked',
        );
        final candidateBytes = codec.encodeBytes(candidateState);

        // Successful pick
        final successTransfer = RecordingTransfer()
          ..openResult = CapabilitySuccess(candidateBytes);
        final successRes = await controller.pickImport(successTransfer);
        expect(
          successRes,
          isA<CapabilitySuccess<PendingPortableAccountImport>>(),
        );
        expect(controller.hasPendingImport, true);
        expect(
          controller.pendingImport!.state.accountLineage,
          'lineage-picked',
        );

        // Cancel import
        controller.cancelImport();
        expect(controller.hasPendingImport, false);

        // Cancelled transfer
        final cancelledTransfer = RecordingTransfer()
          ..openResult = const CapabilityCancelled();
        final cancelRes = await controller.pickImport(cancelledTransfer);
        expect(
          cancelRes,
          isA<CapabilityCancelled<PendingPortableAccountImport>>(),
        );
        expect(controller.hasPendingImport, false);

        // Unreadable transfer failure
        final failingTransfer = RecordingTransfer()..throwOnOpen = true;
        final failRes = await controller.pickImport(failingTransfer);
        expect((failRes as CapabilityFailure).code, 'file_unreadable');
        expect(controller.hasPendingImport, false);
      },
    );
  });

  group('Fenced Replacement and Reconciliation', () {
    test('confirmImport preserves source bytes, replaces generation fence, and commits state', () async {
      final candidateState = createSampleState(
        lineage: 'lineage-replacement',
        restaurantName: 'مطعم الأمل',
        journalId: 'opening-replacement',
      );
      final candidateBytes = codec.encodeBytes(candidateState);
      controller.prepareImport(candidateBytes);

      final initialFence = controller.authorityFence;
      expect(store.archives, 0);

      final result = await controller.confirmImport();
      expect(result, isA<CapabilitySuccess<void>>());

      // 1. Original bytes preserved
      expect(store.archives, 1);

      // 2. Generation fence replaced (different generation)
      expect(
        controller.authorityFence.generation,
        isNot(initialFence.generation),
      );

      // 3. New state adopted
      expect(controller.accountLineage, 'lineage-replacement');
      expect(controller.account.preferences.restaurant['name'], 'مطعم الأمل');
      expect(controller.journals.first.journal.id, 'opening-replacement');
      expect(controller.hasPendingImport, false);

      // 4. Store contains valid version 12 payload with the replaced generation
      final persisted = codec.decodeState(store.document!.payload);
      expect(persisted.accountLineage, 'lineage-replacement');
      expect(persisted.account.preferences.restaurant['name'], 'مطعم الأمل');
    });

    test(
      'confirmImport detects stale revision conflict before writing',
      () async {
        final candidateState = createSampleState(
          lineage: 'lineage-conflict',
          restaurantName: 'مطعم الصراع',
        );
        controller.prepareImport(codec.encodeBytes(candidateState));

        // Concurrently advance store revision
        await store.writeDocument(
          codec.encodeState(initialState),
          writeToken: 'concurrent-writer',
          expected: store.document,
        );

        final result = await controller.confirmImport();
        expect((result as CapabilityFailure).code, 'stale_revision');
        expect(controller.requiresReload, true);
        expect(controller.accountLineage, 'lineage-alpha');

        // Reloading recovers latest store state
        expect(
          await controller.reload(discardPendingImport: true),
          isA<CapabilitySuccess<void>>(),
        );
        expect(controller.requiresReload, false);
        expect(controller.hasPendingImport, false);
      },
    );

    test('unknown commit outcome requires reconciliation and recovers upon confirmation', () async {
      final candidateState = createSampleState(
        lineage: 'lineage-unknown',
        restaurantName: 'مطعم مجهول الحسم',
      );
      final candidateBytes = codec.encodeBytes(candidateState);
      controller.prepareImport(candidateBytes);

      // Inject lost acknowledgement after store commit
      store.throwAfterCommit = true;

      final result = await controller.confirmImport();
      expect((result as CapabilityFailure).code, 'commit_unknown');
      expect(controller.needsReadback, true);

      // Any normal write or export is blocked during needsReadback
      final transfer = RecordingTransfer();
      expect(
        (await controller.exportTo(transfer) as CapabilityFailure).code,
        'commit_unknown',
      );
      expect(
        (await controller.confirmImport() as CapabilityFailure).code,
        'commit_unknown',
      );
      expect(
        (await controller.reload() as CapabilityFailure).code,
        'commit_unknown',
      );

      // Reconcile successfully verifies the committed write
      expect(await controller.reconcile(), isA<CapabilitySuccess<void>>());
      expect(controller.needsReadback, false);
      expect(controller.accountLineage, 'lineage-unknown');
      expect(
        controller.account.preferences.restaurant['name'],
        'مطعم مجهول الحسم',
      );
    });
  });
}
