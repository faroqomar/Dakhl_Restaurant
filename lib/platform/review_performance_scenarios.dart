import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounting/daily_register_snapshot_controller.dart';
import '../accounting/categories_view_model.dart';
import '../accounts/accounts_repository.dart';
import '../accounts/portable_metadata_repository_bridge.dart';
import '../parties/additional_debt_controller.dart';
import '../parties/supplier_opening_controller.dart';
import '../parties/supplier_opening_commands.dart';
import '../accounting/day_date_correction_controller.dart';
import '../accounting/financial_session_undo.dart';
import '../accounting/restaurant_journal_mapper.dart';
import '../accounting/restaurant_journal_sale_commands.dart';
import '../accounting/spending_operations_view_model.dart';
import '../accounting/spending_session_undo_adapter.dart';
import '../accounts/legacy_account_codec.dart';
import '../accounts/account_document.dart';
import '../accounts/portable_account_transfer_controller.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import '../app/accounts_store.dart';
import '../parties/parties_operations_view_model.dart';
import '../parties/purchase_analysis.dart';
import '../parties/purchase_proposal.dart';
import '../parties/supplier_ledger.dart';
import '../reports/restaurant_report.dart';
import '../reports/restaurant_report_pdf.dart';
import '../sales/return_proposal.dart';
import '../sales/sale_proposal.dart';
import '../sales/sales_operations_view_model.dart';
import '../sales/ticket_workspace.dart';

const reviewPerformanceCases = {
  'review.suppliers.opening_write',
  'review.suppliers.additional_debt',
  'review.cash.external_deposit',
  'review.categories.save',
  'review.sales.checkout',
  'review.sales.refund',
  'review.spending.expense',
  'review.cash.transfer',
  'review.register.remaining',
  'review.purchases.invoice',
  'review.purchases.payment',
  'review.portable.export',
  'review.portable.import',
  'review.portable.recover',
  'review.reports.generate',
  'review.undo.expense',
  'review.sales.void',
  'review.spending.correct',
  'review.days.shift',
  'review.suppliers.ledger_query',
  'review.purchases.invoice_inline',
  'review.purchases.analysis',
  'review.reports.daily.short',
  'review.reports.daily.multi',
  'review.reports.invoice.short',
  'review.reports.invoice.multi',
  'review.reports.sale.short',
  'review.reports.sale.multi',
  'review.reports.sales.short',
  'review.reports.sales.multi',
  'review.reports.statement.short',
  'review.reports.statement.multi',
  'review.reports.cash.short',
  'review.reports.cash.multi',
  'review.reports.payment.short',
  'review.reports.payment.max',
};

const reviewPerformanceWorkload = {
  'id': 'review-operations-v1',
  'products': 20,
  'historicalCashRows': 200,
  'suppliers': 1,
  'materials': 1,
  'invoiceLines': 1,
  'saleLines': 1,
};

final class ReviewPerformanceOptions {
  const ReviewPerformanceOptions(this.operationId, this.iterations, this.runId);
  final String operationId, runId;
  final int iterations;
  factory ReviewPerformanceOptions.parse(List<String> args) {
    final values = <String, String>{};
    for (var i = 0; i < args.length; i += 2) {
      if (i + 1 >= args.length ||
          !{'--case', '--iterations', '--run-id'}.contains(args[i]) ||
          values.containsKey(args[i])) {
        throw const FormatException('Invalid review benchmark arguments.');
      }
      values[args[i]] = args[i + 1];
    }
    final operation = values['--case'] ?? '';
    final iterations = int.tryParse(values['--iterations'] ?? '1') ?? 0;
    final runId = values['--run-id'] ?? 'local';
    if (!reviewPerformanceCases.contains(operation) ||
        iterations < 1 ||
        iterations > 100 ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(runId)) {
      throw const FormatException('Unsupported review benchmark options.');
    }
    return ReviewPerformanceOptions(operation, iterations, runId);
  }
}

DateOnly _date(String value) =>
    DateOnly.parse(value, minimumYear: 1000, maximumYear: 9999);
void _ack(CapabilityResult<dynamic> result) {
  if (result is! CapabilitySuccess) {
    throw StateError('Benchmark capability failed.');
  }
}

void _committed(DurableCommandResult<dynamic> result) {
  if (result is! DurableCommandSuccess) {
    throw StateError('Benchmark command failed.');
  }
}

/// Fresh real-adapter fixture per sample. No normal storage location is resolved.
/// Historical source rows predate the explicitly synthetic verified cutover.
final class ReviewPerformanceFixture {
  ReviewPerformanceFixture._(this.directory, this.operation) {
    store = AppAccountsStore(
      openStore: () => PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: directory.path,
      ),
    );
  }
  final Directory directory;
  final String operation;
  late final AppAccountsStore store;
  late DocumentSnapshot _snapshot, beforeRun;
  final _dispose = <void Function()>[];
  Future<void> Function()? _action;
  Uint8List? bytes;
  List<SupplierLedgerRow>? ledgerRows;
  PurchaseAnalysis? purchaseAnalysis;
  RestaurantReport? report;
  String? _expectedReplacementPayload;
  String? get expectedReplacementPayload => _expectedReplacementPayload;
  PortableJournalState get state =>
      const PortableJournalCodec().decodeState(_snapshot.payload);
  DocumentSnapshot get snapshot => _snapshot;

  static Future<ReviewPerformanceFixture> create(
    String runId,
    String operation,
  ) async {
    ReviewPerformanceOptions.parse(['--case', operation, '--run-id', runId]);
    final directory = await Directory.systemTemp.createTemp(
      'dakhl-review-bench-$runId-$pid-',
    );
    final fixture = ReviewPerformanceFixture._(directory, operation);
    try {
      await fixture._prepare();
      return fixture;
    } on Object {
      await fixture.close();
      rethrow;
    }
  }

  Future<void> _read() async {
    final read = await store.readDocument();
    _ack(read);
    _snapshot =
        (read as CapabilitySuccess<DocumentSnapshot?>).value ??
        (throw StateError('Missing benchmark account.'));
  }

  Future<void> _prepare() async {
    const legacy = LegacyAccountCodec(), codec = PortableJournalCodec();
    var account = legacy.decodeJson({
      ...legacy.empty().toJson(),
      'products': [
        for (var i = 0; i < 20; i++)
          {
            'id': 'product-$i',
            'name': 'Synthetic item $i',
            'code': 'BENCH-$i',
            'unit': 'piece',
            'group': 'Synthetic',
            'price': 1000,
            'minStock': 0,
            'trackStock': false,
            'archived': false,
          },
      ],
      'transactions': [
        for (var i = 0; i < 200; i++)
          {
            'id': 'history-$i',
            'date': '2026-10-01',
            'type': 'deposit',
            'amount': 1,
            'note': 'Synthetic historical source',
            'createdAt': '2026-10-01T00:00:00Z',
          },
      ],
      'days': {
        '2026-11-07': {
          'expenses': <Object?>[],
          'chickenUsed': 0,
          'chickenLeft': 0,
          'balance': 100000,
          'totalOverride': null,
          'remaining': {
            'amount': 100000,
            'dailySpent': 0,
            'transferred': 0,
            'salesTotal': 0,
          },
        },
      },
      'suppliers': [
        {
          'id': 'supplier',
          'name': 'Synthetic supplier',
          'phone': '',
          'note': '',
          'categoryId': 'samoon',
          'openingBalance': 0,
          'archived': false,
          'materials': <Object?>[],
        },
      ],
      'materials': [
        {
          'id': 'material',
          'name': 'Synthetic material',
          'unit': 'piece',
          'priceCarton': 1000,
          'pricePiece': 100,
          'archived': false,
        },
      ],
    });
    final reportOperation =
        operation.startsWith('review.reports.') &&
        operation != 'review.reports.generate';
    if (reportOperation) {
      account = _reportFixture(account, operation);
    } else if (operation == 'review.suppliers.ledger_query' ||
        operation == 'review.purchases.analysis') {
      account = _purchaseHistoryFixture(account);
    }
    final opening = RestaurantJournalMapper().mapVerifiedCutoverOpening(
      journalId: 'opening',
      effectiveDate: _date('2026-11-01'),
      verifiedPhysicalRegisterCash: BigInt.from(100000),
      verifiedCashboxBalance: BigInt.from(200),
      verifiedSupplierDebts: {},
    );
    final initialState = PortableJournalState(
      accountLineage: 'synthetic-review',
      account: account,
      sourceProvenance: const PortableJournalSourceProvenance(
        sourceVersion: 11,
        enrolledAt: '2026-11-01T00:00:00Z',
        migrated: false,
      ),
      cutoverState: PortableJournalCutoverState.established(
        cutoverDate: _date('2026-11-01'),
        openingJournalId: 'opening',
      ),
      journals: [
        PortableJournalEntry(
          journal: opening.journal,
          sourceType: RestaurantJournalSourceType.cutoverOpening.name,
          sourceRecordId: 'opening-source',
          recordedAt: '2026-11-01T00:00:00Z',
        ),
      ],
    );
    _ack(
      await store.writeDocument(
        codec.encodeState(initialState),
        writeToken: 'initial',
      ),
    );
    await _read();
    if (operation == 'review.suppliers.opening_write') {
      final openings = SupplierOpeningController(
        store: store,
        snapshot: _snapshot,
        isWriteBlocked: () => false,
        acceptedOpeningEquityAccountId:
            RestaurantAccountProfile().openingEquityAccountId,
      );
      _dispose.add(openings.dispose);
      final command = openings.capture(
        operationId: 'opening-amendment-operation',
        supplierId: 'supplier',
        openingBalance: BigInt.from(1000),
        reason: 'Synthetic verified opening correction',
        recordedAt: '2026-11-07T12:00:00Z',
      );
      _action = () async {
        _committed(await openings.submit(command));
      };
    } else if (operation == 'review.suppliers.additional_debt') {
      final debt = AdditionalDebtController(
        store: store,
        snapshot: _snapshot,
        isWriteBlocked: () => false,
        acceptedCounterAccountId: 'synthetic:accepted-debt-counter',
      );
      _dispose.add(debt.dispose);
      final command = debt.capture(
        operationId: 'additional-debt-operation',
        debtId: 'additional-debt',
        supplierId: 'supplier',
        date: '2026-11-07',
        amount: BigInt.from(1000),
        note: 'Synthetic dated debt',
        recordedAt: '2026-11-07T12:00:00Z',
      );
      _action = () async {
        _committed(await debt.submit(command));
      };
    } else if (operation == 'review.cash.external_deposit') {
      final spending = SpendingOperationsViewModel(
        store: store,
        snapshot: _snapshot,
        acceptedCounterAccountId: 'synthetic:accepted-external-counter',
      );
      _dispose.add(spending.dispose);
      final command = spending.createExternalCashIntent(
        operationId: 'external-deposit-operation',
        transactionId: 'external-deposit',
        journalId: 'external-deposit-journal',
        date: _date('2026-11-07'),
        amount: BigInt.from(1000),
        type: 'deposit',
        note: 'Synthetic external deposit',
        recordedAt: '2026-11-07T12:00:00Z',
      );
      _action = () async {
        _committed(await spending.submitExternalCash(command));
      };
    } else if (operation == 'review.categories.save') {
      final bridge = PortableMetadataRepositoryBridge(
        inner: store,
        snapshot: _snapshot,
        isWriteBlocked: () => false,
      );
      _dispose.add(bridge.dispose);
      final repository = AccountsRepository(store: bridge);
      _ack(await repository.open());
      final categories = CategoriesViewModel(repository);
      _dispose.add(categories.dispose);
      final draft = categories.newCategoryDraft(id: 'synthetic-category')
        ..name = 'Synthetic category';
      _action = () async {
        _ack(await categories.saveCategory(draft));
      };
    } else if (operation.startsWith('review.sales.')) {
      final model = SalesOperationsViewModel(
        commands: RestaurantJournalSaleCommandCoordinator(store: store),
        snapshot: _snapshot,
        compareText: (a, b) => a.compareTo(b),
      );
      _dispose.add(model.dispose);
      final command = model.checkoutIntent(
        ticket: TicketDraft(
          id: 'sale',
          date: '2026-11-07',
          orderType: account.preferences.orderTypes.first,
          discount: '0',
          note: 'Synthetic sale',
          lines: [
            TicketLine(
              productId: 'product-0',
              quantityUnits: BigInt.from(1000),
              price: 1000,
            ),
          ],
        ),
        operationId: 'sale-operation',
        journalId: 'sale-journal',
        recordedAt: '2026-11-07T12:00:00Z',
      );
      if (operation == 'review.sales.checkout') {
        _action = () async {
          _committed(await model.submit(command));
        };
      } else if (operation == 'review.sales.void') {
        _committed(await model.submit(command));
        final voidCommand = model.voidIntent(
          operationId: 'void-operation',
          saleId: 'sale',
          reversalJournalId: 'void-journal',
          reason: 'Synthetic correction',
          voidedAt: '2026-11-07T13:00:00Z',
        );
        _action = () async {
          _committed(await model.submit(voidCommand));
        };
      } else {
        _committed(await model.submit(command));
        final refund = model.returnIntent(
          operationId: 'refund-operation',
          saleId: 'sale',
          returnId: 'refund',
          journalId: 'refund-journal',
          date: _date('2026-11-08'),
          today: _date('2026-11-08'),
          reason: 'Synthetic return',
          recordedAt: '2026-11-08T12:00:00Z',
          lines: [
            ReturnLineRequest(
              productId: 'product-0',
              quantityUnits: BigInt.from(1000),
              restock: false,
            ),
          ],
        );
        _action = () async {
          _committed(await model.submit(refund));
        };
      }
    } else if (operation == 'review.spending.expense' ||
        operation == 'review.spending.correct' ||
        operation == 'review.days.shift' ||
        operation == 'review.cash.transfer' ||
        operation == 'review.undo.expense') {
      final model = SpendingOperationsViewModel(
        store: store,
        snapshot: _snapshot,
      );
      _dispose.add(model.dispose);
      final expense = model.createExpenseIntent(
        operationId: 'expense-operation',
        expenseId: 'expense',
        journalId: 'expense-journal',
        date: _date('2026-11-07'),
        categoryId: 'samoon',
        amount: BigInt.from(100),
        fundingSource: FundingSource.daily,
        note: 'Synthetic expense',
        recordedAt: '2026-11-07T12:00:00Z',
      );
      if (operation == 'review.spending.expense') {
        _action = () async {
          _committed(await model.submitExpense(expense));
        };
      } else if (operation == 'review.cash.transfer') {
        final transfer = model.transferIntent(
          operationId: 'transfer-operation',
          transferId: 'transfer',
          journalId: 'transfer-journal',
          date: _date('2026-11-07'),
          amount: BigInt.from(50),
          recordedAt: '2026-11-07T12:00:00Z',
        );
        _action = () async {
          _committed(await model.submitTransfer(transfer));
        };
      } else if (operation == 'review.spending.correct') {
        _committed(await model.submitExpense(expense));
        final correction = model.editExpenseIntent(
          operationId: 'expense-correction',
          expenseId: 'expense',
          expectedActiveJournalId: 'expense-journal',
          inverseJournalId: 'expense-inverse',
          replacementJournalId: 'expense-replacement',
          date: _date('2026-11-07'),
          categoryId: 'samoon',
          amount: BigInt.from(125),
          fundingSource: FundingSource.daily,
          note: 'Corrected synthetic expense',
          reason: 'Correct amount',
          recordedAt: '2026-11-07T13:00:00Z',
        );
        _action = () async {
          _committed(await model.submitExpenseCorrection(correction));
        };
      } else if (operation == 'review.days.shift') {
        _committed(await model.submitExpense(expense));
        final dates = DayDateCorrectionController(
          store: store,
          snapshot: model.snapshot,
          isWriteBlocked: () => false,
        );
        _dispose.add(dates.dispose);
        final shift = dates.capture(
          operationId: 'date-shift',
          from: '2026-11-07',
          to: '2026-11-08',
          end: '2026-11-07',
          reason: 'Synthetic one-day date correction',
          recordedAt: '2026-11-09T12:00:00Z',
        );
        _action = () async {
          _committed(await dates.submit(shift));
        };
      } else {
        final before = model.snapshot;
        final result = await model.submitExpense(expense);
        _committed(result);
        final undo = FinancialSessionUndoController(
          readSnapshot: () => model.snapshot,
          isWriteBlocked: () => false,
        );
        _dispose.add(undo.dispose);
        _ack(
          undo.register(
            before: before,
            result: result,
            adapter: SpendingSessionUndoAdapter(
              spending: model,
              identity: expense.identity,
            ),
          ),
        );
        _action = () async {
          _ack(await undo.undo());
        };
      }
    } else if (operation == 'review.register.remaining') {
      final register = DailyRegisterSnapshotController(
        store: store,
        snapshot: _snapshot,
      );
      _dispose.add(register.dispose);
      _action = () async {
        _committed(
          await register.recordRemaining(
            date: '2026-11-07',
            amount: BigInt.from(100000),
            operationId: 'register-operation',
            recordedAt: '2026-11-07T12:00:00Z',
          ),
        );
      };
    } else if (operation == 'review.suppliers.ledger_query') {
      final queries = SupplierLedgerQueries(
        account,
        compareText: (a, b) => a.compareTo(b),
      );
      _action = () async {
        ledgerRows = queries.ledger('supplier');
      };
    } else if (operation == 'review.purchases.analysis') {
      _action = () async {
        purchaseAnalysis = PurchaseAnalysis.build(
          account,
          supplierId: 'supplier',
          compareText: (a, b) => a.compareTo(b),
        );
      };
    } else if (operation.startsWith('review.purchases.')) {
      final parties = PartiesOperationsViewModel(
        store: store,
        snapshot: _snapshot,
      );
      _dispose.add(parties.dispose);
      final invoice = parties.purchaseInvoiceIntent(
        operationId: 'invoice-operation',
        invoiceId: 'invoice',
        invoiceJournalId: 'invoice-journal',
        supplierId: 'supplier',
        invoiceNumber: 'BENCH-1',
        date: _date('2026-11-07'),
        lines: [
          PurchaseLine(
            materialIdForCreation: 'material',
            name: 'Synthetic material',
            unit: 'piece',
            quantityCartons: 2,
            quantityPieces: 3,
            priceCarton: 1000,
            pricePiece: 100,
          ),
        ],
        note: 'Synthetic invoice',
        immediatePayment: operation == 'review.purchases.invoice_inline'
            ? const PurchasePayment(
                id: 'inline-payment',
                amount: 500,
                source: 'daily',
                dailyAmount: 500,
              )
            : null,
        paymentJournalId: operation == 'review.purchases.invoice_inline'
            ? 'inline-payment-journal'
            : null,
        recordedAt: '2026-11-07T12:00:00Z',
      );
      if (operation == 'review.purchases.invoice' ||
          operation == 'review.purchases.invoice_inline') {
        _action = () async {
          _committed(await parties.submitInvoice(invoice));
        };
      } else {
        _committed(await parties.submitInvoice(invoice));
        final payment = parties.supplierPaymentIntent(
          operationId: 'payment-operation',
          paymentId: 'payment',
          journalId: 'payment-journal',
          supplierId: 'supplier',
          invoiceId: 'invoice',
          date: _date('2026-11-07'),
          amount: BigInt.from(500),
          fundingSource: FundingSource.daily,
          dailyAmount: BigInt.from(500),
          cashAmount: BigInt.zero,
          note: 'Synthetic payment',
          recordedAt: '2026-11-07T13:00:00Z',
        );
        _action = () async {
          _committed(await parties.submitPayment(payment));
        };
      }
    } else if (operation.startsWith('review.portable.')) {
      PortableJournalState named(PortableJournalState state, String name) {
        final raw = state.account.toJson();
        final preferences = (raw['preferences']! as Map)
            .cast<String, Object?>();
        final restaurant = (preferences['restaurant']! as Map)
            .cast<String, Object?>();
        return state.copyWith(
          account: legacy.decodeJson({
            ...raw,
            'preferences': {
              ...preferences,
              'restaurant': {...restaurant, 'name': name},
            },
          }),
        );
      }

      if (operation == 'review.portable.recover') {
        final previousPayload = codec.encodeState(
          named(initialState, 'Synthetic previous backup'),
        );
        _ack(
          await store.writeDocument(
            previousPayload,
            writeToken: 'previous-candidate',
            expected: _snapshot,
          ),
        );
        await _read();
        _expectedReplacementPayload = previousPayload;
      }
      if (operation != 'review.portable.export') {
        final currentPayload = codec.encodeState(
          named(initialState, 'Synthetic current account'),
        );
        _ack(
          await store.writeDocument(
            currentPayload,
            writeToken: 'current-account',
            expected: _snapshot,
          ),
        );
        await _read();
      }
      final transfer = PortableAccountTransferController(
        store: store,
        snapshot: _snapshot,
        isWriteBlocked: () => false,
      );
      _dispose.add(transfer.dispose);
      if (operation == 'review.portable.export') {
        _action = () async {
          bytes = transfer.exportBytes();
        };
      } else {
        if (operation == 'review.portable.recover') {
          _ack(await transfer.preparePrevious());
        } else {
          final incoming = named(initialState, 'Synthetic incoming backup');
          _expectedReplacementPayload = codec.encodeState(incoming);
          _ack(transfer.prepareImport(codec.encodeBytes(incoming)));
        }
        if (_expectedReplacementPayload == _snapshot.payload ||
            codec.encodeState(transfer.pendingImport!.state) !=
                _expectedReplacementPayload) {
          throw StateError(
            'Benchmark replacement candidate is not distinct or selected.',
          );
        }
        _action = () async {
          _ack(await transfer.confirmImport());
        };
      }
    } else if (reportOperation) {
      final composer = RestaurantReportComposer(
        account,
        compareText: (a, b) => a.compareTo(b),
      );
      final kind = operation.split('.')[2];
      report = switch (kind) {
        'daily' => composer.daily('2026-10-04'),
        'invoice' => composer.invoice('report-invoice'),
        'sale' => composer.sale('report-sale'),
        'sales' => composer.sales(),
        'statement' => composer.statement(from: '2026-10-04', to: '2026-10-04'),
        'cash' => composer.cash(from: '2026-10-04', to: '2026-10-04'),
        'payment' => composer.payment('report-payment'),
        _ => throw StateError('Unsupported report benchmark kind.'),
      };
      final pdf = RestaurantReportPdf();
      _action = () async {
        final generated = await pdf.generate(report!);
        _ack(generated);
        bytes = (generated as CapabilitySuccess<Uint8List>).value;
      };
    } else if (operation == 'review.reports.generate') {
      // Explicit comparator is confined to ASCII synthetic source keys.
      final report = RestaurantReportComposer(
        account,
        compareText: (a, b) => a.compareTo(b),
      ).cash();
      final pdf = RestaurantReportPdf();
      _action = () async {
        final generated = await pdf.generate(report);
        _ack(generated);
        bytes = (generated as CapabilitySuccess<Uint8List>).value;
      };
    }
    if (_action == null) throw StateError('Unsupported review benchmark case.');
    await _read();
    beforeRun = _snapshot;
  }

  static AccountDocument _purchaseHistoryFixture(AccountDocument base) {
    final raw = base.toJson();
    return const LegacyAccountCodec().decodeJson({
      ...raw,
      'invoices': [
        for (var i = 0; i < 200; i++)
          {
            'id': 'history-invoice-$i',
            'supplierId': 'supplier',
            'number': 'H$i',
            'date': '2026-10-04',
            'createdAt': '2026-10-04T12:00:00Z',
            'note': 'Synthetic history',
            'lines': [
              {
                'materialId': 'material',
                'name': 'Synthetic material',
                'unit': 'piece',
                'quantityCartons': 1,
                'quantityPieces': 2,
                'priceCarton': 1000 + i,
                'pricePiece': 100,
              },
            ],
          },
      ],
    });
  }

  static AccountDocument _reportFixture(
    AccountDocument base,
    String operation,
  ) {
    final large = operation.endsWith('.multi');
    final count = large ? 150 : 1;
    if (large) {
      final raw = base.toJson();
      final prototype = (raw['products']! as List).first as Map;
      base = const LegacyAccountCodec().decodeJson({
        ...raw,
        'products': [
          for (var i = 0; i < 150; i++)
            {
              ...prototype.cast<String, Object?>(),
              'id': 'product-$i',
              'name': 'Synthetic item $i',
              'code': 'BENCH-$i',
            },
        ],
      });
    }
    final saleLineCount = large && operation.startsWith('review.reports.sale.')
        ? 150
        : 1;
    final sale = SaleProposal.build(
      base,
      draft: {
        'date': '2026-10-04',
        'orderType': base.preferences.orderTypes.first,
        'discount': 0,
        'note': 'Synthetic report',
        'lines': [
          for (var i = 0; i < saleLineCount; i++)
            {'productId': 'product-$i', 'quantity': 1, 'price': 1000},
        ],
      },
      saleId: 'report-sale',
      createdAt: '2026-10-04T12:00:00Z',
    ).sale;
    final raw = base.toJson();
    final invoice = {
      'id': 'report-invoice',
      'supplierId': 'supplier',
      'number': 'REPORT',
      'date': '2026-10-04',
      'createdAt': '2026-10-04T12:00:00Z',
      'note': 'Synthetic report',
      'lines': [
        for (var i = 0; i < count; i++)
          {
            'materialId': 'material',
            'name': 'Synthetic material $i',
            'unit': 'piece',
            'quantityCartons': 1,
            'quantityPieces': 2,
            'priceCarton': 1000,
            'pricePiece': 100,
          },
      ],
    };
    return const LegacyAccountCodec().decodeJson({
      ...raw,
      'sales': [
        sale,
        if (operation.startsWith('review.reports.sales.') && large)
          for (var i = 1; i < count; i++)
            {
              ...sale,
              'id': 'report-sale-$i',
              'number': 'S-${(i + 1).toString().padLeft(6, '0')}',
            },
      ],
      'invoices': [invoice],
      'payments': [
        {
          'id': 'report-payment',
          'supplierId': 'supplier',
          'invoiceId': 'report-invoice',
          'invoiceAmount': 50,
          'debtAmount': 0,
          'categoryId': 'samoon',
          'date': '2026-10-04',
          'amount': 50,
          'funding': {'source': 'daily', 'dailyAmount': 50, 'cashAmount': 0},
          'note': operation.endsWith('.max')
              ? 'Valid bounded note. ' * 25
              : 'Synthetic payment',
          'createdAt': '2026-10-04T13:00:00Z',
        },
      ],
      'days': {
        ...base.days,
        '2026-10-04': {
          'expenses': [
            for (var i = 0; i < count; i++)
              {
                'id': 'report-expense-$i',
                'categoryId': 'samoon',
                'amount': 10,
                'note': 'Synthetic expense $i',
                'createdAt': '2026-10-04T12:00:00Z',
                'funding': {
                  'source': 'daily',
                  'dailyAmount': 10,
                  'cashAmount': 0,
                },
              },
          ],
          'chickenUsed': 0,
          'chickenLeft': 0,
          'balance': null,
          'totalOverride': null,
          'remaining': null,
        },
      },
      'transactions': [
        for (var i = 0; i < 200; i++)
          {
            'id': 'report-cash-$i',
            'date': i < count ? '2026-10-04' : '2026-10-01',
            'type': 'deposit',
            'amount': 1,
            'note': 'Synthetic cash $i',
            'createdAt': '2026-10-04T12:00:00Z',
          },
      ],
    });
  }

  /// Exactly the registered command; preparation and validation are outside it.
  Future<void> run() => _action!();

  Future<void> verifyDurable() async {
    await _read();
    final current = state;
    final raw = current.account.toJson();
    final expenses =
        (current.account.days['2026-11-07'] as Map?)?['expenses'] as List? ??
        <Object?>[];
    final correct = switch (operation) {
      'review.suppliers.opening_write' => _verifyOpening(current),
      'review.suppliers.additional_debt' =>
        (raw['debts'] as List).length == 1 &&
            (raw['debts'] as List).single['id'] == 'additional-debt' &&
            (raw['debts'] as List).single['supplierId'] == 'supplier' &&
            (raw['debts'] as List).single['amount'] == 1000 &&
            current.journals.length == 2 &&
            current.journals.last.journal.id ==
                'additional-debt-operation:debt' &&
            current.receipts.length == 1 &&
            current.receipts.single.identity.operationId ==
                'additional-debt-operation',
      'review.cash.external_deposit' =>
        (raw['transactions'] as List).length == 201 &&
            (raw['transactions'] as List).any(
              (row) =>
                  row['id'] == 'external-deposit' &&
                  row['amount'] == 1000 &&
                  row['type'] == 'deposit',
            ) &&
            current.journals.length == 2 &&
            current.journals.last.journal.id == 'external-deposit-journal' &&
            current.receipts.length == 1 &&
            current.receipts.single.identity.operationId ==
                'external-deposit-operation',
      'review.categories.save' =>
        (raw['categories'] as List).any(
              (row) =>
                  row['id'] == 'synthetic-category' &&
                  row['name'] == 'Synthetic category' &&
                  row['type'] == 'additional',
            ) &&
            current.journals.length == 1 &&
            current.receipts.isEmpty,

      'review.sales.checkout' =>
        (raw['sales'] as List).length == 1 &&
            current.receipts.last.identity.operationId == 'sale-operation',
      'review.sales.void' => (raw['sales'] as List).single['status'] == 'void',
      'review.spending.correct' =>
        expenses.length == 1 && (expenses.single as Map)['amount'] == 125,
      'review.days.shift' =>
        ((current.account.days['2026-11-08'] as Map?)?['expenses'] as List? ??
                    [])
                .length ==
            1,
      'review.suppliers.ledger_query' => ledgerRows?.length == 200,
      'review.purchases.analysis' => purchaseAnalysis?.invoiceCount == 200,
      'review.purchases.invoice_inline' =>
        (raw['invoices'] as List).length == 1 &&
            (raw['payments'] as List).single['amount'] == 500,
      'review.sales.refund' =>
        (raw['saleReturns'] as List).length == 1 &&
            (raw['saleReturns'] as List).single['amount'] == 1000,
      'review.spending.expense' =>
        expenses.length == 1 && (expenses.single as Map)['amount'] == 100,
      'review.cash.transfer' =>
        (raw['transfers'] as List).length == 1 &&
            (raw['transfers'] as List).single['amount'] == 50,
      'review.register.remaining' =>
        ((current.account.days['2026-11-07'] as Map)['remaining']
                as Map)['amount'] ==
            100000,
      'review.purchases.invoice' =>
        (raw['invoices'] as List).length == 1 &&
            SupplierLedgerQueries(
                  current.account,
                  compareText: (a, b) => a.compareTo(b),
                ).invoiceTotal(
                  (raw['invoices'] as List).single as Map<String, Object?>,
                ) ==
                BigInt.from(2300),
      'review.purchases.payment' =>
        (raw['payments'] as List).length == 1 &&
            (raw['payments'] as List).single['amount'] == 500,
      'review.portable.export' =>
        bytes != null &&
            codecEqual(
              const PortableJournalCodec().decodeBytes(bytes!),
              current,
            ),
      'review.portable.import' || 'review.portable.recover' =>
        _snapshot.fence != beforeRun.fence &&
            _expectedReplacementPayload != beforeRun.payload &&
            _snapshot.payload == _expectedReplacementPayload,
      'review.reports.generate' =>
        bytes != null &&
            bytes!.length > 1000 &&
            ascii.decode(bytes!.take(5).toList()) == '%PDF-',
      'review.undo.expense' =>
        expenses.isEmpty &&
            current.journals.length == 3 &&
            current.receipts.length == 2,
      _ when operation.startsWith('review.reports.') =>
        bytes != null &&
            bytes!.length > 1000 &&
            ascii.decode(bytes!.take(5).toList()) == '%PDF-',
      _ => false,
    };
    if (!correct) throw StateError('Review benchmark postcondition failed.');
    if (operation == 'review.portable.export' ||
        operation.startsWith('review.reports.') ||
        operation == 'review.suppliers.ledger_query' ||
        operation == 'review.purchases.analysis') {
      if (_snapshot.revision != beforeRun.revision ||
          _snapshot.fence != beforeRun.fence ||
          _snapshot.payload != beforeRun.payload) {
        throw StateError('Read-only benchmark wrote account state.');
      }
    }
    final exact = _snapshot.payload;
    await store.close();
    final reopened = AppAccountsStore(
      openStore: () => PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: directory.path,
      ),
    );
    try {
      final read = await reopened.readDocument();
      _ack(read);
      if ((read as CapabilitySuccess<DocumentSnapshot?>).value?.payload !=
          exact) {
        throw StateError('Review benchmark durable reopen mismatch.');
      }
    } finally {
      await reopened.close();
    }
  }

  bool _verifyOpening(PortableJournalState current) {
    final before = const PortableJournalCodec().decodeState(beforeRun.payload);
    final expectedRaw = <String, Object?>{...before.account.toJson()};
    expectedRaw['suppliers'] = [
      for (final row in expectedRaw['suppliers']! as List)
        if ((row as Map)['id'] == 'supplier')
          <String, Object?>{
            ...row.cast<String, Object?>(),
            'openingBalance': 1000,
          }
        else
          row,
    ];
    final original = SupplierOpeningHistory.baseOpening(before);
    final retained = SupplierOpeningHistory.baseOpening(current);
    if (jsonEncode(current.account.toJson()) != jsonEncode(expectedRaw) ||
        jsonEncode(original.toJson()) != jsonEncode(retained.toJson()) ||
        current.journals.length != before.journals.length + 1 ||
        current.receipts.length != before.receipts.length + 1 ||
        current.receipts.last.identity.operationId !=
            'opening-amendment-operation' ||
        current.receipts.last.status != DurableCommandStatus.committed ||
        !current.requiredFeatures.contains('supplierOpeningAmendments-v1') ||
        current.accountLineage != before.accountLineage ||
        jsonEncode(current.cutoverState.toJson()) !=
            jsonEncode(before.cutoverState.toJson()) ||
        jsonEncode(current.sourceProvenance.toJson()) !=
            jsonEncode(before.sourceProvenance.toJson())) {
      return false;
    }
    final linked = current.journals.last;
    return linked.journal.id ==
            'opening-amendment-operation:opening-amendment' &&
        linked.journal.effectiveDate == before.cutoverState.cutoverDate &&
        linked.sourceType == SupplierOpeningCommand.sourceType &&
        linked.sourceRecordId == 'supplier' &&
        linked.metadata['baseOpeningSha256'] ==
            SupplierOpeningHistory.openingHash(original) &&
        SupplierOpeningHistory.recognizedOpening(
              current,
              'supplier',
              RestaurantJournalMapper(),
            ) ==
            BigInt.from(1000);
  }

  static bool codecEqual(PortableJournalState a, PortableJournalState b) =>
      jsonEncode(a.toJson()) == jsonEncode(b.toJson());

  Future<void> close() async {
    for (final dispose in _dispose.reversed) {
      dispose();
    }
    _dispose.clear();
    await store.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
