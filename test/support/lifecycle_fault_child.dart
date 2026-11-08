import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_sale_commands.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_spending_commands.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/parties/purchase_proposal.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:madar_domain/madar_domain.dart';

// Synthetic acceptance fixture shared by the host test and its killed child.
// This executable does not bootstrap, migrate or read restaurant account data.
const lifecycleCodec = PortableJournalCodec();
const lifecycleTimestamp = '2026-01-05T12:00:00.000Z';

DateOnly lifecycleDate(String value) =>
    DateOnly.parse(value, minimumYear: 1000, maximumYear: 9999);

PortableJournalState lifecycleSeed() {
  final fixture = jsonDecode(
    File('test/sales/sale_proposal_oracle.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final raw = Map<String, Object?>.from(
    ((fixture['cases'] as List).first as Map)['state'] as Map,
  );
  raw['suppliers'] = [
    {
      'id': 'supplier',
      'name': 'Synthetic supplier',
      'phone': '',
      'note': '',
      'categoryId': 'samoon',
      'openingBalance': 0,
      'materials': <Map<String, Object?>>[],
    },
  ];
  return PortableJournalState(
    accountLineage: 'lifecycle-fixture',
    account: const LegacyAccountCodec().decodeJson(raw),
    sourceProvenance: const PortableJournalSourceProvenance(
      sourceVersion: 11,
      enrolledAt: '2026-01-01T00:00:00.000Z',
      migrated: false,
    ),
    cutoverState: PortableJournalCutoverState.established(
      cutoverDate: lifecycleDate('2026-01-01'),
      openingJournalId: 'opening-journal',
    ),
    journals: [
      PortableJournalEntry(
        journal: BalancedJournal.validate(
          id: 'opening-journal',
          effectiveDate: lifecycleDate('2026-01-01'),
          policy: RestaurantJournalPolicies.opening,
          lines: [
            JournalLine(
              accountId: 'asset:cash:daily',
              side: JournalSide.debit,
              amountUnits: BigInt.from(10000),
              currency: 'IQD',
              scale: 0,
            ),
            JournalLine(
              accountId: 'equity:opening_balance',
              side: JournalSide.credit,
              amountUnits: BigInt.from(10000),
              currency: 'IQD',
              scale: 0,
            ),
          ],
        ),
        sourceType: 'cutoverOpening',
        sourceRecordId: 'synthetic-opening',
        recordedAt: '2026-01-01T00:00:00.000Z',
      ),
    ],
    receipts: const [],
  );
}

Object lifecycleCommand(
  String kind,
  StorageFence fence, {
  bool changed = false,
}) => switch (kind) {
  'sale' => CompleteSaleCommand(
    operationId: 'sale-op',
    accountLineage: 'lifecycle-fixture',
    expectedFence: fence,
    saleId: 'sale',
    journalId: 'sale-journal',
    recordedAt: lifecycleTimestamp,
    draft: {
      'date': '2026-01-03',
      'discount': changed ? 1 : 0,
      'lines': [
        {'productId': 'p', 'quantity': 2},
      ],
    },
  ),
  'invoice' => CreatePurchaseInvoiceCommand(
    operationId: 'invoice-op',
    accountLineage: 'lifecycle-fixture',
    expectedFence: fence,
    invoiceId: 'invoice',
    invoiceJournalId: 'invoice-journal',
    paymentJournalId: 'inline-payment-journal',
    supplierId: 'supplier',
    invoiceNumber: changed ? 'CHANGED' : 'SYNTHETIC-1',
    date: lifecycleDate('2026-01-04'),
    lines: const [
      PurchaseLine(
        materialIdForCreation: 'inline-material',
        name: 'Synthetic flour',
        unit: 'bag',
        quantityCartons: 2,
        quantityPieces: 2,
        priceCarton: 2000,
        pricePiece: 100,
      ),
    ],
    immediatePayment: const PurchasePayment(
      id: 'inline-payment',
      amount: 1500,
      source: 'shared',
      dailyAmount: 900,
      cashAmount: 600,
    ),
    recordedAt: lifecycleTimestamp,
  ),
  _ => throw ArgumentError.value(kind, 'kind'),
};

Future<DurableCommandResult<Object>> executeLifecycleCommand(
  LocalDocumentWorkspaceStore store,
  Object command,
) => switch (command) {
  RestaurantJournalSaleCommand() => RestaurantJournalSaleCommandCoordinator(
    store: store,
  ).execute(command),
  RestaurantJournalSpendingCommand() =>
    RestaurantJournalSpendingCommandCoordinator(store: store).execute(command),
  _ => throw ArgumentError.value(command.runtimeType, 'command'),
};

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    throw ArgumentError(
      'Expected owned directory, command kind and checkpoint.',
    );
  }
  final [directory, kind, target] = args;
  var armed = false;
  final opened = await PowerSyncLocalDocumentWorkspaceStore.open(
    directoryPath: directory,
    checkpoint: (point) async {
      if (armed && point == target) {
        stdout.writeln(
          jsonEncode({
            'event': 'lifecycle-checkpoint',
            'kind': kind,
            'checkpoint': point,
            'pid': pid,
          }),
        );
        await stdout.flush();
        await Completer<void>().future;
      }
    },
  );
  if (opened is! CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>) {
    throw StateError('Child could not obtain its isolated store owner.');
  }
  final store = opened.value;
  final read = await store.readDocument();
  if (read is! CapabilitySuccess<DocumentSnapshot?> || read.value == null) {
    throw StateError('Child requires the host-created complete base.');
  }
  armed = true;
  await executeLifecycleCommand(
    store,
    lifecycleCommand(kind, read.value!.fence),
  );
  throw StateError('Checkpoint was not reached before command completion.');
}
