import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounting/restaurant_journal_sale_commands.dart';
import '../accounts/account_document.dart';
import '../accounts/portable_journal_state.dart';
import '../reports/sales_report.dart';
import 'return_proposal.dart';
import 'ticket_workspace.dart';

/// Nonvisual sales workflow bound to an explicitly initialized complete-state
/// account. Construction does not enroll an account, establish cutover, or
/// change the schema-11 runtime repository. The composition owner supplies its
/// acknowledged snapshot and publishes successful snapshots to other readers.
final class SalesOperationsViewModel extends ChangeNotifier {
  SalesOperationsViewModel({
    required this.commands,
    required DocumentSnapshot snapshot,
    this.isWriteBlocked,
    this.compareText,
  }) : authorityFence = snapshot.fence,
       _snapshot = snapshot,
       _state = commands.codec.decodeState(snapshot.payload) {
    _lineage = _state.accountLineage;
  }

  final RestaurantJournalSaleCommandCoordinator commands;
  final bool Function()? isWriteBlocked;
  final int Function(String, String)? compareText;
  final StorageFence authorityFence;
  late final String _lineage;
  DocumentSnapshot _snapshot;
  PortableJournalState _state;
  bool _busy = false, _disposed = false;
  int _notificationDepth = 0;
  String? _errorCode, _selectedSaleId;
  SalesHistoryFilter _filter = const SalesHistoryFilter();
  RestaurantJournalSaleCommand? _pending;
  RestaurantJournalSaleOutcome? _lastOutcome;

  bool get busy => _busy;
  bool get needsReadback => _pending != null;
  bool get postingEnabled =>
      !_disposed &&
      !_busy &&
      !(isWriteBlocked?.call() ?? false) &&
      !needsReadback &&
      !_state.cutoverState.isGated &&
      _state.cutoverState.hasActivePosting;
  String? get errorCode => _errorCode;
  DocumentSnapshot get snapshot => _snapshot;
  AccountDocument get account => _state.account;
  String get accountLineage => _lineage;
  SalesHistoryFilter get filter => _filter;
  RestaurantJournalSaleOutcome? get lastOutcome => _lastOutcome;
  SalesReport get history =>
      SalesReport.build(account, filter: _filter, compareText: compareText);

  /// The saved receipt keeps captured product names/prices and original paid
  /// values; changing the catalog never rewrites this snapshot.
  Map<String, Object?>? get selectedSale {
    for (final sale
        in (account.toJson()['sales']! as List).cast<Map<String, Object?>>()) {
      if (sale['id'] == _selectedSaleId) return sale;
    }
    return null;
  }

  List<Map<String, Object?>> get selectedReturns => List.unmodifiable(
    (account.toJson()['saleReturns']! as List)
        .cast<Map<String, Object?>>()
        .where((record) => record['saleId'] == _selectedSaleId),
  );

  void selectSale(String? id) {
    if (_disposed || _busy) return;
    if (id != null &&
        !(account.toJson()['sales']! as List).cast<Map<String, Object?>>().any(
          (sale) => sale['id'] == id,
        )) {
      _errorCode = 'sale_not_found';
    } else {
      _selectedSaleId = id;
      _errorCode = null;
    }
    _notify();
  }

  void setFilter(SalesHistoryFilter filter) {
    if (_disposed) return;
    // Validate first so a rejected filter cannot replace the visible history.
    SalesReport.validateFilter(filter);
    _filter = filter;
    _notify();
  }

  /// Refresh from the same complete-state owner after other workflows commit.
  /// An uncertain command must first retry its exact captured intent; replacing
  /// the visible snapshot does not establish whether that command committed.
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
    final state = commands.codec.decodeState(next.payload);
    if (state.accountLineage != _lineage) {
      throw const FormatException('account_lineage_mismatch');
    }
    _snapshot = next;
    _state = state;
  }

  /// Pure preview uses the same restaurant proposal/mapping as persistence.
  /// A preview never acknowledges customer cash or changes the store.
  DurableProposalEvaluation<PortableJournalState, RestaurantJournalSaleOutcome>
  preview(RestaurantJournalSaleCommand command) {
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
    return RestaurantJournalSaleCommandCoordinator.evaluateCommand(
      command: command,
      state: _state,
      cutoverDate: cutover.cutoverDate!,
      mapper: commands.mapper,
    );
  }

  /// Captures exact prices and quantities from the persisted ticket draft.
  /// Completion acknowledges the net amount without a received-cash field.
  CompleteSaleCommand checkoutIntent({
    required TicketDraft ticket,
    required String operationId,
    required String journalId,
    required String recordedAt,
    JournalPolicy? policy,
  }) {
    final text = LegacyText.trimJavaScript(ticket.discount);
    final discount = text.isEmpty
        ? BigInt.zero
        : ExactIntegerPolicy(
            maxAbs: BigInt.from(1000000000000),
            signed: false,
            positive: false,
            maxSafeInteger: BigInt.parse('9007199254740991'),
          ).parse(text, normalizeDigits: true, allowGrouping: true);
    return CompleteSaleCommand(
      operationId: operationId,
      accountLineage: _lineage,
      expectedFence: authorityFence,
      saleId: ticket.id,
      journalId: journalId,
      recordedAt: recordedAt,
      policy: policy,
      draft: {
        'date': ticket.date,
        'orderType': ticket.orderType,
        'discount': discount.toInt(),
        'note': ticket.note,
        'lines': [
          for (final line in ticket.lines)
            {
              'productId': line.productId,
              'quantity': num.parse(
                ExactDecimal.fromUnits(line.quantityUnits, 3).toString(),
              ),
              'price': line.price,
            },
        ],
      },
    );
  }

  SaleReturnCommand returnIntent({
    required String operationId,
    required String saleId,
    required String returnId,
    required String journalId,
    required DateOnly date,
    required DateOnly today,
    required String reason,
    required String recordedAt,
    required Iterable<ReturnLineRequest> lines,
    JournalPolicy? policy,
  }) => SaleReturnCommand(
    operationId: operationId,
    accountLineage: _lineage,
    expectedFence: authorityFence,
    saleId: saleId,
    returnId: returnId,
    journalId: journalId,
    returnDate: date,
    today: today,
    reason: reason,
    recordedAt: recordedAt,
    lines: lines,
    policy: policy,
  );

  SaleVoidCommand voidIntent({
    required String operationId,
    required String saleId,
    required String reversalJournalId,
    required String reason,
    required String voidedAt,
    JournalPolicy? policy,
  }) => SaleVoidCommand(
    operationId: operationId,
    accountLineage: _lineage,
    expectedFence: authorityFence,
    saleId: saleId,
    reversalJournalId: reversalJournalId,
    reason: reason,
    voidedAt: voidedAt,
    policy: policy,
  );

  Future<DurableCommandResult<RestaurantJournalSaleOutcome>> submit(
    RestaurantJournalSaleCommand command,
  ) async {
    if (_disposed) return _commandFailure('disposed');
    if (_busy || (isWriteBlocked?.call() ?? false)) {
      return _commandFailure('busy');
    }
    if (_pending != null && !identical(_pending, command)) {
      return _commandFailure('commit_unknown');
    }
    if (command.accountLineage != _lineage ||
        command.expectedFence != authorityFence) {
      return _commandFailure('stale_authority_fence');
    }
    _busy = true;
    _errorCode = null;
    try {
      _notify();
      if (_disposed) return _commandFailure('disposed');
      // Preserve the exact immutable command before crossing the async boundary.
      _pending = command;
      final result = await commands.execute(command);
      if (_disposed) return result;
      switch (result) {
        case DurableCommandSuccess(:final outcome, :final snapshot):
          _accept(snapshot);
          _lastOutcome = outcome;
          _selectedSaleId = outcome.saleId;
          _pending = null;
        case DurableCommandReplayed(:final outcome, :final snapshot):
          _accept(snapshot);
          _lastOutcome = outcome;
          _selectedSaleId = outcome?.saleId ?? command.saleId;
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
      // A wrapper failure after dispatch cannot prove that storage was unchanged.
      _errorCode = 'commit_unknown';
      return _commandFailure('commit_unknown');
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Reuses the original identity and payload. The shared coordinator resolves
  /// uncertainty and reconciles receipt/source/journal state before replay.
  Future<DurableCommandResult<RestaurantJournalSaleOutcome>> retry() {
    final command = _pending;
    if (command == null) {
      return Future.value(_commandFailure('nothing_to_retry'));
    }
    return submit(command);
  }

  CapabilityFailure<void> _failure(String code) =>
      CapabilityFailure(code, 'The sales snapshot was not accepted.');
  DurableCommandFailure<RestaurantJournalSaleOutcome> _commandFailure(
    String code,
  ) =>
      DurableCommandFailure(code: code, message: 'Sales action not confirmed.');

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
