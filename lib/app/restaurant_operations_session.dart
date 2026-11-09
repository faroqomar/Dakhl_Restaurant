import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';

import '../accounting/daily_cash_controller.dart';
import '../accounting/day_date_correction_controller.dart';
import '../accounting/daily_register_snapshot_controller.dart';
import '../accounting/restaurant_journal_sale_commands.dart';
import '../accounting/spending_operations_view_model.dart';
import '../accounts/accounts_repository.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_metadata_repository_bridge.dart';
import '../reports/reports_view_model.dart';
import '../parties/parties_operations_view_model.dart';
import '../parties/additional_debt_controller.dart';
import '../parties/supplier_opening_controller.dart';
import '../parties/purchase_operations_controller.dart';
import '../sales/sales_workflow_session.dart';
import '../sales/ticket_workspace.dart';
import '../settings/portable_settings_controller.dart';

/// Caller-initialized portable-account composition. Borrows one store without
/// creating/migrating an account, choosing openings or activating normal runtime.
/// Disposal releases listeners/controllers; the caller still owns the store.
final class RestaurantOperationsSession extends ChangeNotifier {
  RestaurantOperationsSession._(
    this.store,
    this._fresh, [
    this._externalWriteBlocked,
  ]);
  final LocalDocumentWorkspaceStore store;
  final bool Function()? _externalWriteBlocked;
  late final SalesWorkflowSession sales;
  late final PortableSettingsController settings;
  late final ReportsViewModel reports;
  late final SpendingOperationsViewModel spending;
  late final DailyCashController dailyCash;
  late final DailyRegisterSnapshotController dailyRegister;
  late final DayDateCorrectionController dayDates;
  late final AdditionalDebtController additionalDebts;
  late final SupplierOpeningController supplierOpenings;
  late final PartiesOperationsViewModel parties;
  late final PurchaseOperationsController purchases;
  late final PortableMetadataRepositoryBridge metadataBridge;
  late final AccountsRepository metadataRepository;
  TicketDraft _fresh;
  bool _disposed = false, _synchronizing = false, _actionBusy = false;
  int _notificationDepth = 0;
  String? _syncError;
  Future<CapabilityResult<void>>? _syncFuture;
  bool get busy =>
      _synchronizing ||
      _actionBusy ||
      sales.busy ||
      settings.busy ||
      spending.busy ||
      parties.busy ||
      metadataBridge.busy ||
      dailyRegister.busy ||
      dayDates.busy ||
      additionalDebts.busy ||
      supplierOpenings.busy;
  String? get synchronizationError => _syncError;
  DocumentSnapshot get snapshot => sales.operations.snapshot;

  static Future<CapabilityResult<RestaurantOperationsSession>> open({
    required LocalDocumentWorkspaceStore store,
    required DocumentSnapshot snapshot,
    required int Function(String, String) compareText,
    required TicketDraft fresh,
    PortableJournalCodec codec = const PortableJournalCodec(),
    bool Function()? isWriteBlocked,
    String? acceptedCashCounterAccountId,
    String? acceptedDebtCounterAccountId,
    String? acceptedOpeningEquityAccountId,
  }) async {
    final result = RestaurantOperationsSession._(store, fresh, isWriteBlocked);
    PortableSettingsController? editor;
    SalesWorkflowSession? workflow;
    SpendingOperationsViewModel? expenses;
    PartiesOperationsViewModel? suppliers;
    PortableMetadataRepositoryBridge? metadata;
    AccountsRepository? metadataRepo;
    DailyRegisterSnapshotController? register;
    DayDateCorrectionController? dates;
    AdditionalDebtController? debts;
    SupplierOpeningController? openings;
    bool metadataPending() =>
        (metadata != null && (metadata.busy || metadata.needsReadback)) ||
        (metadataRepo != null &&
            (metadataRepo.hasUnknownWrite ||
                metadataRepo.hasUnknownWorkspaceWrite));
    bool registerPending() =>
        register != null && (register.busy || register.needsReadback);
    bool datesPending() => dates != null && (dates.busy || dates.needsReadback);
    bool debtsPending() => debts != null && (debts.busy || debts.needsReadback);
    bool openingsPending() =>
        openings != null && (openings.busy || openings.needsReadback);
    try {
      final opened = await SalesWorkflowSession.open(
        commands: RestaurantJournalSaleCommandCoordinator(
          store: store,
          codec: codec,
        ),
        snapshot: snapshot,
        initial: fresh,
        compareText: compareText,
        isWriteBlocked: () =>
            (isWriteBlocked != null && isWriteBlocked()) ||
            openingsPending() ||
            (editor != null && (editor.busy || editor.needsReadback)) ||
            (expenses != null && (expenses.busy || expenses.needsReadback)) ||
            (suppliers != null &&
                (suppliers.busy || suppliers.needsReadback)) ||
            metadataPending() ||
            registerPending() ||
            datesPending() ||
            debtsPending(),
      );
      if (opened is! CapabilitySuccess<SalesWorkflowSession>) {
        return _failure(_code(opened));
      }
      workflow = opened.value;
      result.sales = workflow;
      editor = PortableSettingsController(
        store: store,
        snapshot: workflow.operations.snapshot,
        codec: codec,
        isWriteBlocked: () =>
            (isWriteBlocked != null && isWriteBlocked()) ||
            openingsPending() ||
            workflow!.busy ||
            workflow.checkoutPending ||
            workflow.operations.needsReadback ||
            workflow.draftNeedsReadback ||
            (expenses != null && (expenses.busy || expenses.needsReadback)) ||
            (suppliers != null &&
                (suppliers.busy || suppliers.needsReadback)) ||
            metadataPending() ||
            registerPending() ||
            datesPending() ||
            debtsPending(),
      );
      result.settings = editor;
      expenses = SpendingOperationsViewModel(
        acceptedCounterAccountId: acceptedCashCounterAccountId,
        store: store,
        codec: codec,
        snapshot: workflow.operations.snapshot,
        isWriteBlocked: () =>
            (isWriteBlocked != null && isWriteBlocked()) ||
            openingsPending() ||
            workflow!.busy ||
            workflow.checkoutPending ||
            workflow.operations.needsReadback ||
            workflow.draftNeedsReadback ||
            editor!.busy ||
            editor.needsReadback ||
            (suppliers != null &&
                (suppliers.busy || suppliers.needsReadback)) ||
            metadataPending() ||
            registerPending() ||
            datesPending() ||
            debtsPending(),
      );
      result.spending = expenses;
      suppliers = PartiesOperationsViewModel(
        store: store,
        codec: codec,
        snapshot: workflow.operations.snapshot,
        compareText: compareText,
        isWriteBlocked: () =>
            (isWriteBlocked != null && isWriteBlocked()) ||
            openingsPending() ||
            workflow!.busy ||
            workflow.checkoutPending ||
            workflow.operations.needsReadback ||
            workflow.draftNeedsReadback ||
            editor!.busy ||
            editor.needsReadback ||
            expenses!.busy ||
            expenses.needsReadback ||
            metadataPending() ||
            registerPending() ||
            datesPending() ||
            debtsPending(),
      );
      result.parties = suppliers;
      result.dailyCash = DailyCashController(
        spending: expenses,
        initialDate: fresh.date,
      );
      result.purchases = PurchaseOperationsController(parties: suppliers);
      metadata = PortableMetadataRepositoryBridge(
        inner: store,
        snapshot: workflow.operations.snapshot,
        codec: codec,
        isWriteBlocked: () =>
            (isWriteBlocked != null && isWriteBlocked()) ||
            openingsPending() ||
            workflow!.busy ||
            workflow.checkoutPending ||
            workflow.operations.needsReadback ||
            workflow.draftNeedsReadback ||
            editor!.busy ||
            editor.needsReadback ||
            expenses!.busy ||
            expenses.needsReadback ||
            suppliers!.busy ||
            suppliers.needsReadback ||
            registerPending() ||
            datesPending() ||
            debtsPending(),
      );
      metadataRepo = AccountsRepository(store: metadata);
      final metadataOpened = await metadataRepo.open();
      if (metadataOpened is! CapabilitySuccess) {
        result.dailyCash.dispose();
        result.purchases.dispose();
        metadata.dispose();
        editor.dispose();
        expenses.dispose();
        suppliers.dispose();
        workflow.dispose();
        return _failure(_code(metadataOpened));
      }
      result.metadataBridge = metadata;
      result.metadataRepository = metadataRepo;
      register = DailyRegisterSnapshotController(
        store: store,
        snapshot: workflow.operations.snapshot,
        codec: codec,
        isWriteBlocked: () =>
            (isWriteBlocked != null && isWriteBlocked()) ||
            openingsPending() ||
            workflow!.busy ||
            workflow.checkoutPending ||
            workflow.operations.needsReadback ||
            workflow.draftNeedsReadback ||
            editor!.busy ||
            editor.needsReadback ||
            expenses!.busy ||
            expenses.needsReadback ||
            suppliers!.busy ||
            suppliers.needsReadback ||
            metadataPending() ||
            datesPending() ||
            debtsPending(),
      );
      result.dailyRegister = register;
      dates = DayDateCorrectionController(
        acceptedCounterAccountId: acceptedCashCounterAccountId,
        store: store,
        snapshot: workflow.operations.snapshot,
        isWriteBlocked: () =>
            (isWriteBlocked != null && isWriteBlocked()) ||
            openingsPending() ||
            workflow!.busy ||
            workflow.checkoutPending ||
            workflow.operations.needsReadback ||
            workflow.draftNeedsReadback ||
            editor!.busy ||
            editor.needsReadback ||
            expenses!.busy ||
            expenses.needsReadback ||
            suppliers!.busy ||
            suppliers.needsReadback ||
            metadataPending() ||
            registerPending() ||
            debtsPending(),
      );
      result.dayDates = dates;
      debts = AdditionalDebtController(
        store: store,
        snapshot: workflow.operations.snapshot,
        acceptedCounterAccountId: acceptedDebtCounterAccountId,
        isWriteBlocked: () =>
            (isWriteBlocked != null && isWriteBlocked()) ||
            openingsPending() ||
            workflow!.busy ||
            workflow.checkoutPending ||
            workflow.operations.needsReadback ||
            workflow.draftNeedsReadback ||
            editor!.busy ||
            editor.needsReadback ||
            expenses!.busy ||
            expenses.needsReadback ||
            suppliers!.busy ||
            suppliers.needsReadback ||
            metadataPending() ||
            registerPending() ||
            datesPending(),
      );
      result.additionalDebts = debts;
      openings = SupplierOpeningController(
        store: store,
        snapshot: workflow.operations.snapshot,
        acceptedOpeningEquityAccountId: acceptedOpeningEquityAccountId,
        isWriteBlocked: () =>
            (isWriteBlocked != null && isWriteBlocked()) ||
            workflow!.busy ||
            workflow.checkoutPending ||
            workflow.operations.needsReadback ||
            workflow.draftNeedsReadback ||
            editor!.busy ||
            editor.needsReadback ||
            expenses!.busy ||
            expenses.needsReadback ||
            suppliers!.busy ||
            suppliers.needsReadback ||
            metadataPending() ||
            registerPending() ||
            datesPending() ||
            debtsPending(),
      );
      result.supplierOpenings = openings;

      // Reports use the portable operations projection exclusively. This
      // borrowed repository is never opened or used for schema11 account writes.
      result.reports = ReportsViewModel(
        AccountsRepository(store: store),
        compareText: compareText,
        readAccount: () => result.sales.operations.account,
        updates: result.sales.operations,
      );
      result.sales.addListener(result._changed);
      result.settings.addListener(result._changed);
      result.spending.addListener(result._changed);
      result.parties.addListener(result._changed);
      result.metadataBridge.addListener(result._changed);
      result.dailyRegister.addListener(result._changed);
      result.dayDates.addListener(result._changed);
      result.additionalDebts.addListener(result._changed);
      result.supplierOpenings.addListener(result._changed);
      return CapabilitySuccess(result);
    } on Object {
      openings?.dispose();
      debts?.dispose();
      dates?.dispose();
      register?.dispose();
      editor?.dispose();
      expenses?.dispose();
      suppliers?.dispose();
      metadata?.dispose();
      workflow?.dispose();
      return _failure('operations_session_unavailable');
    }
  }

  static String _code<T>(CapabilityResult<T> value) => switch (value) {
    CapabilityFailure<T>(:final code) => code,
    CapabilityCancelled<T>() => 'cancelled',
    _ => 'unavailable',
  };
  static CapabilityFailure<T> _failure<T>(String code) => CapabilityFailure(
    code,
    'The operation readers need explicit synchronization.',
  );
  bool _same(DocumentSnapshot a, DocumentSnapshot b) =>
      a.fence == b.fence &&
      a.revision == b.revision &&
      a.payload == b.payload &&
      a.writeToken == b.writeToken;

  /// Refreshes only readers. Dirty settings retain their captured revision and
  /// input: a later save must fail stale until an explicit discard/reload.
  /// This performs no automatic retry of any uncertain financial command.
  Future<CapabilityResult<void>> synchronize({TicketDraft? fresh}) {
    final pending = _syncFuture;
    if (pending != null) return pending;
    return _syncFuture = _synchronize(fresh: fresh).whenComplete(() {
      _syncFuture = null;
    });
  }

  Future<CapabilityResult<void>> _synchronize({TicketDraft? fresh}) async {
    if (_disposed) return _failure('disposed');
    if (_synchronizing ||
        sales.busy ||
        settings.busy ||
        spending.busy ||
        parties.busy ||
        metadataBridge.busy ||
        dailyRegister.busy ||
        dayDates.busy ||
        additionalDebts.busy ||
        supplierOpenings.busy) {
      return _failure('busy');
    }
    if (sales.checkoutPending ||
        sales.operations.needsReadback ||
        sales.draftNeedsReadback ||
        settings.needsReadback ||
        spending.needsReadback ||
        parties.needsReadback ||
        metadataBridge.needsReadback ||
        metadataRepository.hasUnknownWrite ||
        metadataRepository.hasUnknownWorkspaceWrite ||
        dailyRegister.needsReadback ||
        dayDates.needsReadback ||
        additionalDebts.needsReadback ||
        supplierOpenings.needsReadback) {
      return _failure('commit_unknown');
    }
    if (fresh != null) _fresh = fresh;
    final snapshots = [
      sales.operations.snapshot,
      settings.snapshot,
      spending.snapshot,
      parties.snapshot,
      metadataBridge.snapshot,
      dailyRegister.snapshot,
      dayDates.snapshot,
      additionalDebts.snapshot,
      supplierOpenings.snapshot,
    ];
    final latest = snapshots.reduce((a, b) => a.revision >= b.revision ? a : b);
    if (snapshots.every((s) => _same(s, latest)) &&
        metadataRepository.snapshot?.revision == latest.revision) {
      _syncError = null;
      return const CapabilitySuccess(null);
    }
    if (snapshots.any(
      (s) =>
          s.fence != latest.fence ||
          (s.revision == latest.revision && !_same(s, latest)),
    )) {
      _syncError = 'snapshot_disagreement';
      _notify();
      return _failure(_syncError!);
    }
    _synchronizing = true;
    _notify();
    try {
      if (!_same(sales.operations.snapshot, latest)) {
        final refreshed = await sales.refreshAccount(fresh: _fresh);
        if (refreshed is! CapabilitySuccess<void>) {
          _syncError = _code(refreshed);
          return refreshed;
        }
      }
      if (_disposed) return _failure('disposed');
      final current = sales.operations.snapshot;
      for (final accepted in [
        spending.acceptSnapshot(current),
        parties.acceptSnapshot(current),
        dailyRegister.acceptSnapshot(current),
        dayDates.acceptSnapshot(current),
        additionalDebts.acceptSnapshot(current),
        supplierOpenings.acceptSnapshot(current),
      ]) {
        if (accepted is! CapabilitySuccess<void>) {
          _syncError = _code(accepted);
          return accepted;
        }
      }
      if (!_same(settings.snapshot, current) && !settings.isDirty) {
        final refreshed = await settings.load();
        if (refreshed is! CapabilitySuccess<void>) {
          _syncError = _code(refreshed);
          return refreshed;
        }
        if (!_same(settings.snapshot, current)) {
          _syncError = 'reader_refresh_required';
          return _failure(_syncError!);
        }
      }
      if (!_same(metadataBridge.snapshot, current) ||
          metadataRepository.snapshot?.revision != current.revision) {
        final refreshed = await metadataRepository.open();
        if (refreshed is! CapabilitySuccess) {
          _syncError = _code(refreshed);
          return _failure(_syncError!);
        }
        if (!_same(metadataBridge.snapshot, current)) {
          _syncError = 'reader_refresh_required';
          return _failure(_syncError!);
        }
      }
      _syncError = null;
      return const CapabilitySuccess(null);
    } on Object {
      _syncError = 'reader_refresh_failed';
      return _failure(_syncError!);
    } finally {
      _synchronizing = false;
      _notify();
    }
  }

  Future<CapabilityResult<void>> saveSettings({TicketDraft? fresh}) async {
    if (_externalWriteBlocked != null && _externalWriteBlocked()) {
      return _failure<void>('busy');
    }
    return _settingsAction(settings.save, fresh: fresh);
  }

  Future<CapabilityResult<void>> reconcileSettings({TicketDraft? fresh}) =>
      _settingsAction(settings.reconcile, fresh: fresh);
  Future<CapabilityResult<void>> reloadSettings({
    bool discardChanges = false,
    TicketDraft? fresh,
  }) => _settingsAction(
    () => settings.load(discardChanges: discardChanges),
    fresh: fresh,
  );
  Future<CapabilityResult<void>> _settingsAction(
    Future<CapabilityResult<void>> Function() action, {
    TicketDraft? fresh,
  }) async {
    if (_disposed) return _failure('disposed');
    if (busy) return _failure('busy');
    _actionBusy = true;
    _notify();
    try {
      final result = await action();
      if (result is! CapabilitySuccess<void>) return result;
      // A metadata commit already succeeded. A refresh failure is exposed
      // separately so callers never resubmit the saved metadata as a new write.
      await synchronize(fresh: fresh);
      return result;
    } finally {
      _actionBusy = false;
      _notify();
    }
  }

  Future<CapabilityResult<void>> reconcileMetadata() async {
    if (_disposed) return _failure('disposed');
    if (busy) return _failure('busy');
    _actionBusy = true;
    _notify();
    try {
      final result = await metadataRepository.reconcile();
      if (result is! CapabilitySuccess) return _failure(_code(result));
      return await synchronize();
    } finally {
      _actionBusy = false;
      _notify();
    }
  }

  void _changed() {
    if (_disposed) return;
    _notify();
    if (!_disposed &&
        !_actionBusy &&
        !_synchronizing &&
        !sales.busy &&
        !settings.busy &&
        !spending.busy &&
        !parties.busy &&
        !metadataBridge.busy &&
        !dailyRegister.busy &&
        !dayDates.busy &&
        !additionalDebts.busy &&
        !supplierOpenings.busy) {
      unawaited(synchronize());
    }
  }

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
    sales.removeListener(_changed);
    settings.removeListener(_changed);
    spending.removeListener(_changed);
    parties.removeListener(_changed);
    metadataBridge.removeListener(_changed);
    dailyRegister.removeListener(_changed);
    dayDates.removeListener(_changed);
    additionalDebts.removeListener(_changed);
    supplierOpenings.removeListener(_changed);
    dailyCash.dispose();
    purchases.dispose();
    reports.dispose();
    settings.dispose();
    sales.dispose();
    spending.dispose();
    parties.dispose();
    metadataBridge.dispose();
    dailyRegister.dispose();
    dayDates.dispose();
    additionalDebts.dispose();
    supplierOpenings.dispose();
    if (_notificationDepth == 0) super.dispose();
  }
}
