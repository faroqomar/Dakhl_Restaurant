import 'package:dakhl_restaurant/accounting/restaurant_journal_sale_commands.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_spending_commands.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/journal_command_host.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';

class _FakeStore implements LocalDocumentWorkspaceStore {
  _FakeStore();
  final StorageFence fence = const StorageFence(
    storeId: 'store-1',
    generation: 'gen-1',
  );
  int readCalls = 0;
  int writeCalls = 0;

  @override
  Future<CapabilityResult<DocumentSnapshot?>> readDocument() async {
    readCalls++;
    return CapabilitySuccess(
      DocumentSnapshot(
        payload: '{}',
        revision: 1,
        writeToken: 'wt-1',
        fence: fence,
      ),
    );
  }

  @override
  Future<CapabilityResult<DocumentSnapshot>> writeDocument(
    String payload, {
    required String writeToken,
    DocumentSnapshot? expected,
    bool replaceGeneration = false,
  }) async {
    writeCalls++;
    return CapabilitySuccess(
      DocumentSnapshot(
        payload: payload,
        revision: (expected?.revision ?? 0) + 1,
        writeToken: writeToken,
        fence: fence,
      ),
    );
  }

  @override
  Future<CapabilityResult<DocumentSnapshot>> resumeInitialCreation(
    String payload, {
    required String writeToken,
  }) async => throw UnimplementedError();

  @override
  Future<CapabilityResult<WorkspaceState>> readWorkspace(
    StorageFence fence,
  ) async => throw UnimplementedError();

  @override
  Future<CapabilityResult<WorkspaceSnapshot>> writeWorkspace(
    String payload, {
    required StorageFence fence,
    required int? expectedRevision,
    required String writeToken,
  }) async => throw UnimplementedError();

  @override
  Future<CapabilityResult<PreviousDocument?>> readPrevious() async =>
      const CapabilitySuccess(null);

  @override
  Future<CapabilityResult<String>> preserveSource(List<int> bytes) async =>
      const CapabilitySuccess('hash');

  @override
  Future<CapabilityResult<DocumentSnapshot>> recoverPrevious(
    PreviousDocument previous, {
    required String payload,
    required String writeToken,
  }) async => throw UnimplementedError();

  @override
  Future<CapabilityResult<void>> resolvePendingWrite() async =>
      const CapabilitySuccess(null);

  @override
  Future<void> close() async {}
}

void main() {
  test('sales coordinator refuses a host bound to another store owner', () {
    final store = _FakeStore();
    final otherStore = _FakeStore();
    expect(
      () => RestaurantJournalSaleCommandCoordinator(
        store: store,
        host: JournalCommandHost(store: otherStore),
      ),
      throwsArgumentError,
    );
    expect(store.readCalls + otherStore.readCalls, 0);
  });

  test('spending coordinator refuses a host bound to another store owner', () {
    final store = _FakeStore();
    final otherStore = _FakeStore();
    expect(
      () => RestaurantJournalSpendingCommandCoordinator(
        store: store,
        host: JournalCommandHost(store: otherStore),
      ),
      throwsArgumentError,
    );
    expect(store.readCalls + otherStore.readCalls, 0);
  });

  group('CommandSnapshot and Canonical Identity Tests', () {
    test('deeply freezes maps and collections recursively', () {
      final mutable = {
        'a': 1,
        'b': [
          'item1',
          {'nested': true},
        ],
      };
      final frozen = freezeMap(mutable);
      expect(frozen, isA<Map<String, Object?>>());
      expect(() => frozen['a'] = 2, throwsUnsupportedError);
      final list = frozen['b'] as List<Object?>;
      expect(() => list.add('item2'), throwsUnsupportedError);
      final nested = list[1] as Map<String, Object?>;
      expect(() => nested['nested'] = false, throwsUnsupportedError);
    });

    test('freezeList enforces maximum item count', () {
      final items = [1, 2, 3];
      expect(
        () => freezeList(items, maxCount: 2, errorCode: 'too_many'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'too_many',
          ),
        ),
      );
      final frozen = freezeList(items, maxCount: 5);
      expect(frozen, hasLength(3));
      expect(() => (frozen as dynamic).add(4), throwsUnsupportedError);
    });

    test('detects and rejects cyclical references', () {
      final mapA = <String, Object?>{};
      final mapB = <String, Object?>{'a': mapA};
      mapA['b'] = mapB;

      expect(
        () => freezeMap(mapA),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'invalid_command_payload',
          ),
        ),
      );
    });

    test('rejects recursion depth exceeding 100 levels', () {
      Map<String, Object?> current = {'leaf': true};
      for (var i = 0; i < 110; i++) {
        current = {'next': current};
      }
      expect(
        () => freezeMap(current),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'invalid_command_payload',
          ),
        ),
      );
    });

    test('rejects integers exceeding maximum safe aggregate', () {
      final tooBig = BigInt.parse('9007199254740992');
      expect(
        () => CommandSnapshot().copy(tooBig.toInt()),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects non-finite floating point numbers', () {
      expect(
        () => CommandSnapshot().copy(double.nan),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CommandSnapshot().copy(double.infinity),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'canonicalIdentity sorts map keys recursively and deterministically',
      () {
        final map1 = {
          'z': 1,
          'a': {'b': 2, 'a': 1},
        };
        final map2 = {
          'a': {'a': 1, 'b': 2},
          'z': 1,
        };
        expect(canonicalIdentity(map1), canonicalIdentity(map2));
        expect(canonicalIdentity(map1), '{"a":{"a":1,"b":2},"z":1}');
      },
    );

    test('canonicalIdentity is sensitive to value modifications', () {
      final map1 = {'k': 'v1'};
      final map2 = {'k': 'v2'};
      expect(canonicalIdentity(map1), isNot(canonicalIdentity(map2)));
    });
  });

  group('LineageScopedJournalCodec Tests', () {
    const legacyCodec = LegacyAccountCodec();
    const codec = PortableJournalCodec();

    PortableJournalState sampleState({
      required String accountLineage,
      bool isGated = false,
    }) {
      final cutover = isGated
          ? PortableJournalCutoverState.gated()
          : PortableJournalCutoverState.established(
              cutoverDate: DateOnly.parse(
                '2026-01-01',
                minimumYear: 1000,
                maximumYear: 9999,
              ),
              openingJournalId: 'open-1',
            );

      final openEntry = isGated
          ? null
          : PortableJournalEntry(
              journal: BalancedJournal.validate(
                id: 'open-1',
                effectiveDate: DateOnly.parse(
                  '2026-01-01',
                  minimumYear: 1000,
                  maximumYear: 9999,
                ),
                policy: RestaurantJournalPolicies.opening,
                lines: [
                  JournalLine(
                    accountId: 'asset:cash:daily',
                    side: JournalSide.debit,
                    amountUnits: BigInt.from(1000),
                    currency: 'IQD',
                    scale: 0,
                  ),
                  JournalLine(
                    accountId: 'equity:opening_balance',
                    side: JournalSide.credit,
                    amountUnits: BigInt.from(1000),
                    currency: 'IQD',
                    scale: 0,
                  ),
                ],
              ),
              sourceType: RestaurantJournalSourceType.cutoverOpening.name,
              sourceRecordId: 'open-rec',
              recordedAt: '2026-01-01T00:00:00.000Z',
            );

      return PortableJournalState(
        accountLineage: accountLineage,
        account: legacyCodec.empty(),
        sourceProvenance: const PortableJournalSourceProvenance(
          sourceVersion: 11,
          enrolledAt: '2026-01-01T00:00:00.000Z',
          migrated: false,
        ),
        cutoverState: cutover,
        journals: [?openEntry],
      );
    }

    test(
      'enforces matching accountLineage on decode and sets mismatch flag',
      () {
        final state = sampleState(accountLineage: 'lineage-A');
        final encoded = codec.encodeState(state);

        final scoped = LineageScopedJournalCodec(
          inner: codec,
          accountLineage: 'lineage-B',
          targetIdentity: const DurableCommandIdentity(
            operationId: 'op-1',
            payloadVersion: 1,
            canonicalPayloadIdentity: '{}',
          ),
        );

        expect(
          () => scoped.decodeState(encoded),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'account_lineage_mismatch',
            ),
          ),
        );
        expect(scoped.lineageMismatch, isTrue);
      },
    );

    test(
      'extractReceipts runs validateReplayOutcome before receipt matching',
      () {
        const identity = DurableCommandIdentity(
          operationId: 'op-1',
          payloadVersion: 1,
          canonicalPayloadIdentity: '{"cmd":"test"}',
        );

        var state = sampleState(accountLineage: 'lineage-A');
        final receipt = DurableCommandReceipt(
          identity: identity,
          status: DurableCommandStatus.committed,
          outcomePayload: '{"netAmount":"5000"}',
          committedRevision: 1,
          fence: const StorageFence(storeId: 's', generation: 'g'),
          sequence: 1,
        );
        state = state.attachReceipt(receipt);

        final failingValidator = LineageScopedJournalCodec(
          inner: codec,
          accountLineage: 'lineage-A',
          targetIdentity: identity,
          validateReplayOutcome: (payload, st) => false, // rejects!
        );

        expect(
          () => failingValidator.extractReceipts(state),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'outcome_mismatch',
            ),
          ),
        );

        final passingValidator = LineageScopedJournalCodec(
          inner: codec,
          accountLineage: 'lineage-A',
          targetIdentity: identity,
          validateReplayOutcome: (payload, st) => true,
        );

        final extracted = passingValidator.extractReceipts(state);
        expect(extracted, hasLength(1));
        expect(extracted.first.identity.operationId, 'op-1');
      },
    );
  });

  group('JournalCommandHost Coordinator Tests', () {
    test('rejects coordinator bound to another store owner', () {
      final store1 = _FakeStore();
      final store2 = _FakeStore();
      final coordinator = DurableCommandCoordinator(store: store2);

      expect(
        () => JournalCommandHost(store: store1, coordinator: coordinator),
        throwsArgumentError,
      );
    });

    test('missing authority fence returns failure before I/O', () async {
      final store = _FakeStore();
      final host = JournalCommandHost(store: store);

      final result = await host.execute<String>(
        identity: const DurableCommandIdentity(
          operationId: 'op-1',
          payloadVersion: 1,
          canonicalPayloadIdentity: '{}',
        ),
        accountLineage: 'lineage-1',
        expectedFence: null, // missing fence!
        validateReplayOutcome: (_, _) => true,
        parseOutcome: (p) => p,
        evaluateProposal: (s, f) => throw UnimplementedError(),
      );

      expect(result, isA<DurableCommandFailure<String>>());
      final failure = result as DurableCommandFailure<String>;
      expect(failure.code, 'missing_authority_fence');
      expect(store.readCalls, 0); // zero I/O
    });
  });
}
