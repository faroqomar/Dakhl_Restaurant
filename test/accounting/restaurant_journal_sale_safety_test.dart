import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:madar_data/madar_data.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_sale_commands.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/sales/return_proposal.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;
import 'restaurant_journal_sale_conformance_test.dart' show UnknownAckStore;

class ControlledStore extends UnknownAckStore {
  ControlledStore(super.inner);
  int reads = 0;
  Object? readException;
  CapabilityResult<DocumentSnapshot?>? readResult;
  CapabilityResult<void>? resolution;
  @override
  Future<CapabilityResult<DocumentSnapshot?>> readDocument() async {
    reads++;
    if (readException != null) throw readException!;
    return readResult ?? await super.readDocument();
  }

  @override
  Future<CapabilityResult<void>> resolvePendingWrite() async {
    if (resolution != null) return resolution!;
    return super.resolvePendingWrite();
  }
}

class LostCommitAcknowledgementStore extends UnknownAckStore {
  LostCommitAcknowledgementStore(super.inner);
  bool loseNextWrite = false, pending = false;
  int writes = 0;
  @override
  Future<CapabilityResult<DocumentSnapshot>> writeDocument(
    String payload, {
    required String writeToken,
    DocumentSnapshot? expected,
    bool replaceGeneration = false,
  }) async {
    writes++;
    final result = await super.writeDocument(
      payload,
      writeToken: writeToken,
      expected: expected,
      replaceGeneration: replaceGeneration,
    );
    if (loseNextWrite && result is CapabilitySuccess<DocumentSnapshot>) {
      loseNextWrite = false;
      pending = true;
      return const CapabilityFailure(
        DocumentErrorCodes.commitUnknown,
        'Acknowledgement lost after commit.',
      );
    }
    return result;
  }

  @override
  Future<CapabilityResult<DocumentSnapshot?>> readDocument() async => pending
      ? const CapabilityFailure(
          DocumentErrorCodes.commitUnknown,
          'Resolve acknowledged state.',
        )
      : super.readDocument();
  @override
  Future<CapabilityResult<void>> resolvePendingWrite() async {
    pending = false;
    return super.resolvePendingWrite();
  }
}

void main() {
  const codec = PortableJournalCodec();
  const fence = StorageFence(storeId: 'store', generation: 'first');
  final mapper = RestaurantJournalMapper();
  final date = DateOnly.parse(
    '2026-11-07',
    minimumYear: 1000,
    maximumYear: 9999,
  );
  Map<String, Object?> draft() => {
    'date': '2026-11-07',
    'discount': 0,
    'lines': [
      {'productId': 'p', 'quantity': 1},
    ],
  };
  CompleteSaleCommand sale({
    StorageFence? expected = fence,
    String? receipt,
    Map<String, Object?>? input,
  }) => CompleteSaleCommand(
    operationId: 'sale-op',
    accountLineage: 'lineage',
    expectedFence: expected,
    saleId: 'sale',
    journalId: 'sale-journal',
    recordedAt: '2026-11-07T12:00:00.000Z',
    draft: input ?? draft(),
    receiptNumber: receipt,
  );
  PortableJournalState state() {
    const legacy = LegacyAccountCodec();
    final account = legacy.decodeJson({
      ...legacy.empty().toJson(),
      'products': [
        {
          'id': 'p',
          'name': 'صنف',
          'code': '',
          'unit': 'قطعة',
          'group': '',
          'price': 1000,
          'minStock': 0,
          'trackStock': false,
          'archived': false,
        },
      ],
    });
    final opening = mapper.mapVerifiedCutoverOpening(
      journalId: 'opening',
      effectiveDate: date,
      verifiedPhysicalRegisterCash: BigInt.from(10000),
      verifiedCashboxBalance: BigInt.zero,
      verifiedSupplierDebts: {},
    );
    return PortableJournalState(
      accountLineage: 'lineage',
      account: account,
      sourceProvenance: const PortableJournalSourceProvenance(
        sourceVersion: 11,
        enrolledAt: '2026-11-07T00:00:00.000Z',
        migrated: false,
      ),
      cutoverState: PortableJournalCutoverState.established(
        cutoverDate: date,
        openingJournalId: 'opening',
      ),
      journals: [
        PortableJournalEntry(
          journal: opening.journal,
          sourceType: 'cutoverOpening',
          recordedAt: '2026-11-07T00:00:00.000Z',
        ),
      ],
    );
  }

  ControlledStore store() {
    final inner = FixtureStore()
      ..document = DocumentSnapshot(
        payload: codec.encodeState(state()),
        revision: 1,
        fence: fence,
        writeToken: 'seed',
      );
    return ControlledStore(inner);
  }

  test(
    'unbound command cannot execute or read a possibly different authority',
    () async {
      final s = store();
      final result = await RestaurantJournalSaleCommandCoordinator(store: s)
          .execute(sale(expected: null));
      expect(
        result,
        isA<DurableCommandFailure<RestaurantJournalSaleOutcome>>(),
      );
      expect(s.reads, 0);
    },
  );
  test('cancelled and thrown reads return structured failures', () async {
    for (final throwing in [false, true]) {
      final s = store();
      if (throwing) {
        s.readException = StateError('private');
      } else {
        s.readResult = const CapabilityCancelled();
      }
      final result = await RestaurantJournalSaleCommandCoordinator(store: s)
          .execute(sale());
      expect(
        result,
        isA<DurableCommandFailure<RestaurantJournalSaleOutcome>>(),
      );
      expect((s.inner as FixtureStore).writes, 0);
    }
  });
  test('failed pending-write resolution is not ignored', () async {
    final s = store()
      ..injectUnknownRead = true
      ..resolution = const CapabilityFailure(
        'resolution_failed',
        'Unavailable',
      );
    final result = await RestaurantJournalSaleCommandCoordinator(store: s)
        .execute(sale());
    expect(result, isA<DurableCommandFailure<RestaurantJournalSaleOutcome>>());
    expect((s.inner as FixtureStore).writes, 0);
  });
  test('coordinator injection cannot refer to a second store owner', () {
    final a = store(), b = store();
    expect(
      () => RestaurantJournalSaleCommandCoordinator(
        store: a,
        coordinator: DurableCommandCoordinator(store: b),
      ),
      throwsArgumentError,
    );
  });
  test(
    'a normal command uses the engine read path without duplicated pre-reads',
    () async {
      final s = store();
      final result = await RestaurantJournalSaleCommandCoordinator(store: s)
          .execute(sale());
      expect(
        result,
        isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
      );
      expect(s.reads, 1);
    },
  );
  test(
    'lineage mismatch before receipt inspection cannot emit a replay event',
    () async {
      final s = store();
      final diagnostics = <DurableCommandDiagnostic>[];
      final owner = RestaurantJournalSaleCommandCoordinator(
        store: s,
        coordinator: DurableCommandCoordinator(
          store: s,
          diagnosticSink: diagnostics.add,
        ),
      );
      expect(
        await owner.execute(sale()),
        isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
      );
      final inner = s.inner as FixtureStore;
      final old = inner.document!;
      final changed = codec
          .decodeState(old.payload)
          .copyWith(accountLineage: 'replacement-lineage');
      inner.document = DocumentSnapshot(
        payload: codec.encodeState(changed),
        revision: old.revision + 1,
        fence: fence,
        writeToken: 'replacement',
      );
      diagnostics.clear();
      final result = await owner.execute(sale());
      expect(
        result,
        isA<DurableCommandFailure<RestaurantJournalSaleOutcome>>(),
      );
      expect(diagnostics.any((d) => d.outcome == 'replayed'), isFalse);
      expect(inner.writes, 1);
    },
  );
  test(
    'return input iterable is captured exactly once before identity generation',
    () {
      var enumerations = 0;
      Iterable<ReturnLineRequest> values() sync* {
        enumerations++;
        yield ReturnLineRequest(
          productId: 'p',
          quantityUnits: BigInt.from(enumerations * 1000),
          restock: false,
        );
      }

      final cmd = SaleReturnCommand(
        operationId: 'return-op',
        accountLineage: 'lineage',
        expectedFence: fence,
        saleId: 'sale',
        returnId: 'return',
        journalId: 'return-journal',
        returnDate: date,
        today: date,
        reason: 'سبب',
        recordedAt: '2026-11-07T12:00:00.000Z',
        lines: values(),
      );
      final json = jsonDecode(cmd.canonicalPayloadIdentity) as Map;
      expect(enumerations, 1);
      expect(
        ((json['lines'] as List).single as Map)['quantityUnits'],
        cmd.lines.single.quantityUnits.toString(),
      );
    },
  );
  test(
    'outcomes detach nested metadata and compare complete metadata content',
    () {
      final nested = <Object?>[
        <String, Object?>{'amount': '1000'},
      ];
      RestaurantJournalSaleOutcome outcome(Map<String, Object?> metadata) =>
          RestaurantJournalSaleOutcome(
            commandType: 'complete_sale',
            operationId: 'op',
            saleId: 'sale',
            journalId: 'j',
            effectiveDate: '2026-11-07',
            netAmount: '1000',
            metadata: metadata,
          );
      final before = outcome({'nested': nested});
      (nested.single as Map)['amount'] = '999';
      expect(
        ((before.metadata['nested'] as List).single as Map)['amount'],
        '1000',
      );
      expect(
        () => (before.metadata['nested'] as List).clear(),
        throwsUnsupportedError,
      );
      final same = outcome({
        'nested': [
          {'amount': '1000'},
        ],
      });
      final different = outcome({
        'nested': [
          {'amount': '999'},
        ],
      });
      expect(before, same);
      expect(before.hashCode, same.hashCode);
      expect(before, isNot(different));
    },
  );
  test(
    'receipt override cannot diverge from the persisted generated sale number',
    () {
      final result = RestaurantJournalSaleCommandCoordinator.evaluateSale(
        command: sale(receipt: 'unrelated'),
        state: state(),
        cutoverDate: date,
        mapper: mapper,
      );
      expect(result.rejected, isTrue);
    },
  );
  test(
    'a refund refuses a source sale whose posting has already been reversed',
    () {
      final accepted = RestaurantJournalSaleCommandCoordinator.evaluateSale(
        command: sale(),
        state: state(),
        cutoverDate: date,
        mapper: mapper,
      );
      final withSale = accepted.candidateState!;
      final original = withSale.journals.last;
      final reversed = withSale.addJournal(
        PortableJournalEntry(
          journal: original.journal.reversed(
            id: 'inverse',
            effectiveDate: date,
            reason: 'void',
          ),
          sourceType: 'voidReversal',
          sourceRecordId: 'sale',
          recordedAt: '2026-11-07T13:00:00.000Z',
        ),
      );
      final cmd = SaleReturnCommand(
        operationId: 'refund',
        accountLineage: 'lineage',
        saleId: 'sale',
        returnId: 'return',
        journalId: 'refund-journal',
        expectedFence: fence,
        returnDate: date,
        today: date,
        reason: 'سبب',
        recordedAt: '2026-11-07T14:00:00.000Z',
        lines: [
          ReturnLineRequest(
            productId: 'p',
            quantityUnits: BigInt.from(1000),
            restock: false,
          ),
        ],
      );
      expect(
        RestaurantJournalSaleCommandCoordinator.evaluateReturn(
          command: cmd,
          state: reversed,
          cutoverDate: date,
          mapper: mapper,
        ).rejected,
        isTrue,
      );
    },
  );
  test(
    'command payload rejects cyclic and unsupported values with bounded errors',
    () {
      final cycle = <String, Object?>{};
      cycle['self'] = cycle;
      for (final value in <Object?>[
        cycle,
        BigInt.one,
        StringBuffer('mutable'),
      ]) {
        expect(
          () => sale(input: {...draft(), 'extra': value}),
          throwsFormatException,
        );
      }
      var deep = <String, Object?>{};
      for (var i = 0; i < 110; i++) {
        deep = {'nested': deep};
      }
      expect(
        () => sale(input: {...draft(), 'extra': deep}),
        throwsFormatException,
      );
    },
  );
  test('oversized canonical payload fails at command construction', () {
    expect(
      () => sale(
        input: {...draft(), 'note': 'x' * (DocumentLimits.accountBytes + 1)},
      ),
      throwsFormatException,
    );
  });
  test('return and void refuse mismatched source posting snapshots', () {
    final accepted = RestaurantJournalSaleCommandCoordinator.evaluateSale(
      command: sale(),
      state: state(),
      cutoverDate: date,
      mapper: mapper,
    );
    final posted = accepted.candidateState!;
    final original = posted.journals.last;
    for (final metadata in [
      {...original.metadata, 'receiptNumber': 'wrong'},
      {...original.metadata, 'net': '999'},
    ]) {
      final changed = posted.copyWith(
        journals: [
          posted.journals.first,
          PortableJournalEntry(
            journal: original.journal,
            sourceType: original.sourceType,
            sourceRecordId: original.sourceRecordId,
            recordedAt: original.recordedAt,
            metadata: metadata,
          ),
        ],
      );
      final refund = SaleReturnCommand(
        operationId: 'return',
        accountLineage: 'lineage',
        expectedFence: fence,
        saleId: 'sale',
        returnId: 'return',
        journalId: 'return-journal',
        returnDate: date,
        today: date,
        reason: 'سبب',
        recordedAt: '2026-11-07T13:00:00.000Z',
        lines: [
          ReturnLineRequest(
            productId: 'p',
            quantityUnits: BigInt.from(1000),
            restock: false,
          ),
        ],
      );
      final voided = SaleVoidCommand(
        operationId: 'void',
        accountLineage: 'lineage',
        expectedFence: fence,
        saleId: 'sale',
        reversalJournalId: 'inverse',
        reason: 'سبب',
        voidedAt: '2026-11-07T13:00:00.000Z',
      );
      expect(
        RestaurantJournalSaleCommandCoordinator.evaluateReturn(
          command: refund,
          state: changed,
          cutoverDate: date,
          mapper: mapper,
        ).rejected,
        isTrue,
      );
      expect(
        RestaurantJournalSaleCommandCoordinator.evaluateVoid(
          command: voided,
          state: changed,
          cutoverDate: date,
          mapper: mapper,
        ).rejected,
        isTrue,
      );
    }
  });
  test(
    'replay rejects a stored outcome that disagrees with its journal',
    () async {
      final s = store();
      final owner = RestaurantJournalSaleCommandCoordinator(store: s);
      final first = await owner.execute(
        sale(),
      ) as DurableCommandSuccess<RestaurantJournalSaleOutcome>;
      final json = jsonDecode(first.snapshot.payload) as Map<String, Object?>;
      final receipt = (json['receipts'] as List).first as Map;
      final outcome = jsonDecode(receipt['outcomePayload'] as String) as Map;
      outcome['netAmount'] = '999';
      receipt['outcomePayload'] = jsonEncode(outcome);
      final inner = s.inner as FixtureStore;
      inner.document = DocumentSnapshot(
        payload: jsonEncode(json),
        revision: 3,
        fence: fence,
        writeToken: 'tampered',
      );
      final before = inner.document;
      expect(
        await owner.execute(sale()),
        isA<DurableCommandFailure<RestaurantJournalSaleOutcome>>(),
      );
      expect(inner.document, same(before));
      expect(inner.writes, 1);
    },
  );
  test(
    'completed sale still replays its original outcome after an eligible void',
    () async {
      final s = store();
      final owner = RestaurantJournalSaleCommandCoordinator(store: s);
      final original = await owner.execute(
        sale(),
      ) as DurableCommandSuccess<RestaurantJournalSaleOutcome>;
      final voided = SaleVoidCommand(
        operationId: 'void',
        accountLineage: 'lineage',
        expectedFence: fence,
        saleId: 'sale',
        reversalJournalId: 'inverse',
        reason: 'سبب',
        voidedAt: '2026-11-07T13:00:00.000Z',
      );
      expect(
        await owner.execute(voided),
        isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
      );
      final replay = await owner.execute(
        sale(),
      ) as DurableCommandReplayed<RestaurantJournalSaleOutcome>;
      expect(replay.outcome, original.outcome);
      expect((s.inner as FixtureStore).writes, 2);
    },
  );
  test('real committed write with a lost acknowledgement replays exactly once after reopen', () async {
    final root = await Directory.systemTemp.createTemp('dakhl-sales-lost-ack-');
    final opened = await PowerSyncLocalDocumentWorkspaceStore.open(
      directoryPath: root.path,
    );
    final first =
        (opened as CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>)
            .value;
    addTearDown(() async {
      await first.close();
      if (await root.exists()) await root.delete(recursive: true);
    });
    final seed = await first.writeDocument(
      codec.encodeState(state()),
      writeToken: 'seed',
    );
    final expected = (seed as CapabilitySuccess<DocumentSnapshot>).value.fence;
    final wrapped = LostCommitAcknowledgementStore(first)..loseNextWrite = true;
    final command = sale(expected: expected);
    final result = await RestaurantJournalSaleCommandCoordinator(store: wrapped)
        .execute(command);
    expect(result, isA<DurableCommandReplayed<RestaurantJournalSaleOutcome>>());
    expect(wrapped.writes, 1);
    expect(wrapped.resolveCalls, 1);
    await first.close();
    final reopened = (await PowerSyncLocalDocumentWorkspaceStore.open(
      directoryPath: root.path,
    ) as CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>).value;
    addTearDown(reopened.close);
    final read = await reopened.readDocument();
    final saved = codec.decodeState(
      (read as CapabilitySuccess<DocumentSnapshot?>).value!.payload,
    );
    expect(saved.receipts, hasLength(1));
    expect(saved.journals, hasLength(2));
    expect(saved.account.toJson()['sales'], hasLength(1));
    expect(
      await RestaurantJournalSaleCommandCoordinator(store: reopened)
          .execute(command),
      isA<DurableCommandReplayed<RestaurantJournalSaleOutcome>>(),
    );
  });
  test(
    'return input materialization stops at the source 200-line boundary',
    () {
      var produced = 0;
      Iterable<ReturnLineRequest> stream() sync* {
        for (var i = 0; i < 202; i++) {
          produced++;
          yield ReturnLineRequest(
            productId: 'p$i',
            quantityUnits: BigInt.from(1000),
            restock: false,
          );
        }
      }

      expect(
        () => SaleReturnCommand(
          operationId: 'return',
          accountLineage: 'lineage',
          expectedFence: fence,
          saleId: 'sale',
          returnId: 'return',
          journalId: 'return-journal',
          returnDate: date,
          today: date,
          reason: 'سبب',
          recordedAt: '2026-11-07T14:00:00.000Z',
          lines: stream(),
        ),
        throwsFormatException,
      );
      expect(produced, 201);
    },
  );
  test(
    'canonical intent retains the submitted return and void reason text',
    () {
      SaleReturnCommand refund(String reason) => SaleReturnCommand(
        operationId: 'return',
        accountLineage: 'lineage',
        expectedFence: fence,
        saleId: 'sale',
        returnId: 'return',
        journalId: 'return-journal',
        returnDate: date,
        today: date,
        reason: reason,
        recordedAt: '2026-11-07T14:00:00.000Z',
        lines: [
          ReturnLineRequest(
            productId: 'p',
            quantityUnits: BigInt.from(1000),
            restock: false,
          ),
        ],
      );
      SaleVoidCommand voided(String reason) => SaleVoidCommand(
        operationId: 'void',
        accountLineage: 'lineage',
        expectedFence: fence,
        saleId: 'sale',
        reversalJournalId: 'inverse',
        reason: reason,
        voidedAt: '2026-11-07T14:00:00.000Z',
      );
      expect(
        refund('سبب').canonicalPayloadIdentity,
        isNot(refund(' سبب ').canonicalPayloadIdentity),
      );
      expect(
        voided('سبب').canonicalPayloadIdentity,
        isNot(voided(' سبب ').canonicalPayloadIdentity),
      );
    },
  );
}
