import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounts/account_document.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';

class UnknownAckStore implements LocalDocumentWorkspaceStore {
  UnknownAckStore(this.inner);
  final LocalDocumentWorkspaceStore inner;
  bool injectUnknownRead = false;
  int resolveCalls = 0;

  @override
  Future<CapabilityResult<DocumentSnapshot?>> readDocument() async {
    if (injectUnknownRead) {
      injectUnknownRead = false;
      return const CapabilityFailure(
        DocumentErrorCodes.commitUnknown,
        'Simulated unknown write acknowledgement.',
      );
    }
    return inner.readDocument();
  }

  @override
  Future<CapabilityResult<void>> resolvePendingWrite() async {
    resolveCalls++;
    return inner.resolvePendingWrite();
  }

  @override
  Future<CapabilityResult<DocumentSnapshot>> writeDocument(
    String payload, {
    required String writeToken,
    DocumentSnapshot? expected,
    bool replaceGeneration = false,
  }) => inner.writeDocument(
    payload,
    writeToken: writeToken,
    expected: expected,
    replaceGeneration: replaceGeneration,
  );

  @override
  Future<CapabilityResult<DocumentSnapshot>> resumeInitialCreation(
    String payload, {
    required String writeToken,
  }) => inner.resumeInitialCreation(payload, writeToken: writeToken);

  @override
  Future<CapabilityResult<WorkspaceState>> readWorkspace(StorageFence fence) =>
      inner.readWorkspace(fence);

  @override
  Future<CapabilityResult<WorkspaceSnapshot>> writeWorkspace(
    String payload, {
    required StorageFence fence,
    required int? expectedRevision,
    required String writeToken,
  }) => inner.writeWorkspace(
    payload,
    fence: fence,
    expectedRevision: expectedRevision,
    writeToken: writeToken,
  );

  @override
  Future<CapabilityResult<PreviousDocument?>> readPrevious() =>
      inner.readPrevious();

  @override
  Future<CapabilityResult<String>> preserveSource(List<int> bytes) =>
      inner.preserveSource(bytes);

  @override
  Future<CapabilityResult<DocumentSnapshot>> recoverPrevious(
    PreviousDocument previous, {
    required String payload,
    required String writeToken,
  }) =>
      inner.recoverPrevious(previous, payload: payload, writeToken: writeToken);

  @override
  Future<void> close() => inner.close();
}

void main() {
  const legacyCodec = LegacyAccountCodec();
  const codec = PortableJournalCodec();

  final corpus = jsonDecode(
    File('test/fixtures/accounts/oracle.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final cases = (corpus['cases'] as List).cast<Map<String, dynamic>>();

  AccountDocument sampleAccountDocument() {
    final sample = cases.firstWhere((s) => s['name'] == 'all-entities-history');
    final input = sample['input'] as Map<String, dynamic>;
    return legacyCodec.decodeJson(Map<String, Object?>.from(input));
  }

  DateOnly testDate(String iso) =>
      DateOnly.parse(iso, minimumYear: 1000, maximumYear: 9999);

  group('PortableJournalState Durable Command Store Conformance', () {
    late Directory tempDir;
    final openStores = <PowerSyncLocalDocumentWorkspaceStore>[];

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'dakhl-portable-journal-store-',
      );
    });

    tearDown(() async {
      for (final s in openStores) {
        try {
          await s.close();
        } catch (_) {}
      }
      openStores.clear();
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    Future<PowerSyncLocalDocumentWorkspaceStore> openStore() async {
      final res = await PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: tempDir.path,
      );
      if (res is! CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>) {
        throw StateError('Failed to open store: $res');
      }
      final s = res.value;
      openStores.add(s);
      return s;
    }

    test(
      'isolated single store owner coordinates durable command lifecycle',
      () async {
        final store = await openStore();
        final coordinator = DurableCommandCoordinator(store: store);

        final initialDoc = sampleAccountDocument();
        final initialV12 = codec.enrollLegacyDocument(
          initialDoc,
          accountLineage: 'store-conformance-lineage-1',
        );

        // Seed initial v12 document in store
        final initialPayload = codec.encodeState(initialV12);
        final seedRes = await store.writeDocument(
          initialPayload,
          writeToken: 'seed-token-1',
        );
        expect(seedRes, isA<CapabilitySuccess<DocumentSnapshot>>());
        final seedSnap = (seedRes as CapabilitySuccess<DocumentSnapshot>).value;
        expect(seedSnap.revision, 1);

        // Execute command 1: post a valid balanced sale journal
        const cmd1Identity = DurableCommandIdentity(
          operationId: 'cmd-sale-001',
          payloadVersion: 1,
          canonicalPayloadIdentity: 'sale-hash-1',
        );

        final result1 = await coordinator
            .executeCommand<PortableJournalState, String>(
              identity: cmd1Identity,
              codec: codec,
              proposal: (currentState, currentFence) {
                expect(currentState, isNotNull);
                final journal = BalancedJournal.validate(
                  id: 'journal-sale-101',
                  effectiveDate: testDate('2026-11-07'),
                  policy: JournalPolicy(
                    currency: 'IQD',
                    scale: 0,
                    maximumLineUnits: BigInt.from(1000000000000),
                    maximumSideUnits: BigInt.from(1000000000000),
                    maximumLines: 500,
                    allowZeroLines: false,
                  ),
                  lines: [
                    JournalLine(
                      accountId: 'asset:cash:daily',
                      side: JournalSide.debit,
                      amountUnits: BigInt.from(18000),
                      currency: 'IQD',
                      scale: 0,
                    ),
                    JournalLine(
                      accountId: 'revenue:sales',
                      side: JournalSide.credit,
                      amountUnits: BigInt.from(18000),
                      currency: 'IQD',
                      scale: 0,
                    ),
                  ],
                );
                final nextState = currentState!.addJournal(
                  PortableJournalEntry(
                    journal: journal,
                    sourceType: 'sale',
                    sourceRecordId: 'sale-item-1',
                    recordedAt: '2026-11-07T14:00:00.000Z',
                  ),
                );
                return DurableProposalEvaluation.accept(
                  candidateState: nextState,
                  outcome: 'sale_posted_101',
                );
              },
            );

        expect(result1, isA<DurableCommandSuccess<String>>());
        final success1 = result1 as DurableCommandSuccess<String>;
        expect(success1.outcome, 'sale_posted_101');
        expect(success1.receipt.identity, cmd1Identity);
        expect(success1.receipt.sequence, 1);
        expect(success1.snapshot.revision, 2);

        // Replay command 1 with identical identity: returns DurableCommandReplayed
        final replay1 = await coordinator
            .executeCommand<PortableJournalState, String>(
              identity: cmd1Identity,
              codec: codec,
              proposal: (currentState, currentFence) => throw StateError(
                'Proposal should not be evaluated on replay',
              ),
            );
        expect(replay1, isA<DurableCommandReplayed<String>>());
        final replayed1 = replay1 as DurableCommandReplayed<String>;
        expect(replayed1.receipt.identity, cmd1Identity);
        expect(replayed1.snapshot.revision, 2); // No new revision!

        // Changed payload with same operationId: fails closed with changed_payload_rejected
        const changedCmd1 = DurableCommandIdentity(
          operationId: 'cmd-sale-001',
          payloadVersion: 1,
          canonicalPayloadIdentity: 'different-hash-tampered',
        );
        final changedResult = await coordinator
            .executeCommand<PortableJournalState, String>(
              identity: changedCmd1,
              codec: codec,
              proposal: (currentState, currentFence) => throw StateError(
                'Proposal should not be evaluated on tampered replay',
              ),
            );
        expect(changedResult, isA<DurableCommandFailure<String>>());
        final failure = changedResult as DurableCommandFailure<String>;
        expect(failure.code, DurableCommandErrorCodes.changedPayloadRejected);

        // Execute command 2: sequential command
        const cmd2Identity = DurableCommandIdentity(
          operationId: 'cmd-expense-002',
          payloadVersion: 1,
          canonicalPayloadIdentity: 'expense-hash-2',
        );
        final result2 = await coordinator
            .executeCommand<PortableJournalState, String>(
              identity: cmd2Identity,
              codec: codec,
              proposal: (currentState, currentFence) {
                final journal = BalancedJournal.validate(
                  id: 'journal-exp-102',
                  effectiveDate: testDate('2026-11-07'),
                  policy: JournalPolicy(
                    currency: 'IQD',
                    scale: 0,
                    maximumLineUnits: BigInt.from(1000000000000),
                    maximumSideUnits: BigInt.from(1000000000000),
                    maximumLines: 500,
                    allowZeroLines: false,
                  ),
                  lines: [
                    JournalLine(
                      accountId: 'expense:supplies',
                      side: JournalSide.debit,
                      amountUnits: BigInt.from(5000),
                      currency: 'IQD',
                      scale: 0,
                    ),
                    JournalLine(
                      accountId: 'asset:cash:daily',
                      side: JournalSide.credit,
                      amountUnits: BigInt.from(5000),
                      currency: 'IQD',
                      scale: 0,
                    ),
                  ],
                );
                final nextState = currentState!.addJournal(
                  PortableJournalEntry(
                    journal: journal,
                    sourceType: 'expense',
                    recordedAt: '2026-11-07T15:00:00.000Z',
                  ),
                );
                return DurableProposalEvaluation.accept(
                  candidateState: nextState,
                  outcome: 'expense_posted_102',
                );
              },
            );
        expect(result2, isA<DurableCommandSuccess<String>>());
        final success2 = result2 as DurableCommandSuccess<String>;
        expect(success2.receipt.sequence, 2);
        expect(success2.snapshot.revision, 3);

        // Verify readback from store: all journals and receipts intact
        final readRes = await store.readDocument();
        expect(readRes, isA<CapabilitySuccess<DocumentSnapshot?>>());
        final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
        final persistedState = codec.decodeState(snap.payload);
        expect(persistedState.journals.length, 2);
        expect(persistedState.receipts.length, 2);
        expect(persistedState.receipts[0].identity.operationId, 'cmd-sale-001');
        expect(
          persistedState.receipts[1].identity.operationId,
          'cmd-expense-002',
        );
        expect(persistedState.accountLineage, 'store-conformance-lineage-1');

        // Close store and reopen from disk: verifies durability
        await store.close();
        openStores.remove(store);

        final reopenedStore = await openStore();
        final reopenedRead = await reopenedStore.readDocument();
        final reopenedSnap =
            (reopenedRead as CapabilitySuccess<DocumentSnapshot?>).value!;
        expect(reopenedSnap.revision, 3);
        final reopenedState = codec.decodeState(reopenedSnap.payload);
        expect(reopenedState.journals.length, 2);
        expect(reopenedState.receipts.length, 2);
        expect(reopenedState.receipts[1].sequence, 2);
      },
    );

    test('reopen/restore fence replacement rejects commands targeting stale generation fence', () async {
      final store = await openStore();
      final coordinator = DurableCommandCoordinator(store: store);

      final initialDoc = sampleAccountDocument();
      final initialV12 = codec.enrollLegacyDocument(
        initialDoc,
        accountLineage: 'fence-lineage-test',
      );

      final seedRes = await store.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'fence-seed',
      );
      final seedSnap = (seedRes as CapabilitySuccess<DocumentSnapshot>).value;
      final originalFence = seedSnap.fence;

      // Now simulate a restore/replacement with replaceGeneration: true
      final replacedRes = await store.writeDocument(
        seedSnap.payload,
        expected: seedSnap,
        writeToken: 'restore-replacement-token',
        replaceGeneration: true,
      );
      expect(replacedRes, isA<CapabilitySuccess<DocumentSnapshot>>());
      final replacedSnap =
          (replacedRes as CapabilitySuccess<DocumentSnapshot>).value;
      expect(replacedSnap.fence.generation, isNot(originalFence.generation));

      // Attempt command with old expected fence: fails with stale_authority_fence
      const staleCmd = DurableCommandIdentity(
        operationId: 'cmd-stale-fence',
        payloadVersion: 1,
        canonicalPayloadIdentity: 'stale-hash',
      );
      final staleResult = await coordinator
          .executeCommand<PortableJournalState, String>(
            identity: staleCmd,
            codec: codec,
            expectedFence: originalFence, // Stale!
            proposal: (state, fence) => DurableProposalEvaluation.accept(
              candidateState: state!,
              outcome: 'should_not_reach',
            ),
          );
      expect(staleResult, isA<DurableCommandFailure<String>>());
      final fail = staleResult as DurableCommandFailure<String>;
      expect(fail.code, DurableCommandErrorCodes.staleAuthorityFence);
    });

    test('unknown acknowledgement triggers resolvePendingWrite and succeeds upon resolution', () async {
      final realStore = await openStore();
      final unknownStore = UnknownAckStore(realStore);
      final coordinator = DurableCommandCoordinator(store: unknownStore);

      final initialDoc = sampleAccountDocument();
      final initialV12 = codec.enrollLegacyDocument(
        initialDoc,
        accountLineage: 'ack-lineage-test',
      );
      await unknownStore.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'ack-seed',
      );

      // Inject unknown on read
      unknownStore.injectUnknownRead = true;

      const ackCmd = DurableCommandIdentity(
        operationId: 'cmd-ack-resolve-001',
        payloadVersion: 1,
        canonicalPayloadIdentity: 'ack-hash-1',
      );

      final result = await coordinator
          .executeCommand<PortableJournalState, String>(
            identity: ackCmd,
            codec: codec,
            proposal: (state, fence) => DurableProposalEvaluation.accept(
              candidateState: state!,
              outcome: 'resolved_success',
            ),
          );

      expect(unknownStore.resolveCalls, 1);
      expect(result, isA<DurableCommandSuccess<String>>());
      final success = result as DurableCommandSuccess<String>;
      expect(success.outcome, 'resolved_success');
      expect(success.receipt.identity, ackCmd);
    });
  });
}
