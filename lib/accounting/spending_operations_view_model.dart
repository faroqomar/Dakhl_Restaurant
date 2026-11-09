import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart' hide PaidSpendingStatement;

import '../accounts/account_document.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import 'daily_cash_queries.dart';
import 'deleted_spending_restoration.dart';
import 'journal_command_host.dart';
import 'source_record_order.dart';
import 'restaurant_journal_expense_correction_commands.dart';
import 'restaurant_journal_mapper.dart';
import 'restaurant_journal_external_cash_commands.dart';
import 'restaurant_journal_spending_commands.dart';
import 'restaurant_journal_transfer_commands.dart';
import 'restaurant_journal_transfer_correction_commands.dart';

/// Nonvisual spending and cash operations workflow bound to an explicitly
/// initialized complete-state account. Construction does not enroll an account,
/// establish cutover, or change the schema-11 runtime repository.
final class SpendingOperationsViewModel extends ChangeNotifier {
  SpendingOperationsViewModel({
    required DocumentSnapshot snapshot,
    RestaurantJournalSpendingCommandCoordinator? spendingCommands,
    RestaurantJournalExpenseCorrectionCoordinator? expenseCorrectionCommands,
    RestaurantJournalTransferCommandCoordinator? transferCommands,
    RestaurantJournalTransferCorrectionCommandCoordinator?
    transferCorrectionCommands,
    LocalDocumentWorkspaceStore? store,
    RestaurantJournalMapper? mapper,
    PortableJournalCodec? codec,
    this.isWriteBlocked,
    this.acceptedCounterAccountId,
  }) : authorityFence = snapshot.fence,
       _snapshot = snapshot,
       _codec =
           codec ?? spendingCommands?.codec ?? const PortableJournalCodec() {
    final s =
        store ??
        spendingCommands?.store ??
        expenseCorrectionCommands?.host.store ??
        transferCommands?.store ??
        transferCorrectionCommands?.store;
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
    this.expenseCorrectionCommands =
        expenseCorrectionCommands ??
        RestaurantJournalExpenseCorrectionCoordinator(
          store: _store,
          host: h,
          mapper: m,
          codec: c,
        );
    this.transferCommands =
        transferCommands ??
        RestaurantJournalTransferCommandCoordinator(
          store: _store,
          host: h,
          mapper: m,
          codec: c,
        );
    this.transferCorrectionCommands =
        transferCorrectionCommands ??
        RestaurantJournalTransferCorrectionCommandCoordinator(
          store: _store,
          host: h,
          mapper: m,
          codec: c,
        );

    externalCashCommands = RestaurantJournalExternalCashCoordinator(
      store: _store,
      host: h,
      mapper: m,
      codec: c,
    );

    deletedRestorationCommands = DeletedSpendingRestorationCoordinator(
      host: h,
      mapper: m,
    );
    _state = _codec.decodeState(snapshot.payload);
    _lineage = _state.accountLineage;
  }

  late final LocalDocumentWorkspaceStore _store;
  final PortableJournalCodec _codec;
  late final RestaurantJournalSpendingCommandCoordinator spendingCommands;
  late final RestaurantJournalExpenseCorrectionCoordinator
  expenseCorrectionCommands;
  late final RestaurantJournalTransferCommandCoordinator transferCommands;
  late final RestaurantJournalTransferCorrectionCommandCoordinator
  transferCorrectionCommands;

  late final RestaurantJournalExternalCashCoordinator externalCashCommands;
  late final DeletedSpendingRestorationCoordinator deletedRestorationCommands;
  final String? acceptedCounterAccountId;
  bool get externalCashMappingAccepted =>
      acceptedCounterAccountId?.trim().isNotEmpty ?? false;

  final StorageFence authorityFence;
  final bool Function()? isWriteBlocked;
  bool get externallyBlocked => isWriteBlocked?.call() ?? false;
  late final String _lineage;
  DocumentSnapshot _snapshot;
  late PortableJournalState _state;

  bool _busy = false;
  bool _disposed = false;
  int _notificationDepth = 0;
  String? _errorCode;
  String? _selectedExpenseId;
  String? _selectedTransferId;

  Object? _pending;
  RestaurantJournalSpendingOutcome? _lastSpendingOutcome;
  RestaurantJournalExpenseCorrectionOutcome? _lastExpenseCorrectionOutcome;
  RestaurantJournalTransferOutcome? _lastTransferOutcome;
  RestaurantJournalTransferCorrectionOutcome? _lastTransferCorrectionOutcome;

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
  String get accountLineage => _lineage;

  String? get selectedExpenseId => _selectedExpenseId;
  String? get selectedTransferId => _selectedTransferId;
  RestaurantJournalSpendingOutcome? get lastSpendingOutcome =>
      _lastSpendingOutcome;
  RestaurantJournalExpenseCorrectionOutcome? get lastExpenseCorrectionOutcome =>
      _lastExpenseCorrectionOutcome;
  RestaurantJournalTransferOutcome? get lastTransferOutcome =>
      _lastTransferOutcome;
  RestaurantJournalTransferCorrectionOutcome?
  get lastTransferCorrectionOutcome => _lastTransferCorrectionOutcome;

  DailyCashQueries get queries => DailyCashQueries(account);
  DailyCashSnapshot daySnapshot(String date) => queries.day(date);
  List<Map<String, Object?>> expensesForDate(String date) =>
      queries.expenses(date);
  BigInt netSales(String date) => queries.netSales(date);
  List<Map<String, Object?>> get cashMovements => queries.cashMovements;
  BigInt get cashBalance => queries.cashBalance;
  PaidSpendingStatement statement({
    String from = '',
    String to = '',
    String categoryId = '',
    SpendingSource source = SpendingSource.all,
  }) => queries.statement(
    from: from,
    to: to,
    categoryId: categoryId,
    source: source,
  );

  Map<String, Object?>? get selectedExpense {
    final id = _selectedExpenseId;
    if (id == null) return null;
    final days = _state.account.toJson()['days'] as Map<String, Object?>? ?? {};
    for (final dayEntry in days.values) {
      if (dayEntry is Map<String, Object?>) {
        final list = (dayEntry['expenses'] as List?) ?? const [];
        for (final exp in list.cast<Map<String, Object?>>()) {
          if (exp['id'] == id) return exp;
        }
      }
    }
    return null;
  }

  Map<String, Object?>? get selectedTransfer {
    final id = _selectedTransferId;
    if (id == null) return null;
    final transfers =
        (_state.account.toJson()['transfers'] as List?) ?? const [];
    for (final tr in transfers.cast<Map<String, Object?>>()) {
      if (tr['id'] == id) return tr;
    }
    return null;
  }

  void selectExpense(String? id) {
    if (_disposed || _busy) return;
    _selectedExpenseId = id;
    _errorCode = null;
    _notify();
  }

  void selectTransfer(String? id) {
    if (_disposed || _busy) return;
    _selectedTransferId = id;
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
  previewExpense(CreateOperatingExpenseCommand command) {
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
    return RestaurantJournalSpendingCommandCoordinator.evaluateExpense(
      command: command,
      state: _state,
      cutoverDate: cutover.cutoverDate!,
      mapper: spendingCommands.mapper,
    );
  }

  DurableProposalEvaluation<
    PortableJournalState,
    RestaurantJournalExpenseCorrectionOutcome
  >
  previewExpenseCorrection(OperatingExpenseCorrectionCommand command) {
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
    return RestaurantJournalExpenseCorrectionCoordinator.evaluate(
      command: command,
      state: _state,
      mapper: expenseCorrectionCommands.mapper,
    );
  }

  DurableProposalEvaluation<
    PortableJournalState,
    RestaurantJournalTransferOutcome
  >
  previewTransfer(DailyToCashboxTransferCommand command) {
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
    return RestaurantJournalTransferCommandCoordinator.evaluateTransfer(
      command: command,
      state: _state,
      cutoverDate: cutover.cutoverDate!,
      mapper: transferCommands.mapper,
    );
  }

  DurableProposalEvaluation<
    PortableJournalState,
    RestaurantJournalTransferCorrectionOutcome
  >
  previewTransferCorrection(Object command) {
    final (String lineage, StorageFence? fence) = switch (command) {
      EditDailyTransferCommand(:final accountLineage, :final expectedFence) => (
        accountLineage,
        expectedFence,
      ),
      DeleteDailyTransferCommand(:final accountLineage, :final expectedFence) =>
        (accountLineage, expectedFence),
      _ => throw ArgumentError('Unsupported transfer correction command.'),
    };

    if (lineage != _lineage || fence != authorityFence) {
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
    return switch (command) {
      EditDailyTransferCommand() =>
        RestaurantJournalTransferCorrectionCommandCoordinator.evaluateEdit(
          command: command,
          state: _state,
          cutoverDate: cutover.cutoverDate!,
          mapper: transferCorrectionCommands.mapper,
        ),
      DeleteDailyTransferCommand() =>
        RestaurantJournalTransferCorrectionCommandCoordinator.evaluateDelete(
          command: command,
          state: _state,
          cutoverDate: cutover.cutoverDate!,
          mapper: transferCorrectionCommands.mapper,
        ),
      _ => throw ArgumentError('Unsupported transfer correction command.'),
    };
  }

  // --- Intent Creators ---

  CreateOperatingExpenseCommand createExpenseIntent({
    required String operationId,
    required String expenseId,
    required String journalId,
    required DateOnly date,
    required String categoryId,
    required BigInt amount,
    required FundingSource fundingSource,
    BigInt? dailyAmount,
    BigInt? cashAmount,
    String note = '',
    required String recordedAt,
    JournalPolicy? policy,
  }) => CreateOperatingExpenseCommand(
    operationId: operationId,
    accountLineage: _lineage,
    expectedFence: authorityFence,
    expenseId: expenseId,
    journalId: journalId,
    date: date,
    categoryId: categoryId,
    amount: amount,
    fundingSource: fundingSource,
    dailyAmount: dailyAmount,
    cashAmount: cashAmount,
    note: note,
    recordedAt: recordedAt,
    policy: policy,
  );

  EditOperatingExpenseCommand editExpenseIntent({
    required String operationId,
    required String expenseId,
    required String expectedActiveJournalId,
    required String inverseJournalId,
    required String replacementJournalId,
    required DateOnly date,
    required String categoryId,
    required BigInt amount,
    required FundingSource fundingSource,
    BigInt? dailyAmount,
    BigInt? cashAmount,
    String note = '',
    required String reason,
    required String recordedAt,
    RestaurantAccountProfile? profile,
    JournalPolicy? policy,
    SourceRecordOrder? sourceOrder,
  }) => EditOperatingExpenseCommand(
    operationId: operationId,
    accountLineage: _lineage,
    expectedFence: authorityFence,
    expenseId: expenseId,
    expectedActiveJournalId: expectedActiveJournalId,
    inverseJournalId: inverseJournalId,
    replacementJournalId: replacementJournalId,
    date: date,
    categoryId: categoryId,
    amount: amount,
    fundingSource: fundingSource,
    dailyAmount: dailyAmount,
    cashAmount: cashAmount,
    note: note,
    reason: reason,
    recordedAt: recordedAt,
    profile: profile ?? const RestaurantAccountProfile(),
    policy: policy,
    sourceOrder: sourceOrder,
  );

  DeleteOperatingExpenseCommand deleteExpenseIntent({
    required String operationId,
    required String expenseId,
    required String expectedActiveJournalId,
    required String inverseJournalId,
    required String reason,
    required String recordedAt,
    RestaurantAccountProfile? profile,
    JournalPolicy? policy,
  }) => DeleteOperatingExpenseCommand(
    operationId: operationId,
    accountLineage: _lineage,
    expectedFence: authorityFence,
    expenseId: expenseId,
    expectedActiveJournalId: expectedActiveJournalId,
    inverseJournalId: inverseJournalId,
    reason: reason,
    recordedAt: recordedAt,
    profile: profile ?? const RestaurantAccountProfile(),
    policy: policy,
  );

  DailyToCashboxTransferCommand transferIntent({
    required String operationId,
    required String transferId,
    required String journalId,
    required DateOnly date,
    required BigInt amount,
    required String recordedAt,
    JournalPolicy? policy,
  }) => DailyToCashboxTransferCommand(
    operationId: operationId,
    accountLineage: _lineage,
    expectedFence: authorityFence,
    transferId: transferId,
    journalId: journalId,
    date: date,
    amount: amount,
    recordedAt: recordedAt,
    policy: policy,
  );

  EditDailyTransferCommand editTransferIntent({
    required String operationId,
    required String transferId,
    required String expectedActiveJournalId,
    required String inverseJournalId,
    required String replacementJournalId,
    required BigInt newAmount,
    required String reason,
    required String recordedAt,
    JournalPolicy? policy,
    SourceRecordOrder? sourceOrder,
  }) => EditDailyTransferCommand(
    operationId: operationId,
    accountLineage: _lineage,
    expectedFence: authorityFence,
    transferId: transferId,
    expectedActiveJournalId: expectedActiveJournalId,
    inverseJournalId: inverseJournalId,
    replacementJournalId: replacementJournalId,
    newAmount: newAmount,
    reason: reason,
    recordedAt: recordedAt,
    policy: policy,
    sourceOrder: sourceOrder,
  );

  DeleteDailyTransferCommand deleteTransferIntent({
    required String operationId,
    required String transferId,
    required String expectedActiveJournalId,
    required String inverseJournalId,
    required String reason,
    required String recordedAt,
    JournalPolicy? policy,
  }) => DeleteDailyTransferCommand(
    operationId: operationId,
    accountLineage: _lineage,
    expectedFence: authorityFence,
    transferId: transferId,
    expectedActiveJournalId: expectedActiveJournalId,
    inverseJournalId: inverseJournalId,
    reason: reason,
    recordedAt: recordedAt,
    policy: policy,
  );

  /// Validated complete transaction history; a missing posting remains ineligible.
  PortableJournalEntry? activeExternalCashPosting(String id) =>
      RestaurantJournalExternalCashHistory.activePosting(
        _state,
        id,
        externalCashCommands.mapper,
      );

  ExternalCashCommand createExternalCashIntent({
    required String operationId,
    required String transactionId,
    required String journalId,
    required DateOnly date,
    required BigInt amount,
    required String type,
    String note = '',
    required String recordedAt,
  }) => ExternalCashCommand.create(
    operationId: operationId,
    accountLineage: _lineage,
    expectedFence: authorityFence,
    transactionId: transactionId,
    journalId: journalId,
    date: date,
    amount: amount,
    type: type,
    note: note,
    recordedAt: recordedAt,
    acceptedCounterAccountId: acceptedCounterAccountId,
    mapper: externalCashCommands.mapper,
  );
  ExternalCashCommand editExternalCashIntent({
    required String operationId,
    required String transactionId,
    required String journalId,
    required String inverseJournalId,
    required String expectedActiveJournalId,
    required Map<String, Object?> expectedSource,
    required String reason,
    required DateOnly date,
    required BigInt amount,
    required String type,
    String note = '',
    required String recordedAt,
    SourceRecordOrder? sourceOrder,
  }) => ExternalCashCommand.edit(
    operationId: operationId,
    accountLineage: _lineage,
    expectedFence: authorityFence,
    transactionId: transactionId,
    journalId: journalId,
    inverseJournalId: inverseJournalId,
    expectedActiveJournalId: expectedActiveJournalId,
    expectedSource: expectedSource,
    reason: reason,
    date: date,
    amount: amount,
    type: type,
    note: note,
    recordedAt: recordedAt,
    acceptedCounterAccountId: acceptedCounterAccountId,
    mapper: externalCashCommands.mapper,
    sourceOrder: sourceOrder,
  );
  ExternalCashCommand deleteExternalCashIntent({
    required String operationId,
    required String transactionId,
    required String inverseJournalId,
    required String expectedActiveJournalId,
    required Map<String, Object?> expectedSource,
    required String reason,
    required String recordedAt,
  }) => ExternalCashCommand.delete(
    operationId: operationId,
    accountLineage: _lineage,
    expectedFence: authorityFence,
    transactionId: transactionId,
    inverseJournalId: inverseJournalId,
    expectedActiveJournalId: expectedActiveJournalId,
    expectedSource: expectedSource,
    reason: reason,
    recordedAt: recordedAt,
    acceptedCounterAccountId: acceptedCounterAccountId,
    mapper: externalCashCommands.mapper,
  );
  Future<DurableCommandResult<ExternalCashOutcome>> submitExternalCash(
    ExternalCashCommand command,
  ) {
    if (!externalCashMappingAccepted ||
        command.acceptedCounterAccountId != acceptedCounterAccountId) {
      return Future.value(
        _commandFailure<ExternalCashOutcome>('unmapped_financial_gap'),
      );
    }
    return _submit<ExternalCashOutcome>(
      command: command,
      lineage: command.accountLineage,
      fence: command.expectedFence,
      execute: () => externalCashCommands.execute(command),
      onCommitted: (_) {},
      onReplayed: (_) {},
    );
  }

  RestoreDeletedSpendingCommand restoreDeletedIntent({
    required DeletedSpendingKind kind,
    required String operationId,
    required String recordId,
    required String deletedJournalId,
    required String deleteInverseJournalId,
    required String deleteOperationId,
    required String replacementJournalId,
    required Map<String, Object?> sourceSnapshot,
    required int position,
    required Iterable<String> expectedSiblingIds,
    required String reason,
    required String recordedAt,
  }) => RestoreDeletedSpendingCommand(
    kind: kind,
    operationId: operationId,
    accountLineage: _lineage,
    expectedFence: authorityFence,
    recordId: recordId,
    deletedJournalId: deletedJournalId,
    deleteInverseJournalId: deleteInverseJournalId,
    deleteOperationId: deleteOperationId,
    replacementJournalId: replacementJournalId,
    sourceSnapshot: sourceSnapshot,
    position: position,
    expectedSiblingIds: expectedSiblingIds,
    reason: reason,
    recordedAt: recordedAt,
    mapper: deletedRestorationCommands.mapper,
    acceptedCounterAccountId: acceptedCounterAccountId,
  );
  DurableProposalEvaluation<PortableJournalState, SpendingRestorationOutcome>
  previewDeletedRestoration(RestoreDeletedSpendingCommand command) =>
      deletedRestorationCommands.evaluate(command, _state);
  Future<DurableCommandResult<SpendingRestorationOutcome>>
  submitDeletedRestoration(RestoreDeletedSpendingCommand command) {
    if (command.kind == DeletedSpendingKind.externalCash &&
        (!externalCashMappingAccepted ||
            command.acceptedCounterAccountId != acceptedCounterAccountId)) {
      return Future.value(
        _commandFailure<SpendingRestorationOutcome>('unmapped_financial_gap'),
      );
    }
    return _submit<SpendingRestorationOutcome>(
      command: command,
      lineage: command.accountLineage,
      fence: command.expectedFence,
      execute: () => deletedRestorationCommands.execute(command),
      onCommitted: (_) {},
      onReplayed: (_) {},
    );
  }

  // --- Submissions ---

  Future<DurableCommandResult<RestaurantJournalSpendingOutcome>> submitExpense(
    CreateOperatingExpenseCommand command,
  ) => _submit<RestaurantJournalSpendingOutcome>(
    command: command,
    lineage: command.accountLineage,
    fence: command.expectedFence,
    execute: () => spendingCommands.execute(command),
    onCommitted: (outcome) {
      _lastSpendingOutcome = outcome;
      _selectedExpenseId = outcome.expenseId ?? command.expenseId;
    },
    onReplayed: (outcome) {
      _lastSpendingOutcome = outcome;
      _selectedExpenseId = outcome?.expenseId ?? command.expenseId;
    },
  );

  Future<DurableCommandResult<RestaurantJournalExpenseCorrectionOutcome>>
  submitExpenseCorrection(OperatingExpenseCorrectionCommand command) =>
      _submit<RestaurantJournalExpenseCorrectionOutcome>(
        command: command,
        lineage: command.accountLineage,
        fence: command.expectedFence,
        execute: () => expenseCorrectionCommands.execute(command),
        onCommitted: (outcome) {
          _lastExpenseCorrectionOutcome = outcome;
          _selectedExpenseId = outcome.expenseId;
        },
        onReplayed: (outcome) {
          _lastExpenseCorrectionOutcome = outcome;
          _selectedExpenseId = outcome?.expenseId ?? command.expenseId;
        },
      );

  Future<DurableCommandResult<RestaurantJournalTransferOutcome>> submitTransfer(
    DailyToCashboxTransferCommand command,
  ) => _submit<RestaurantJournalTransferOutcome>(
    command: command,
    lineage: command.accountLineage,
    fence: command.expectedFence,
    execute: () => transferCommands.execute(command),
    onCommitted: (outcome) {
      _lastTransferOutcome = outcome;
      _selectedTransferId = outcome.transferId;
    },
    onReplayed: (outcome) {
      _lastTransferOutcome = outcome;
      _selectedTransferId = outcome?.transferId ?? command.transferId;
    },
  );

  Future<DurableCommandResult<RestaurantJournalTransferCorrectionOutcome>>
  submitTransferCorrection(Object command) =>
      _submit<RestaurantJournalTransferCorrectionOutcome>(
        command: command,
        lineage: switch (command) {
          EditDailyTransferCommand(:final accountLineage) => accountLineage,
          DeleteDailyTransferCommand(:final accountLineage) => accountLineage,
          _ => throw ArgumentError('Unsupported transfer correction command.'),
        },
        fence: switch (command) {
          EditDailyTransferCommand(:final expectedFence) => expectedFence,
          DeleteDailyTransferCommand(:final expectedFence) => expectedFence,
          _ => throw ArgumentError('Unsupported transfer correction command.'),
        },
        execute: () => switch (command) {
          EditDailyTransferCommand() => transferCorrectionCommands.executeEdit(
            command,
          ),
          DeleteDailyTransferCommand() =>
            transferCorrectionCommands.executeDelete(command),
          _ => throw ArgumentError('Unsupported transfer correction command.'),
        },
        onCommitted: (outcome) {
          _lastTransferCorrectionOutcome = outcome;
          _selectedTransferId = outcome.transferId;
        },
        onReplayed: (outcome) {
          _lastTransferCorrectionOutcome = outcome;
          _selectedTransferId = outcome?.transferId;
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
    if (pending is RestoreDeletedSpendingCommand) {
      return submitDeletedRestoration(pending);
    }
    if (pending is ExternalCashCommand) return submitExternalCash(pending);
    if (pending is CreateOperatingExpenseCommand) return submitExpense(pending);
    if (pending is OperatingExpenseCorrectionCommand) {
      return submitExpenseCorrection(pending);
    }
    if (pending is DailyToCashboxTransferCommand) {
      return submitTransfer(pending);
    }
    if (pending is EditDailyTransferCommand ||
        pending is DeleteDailyTransferCommand) {
      return submitTransferCorrection(pending);
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
      CapabilityFailure(code, 'The spending snapshot was not accepted.');
  DurableCommandFailure<T> _commandFailure<T>(String code) =>
      DurableCommandFailure<T>(
        code: code,
        message: 'Spending action not confirmed.',
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
