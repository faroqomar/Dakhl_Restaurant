import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounting/journal_command_host.dart';
import '../accounting/deleted_party_restoration.dart';
import '../accounting/party_session_compensation.dart';
import '../accounting/source_record_order.dart';
import '../accounting/source_material_restoration.dart';
import '../accounting/restaurant_journal_invoice_correction_commands.dart';
import '../accounting/restaurant_journal_mapper.dart';
import '../accounting/restaurant_journal_payment_correction_commands.dart';
import '../accounting/restaurant_journal_spending_commands.dart';
import '../accounts/account_document.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import 'parties_view_model.dart';
import 'purchase_proposal.dart';
import 'supplier_ledger.dart';

/// Nonvisual supplier, purchase invoice, and payment operations workflow bound
/// to an explicitly initialized complete-state account. Construction does not
/// enroll an account, establish cutover, or change the schema-11 runtime repository.
final class PartiesOperationsViewModel extends ChangeNotifier {
  PartiesOperationsViewModel({
    required DocumentSnapshot snapshot,
    RestaurantJournalSpendingCommandCoordinator? spendingCommands,
    RestaurantJournalPaymentCorrectionCoordinator? paymentCorrectionCommands,
    RestaurantJournalInvoiceCorrectionCoordinator? invoiceCorrectionCommands,
    LocalDocumentWorkspaceStore? store,
    RestaurantJournalMapper? mapper,
    PortableJournalCodec? codec,
    this.isWriteBlocked,
    this.compareText,
  }) : authorityFence = snapshot.fence,
       _snapshot = snapshot,
       _codec =
           codec ?? spendingCommands?.codec ?? const PortableJournalCodec() {
    final s =
        store ??
        spendingCommands?.store ??
        paymentCorrectionCommands?.host.store ??
        invoiceCorrectionCommands?.host.store;
    if (s == null) {
      throw ArgumentError(
        'Either store or a coordinator with a store must be provided.',
      );
    }
    _store = s;
    final m = mapper ?? spendingCommands?.mapper ?? RestaurantJournalMapper();
    final c = _codec;
    final h = JournalCommandHost(store: _store, codec: c);

    this.spendingCommands =
        spendingCommands ??
        RestaurantJournalSpendingCommandCoordinator(
          store: _store,
          host: h,
          mapper: m,
          codec: c,
        );
    this.paymentCorrectionCommands =
        paymentCorrectionCommands ??
        RestaurantJournalPaymentCorrectionCoordinator(
          store: _store,
          host: h,
          mapper: m,
          codec: c,
        );
    this.invoiceCorrectionCommands =
        invoiceCorrectionCommands ??
        RestaurantJournalInvoiceCorrectionCoordinator(
          store: _store,
          host: h,
          mapper: m,
          codec: c,
        );
    if (!identical(this.invoiceCorrectionCommands.host.store, _store)) {
      throw ArgumentError('Invoice corrections must use the same store owner.');
    }

    restorationCommands = DeletedPartyRestorationCoordinator(
      host: h,
      mapper: m,
    );
    compensationCommands = PartySessionCompensationCoordinator(
      host: h,
      mapper: m,
    );
    _state = _codec.decodeState(snapshot.payload);
    _lineage = _state.accountLineage;
  }

  late final LocalDocumentWorkspaceStore _store;
  final PortableJournalCodec _codec;
  late final RestaurantJournalSpendingCommandCoordinator spendingCommands;
  late final DeletedPartyRestorationCoordinator restorationCommands;
  late final PartySessionCompensationCoordinator compensationCommands;
  late final RestaurantJournalPaymentCorrectionCoordinator
  paymentCorrectionCommands;
  late final RestaurantJournalInvoiceCorrectionCoordinator
  invoiceCorrectionCommands;

  final StorageFence authorityFence;
  final bool Function()? isWriteBlocked;
  final int Function(String, String)? compareText;
  bool get externallyBlocked => isWriteBlocked?.call() ?? false;
  late final String _lineage;
  DocumentSnapshot _snapshot;
  late PortableJournalState _state;

  bool _busy = false;
  bool _disposed = false;
  int _notificationDepth = 0;
  String? _errorCode;

  String? _selectedSupplierId;
  String? _selectedInvoiceId;
  String? _selectedPaymentId;

  Object? _pending;
  RestaurantJournalSpendingOutcome? _lastSpendingOutcome;
  RestaurantJournalPaymentCorrectionOutcome? _lastPaymentCorrectionOutcome;

  bool get busy => _busy;
  bool get needsReadback => _pending != null;
  bool get postingEnabled =>
      !_disposed &&
      !_busy &&
      !externallyBlocked &&
      !needsReadback &&
      !_state.cutoverState.isGated &&
      _state.cutoverState.hasActivePosting;
  String? get errorCode => _errorCode;
  DocumentSnapshot get snapshot => _snapshot;
  AccountDocument get account => _state.account;
  PortableJournalEntry? activeInvoicePosting(String id) =>
      RestaurantJournalInvoiceHistory.activePosting(
        _state,
        id,
        invoiceCorrectionCommands.mapper,
      );
  EditPurchaseInvoiceCommand editInvoiceIntent({
    required String operationId,
    required String invoiceId,
    required Map<String, Object?> expectedSource,
    required String expectedActiveJournalId,
    required String inverseJournalId,
    required String replacementJournalId,
    required String supplierId,
    required String invoiceNumber,
    required DateOnly date,
    required Iterable<PurchaseLine> lines,
    String note = '',
    SourceRecordOrder? sourceOrder,
    SourceMaterialRestoration? materialRestoration,
    required String reason,
    required String recordedAt,
    JournalPolicy? policy,
  }) => EditPurchaseInvoiceCommand(
    operationId: operationId,
    accountLineage: _lineage,
    expectedFence: authorityFence,
    invoiceId: invoiceId,
    expectedSource: expectedSource,
    expectedActiveJournalId: expectedActiveJournalId,
    inverseJournalId: inverseJournalId,
    replacementJournalId: replacementJournalId,
    supplierId: supplierId,
    invoiceNumber: invoiceNumber,
    date: date,
    lines: lines,
    note: note,
    sourceOrder: sourceOrder,
    materialRestoration: materialRestoration,
    reason: reason,
    recordedAt: recordedAt,
    profile: invoiceCorrectionCommands.mapper.profile,
    mapperDefaultPolicy: invoiceCorrectionCommands.mapper.defaultPolicy,
    policy: policy,
  );
  DeletePurchaseInvoiceCommand deleteInvoiceIntent({
    required String operationId,
    required String invoiceId,
    required Map<String, Object?> expectedSource,
    required String expectedActiveJournalId,
    required String inverseJournalId,
    required String reason,
    required String recordedAt,
  }) => DeletePurchaseInvoiceCommand(
    operationId: operationId,
    accountLineage: _lineage,
    expectedFence: authorityFence,
    invoiceId: invoiceId,
    expectedSource: expectedSource,
    expectedActiveJournalId: expectedActiveJournalId,
    inverseJournalId: inverseJournalId,
    reason: reason,
    recordedAt: recordedAt,
    profile: invoiceCorrectionCommands.mapper.profile,
    mapperDefaultPolicy: invoiceCorrectionCommands.mapper.defaultPolicy,
  );
  DurableProposalEvaluation<
    PortableJournalState,
    RestaurantJournalInvoiceCorrectionOutcome
  >
  previewInvoiceCorrection(PurchaseInvoiceCorrectionCommand command) =>
      RestaurantJournalInvoiceCorrectionCoordinator.evaluate(
        command: command,
        state: _state,
        mapper: invoiceCorrectionCommands.mapper,
      );
  Future<DurableCommandResult<RestaurantJournalInvoiceCorrectionOutcome>>
  submitInvoiceCorrection(PurchaseInvoiceCorrectionCommand command) => _submit(
    command: command,
    lineage: command.accountLineage,
    fence: command.expectedFence,
    execute: () => invoiceCorrectionCommands.execute(command),
    onCommitted: (outcome) {
      _selectedInvoiceId = outcome.invoiceId;
    },
    onReplayed: (outcome) {
      _selectedInvoiceId = outcome?.invoiceId;
    },
  );
  String get accountLineage => _lineage;

  String? get selectedSupplierId => _selectedSupplierId;
  String? get selectedInvoiceId => _selectedInvoiceId;
  String? get selectedPaymentId => _selectedPaymentId;
  RestaurantJournalSpendingOutcome? get lastSpendingOutcome =>
      _lastSpendingOutcome;
  RestaurantJournalPaymentCorrectionOutcome? get lastPaymentCorrectionOutcome =>
      _lastPaymentCorrectionOutcome;

  List<SupplierRecord> get suppliers => List.unmodifiable([
    for (final row
        in (_state.account.toJson()['suppliers']! as List)
            .cast<Map<String, Object?>>())
      SupplierRecord.fromMap(row),
  ]);

  List<MaterialRecord> get materials => List.unmodifiable([
    for (final row
        in (_state.account.toJson()['materials']! as List)
            .cast<Map<String, Object?>>())
      MaterialRecord.fromMap(row),
  ]);

  List<Map<String, Object?>> get invoices => List.unmodifiable(
    (_state.account.toJson()['invoices']! as List).cast<Map<String, Object?>>(),
  );

  List<Map<String, Object?>> get payments => List.unmodifiable(
    (_state.account.toJson()['payments']! as List).cast<Map<String, Object?>>(),
  );

  SupplierLedgerQueries supplierLedger(
    String supplierId, {
    int Function(String, String)? compareText,
  }) => SupplierLedgerQueries(
    account,
    compareText:
        compareText ??
        this.compareText ??
        (throw StateError('A reviewed collation comparator is required.')),
  );

  Map<String, Object?>? get selectedSupplier {
    final id = _selectedSupplierId;
    if (id == null) return null;
    for (final s
        in (_state.account.toJson()['suppliers']! as List)
            .cast<Map<String, Object?>>()) {
      if (s['id'] == id) return s;
    }
    return null;
  }

  Map<String, Object?>? get selectedInvoice {
    final id = _selectedInvoiceId;
    if (id == null) return null;
    for (final inv in invoices) {
      if (inv['id'] == id) return inv;
    }
    return null;
  }

  Map<String, Object?>? get selectedPayment {
    final id = _selectedPaymentId;
    if (id == null) return null;
    for (final p in payments) {
      if (p['id'] == id) return p;
    }
    return null;
  }

  void selectSupplier(String? id) {
    if (_disposed || _busy) return;
    _selectedSupplierId = id;
    _errorCode = null;
    _notify();
  }

  void selectInvoice(String? id) {
    if (_disposed || _busy) return;
    _selectedInvoiceId = id;
    _errorCode = null;
    _notify();
  }

  void selectPayment(String? id) {
    if (_disposed || _busy) return;
    _selectedPaymentId = id;
    _errorCode = null;
    _notify();
  }

  /// Refresh from the same complete-state owner after other workflows commit.
  CapabilityResult<void> acceptSnapshot(DocumentSnapshot snapshot) {
    if (_disposed) return _failure('disposed');
    if (_busy) return _failure('busy');
    if (needsReadback) return _failure('commit_unknown');
    try {
      _accept(snapshot);
      _errorCode = null;
      _notify();
      return const CapabilitySuccess(null);
    } on PortableJournalException catch (error) {
      return _failure(error.code);
    } on Object {
      return _failure('invalid_snapshot');
    }
  }

  void _accept(DocumentSnapshot next) {
    if (next.fence != authorityFence) {
      throw const FormatException('stale_generation');
    }
    if (next.revision < _snapshot.revision ||
        (next.revision == _snapshot.revision &&
            (next.payload != _snapshot.payload ||
                next.writeToken != _snapshot.writeToken))) {
      throw const FormatException('stale_snapshot');
    }
    final state = _codec.decodeState(next.payload);
    if (state.accountLineage != _lineage) {
      throw const FormatException('account_lineage_mismatch');
    }
    _snapshot = next;
    _state = state;
  }

  // --- Previews ---

  DurableProposalEvaluation<
    PortableJournalState,
    RestaurantJournalSpendingOutcome
  >
  previewInvoice(CreatePurchaseInvoiceCommand command) {
    if (command.accountLineage != _lineage ||
        command.expectedFence != authorityFence) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: 'stale_authority_fence',
        rejectionMessage: 'The command belongs to another account session.',
      );
    }
    final cutover = _state.cutoverState;
    if (cutover.isGated ||
        !cutover.hasActivePosting ||
        cutover.cutoverDate == null) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: 'cutover_gated',
        rejectionMessage: 'Financial posting has not been activated.',
      );
    }
    return RestaurantJournalSpendingCommandCoordinator.evaluateInvoice(
      command: command,
      state: _state,
      cutoverDate: cutover.cutoverDate!,
      mapper: spendingCommands.mapper,
    );
  }

  DurableProposalEvaluation<
    PortableJournalState,
    RestaurantJournalSpendingOutcome
  >
  previewPayment(CreateSupplierPaymentCommand command) {
    if (command.accountLineage != _lineage ||
        command.expectedFence != authorityFence) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: 'stale_authority_fence',
        rejectionMessage: 'The command belongs to another account session.',
      );
    }
    final cutover = _state.cutoverState;
    if (cutover.isGated ||
        !cutover.hasActivePosting ||
        cutover.cutoverDate == null) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: 'cutover_gated',
        rejectionMessage: 'Financial posting has not been activated.',
      );
    }
    return RestaurantJournalSpendingCommandCoordinator.evaluatePayment(
      command: command,
      state: _state,
      cutoverDate: cutover.cutoverDate!,
      mapper: spendingCommands.mapper,
    );
  }

  DurableProposalEvaluation<
    PortableJournalState,
    RestaurantJournalPaymentCorrectionOutcome
  >
  previewPaymentCorrection(SupplierPaymentCorrectionCommand command) {
    if (command.accountLineage != _lineage ||
        command.expectedFence != authorityFence) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: 'stale_authority_fence',
        rejectionMessage: 'The command belongs to another account session.',
      );
    }
    final cutover = _state.cutoverState;
    if (cutover.isGated ||
        !cutover.hasActivePosting ||
        cutover.cutoverDate == null) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: 'cutover_gated',
        rejectionMessage: 'Financial posting has not been activated.',
      );
    }
    return RestaurantJournalPaymentCorrectionCoordinator.evaluate(
      command: command,
      state: _state,
      mapper: paymentCorrectionCommands.mapper,
    );
  }

  // --- Intent Creators ---

  CreatePurchaseInvoiceCommand purchaseInvoiceIntent({
    required String operationId,
    required String invoiceId,
    required String invoiceJournalId,
    required String supplierId,
    required String invoiceNumber,
    required DateOnly date,
    required Iterable<PurchaseLine> lines,
    String note = '',
    PurchasePayment? immediatePayment,
    String? paymentJournalId,
    required String recordedAt,
    JournalPolicy? policy,
  }) => CreatePurchaseInvoiceCommand(
    operationId: operationId,
    accountLineage: _lineage,
    expectedFence: authorityFence,
    invoiceId: invoiceId,
    invoiceJournalId: invoiceJournalId,
    supplierId: supplierId,
    invoiceNumber: invoiceNumber,
    date: date,
    lines: lines,
    note: note,
    immediatePayment: immediatePayment,
    paymentJournalId: paymentJournalId,
    recordedAt: recordedAt,
    policy: policy,
  );

  CreateSupplierPaymentCommand supplierPaymentIntent({
    required String operationId,
    required String paymentId,
    required String journalId,
    required String supplierId,
    String? invoiceId,
    String? categoryId,
    required DateOnly date,
    required BigInt amount,
    required FundingSource fundingSource,
    BigInt? dailyAmount,
    BigInt? cashAmount,
    String note = '',
    required String recordedAt,
    JournalPolicy? policy,
  }) => CreateSupplierPaymentCommand(
    operationId: operationId,
    accountLineage: _lineage,
    expectedFence: authorityFence,
    paymentId: paymentId,
    journalId: journalId,
    supplierId: supplierId,
    invoiceId: invoiceId,
    categoryId: categoryId,
    date: date,
    amount: amount,
    fundingSource: fundingSource,
    dailyAmount: dailyAmount,
    cashAmount: cashAmount,
    note: note,
    recordedAt: recordedAt,
    policy: policy,
  );

  EditSupplierPaymentCommand editPaymentIntent({
    required String operationId,
    required String paymentId,
    required String expectedActiveJournalId,
    required Map<String, Object?> expectedSource,
    required String inverseJournalId,
    required String replacementJournalId,
    required DateOnly date,
    required String categoryId,
    required String supplierId,
    String? invoiceId,
    required BigInt invoiceAmount,
    required BigInt debtAmount,
    required BigInt amount,
    required FundingSource fundingSource,
    BigInt? dailyAmount,
    BigInt? cashAmount,
    String note = '',
    SourceRecordOrder? sourceOrder,
    required String reason,
    required String recordedAt,
    RestaurantAccountProfile? profile,
    JournalPolicy? policy,
  }) => EditSupplierPaymentCommand(
    operationId: operationId,
    accountLineage: _lineage,
    expectedFence: authorityFence,
    paymentId: paymentId,
    expectedActiveJournalId: expectedActiveJournalId,
    expectedSource: expectedSource,
    inverseJournalId: inverseJournalId,
    replacementJournalId: replacementJournalId,
    date: date,
    categoryId: categoryId,
    supplierId: supplierId,
    invoiceId: invoiceId,
    invoiceAmount: invoiceAmount,
    debtAmount: debtAmount,
    amount: amount,
    fundingSource: fundingSource,
    dailyAmount: dailyAmount,
    cashAmount: cashAmount,
    note: note,
    sourceOrder: sourceOrder,
    reason: reason,
    recordedAt: recordedAt,
    profile: profile ?? const RestaurantAccountProfile(),
    policy: policy,
  );

  DeleteSupplierPaymentCommand deletePaymentIntent({
    required String operationId,
    required String paymentId,
    required String expectedActiveJournalId,
    required Map<String, Object?> expectedSource,
    required String inverseJournalId,
    required String reason,
    required String recordedAt,
    RestaurantAccountProfile? profile,
    JournalPolicy? policy,
  }) => DeleteSupplierPaymentCommand(
    operationId: operationId,
    accountLineage: _lineage,
    expectedFence: authorityFence,
    paymentId: paymentId,
    expectedActiveJournalId: expectedActiveJournalId,
    expectedSource: expectedSource,
    inverseJournalId: inverseJournalId,
    reason: reason,
    recordedAt: recordedAt,
    profile: profile ?? const RestaurantAccountProfile(),
    policy: policy,
  );

  // --- Submissions ---

  Future<DurableCommandResult<PartySessionCompensationOutcome>>
  submitCompensation(PartySessionCompensationCommand command) =>
      _submit<PartySessionCompensationOutcome>(
        command: command,
        lineage: command.accountLineage,
        fence: command.fence,
        execute: () => compensationCommands.execute(command),
        onCommitted: (_) {},
        onReplayed: (_) {},
      );

  Future<DurableCommandResult<PartyRestorationOutcome>> submitRestoration(
    RestoreDeletedPartyCommand command,
  ) => _submit<PartyRestorationOutcome>(
    command: command,
    lineage: command.accountLineage,
    fence: command.expectedFence,
    execute: () => restorationCommands.execute(command),
    onCommitted: (_) {},
    onReplayed: (_) {},
  );

  Future<DurableCommandResult<RestaurantJournalSpendingOutcome>> submitInvoice(
    CreatePurchaseInvoiceCommand command,
  ) => _submit<RestaurantJournalSpendingOutcome>(
    command: command,
    lineage: command.accountLineage,
    fence: command.expectedFence,
    execute: () => spendingCommands.execute(command),
    onCommitted: (outcome) {
      _lastSpendingOutcome = outcome;
      _selectedInvoiceId = outcome.invoiceId ?? command.invoiceId;
      _selectedSupplierId = outcome.supplierId ?? command.supplierId;
      if (outcome.paymentId != null) {
        _selectedPaymentId = outcome.paymentId;
      }
    },
    onReplayed: (outcome) {
      _lastSpendingOutcome = outcome;
      _selectedInvoiceId = outcome?.invoiceId ?? command.invoiceId;
      _selectedSupplierId = outcome?.supplierId ?? command.supplierId;
      if (outcome?.paymentId != null) {
        _selectedPaymentId = outcome!.paymentId;
      }
    },
  );

  Future<DurableCommandResult<RestaurantJournalSpendingOutcome>> submitPayment(
    CreateSupplierPaymentCommand command,
  ) => _submit<RestaurantJournalSpendingOutcome>(
    command: command,
    lineage: command.accountLineage,
    fence: command.expectedFence,
    execute: () => spendingCommands.execute(command),
    onCommitted: (outcome) {
      _lastSpendingOutcome = outcome;
      _selectedPaymentId = outcome.paymentId ?? command.paymentId;
      _selectedSupplierId = outcome.supplierId ?? command.supplierId;
      if (outcome.invoiceId != null) {
        _selectedInvoiceId = outcome.invoiceId;
      }
    },
    onReplayed: (outcome) {
      _lastSpendingOutcome = outcome;
      _selectedPaymentId = outcome?.paymentId ?? command.paymentId;
      _selectedSupplierId = outcome?.supplierId ?? command.supplierId;
      if (outcome?.invoiceId != null) {
        _selectedInvoiceId = outcome!.invoiceId;
      }
    },
  );

  Future<DurableCommandResult<RestaurantJournalPaymentCorrectionOutcome>>
  submitPaymentCorrection(SupplierPaymentCorrectionCommand command) =>
      _submit<RestaurantJournalPaymentCorrectionOutcome>(
        command: command,
        lineage: command.accountLineage,
        fence: command.expectedFence,
        execute: () => paymentCorrectionCommands.execute(command),
        onCommitted: (outcome) {
          _lastPaymentCorrectionOutcome = outcome;
          _selectedPaymentId = outcome.paymentId;
        },
        onReplayed: (outcome) {
          _lastPaymentCorrectionOutcome = outcome;
          _selectedPaymentId = outcome?.paymentId ?? command.paymentId;
        },
      );

  Future<DurableCommandResult<dynamic>> retry() {
    final pending = _pending;
    if (pending == null) {
      return Future.value(
        const DurableCommandFailure(
          code: 'nothing_to_retry',
          message: 'No pending command to retry.',
        ),
      );
    }
    if (pending is PartySessionCompensationCommand) {
      return submitCompensation(pending);
    }
    if (pending is RestoreDeletedPartyCommand) {
      return submitRestoration(pending);
    }
    if (pending is CreatePurchaseInvoiceCommand) return submitInvoice(pending);
    if (pending is PurchaseInvoiceCorrectionCommand) {
      return submitInvoiceCorrection(pending);
    }
    if (pending is CreateSupplierPaymentCommand) return submitPayment(pending);
    if (pending is SupplierPaymentCorrectionCommand) {
      return submitPaymentCorrection(pending);
    }
    return Future.value(
      const DurableCommandFailure(
        code: 'unknown_pending_command',
        message: 'Unrecognized pending command type.',
      ),
    );
  }

  Future<DurableCommandResult<TOutcome>> _submit<TOutcome>({
    required Object command,
    required String lineage,
    required StorageFence? fence,
    required Future<DurableCommandResult<TOutcome>> Function() execute,
    required void Function(TOutcome outcome) onCommitted,
    required void Function(TOutcome? outcome) onReplayed,
  }) async {
    if (_disposed) return _commandFailure<TOutcome>('disposed');
    if (_busy || externallyBlocked) return _commandFailure<TOutcome>('busy');
    if (_pending != null && !identical(_pending, command)) {
      return _commandFailure<TOutcome>('commit_unknown');
    }
    if (lineage != _lineage || fence != authorityFence) {
      return _commandFailure<TOutcome>('stale_authority_fence');
    }
    _busy = true;
    _errorCode = null;
    try {
      _notify();
      if (_disposed) return _commandFailure<TOutcome>('disposed');
      _pending = command;
      final result = await execute();
      if (_disposed) return result;
      switch (result) {
        case DurableCommandSuccess(:final outcome, :final snapshot):
          _accept(snapshot);
          onCommitted(outcome);
          _pending = null;
        case DurableCommandReplayed(:final outcome, :final snapshot):
          _accept(snapshot);
          onReplayed(outcome);
          _pending = null;
        case DurableCommandFailure(
          :final code,
          :final latestSnapshot,
          :final receipt,
        ):
          // A durable rejection can append its receipt without changing source
          // records. Keep peers at that acknowledged complete-state revision.
          if (latestSnapshot != null &&
              receipt?.status == DurableCommandStatus.rejected) {
            _accept(latestSnapshot);
          }
          _errorCode = code;
          if (code != DurableCommandErrorCodes.commitUnknown &&
              code != DocumentErrorCodes.pendingWrite) {
            _pending = null;
          }
      }
      return result;
    } on Object {
      _errorCode = 'commit_unknown';
      return _commandFailure<TOutcome>('commit_unknown');
    } finally {
      _busy = false;
      _notify();
    }
  }

  CapabilityFailure<void> _failure(String code) =>
      CapabilityFailure(code, 'The parties snapshot was not accepted.');
  DurableCommandFailure<T> _commandFailure<T>(String code) =>
      DurableCommandFailure<T>(
        code: code,
        message: 'Parties action not confirmed.',
      );

  void _notify() {
    if (_disposed) return;
    _notificationDepth++;
    try {
      notifyListeners();
    } finally {
      _notificationDepth--;
      if (_disposed && _notificationDepth == 0) super.dispose();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_notificationDepth == 0) super.dispose();
  }
}
