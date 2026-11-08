import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_spending_commands.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/parties/purchase_proposal.dart';

const paymentFence = StorageFence(
  storeId: 'payment-fixture',
  generation: 'one',
);
const paymentStamp = '2026-01-10T12:00:00.000Z';
DateOnly paymentDate(String day) =>
    DateOnly.parse('2026-01-$day', minimumYear: 1000, maximumYear: 9999);
PortableJournalState paymentSeed({RestaurantJournalMapper? mapper}) {
  mapper ??= RestaurantJournalMapper();
  final raw = Map<String, Object?>.from(
    const LegacyAccountCodec().empty().toJson(),
  );
  raw['suppliers'] = [
    for (final id in ['supplier', 'other'])
      {
        'id': id,
        'name': id,
        'phone': '',
        'note': '',
        'categoryId': 'samoon',
        'openingBalance': id == 'supplier' ? 7500 : 0,
      },
  ];
  raw['materials'] = [
    {
      'id': 'material',
      'name': 'Flour',
      'unit': 'bag',
      'priceCarton': 0,
      'pricePiece': 12500,
      'archived': false,
    },
  ];
  final opening = mapper.mapVerifiedCutoverOpening(
    journalId: 'opening',
    effectiveDate: paymentDate('01'),
    verifiedPhysicalRegisterCash: BigInt.from(100000),
    verifiedCashboxBalance: BigInt.from(100000),
    verifiedSupplierDebts: {'supplier': BigInt.from(7500)},
  );
  return PortableJournalState(
    accountLineage: 'lineage',
    account: const LegacyAccountCodec().decodeJson(raw),
    sourceProvenance: const PortableJournalSourceProvenance(
      sourceVersion: 11,
      enrolledAt: '2026-01-01T00:00:00.000Z',
      migrated: false,
    ),
    cutoverState: PortableJournalCutoverState.established(
      cutoverDate: paymentDate('01'),
      openingJournalId: 'opening',
    ),
    journals: [
      PortableJournalEntry(
        journal: opening.journal,
        sourceType: opening.sourceType.name,
        sourceRecordId: 'cutover',
        recordedAt: '2026-01-01T00:00:00.000Z',
      ),
    ],
    receipts: const [],
  );
}

CreatePurchaseInvoiceCommand paymentInvoice({
  StorageFence fence = paymentFence,
}) => CreatePurchaseInvoiceCommand(
  operationId: 'invoice-create',
  accountLineage: 'lineage',
  expectedFence: fence,
  invoiceId: 'invoice',
  invoiceJournalId: 'invoice-journal',
  supplierId: 'supplier',
  invoiceNumber: 'I-1',
  date: paymentDate('05'),
  lines: const [
    PurchaseLine(
      materialIdForCreation: 'material',
      name: 'Flour',
      unit: 'bag',
      quantityCartons: 0,
      quantityPieces: 1,
      priceCarton: 0,
      pricePiece: 12500,
    ),
  ],
  recordedAt: '2026-01-05T12:00:00.000Z',
);
CreateSupplierPaymentCommand paymentCreate({
  StorageFence fence = paymentFence,
  String operation = 'payment-create',
  String id = 'payment',
  String journal = 'payment-journal',
  int amount = 20000,
  String? invoice = 'invoice',
  String day = '10',
}) => CreateSupplierPaymentCommand(
  operationId: operation,
  accountLineage: 'lineage',
  expectedFence: fence,
  paymentId: id,
  journalId: journal,
  supplierId: 'supplier',
  invoiceId: invoice,
  date: paymentDate(day),
  amount: BigInt.from(amount),
  fundingSource: FundingSource.shared,
  dailyAmount: BigInt.from(amount - 5000),
  cashAmount: BigInt.from(5000),
  note: ' original ',
  recordedAt: paymentStamp,
);
PortableJournalState paymentReceipt(
  PortableJournalState state,
  DurableCommandIdentity identity,
  String payload, {
  StorageFence fence = paymentFence,
  int? revision,
}) => state.copyWith(
  receipts: [
    ...state.receipts,
    DurableCommandReceipt(
      identity: identity,
      status: DurableCommandStatus.committed,
      outcomePayload: payload,
      committedRevision: revision ?? state.receipts.length + 1,
      sequence: state.receipts.length + 1,
      fence: fence,
    ),
  ],
);
PortableJournalState paymentPosted({RestaurantJournalMapper? mapper}) {
  mapper ??= RestaurantJournalMapper();
  var state = paymentSeed(mapper: mapper);
  final invoice = paymentInvoice();
  final i = RestaurantJournalSpendingCommandCoordinator.evaluateInvoice(
    command: invoice,
    state: state,
    cutoverDate: paymentDate('01'),
    mapper: mapper,
  );
  expect(i.rejected, false, reason: i.rejectionCode);
  state = paymentReceipt(
    i.candidateState!,
    invoice.identity,
    i.outcomePayload!,
  );
  final create = paymentCreate();
  final p = RestaurantJournalSpendingCommandCoordinator.evaluatePayment(
    command: create,
    state: state,
    cutoverDate: paymentDate('01'),
    mapper: mapper,
  );
  expect(p.rejected, false, reason: p.rejectionCode);
  return paymentReceipt(p.candidateState!, create.identity, p.outcomePayload!);
}

Map<String, Object?> paymentRow(PortableJournalState state) =>
    (state.account.toJson()['payments'] as List)
        .cast<Map<String, Object?>>()
        .singleWhere((r) => r['id'] == 'payment');
