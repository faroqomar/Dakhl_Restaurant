import 'restaurant_journal_sale_safety_test.dart' as sales_support;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:madar_domain/madar_domain.dart';

import 'package:dakhl_restaurant/accounting/daily_cash_queries.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_spending_commands.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/parties/purchase_proposal.dart';

const _codec = PortableJournalCodec();
const _legacy = LegacyAccountCodec();
final _mapper = RestaurantJournalMapper();
DateOnly _date(String day) =>
    DateOnly.parse('2026-01-$day', minimumYear: 1000, maximumYear: 9999);
const _stamp = '2026-01-10T12:00:00.000Z';

PortableJournalState _seed({
  int opening = 100,
  int? verified,
  List<Map<String, Object?>> payments = const [],
  List<Map<String, Object?>> debts = const [],
}) {
  final raw = Map<String, Object?>.from(_legacy.empty().toJson());
  raw['suppliers'] = [
    for (final id in ['s', 'other'])
      {
        'id': id,
        'name': id,
        'phone': '',
        'note': '',
        'categoryId': 'samoon',
        'openingBalance': id == 's' ? opening : 0,
      },
  ];
  raw['materials'] = [
    {
      'id': 'material',
      'name': 'Flour',
      'unit': 'bag',
      'priceCarton': 0,
      'pricePiece': 100,
      'archived': false,
    },
  ];
  raw['payments'] = payments;
  raw['debts'] = debts;
  final proposal = _mapper.mapVerifiedCutoverOpening(
    journalId: 'opening',
    effectiveDate: _date('01'),
    verifiedPhysicalRegisterCash: BigInt.from(100000),
    verifiedCashboxBalance: BigInt.zero,
    verifiedSupplierDebts: {'s': BigInt.from(verified ?? opening)},
  );
  return PortableJournalState(
    accountLineage: 'lineage',
    account: _legacy.decodeJson(raw),
    sourceProvenance: const PortableJournalSourceProvenance(
      sourceVersion: 11,
      enrolledAt: '2026-01-01T00:00:00.000Z',
      migrated: false,
    ),
    cutoverState: PortableJournalCutoverState.established(
      cutoverDate: _date('01'),
      openingJournalId: 'opening',
    ),
    journals: [
      PortableJournalEntry(
        journal: proposal.journal,
        sourceType: proposal.sourceType.name,
        sourceRecordId: 'cutover',
        recordedAt: '2026-01-01T00:00:00.000Z',
      ),
    ],
    receipts: const [],
  );
}

PortableJournalState _reversedOpening() {
  final state = _seed();
  final original = state.journals.single;
  final reversed = state.copyWith(
    journals: [
      original,
      PortableJournalEntry(
        journal: original.journal.reversed(
          id: 'opening-inverse',
          reason: 'withdraw verified opening',
          effectiveDate: original.journal.effectiveDate,
        ),
        sourceType: RestaurantJournalSourceType.voidReversal.name,
        sourceRecordId: 'cutover',
        recordedAt: _stamp,
      ),
    ],
  );
  return _codec.decodeState(_codec.encodeState(reversed));
}

CreateOperatingExpenseCommand _expense({StorageFence? fence}) =>
    CreateOperatingExpenseCommand(
      operationId: 'op-e',
      accountLineage: 'lineage',
      expectedFence: fence,
      expenseId: 'e',
      journalId: 'j-e',
      date: _date('10'),
      categoryId: 'samoon',
      amount: BigInt.from(100),
      fundingSource: FundingSource.daily,
      note: '  note  ',
      recordedAt: _stamp,
    );
CreatePurchaseInvoiceCommand _invoice({
  StorageFence? fence,
  PurchasePayment? immediate,
  String? paymentJournalId,
}) => CreatePurchaseInvoiceCommand(
  operationId: 'op-i',
  accountLineage: 'lineage',
  expectedFence: fence,
  invoiceId: 'i',
  invoiceJournalId: 'j-i',
  supplierId: 's',
  invoiceNumber: ' ١٠٠ ',
  date: _date('10'),
  lines: const [
    PurchaseLine(
      materialIdForCreation: 'new-material',
      name: 'Flour',
      unit: 'bag',
      quantityCartons: 0,
      quantityPieces: 2,
      priceCarton: 0,
      pricePiece: 100,
    ),
  ],
  note: '  invoice note  ',
  immediatePayment: immediate,
  paymentJournalId: paymentJournalId,
  recordedAt: _stamp,
);
CreateSupplierPaymentCommand _payment(
  String id,
  int amount, {
  String? invoiceId,
  String day = '10',
  StorageFence? fence,
}) => CreateSupplierPaymentCommand(
  operationId: 'op-$id',
  accountLineage: 'lineage',
  expectedFence: fence,
  paymentId: id,
  journalId: 'j-$id',
  supplierId: 's',
  invoiceId: invoiceId,
  date: _date(day),
  amount: BigInt.from(amount),
  fundingSource: FundingSource.daily,
  note: '  payment note  ',
  recordedAt: _stamp,
);
DurableProposalEvaluation<
  PortableJournalState,
  RestaurantJournalSpendingOutcome
>
_evaluate(
  PortableJournalState state,
  RestaurantJournalSpendingCommand command,
) => RestaurantJournalSpendingCommandCoordinator.evaluateCommand(
  command: command,
  state: state,
  cutoverDate: _date('01'),
  mapper: _mapper,
);
PortableJournalState _post(
  PortableJournalState state,
  RestaurantJournalSpendingCommand command,
) {
  final result = _evaluate(state, command);
  expect(
    result.rejected,
    false,
    reason: '${result.rejectionCode}: ${result.rejectionMessage}',
  );
  return result.candidateState!;
}

Map<String, Object?> _mutableAccount(PortableJournalState state) =>
    (jsonDecode(jsonEncode(state.account.toJson())) as Map)
        .cast<String, Object?>();

void main() {
  for (final invoiceBound in [false, true]) {
    test(
      'reversed opening cannot fund ${invoiceBound ? 'invoice spillover' : 'debt payment'}',
      () {
        final reversed = _reversedOpening();
        final state = invoiceBound ? _post(reversed, _invoice()) : reversed;
        final before = _codec.encodeState(state);
        final result = _evaluate(
          state,
          _payment(
            'reversed-opening-payment',
            invoiceBound ? 250 : 50,
            invoiceId: invoiceBound ? 'i' : null,
          ),
        );
        expect(result.rejected, true);
        expect(
          result.rejectionCode,
          RestaurantJournalSpendingErrorCodes.unverifiedHistoricalDebt,
        );
        expect(result.candidateState, isNull);
        expect(_codec.encodeState(state), before);
      },
    );
  }

  test('raw post-cutover debt cannot authorize an unjournaled settlement', () {
    final state = _seed(
      opening: 0,
      debts: [
        {
          'id': 'd',
          'supplierId': 's',
          'date': '2026-01-05',
          'amount': 100,
          'note': '',
          'createdAt': _stamp,
        },
      ],
    );
    final result = _evaluate(state, _payment('p', 50));
    expect(result.rejected, true);
    expect(
      result.rejectionCode,
      RestaurantJournalSpendingErrorCodes.unverifiedHistoricalDebt,
    );
  });
  test('verified cutover opening already includes pre-cutover settlements', () {
    final state = _seed(
      opening: 100,
      verified: 60,
      payments: [
        {
          'id': 'historical',
          'supplierId': 's',
          'invoiceId': null,
          'categoryId': 'samoon',
          'date': '2025-12-31',
          'amount': 40,
          'invoiceAmount': 0,
          'debtAmount': 40,
          'funding': {'source': 'daily', 'dailyAmount': 40, 'cashAmount': 0},
          'note': '',
          'createdAt': '2025-12-31T12:00:00.000Z',
        },
      ],
    );
    final paid = _post(state, _payment('p', 50));
    expect((paid.account.toJson()['payments'] as List).length, 2);
    expect(paid.journals.last.journal.totalUnits, BigInt.from(50));
  });
  test(
    'future saved payments reserve opening liability against double spending',
    () {
      final future = _post(_seed(), _payment('future', 60, day: '20'));
      expect(_evaluate(future, _payment('earlier-overpay', 50)).rejected, true);
      final earlier = _post(future, _payment('earlier', 40));
      expect((earlier.account.toJson()['payments'] as List).length, 2);
    },
  );
  test('selected invoice is settled first then eligible verified debt', () {
    final state = _post(_seed(), _invoice());
    final paid = _post(state, _payment('p', 250, invoiceId: 'i'));
    final row = (paid.account.toJson()['payments'] as List).single as Map;
    expect(row['invoiceAmount'], 200);
    expect(row['debtAmount'], 50);
    expect(DailyCashQueries(paid.account).statement().total, BigInt.from(250));
    expect(paid.journals.last.journal.totalUnits, BigInt.from(250));
  });
  test('an invoice whose liability posting was reversed is ineligible', () {
    final state = _post(_seed(), _invoice());
    final original = state.journals.last;
    final reversed = state.copyWith(
      journals: [
        ...state.journals,
        PortableJournalEntry(
          journal: original.journal.reversed(
            id: 'inverse',
            reason: 'correction',
            effectiveDate: original.journal.effectiveDate,
          ),
          sourceType: RestaurantJournalSourceType.voidReversal.name,
          sourceRecordId: 'i',
          recordedAt: _stamp,
        ),
      ],
    );
    expect(
      _evaluate(reversed, _payment('p', 50, invoiceId: 'i')).rejected,
      true,
    );
  });
  test('duplicate invoice liability postings are ineligible', () {
    final state = _post(_seed(), _invoice());
    final duplicate = _mapper.mapPurchaseInvoice(
      journalId: 'duplicate',
      invoiceId: 'i',
      invoiceNumber: '100',
      supplierId: 's',
      effectiveDate: _date('10'),
      amount: BigInt.from(200),
    );
    final altered = state.copyWith(
      journals: [
        ...state.journals,
        PortableJournalEntry(
          journal: duplicate.journal,
          sourceType: duplicate.sourceType.name,
          sourceRecordId: 'i',
          recordedAt: _stamp,
        ),
      ],
    );
    expect(
      _evaluate(altered, _payment('p', 50, invoiceId: 'i')).rejected,
      true,
    );
  });
  test('invoice source and liability posting must agree before settlement', () {
    final state = _post(_seed(), _invoice());
    final raw = _mutableAccount(state);
    (((raw['invoices'] as List).single as Map)['lines'] as List)
            .cast<Map>()
            .single['pricePiece'] =
        200;
    final altered = state.copyWith(account: _legacy.decodeJson(raw));
    expect(
      _evaluate(altered, _payment('p', 50, invoiceId: 'i')).rejected,
      true,
    );
  });
  test('zero optional immediate payment produces no phantom source links', () {
    final result = _evaluate(
      _seed(),
      _invoice(
        immediate: const PurchasePayment(
          id: 'zero',
          amount: 0,
          source: 'daily',
        ),
        paymentJournalId: 'unused',
      ),
    );
    expect(result.rejected, false);
    expect(result.outcome!.paymentId, isNull);
    expect(result.outcome!.paymentJournalId, isNull);
    expect(result.candidateState!.journals.length, 2);
    expect(result.candidateState!.account.toJson()['payments'], isEmpty);
  });

  test(
    'unposted post-cutover settlements cannot stand in for journal history',
    () {
      final state = _seed(
        payments: [
          {
            'id': 'unposted',
            'supplierId': 's',
            'invoiceId': null,
            'categoryId': 'samoon',
            'date': '2026-01-05',
            'amount': 20,
            'invoiceAmount': 0,
            'debtAmount': 20,
            'funding': {'source': 'daily', 'dailyAmount': 20, 'cashAmount': 0},
            'note': '',
            'createdAt': _stamp,
          },
        ],
      );
      final result = _evaluate(state, _payment('p', 30));
      expect(result.rejected, true);
      expect(
        result.rejectionCode,
        RestaurantJournalSpendingErrorCodes.invalidPaymentPosting,
      );
    },
  );
  test(
    'a wrong supplier liability account cannot authorize invoice settlement',
    () {
      final state = _post(_seed(), _invoice());
      final wrong = _mapper.mapPurchaseInvoice(
        journalId: 'j-i',
        invoiceId: 'i',
        invoiceNumber: '100',
        supplierId: 'other',
        effectiveDate: _date('10'),
        amount: BigInt.from(200),
      );
      final altered = state.copyWith(
        journals: [
          state.journals.first,
          PortableJournalEntry(
            journal: wrong.journal,
            sourceType: wrong.sourceType.name,
            sourceRecordId: 'i',
            recordedAt: _stamp,
          ),
        ],
      );
      final result = _evaluate(altered, _payment('p', 50, invoiceId: 'i'));
      expect(result.rejected, true);
      expect(
        result.rejectionCode,
        RestaurantJournalSpendingErrorCodes.invalidInvoicePosting,
      );
    },
  );

  group('real-store replay reconciliation', () {
    late Directory directory;
    late PowerSyncLocalDocumentWorkspaceStore store;
    late RestaurantJournalSpendingCommandCoordinator coordinator;
    late StorageFence fence;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'dakhl-spending-safety-',
      );
      store = (await PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: directory.path,
      ) as CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>).value;
      final initial = await store.writeDocument(
        _codec.encodeState(_seed()),
        writeToken: 'seed',
      ) as CapabilitySuccess<DocumentSnapshot>;
      fence = initial.value.fence;
      coordinator = RestaurantJournalSpendingCommandCoordinator(store: store);
    });
    tearDown(() async {
      await store.close();
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    Future<DocumentSnapshot> snapshot() async =>
        (await store.readDocument() as CapabilitySuccess<DocumentSnapshot?>)
            .value!;
    Future<void> corruptSource(
      void Function(Map<String, Object?>) mutate,
    ) async {
      final previous = await snapshot();
      final state = _codec.decodeState(previous.payload);
      final raw = _mutableAccount(state);
      mutate(raw);
      final next = state.copyWith(account: _legacy.decodeJson(raw));
      expect(
        await store.writeDocument(
          _codec.encodeState(next),
          writeToken: 'tamper',
          expected: previous,
        ),
        isA<CapabilitySuccess<DocumentSnapshot>>(),
      );
    }

    Future<void> rejectsWithoutWrite(
      RestaurantJournalSpendingCommand command,
    ) async {
      final before = await snapshot();
      expect(
        await coordinator.execute(command),
        isA<DurableCommandFailure<RestaurantJournalSpendingOutcome>>(),
      );
      final after = await snapshot();
      expect(after.payload, before.payload);
      expect(after.revision, before.revision);
    }

    for (final invoiceBound in [false, true]) {
      test(
        'real store rejects reversed opening ${invoiceBound ? 'spillover' : 'debt'} without writes',
        () async {
          final initial = await snapshot();
          expect(
            await store.writeDocument(
              _codec.encodeState(_reversedOpening()),
              expected: initial,
              writeToken: 'seed-opening-reversal',
            ),
            isA<CapabilitySuccess<DocumentSnapshot>>(),
          );
          if (invoiceBound) {
            expect(
              await coordinator.execute(_invoice(fence: fence)),
              isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
            );
          }
          final before = await snapshot();
          final result = await coordinator.execute(
            _payment(
              'reversed-opening-payment',
              invoiceBound ? 250 : 50,
              invoiceId: invoiceBound ? 'i' : null,
              fence: fence,
            ),
          );
          expect(
            result,
            isA<DurableCommandFailure<RestaurantJournalSpendingOutcome>>(),
          );
          expect(
            (result as DurableCommandFailure<RestaurantJournalSpendingOutcome>)
                .code,
            RestaurantJournalSpendingErrorCodes.unverifiedHistoricalDebt,
          );
          final after = await snapshot();
          expect(after.payload, before.payload);
          expect(after.revision, before.revision);
          expect(after.fence, before.fence);
          final saved = _codec.decodeState(after.payload);
          expect(saved.receipts.length, invoiceBound ? 1 : 0);
          expect(saved.journals.length, invoiceBound ? 3 : 2);
          expect(saved.account.toJson()['payments'], isEmpty);
        },
      );
    }

    for (final field in ['funding', 'categoryId', 'note', 'createdAt']) {
      test('expense replay rejects changed source $field', () async {
        final command = _expense(fence: fence);
        expect(
          await coordinator.execute(command),
          isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
        );
        await corruptSource((raw) {
          final e =
              (((raw['days'] as Map)['2026-01-10'] as Map)['expenses'] as List)
                      .single
                  as Map;
          e[field] = switch (field) {
            'funding' => {
              'source': 'cash',
              'dailyAmount': 0,
              'cashAmount': 100,
            },
            'categoryId' => 'bread',
            'note' => 'changed',
            _ => '2026-01-10T13:00:00.000Z',
          };
        });
        await rejectsWithoutWrite(command);
      });
    }
    for (final field in [
      'number',
      'supplierId',
      'lines',
      'note',
      'createdAt',
    ]) {
      test('invoice replay rejects changed source $field', () async {
        final command = _invoice(fence: fence);
        expect(
          await coordinator.execute(command),
          isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
        );
        await corruptSource((raw) {
          final i = (raw['invoices'] as List).single as Map;
          if (field == 'lines') {
            ((i['lines'] as List).single as Map)['pricePiece'] = 200;
          } else {
            i[field] = switch (field) {
              'number' => 'changed',
              'supplierId' => 'other',
              'note' => 'changed',
              _ => '2026-01-10T13:00:00.000Z',
            };
          }
        });
        await rejectsWithoutWrite(command);
      });
    }
    for (final field in [
      'funding',
      'supplierId',
      'categoryId',
      'date',
      'note',
      'createdAt',
    ]) {
      test('payment replay rejects changed source $field', () async {
        final command = _payment('p', 50, fence: fence);
        expect(
          await coordinator.execute(command),
          isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
        );
        await corruptSource((raw) {
          final p = (raw['payments'] as List).single as Map;
          if (field == 'supplierId') {
            ((raw['suppliers'] as List).last as Map)['openingBalance'] = 100;
          }
          p[field] = switch (field) {
            'funding' => {'source': 'cash', 'dailyAmount': 0, 'cashAmount': 50},
            'supplierId' => 'other',
            'categoryId' => 'bread',
            'date' => '2026-01-11',
            'note' => 'changed',
            _ => '2026-01-10T13:00:00.000Z',
          };
        });
        await rejectsWithoutWrite(command);
      });
    }
    for (final field in ['funding', 'allocation', 'categoryId', 'journal']) {
      test('immediate-payment replay rejects changed $field', () async {
        final command = _invoice(
          fence: fence,
          immediate: const PurchasePayment(
            id: 'immediate',
            amount: 100,
            source: 'daily',
          ),
          paymentJournalId: 'j-immediate',
        );
        expect(
          await coordinator.execute(command),
          isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
        );
        if (field == 'journal') {
          final before = await snapshot();
          final state = _codec.decodeState(before.payload);
          final entry = state.journals.last;
          final wrong = _mapper.mapSupplierPayment(
            journalId: entry.journal.id,
            paymentId: 'immediate',
            supplierId: 's',
            effectiveDate: _date('10'),
            amount: BigInt.from(100),
            dailyAmount: BigInt.zero,
            cashboxAmount: BigInt.from(100),
            invoiceSettledAmount: BigInt.from(100),
            debtSettledAmount: BigInt.zero,
            invoiceId: 'i',
          );
          final next = state.copyWith(
            journals: [
              ...state.journals.take(state.journals.length - 1),
              PortableJournalEntry(
                journal: wrong.journal,
                sourceType: entry.sourceType,
                sourceRecordId: entry.sourceRecordId,
                recordedAt: entry.recordedAt,
                metadata: entry.metadata,
              ),
            ],
          );
          expect(
            await store.writeDocument(
              _codec.encodeState(next),
              writeToken: 'tamper',
              expected: before,
            ),
            isA<CapabilitySuccess<DocumentSnapshot>>(),
          );
        } else {
          await corruptSource((raw) {
            final p = (raw['payments'] as List).single as Map;
            if (field == 'funding') {
              p['funding'] = {
                'source': 'cash',
                'dailyAmount': 0,
                'cashAmount': 100,
              };
            }
            if (field == 'allocation') {
              p['invoiceAmount'] = 25;
              p['debtAmount'] = 75;
            }
            if (field == 'categoryId') {
              p['categoryId'] = 'bread';
            }
          });
        }
        await rejectsWithoutWrite(command);
      });
    }
    test(
      'separate invoice and payment namespaces allow the same raw id',
      () async {
        final command = _invoice(
          fence: fence,
          immediate: const PurchasePayment(
            id: 'i',
            amount: 100,
            source: 'daily',
          ),
          paymentJournalId: 'j-payment',
        );
        expect(
          await coordinator.execute(command),
          isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
        );
        final state = _codec.decodeState((await snapshot()).payload);
        expect(
          ((state.account.toJson()['invoices'] as List).single as Map)['id'],
          'i',
        );
        expect(
          ((state.account.toJson()['payments'] as List).single as Map)['id'],
          'i',
        );
        expect(
          await coordinator.execute(command),
          isA<DurableCommandReplayed<RestaurantJournalSpendingOutcome>>(),
        );
      },
    );

    test('separate payment replay rejects a changed invoice linkage', () async {
      expect(
        await coordinator.execute(_invoice(fence: fence)),
        isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
      );
      final command = _payment('p', 50, fence: fence);
      expect(
        await coordinator.execute(command),
        isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
      );
      await corruptSource((raw) {
        ((raw['payments'] as List).single as Map)['invoiceId'] = 'i';
      });
      await rejectsWithoutWrite(command);
    });
    test(
      'separate payment replay rejects changed invoice and debt splits',
      () async {
        expect(
          await coordinator.execute(_invoice(fence: fence)),
          isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
        );
        final command = _payment('p', 250, invoiceId: 'i', fence: fence);
        expect(
          await coordinator.execute(command),
          isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
        );
        await corruptSource((raw) {
          final p = (raw['payments'] as List).single as Map;
          p['invoiceAmount'] = 150;
          p['debtAmount'] = 100;
        });
        await rejectsWithoutWrite(command);
      },
    );
    for (final field in [
      'invoiceId',
      'supplierId',
      'paymentId',
      'paymentJournalId',
    ]) {
      test('expense replay rejects an unrelated outcome $field', () async {
        final command = _expense(fence: fence);
        expect(
          await coordinator.execute(command),
          isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
        );
        final before = await snapshot();
        final state = _codec.decodeState(before.payload);
        final receipt = state.receipts.single;
        final outcome =
            (jsonDecode(receipt.outcomePayload!) as Map).cast<String, Object?>()
              ..[field] = 'unrelated';
        final changed = DurableCommandReceipt(
          identity: receipt.identity,
          status: receipt.status,
          outcomePayload: jsonEncode(outcome),
          rejectionCode: receipt.rejectionCode,
          rejectionMessage: receipt.rejectionMessage,
          committedRevision: receipt.committedRevision,
          fence: receipt.fence,
          sequence: receipt.sequence,
        );
        expect(
          await store.writeDocument(
            _codec.encodeState(state.copyWith(receipts: [changed])),
            writeToken: 'tamper',
            expected: before,
          ),
          isA<CapabilitySuccess<DocumentSnapshot>>(),
        );
        await rejectsWithoutWrite(command);
      });
    }
    test('invoice and immediate payment survive a real committed lost acknowledgement and reopen', () async {
      final wrapped = sales_support.LostCommitAcknowledgementStore(store)
        ..loseNextWrite = true;
      final executor = RestaurantJournalSpendingCommandCoordinator(
        store: wrapped,
      );
      final command = _invoice(
        fence: fence,
        immediate: const PurchasePayment(
          id: 'immediate',
          amount: 100,
          source: 'daily',
        ),
        paymentJournalId: 'j-immediate',
      );
      expect(
        await executor.execute(command),
        isA<DurableCommandReplayed<RestaurantJournalSpendingOutcome>>(),
      );
      expect(wrapped.writes, 1);
      var state = _codec.decodeState((await snapshot()).payload);
      expect(state.receipts, hasLength(1));
      expect(state.journals, hasLength(3));
      expect(state.account.toJson()['invoices'], hasLength(1));
      expect(state.account.toJson()['payments'], hasLength(1));
      expect(
        DailyCashQueries(state.account).statement().total,
        BigInt.from(100),
      );
      await store.close();
      store = (await PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: directory.path,
      ) as CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>).value;
      coordinator = RestaurantJournalSpendingCommandCoordinator(store: store);
      expect(
        await coordinator.execute(command),
        isA<DurableCommandReplayed<RestaurantJournalSpendingOutcome>>(),
      );
      state = _codec.decodeState((await snapshot()).payload);
      expect(state.receipts, hasLength(1));
      expect(state.journals, hasLength(3));
      expect(state.account.toJson()['payments'], hasLength(1));
    });

    test('invoice and payment replay stay valid after later settlements and metadata edits', () async {
      final invoice = _invoice(fence: fence);
      expect(
        await coordinator.execute(invoice),
        isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
      );
      final payment = _payment('p', 250, invoiceId: 'i', fence: fence);
      expect(
        await coordinator.execute(payment),
        isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
      );
      await corruptSource((raw) {
        ((raw['suppliers'] as List).first as Map)['categoryId'] = 'bread';
        ((raw['materials'] as List).first as Map)['name'] = 'Renamed material';
      });
      expect(
        await coordinator.execute(invoice),
        isA<DurableCommandReplayed<RestaurantJournalSpendingOutcome>>(),
      );
      expect(
        await coordinator.execute(payment),
        isA<DurableCommandReplayed<RestaurantJournalSpendingOutcome>>(),
      );
    });
  });
}
