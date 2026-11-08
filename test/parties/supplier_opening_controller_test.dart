import 'dart:convert';

import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_account_transfer_controller.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/accounts/portable_metadata_repository_bridge.dart';
import 'package:dakhl_restaurant/accounts/portable_metadata_validation.dart';
import 'package:dakhl_restaurant/parties/additional_debt_controller.dart';
import 'package:dakhl_restaurant/parties/parties_operations_view_model.dart';
import 'package:dakhl_restaurant/parties/supplier_opening_commands.dart';
import 'package:dakhl_restaurant/parties/supplier_opening_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import 'additional_debt_controller_test.dart' show seed;
import '../sales/sales_workflow_session_test.dart' show fixture;
import '../sales/source_sales_completion_test.dart' show RefundAckStore;

const codec = PortableJournalCodec();
const equity = 'equity:opening_balance';
SupplierOpeningController controller(
  LocalDocumentWorkspaceStore store,
  DocumentSnapshot snapshot, {
  String? accepted = equity,
  bool Function()? blocked,
}) => SupplierOpeningController(
  store: store,
  snapshot: snapshot,
  acceptedOpeningEquityAccountId: accepted,
  isWriteBlocked: blocked ?? () => false,
);
SupplierOpeningCommand amend(
  SupplierOpeningController c,
  String op,
  int amount, {
  String id = 'supplier',
  Map<String, Object?> values = const {},
}) => c.capture(
  operationId: op,
  supplierId: id,
  openingBalance: BigInt.from(amount),
  reason: 'Verified opening correction',
  recordedAt: '2026-11-08T10:00:00Z',
  supplierValues: values,
);
Future<void> settle(
  PartiesOperationsViewModel p,
  String op,
  int amount,
  String date,
) async {
  expect(
    await p.submitPayment(
      p.supplierPaymentIntent(
        operationId: op,
        paymentId: op,
        journalId: '$op:journal',
        supplierId: 'supplier',
        date: DateOnly.parse(date, minimumYear: 1000, maximumYear: 9999),
        amount: BigInt.from(amount),
        fundingSource: FundingSource.daily,
        dailyAmount: BigInt.from(amount),
        cashAmount: BigInt.zero,
        recordedAt: '2026-11-08T11:00:00Z',
      ),
    ),
    isA<DurableCommandSuccess>(),
  );
}

void main() {
  test('opening increases, decreases and zero append deltas while base/cash/spending stay exact; replay survives later revisions', () async {
    final (store, initial) = await seed();
    final c = controller(store, initial);
    addTearDown(c.dispose);
    final before = codec.decodeState(initial.payload);
    final commands = <SupplierOpeningCommand>[];
    for (final amount in [1000, 1500, 200, 0]) {
      final command = amend(c, 'opening-$amount', amount);
      commands.add(command);
      expect(await c.submit(command), isA<DurableCommandSuccess>());
    }
    final state = codec.decodeState(c.snapshot.payload);
    expect(state.journals.length, before.journals.length + 4);
    expect(state.journals.first.toJson(), before.journals.first.toJson());
    expect(state.cutoverState.toJson(), before.cutoverState.toJson());
    expect(state.account.toJson()['days'], before.account.toJson()['days']);
    expect(
      state.account.toJson()['transactions'],
      before.account.toJson()['transactions'],
    );
    expect(
      state.account.toJson()['payments'],
      before.account.toJson()['payments'],
    );
    expect(
      state.journals
          .skip(1)
          .every(
            (e) =>
                e.journal.effectiveDate.toString() == '2026-11-01' &&
                e.journal.reversesId == null,
          ),
      isTrue,
    );
    expect(
      SupplierOpeningHistory.recognizedOpening(
        state,
        'supplier',
        RestaurantJournalMapper(),
      ),
      BigInt.zero,
    );
    final writes = store.writes;
    for (final command in commands) {
      expect(await c.submit(command), isA<DurableCommandReplayed>());
    }
    expect(store.writes, writes);
    expect(c.amendments('supplier').map((c) => c.afterAmount.toInt()), [
      1000,
      1500,
      200,
      0,
    ]);
  });

  test('new nonzero supplier and metadata commit atomically; invalid new metadata writes nothing', () async {
    final (store, initial) = await fixture();
    final c = controller(store, initial);
    addTearDown(c.dispose);
    final writes = store.writes;
    expect(
      () => amend(
        c,
        'bad',
        500,
        id: 'new',
        values: {'name': '', 'categoryId': 'samoon'},
      ),
      throwsFormatException,
    );
    expect(store.writes, writes);
    expect(c.account.toJson()['suppliers'], isEmpty);
    final command = amend(
      c,
      'new-supplier',
      500,
      id: 'new',
      values: {
        'name': 'New supplier',
        'categoryId': 'samoon',
        'archived': true,
      },
    );
    expect(await c.submit(command), isA<DurableCommandSuccess>());
    expect(store.writes, writes + 1);
    final state = codec.decodeState(c.snapshot.payload);
    expect(
      (state.account.toJson()['suppliers']! as List).single,
      containsPair('openingBalance', 500),
    );
    expect(
      (state.account.toJson()['suppliers']! as List).single,
      containsPair('archived', true),
    );
    expect(state.journals.last.sourceRecordId, 'new');
    expect(state.receipts.single.identity, command.identity);
  });

  test('opening refusals write nothing and retained opaque rejection receipts do not activate the feature', () async {
    final (store, initial) = await seed();
    final c = controller(store, initial);
    addTearDown(c.dispose);
    final command = amend(c, 'stale-first-opening', 100);
    final before = codec.decodeState(initial.payload);
    final raw =
        jsonDecode(jsonEncode(before.account.toJson())) as Map<String, dynamic>;
    raw['suppliers'][0]['name'] = 'Concurrent metadata edit';
    await store.writeDocument(
      codec.encodeState(
        before.copyWith(account: const LegacyAccountCodec().decodeJson(raw)),
      ),
      expected: initial,
      writeToken: 'concurrent-metadata',
    );
    final beforeRefusalWrites = store.writes;
    final result = await c.submit(command);
    expect(result, isA<DurableCommandFailure>());
    final failure = result as DurableCommandFailure;
    expect(failure.code, 'supplier_opening_source_changed');
    expect(failure.receipt, isNull);
    expect(store.writes, beforeRefusalWrites);
    final state = codec.decodeState(failure.latestSnapshot!.payload);
    final retained = state.copyWith(
      receipts: [
        ...state.receipts,
        DurableCommandReceipt(
          identity: command.identity,
          status: DurableCommandStatus.rejected,
          rejectionCode: failure.code,
          rejectionMessage: failure.message,
          committedRevision: failure.latestSnapshot!.revision + 1,
          fence: failure.latestSnapshot!.fence,
          sequence: state.receipts.length + 1,
        ),
      ],
    );
    final decodedRetained = codec.decodeState(codec.encodeState(retained));
    expect(decodedRetained.requiredFeatures, isEmpty);
    expect(
      SupplierOpeningHistory.recognizedOpening(
        decodedRetained,
        'supplier',
        RestaurantJournalMapper(),
      ),
      BigInt.zero,
    );
    expect(state.requiredFeatures, isEmpty);
    expect(state.journals.length, before.journals.length);
    final writes = store.writes;
    expect(await c.submit(command), isA<DurableCommandFailure>());
    expect(store.writes, writes);
    expect(c.needsReadback, isFalse);
  });

  test('opening amendments cannot exceed the safe aggregate even when source opening is small', () async {
    final (store, initial) = await seed();
    final before = codec.decodeState(initial.payload);
    final mapped = RestaurantJournalMapper().mapVerifiedCutoverOpening(
      journalId: before.cutoverState.openingJournalId!,
      effectiveDate: before.cutoverState.cutoverDate!,
      verifiedPhysicalRegisterCash: BigInt.from(10000),
      verifiedCashboxBalance: BigInt.zero,
      verifiedSupplierDebts: {
        'supplier': RestaurantJournalPolicies.maximumSafeAggregate,
      },
    );
    final boundedBase = before.copyWith(
      journals: [
        PortableJournalEntry(
          journal: mapped.journal,
          sourceType: RestaurantJournalSourceType.cutoverOpening.name,
          sourceRecordId: 'opening-source',
          recordedAt: '2026-11-01T00:00:00Z',
        ),
      ],
    );
    final written = await store.writeDocument(
      codec.encodeState(boundedBase),
      expected: initial,
      writeToken: 'large-verified-base',
    );
    final c = controller(
      store,
      (written as CapabilitySuccess<DocumentSnapshot>).value,
    );
    addTearDown(c.dispose);
    final writes = store.writes;
    final result = await c.submit(amend(c, 'aggregate-overflow', 1000));
    expect(result, isA<DurableCommandFailure>());
    expect(
      (result as DurableCommandFailure).code,
      'invalid_supplier_opening_proposal',
    );
    expect((result as DurableCommandFailure).receipt, isNull);
    expect(store.writes, writes);
    final state = codec.decodeState(c.snapshot.payload);
    expect(
      state.journals.map((j) => j.toJson()),
      boundedBase.journals.map((j) => j.toJson()),
    );
    expect(
      (state.account.toJson()['suppliers'] as List).single['openingBalance'],
      0,
    );
    expect(state.requiredFeatures, isEmpty);
  });

  test('zero opening creation has no zero journal and still requires its reader feature', () async {
    final (store, initial) = await fixture();
    final c = controller(store, initial);
    addTearDown(c.dispose);
    final zero = amend(
      c,
      'zero-supplier',
      0,
      id: 'new',
      values: {'name': 'Zero opening', 'categoryId': 'samoon'},
    );
    expect(await c.submit(zero), isA<DurableCommandSuccess>());
    final state = codec.decodeState(c.snapshot.payload);
    expect(
      state.journals.length,
      codec.decodeState(initial.payload).journals.length,
    );
    expect(state.receipts.length, 1);
    expect(
      () => state.copyWith(requiredFeatures: []),
      throwsA(isA<PortableJournalException>()),
    );
    expect(
      await c.submit(amend(c, 'next-opening', 500, id: 'new')),
      isA<DurableCommandSuccess>(),
    );
    final writes = store.writes;
    expect(await c.submit(zero), isA<DurableCommandReplayed>());
    expect(store.writes, writes);
  });

  test('opening amendments authorize actual debt payments and reserve future settlements without source-only debt', () async {
    final (store, initial) = await seed(importedDebt: true);
    final c = controller(store, initial);
    addTearDown(c.dispose);
    expect(
      await c.submit(amend(c, 'provide-opening', 1000)),
      isA<DurableCommandSuccess>(),
    );
    final p = PartiesOperationsViewModel(store: store, snapshot: c.snapshot);
    addTearDown(p.dispose);
    await settle(p, 'future-payment', 700, '2026-11-10');
    expect(c.acceptSnapshot(p.snapshot), isA<CapabilitySuccess>());
    final lower = amend(c, 'underfund', 0);
    final writes = store.writes;
    final result = await c.submit(lower);
    expect(result, isA<DurableCommandFailure>());
    expect(
      (result as DurableCommandFailure).code,
      'supplier_opening_underfunds_settlement',
    );
    expect(store.writes, writes);
    expect(
      (c.account.toJson()['suppliers'] as List).single['openingBalance'],
      1000,
    );
  });

  test('debt corrections use proven amended opening rather than original cutover only', () async {
    final (store, initial) = await seed();
    final d = AdditionalDebtController(
      store: store,
      snapshot: initial,
      acceptedCounterAccountId: 'test:debt',
      isWriteBlocked: () => false,
    );
    addTearDown(d.dispose);
    expect(
      await d.submit(
        d.capture(
          operationId: 'debt-create',
          debtId: 'd',
          supplierId: 'supplier',
          date: '2026-11-07',
          amount: BigInt.from(1000),
          recordedAt: '2026-11-07T10:00:00Z',
        ),
      ),
      isA<DurableCommandSuccess>(),
    );
    final p = PartiesOperationsViewModel(store: store, snapshot: d.snapshot);
    addTearDown(p.dispose);
    await settle(p, 'pay', 700, '2026-11-08');
    final c = controller(store, p.snapshot);
    addTearDown(c.dispose);
    expect(
      await c.submit(amend(c, 'opening-add', 1000)),
      isA<DurableCommandSuccess>(),
    );
    expect(d.acceptSnapshot(c.snapshot), isA<CapabilitySuccess>());
    expect(
      await d.submit(
        d.capture(
          kind: 'delete',
          operationId: 'debt-remove',
          debtId: 'd',
          reason: 'Opening now covers settlement',
          recordedAt: '2026-11-08T12:00:00Z',
        ),
      ),
      isA<DurableCommandSuccess>(),
    );
    expect(d.account.toJson()['debts'], isEmpty);
  });

  test(
    'lost acknowledgement blocks later intent and exact retry replays once',
    () async {
      final (inner, initial) = await seed();
      final store = RefundAckStore(inner);
      final c = controller(store, initial);
      addTearDown(c.dispose);
      final command = amend(c, 'unknown-opening', 1000);
      store.loseNext = true;
      expect(await c.submit(command), isA<DurableCommandFailure>());
      expect(c.needsReadback, isTrue);
      expect(() => amend(c, 'later', 1200), throwsFormatException);
      final writes = inner.writes;
      store.blocked = false;
      expect(await c.retry(), isA<DurableCommandReplayed>());
      expect(inner.writes, writes);
      expect(c.needsReadback, isFalse);
      expect(
        codec
            .decodeState(c.snapshot.payload)
            .journals
            .where((j) => j.sourceType == SupplierOpeningCommand.sourceType)
            .length,
        1,
      );
    },
  );

  test('missing mapping and peer exclusion refuse before writes; stale source refuses atomic update', () async {
    final (store, initial) = await seed();
    final unaccepted = controller(store, initial, accepted: null);
    addTearDown(unaccepted.dispose);
    final writes = store.writes;
    expect(() => amend(unaccepted, 'unmapped', 100), throwsFormatException);
    expect(store.writes, writes);
    final c = controller(store, initial);
    addTearDown(c.dispose);
    final stale = amend(c, 'stale', 100);
    final peer = controller(store, initial);
    addTearDown(peer.dispose);
    expect(
      await peer.submit(amend(peer, 'peer', 200)),
      isA<DurableCommandSuccess>(),
    );
    expect(await c.submit(stale), isA<DurableCommandFailure>());
    final blocked = controller(store, peer.snapshot, blocked: () => true);
    addTearDown(blocked.dispose);
    expect(() => amend(blocked, 'blocked', 500), throwsFormatException);
  });

  test('feature marker is omitted for old envelopes and required for amendments; unknown features reject', () async {
    final (store, initial) = await seed();
    final original = codec.decodeState(initial.payload);
    expect(original.toJson().containsKey('requiredFeatures'), isFalse);
    expect(codec.encodeState(original), initial.payload);
    final c = controller(store, initial);
    addTearDown(c.dispose);
    expect(
      await c.submit(amend(c, 'feature', 100)),
      isA<DurableCommandSuccess>(),
    );
    final state = codec.decodeState(c.snapshot.payload);
    expect(state.requiredFeatures, [
      PortableJournalState.supplierOpeningFeature,
    ]);
    expect(state.copyWith().requiredFeatures, state.requiredFeatures);
    final raw = jsonDecode(c.snapshot.payload) as Map<String, dynamic>;
    raw.remove('requiredFeatures');
    expect(
      () => codec.decodeState(jsonEncode(raw)),
      throwsA(isA<PortableJournalException>()),
    );
    Iterable<String> duplicateThenFail() sync* {
      yield PortableJournalState.supplierOpeningFeature;
      yield PortableJournalState.supplierOpeningFeature;
      throw StateError(
        'Feature parsing continued after a known invalid input.',
      );
    }

    expect(
      () => state.copyWith(requiredFeatures: duplicateThenFail()),
      throwsA(isA<PortableJournalException>()),
    );
    final unknown = {
      ...state.toJson(),
      'requiredFeatures': ['unknown-future-contract'],
    };
    expect(
      () => codec.decodeJson(unknown),
      throwsA(isA<PortableJournalException>()),
    );
    // This additive key is outside the exact old v12 root-key set. The retained
    // old reader's strict _keys check rejects it; no old-envelope bytes change.
    const oldKeys = {
      'version',
      'accountLineage',
      'sourceProvenance',
      'cutoverState',
      'account',
      'journals',
      'receipts',
    };
    expect(state.toJson().keys.where((key) => !oldKeys.contains(key)), [
      'requiredFeatures',
    ]);
  });

  test('missing or altered amendment proof cannot authorize payment or a further opening revision', () async {
    final (store, initial) = await seed();
    final c = controller(store, initial);
    addTearDown(c.dispose);
    expect(
      await c.submit(amend(c, 'proven', 1000)),
      isA<DurableCommandSuccess>(),
    );
    final saved = codec.decodeState(c.snapshot.payload);
    final invalid = saved.copyWith(receipts: []);
    expect(
      () => SupplierOpeningHistory.recognizedOpening(
        invalid,
        'supplier',
        RestaurantJournalMapper(),
      ),
      throwsFormatException,
    );
    final changed = await store.writeDocument(
      codec.encodeState(invalid),
      expected: c.snapshot,
      writeToken: 'corrupt-proof',
    );
    final broken = controller(
      store,
      (changed as CapabilitySuccess<DocumentSnapshot>).value,
    );
    addTearDown(broken.dispose);
    expect(() => amend(broken, 'next', 1100), throwsFormatException);
    final p = PartiesOperationsViewModel(
      store: store,
      snapshot: broken.snapshot,
    );
    addTearDown(p.dispose);
    final cmd = p.supplierPaymentIntent(
      operationId: 'unproven-pay',
      paymentId: 'up',
      journalId: 'up-j',
      supplierId: 'supplier',
      date: DateOnly.parse('2026-11-08', minimumYear: 1000, maximumYear: 9999),
      amount: BigInt.from(100),
      fundingSource: FundingSource.daily,
      dailyAmount: BigInt.from(100),
      cashAmount: BigInt.zero,
      recordedAt: '2026-11-08T12:00:00Z',
    );
    expect(await p.submitPayment(cmd), isA<DurableCommandFailure>());
  });

  test('metadata writes preserve amendment feature/history while opening bypass stays rejected', () async {
    final (store, initial) = await seed();
    final c = controller(store, initial);
    addTearDown(c.dispose);
    expect(
      await c.submit(amend(c, 'history', 1000)),
      isA<DurableCommandSuccess>(),
    );
    final state = codec.decodeState(c.snapshot.payload);
    final bridge = PortableMetadataRepositoryBridge(
      inner: store,
      snapshot: c.snapshot,
      isWriteBlocked: () => false,
    );
    addTearDown(bridge.dispose);
    final read =
        (await bridge.readDocument() as CapabilitySuccess<DocumentSnapshot?>)
            .value!;
    final raw =
        jsonDecode(jsonEncode(state.account.toJson())) as Map<String, dynamic>;
    (raw['suppliers'] as List).single['name'] = 'Renamed';
    final renamed = const LegacyAccountCodec().decodeJson(raw);
    expect(
      await bridge.writeDocument(
        utf8.decode(const LegacyAccountCodec().encode(renamed)),
        expected: read,
        writeToken: 'rename',
      ),
      isA<CapabilitySuccess>(),
    );
    final full =
        (await store.readDocument() as CapabilitySuccess<DocumentSnapshot?>)
            .value!;
    final after = codec.decodeState(full.payload);
    expect(after.requiredFeatures, state.requiredFeatures);
    expect(
      SupplierOpeningHistory.recognizedOpening(
        after,
        'supplier',
        RestaurantJournalMapper(),
      ),
      BigInt.from(1000),
    );
    raw['suppliers'][0]['openingBalance'] = 1100;
    expect(
      () => validatePortableMetadataChange(
        after.account,
        const LegacyAccountCodec().decodeJson(raw),
      ),
      throwsFormatException,
    );
  });

  test('complete-envelope export/import generation replacement retains opening proof', () async {
    final (store, initial) = await seed();
    final c = controller(store, initial);
    addTearDown(c.dispose);
    expect(
      await c.submit(amend(c, 'portable', 500)),
      isA<DurableCommandSuccess>(),
    );
    final transfer = PortableAccountTransferController(
      store: store,
      snapshot: c.snapshot,
      isWriteBlocked: () => false,
    );
    addTearDown(transfer.dispose);
    expect(
      transfer.prepareImport(transfer.exportBytes()),
      isA<CapabilitySuccess>(),
    );
    expect(await transfer.confirmImport(), isA<CapabilitySuccess>());
    expect(transfer.snapshot.fence, isNot(c.snapshot.fence));
    final stale = amend(c, 'old-generation', 600);
    final writes = store.writes;
    expect(await c.submit(stale), isA<DurableCommandFailure>());
    expect(store.writes, writes);
    expect(
      SupplierOpeningHistory.recognizedOpening(
        codec.decodeState(transfer.snapshot.payload),
        'supplier',
        RestaurantJournalMapper(),
      ),
      BigInt.from(500),
    );
  });
}
