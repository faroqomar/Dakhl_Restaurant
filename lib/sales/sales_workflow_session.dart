import 'dart:math';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';

import '../accounting/restaurant_journal_sale_commands.dart';
import '../accounts/accounts_repository.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounts/workspace_document.dart';
import '../catalog/catalog_read_model.dart';
import 'sales_operations_view_model.dart';
import 'sales_view_model.dart';
import 'ticket_workspace.dart';

/// Isolated composition over one borrowed Madar store. The caller initializes
/// the portable account and retains ownership of the store's lifecycle.
///
/// Account posting and workspace cleanup are separate fenced commits. A saved
/// sale always remains authoritative if cleanup fails; retry only reconciles
/// the captured command/cleanup and never generates a new receipt identity.
final class SalesWorkflowSession extends ChangeNotifier {
  SalesWorkflowSession._(
    this.operations,
    this._projection,
    this._repository,
    this.isWriteBlocked,
  ) : _drafts = SalesViewModel(_repository) {
    _drafts.addListener(_changed);
    operations.addListener(_changed);
  }

  final SalesOperationsViewModel operations;
  final bool Function()? isWriteBlocked;
  final SalesViewModel _drafts;
  int _notificationDepth = 0;
  final _PortableDraftStore _projection;
  final AccountsRepository _repository;
  _Checkout? _checkout;
  bool _busy = false, _disposed = false;
  String? _errorCode;

  bool get busy => _busy || _drafts.busy || operations.busy;
  bool get externallyBlocked => isWriteBlocked?.call() ?? false;
  bool get checkoutPending => _checkout != null;
  String? get errorCode =>
      _errorCode ?? operations.errorCode ?? _drafts.errorCode;

  TicketDraft? get active => _drafts.active;
  List<HeldTicket> get held => _drafts.held;
  SalesTicketQuote get quote => _drafts.quote;
  CatalogPage? get catalog => _drafts.catalog;
  List<String> get groups => _drafts.groups;
  Map<String, int> get groupCounts => _drafts.groupCounts;
  List<String> get orderTypes => _drafts.orderTypes;
  int get page => _drafts.page;
  String get query => _drafts.query;
  String get group => _drafts.group;
  bool get draftNeedsReadback => _drafts.needsReadback;
  Future<CapabilityResult<void>> saveFormDraft(Map<String, String> form) {
    final submitted = Map<String, String>.unmodifiable(form);
    return _edit(() => _drafts.saveFormDraft(submitted));
  }

  Future<CapabilityResult<void>> _edit(
    Future<CapabilityResult<void>> Function() action,
  ) {
    if (_disposed) return Future.value(_failure('disposed'));
    if (busy || externallyBlocked) return Future.value(_failure('busy'));
    if (checkoutPending) return Future.value(_failure('checkout_pending'));
    return action();
  }

  Future<CapabilityResult<void>> addProduct(
    String id, {
    BigInt? quantityUnits,
  }) => _edit(() => _drafts.addProduct(id, quantityUnits: quantityUnits));
  Future<CapabilityResult<void>> setQuantity(String id, String quantity) =>
      _edit(() => _drafts.setQuantity(id, quantity));
  Future<CapabilityResult<void>> removeProduct(String id) =>
      _edit(() => _drafts.removeProduct(id));
  Future<CapabilityResult<void>> updateDetails({
    String? date,
    String? orderType,
    String? discount,
    String? note,
  }) => _edit(
    () => _drafts.updateDetails(
      date: date,
      orderType: orderType,
      discount: discount,
      note: note,
    ),
  );
  Future<CapabilityResult<void>> clear(TicketDraft fresh) =>
      _edit(() => _drafts.clear(fresh));

  Future<CapabilityResult<void>> hold({
    required String label,
    required String heldId,
    required TicketDraft fresh,
    required String savedAt,
  }) => _edit(
    () => _drafts.hold(
      label: label,
      heldId: heldId,
      fresh: fresh,
      savedAt: savedAt,
    ),
  );
  Future<CapabilityResult<void>> resume(
    String id, {
    required String swapId,
    required String swapLabel,
    required String savedAt,
  }) => _edit(
    () => _drafts.resume(
      id,
      swapId: swapId,
      swapLabel: swapLabel,
      savedAt: savedAt,
    ),
  );
  Future<CapabilityResult<void>> deleteHeld(String id) =>
      _edit(() => _drafts.deleteHeld(id));
  Future<CapabilityResult<void>> reconcileDraft() => _edit(_drafts.reconcile);
  void filter({String? query, String? group}) {
    if (!_disposed && !busy && !checkoutPending) {
      _drafts.filter(query: query, group: group);
    }
  }

  void selectPage(int value) {
    if (!_disposed && !busy) _drafts.selectPage(value);
  }

  static Future<CapabilityResult<SalesWorkflowSession>> open({
    required RestaurantJournalSaleCommandCoordinator commands,
    required DocumentSnapshot snapshot,
    required TicketDraft initial,
    bool Function()? isWriteBlocked,
    int Function(String, String)? compareText,
  }) async {
    SalesWorkflowSession? session;
    try {
      final operations = SalesOperationsViewModel(
        commands: commands,
        snapshot: snapshot,
        compareText: compareText,
        isWriteBlocked: () =>
            (isWriteBlocked?.call() ?? false) ||
            (session?.draftNeedsReadback ?? false),
      );
      final projection = _PortableDraftStore(
        commands.store,
        commands.codec,
        snapshot.fence,
        operations.accountLineage,
      );
      final repository = AccountsRepository(store: projection);
      final opened = await repository.open();
      if (opened is! CapabilitySuccess) return _failure(_code(opened));
      session = SalesWorkflowSession._(
        operations,
        projection,
        repository,
        isWriteBlocked,
      );
      final result = await session._refreshAndLoad(
        initial,
        refreshAccount: false,
      );
      if (result is! CapabilitySuccess<void>) {
        session.dispose();
        return _failure(_code(result));
      }
      return CapabilitySuccess(session);
    } on Object {
      session?.dispose();
      return _failure('invalid_sales_session');
    }
  }

  /// New empty draft identity is captured alongside checkout, before dispatch.
  /// Do not reset the ticket or display a confirmed receipt on an unknown result.
  Future<CapabilityResult<RestaurantJournalSaleOutcome>> checkout({
    required TicketDraft fresh,
    required String operationId,
    required String journalId,
    required String recordedAt,
  }) async {
    if (_disposed) return _failure('disposed');
    if (draftNeedsReadback) return _failure('commit_unknown');
    if (busy || externallyBlocked) return _failure('busy');
    if (_checkout != null) return _failure('checkout_pending');
    final ticket = _drafts.active;
    if (ticket == null || !_drafts.quote.eligible) {
      return _failure('invalid_ticket');
    }
    if (!_freshAvailable(fresh, finalizedId: ticket.id)) {
      return _failure('invalid_fresh_ticket');
    }
    try {
      _checkout = _Checkout(
        operations.checkoutIntent(
          ticket: ticket,
          operationId: operationId,
          journalId: journalId,
          recordedAt: recordedAt,
        ),
        fresh,
      );
    } on Object {
      return _failure('invalid_checkout');
    }
    return _finishCheckout();
  }

  /// Explicit refresh after another complete-state workflow acknowledges a
  /// commit. Caller supplies an empty fallback identity for finalized drafts.
  Future<CapabilityResult<void>> refreshAccount({
    required TicketDraft fresh,
  }) async {
    if (_disposed) return _failure('disposed');
    if (busy || externallyBlocked) return _failure('busy');
    if (checkoutPending || operations.needsReadback || draftNeedsReadback) {
      return _failure('checkout_pending');
    }
    _busy = true;
    try {
      return await _refreshAndLoad(fresh);
    } finally {
      _busy = false;
      _changed();
    }
  }

  Future<CapabilityResult<RestaurantJournalSaleOutcome>> retryCheckout() async {
    if (_disposed) return _failure('disposed');
    if (busy || externallyBlocked) return _failure('busy');
    if (_checkout == null) return _failure('nothing_to_retry');
    return _finishCheckout();
  }

  Future<CapabilityResult<RestaurantJournalSaleOutcome>>
  _finishCheckout() async {
    final pending = _checkout!;
    _busy = true;
    _errorCode = null;
    _changed();
    try {
      if (_disposed) return _failure('disposed');
      if (pending.outcome == null) {
        final result = operations.needsReadback
            ? await operations.retry()
            : await operations.submit(pending.command);
        if (_disposed) return _failure('disposed');
        switch (result) {
          case DurableCommandSuccess(:final outcome):
            pending.outcome = outcome;
          case DurableCommandReplayed(:final outcome):
            if (outcome == null) return _failure('missing_checkout_outcome');
            pending.outcome = outcome;
          case DurableCommandFailure(:final code):
            _errorCode = code;
            if (!operations.needsReadback) _checkout = null;
            return _failure(code);
        }
      }
      // A known successful sale is never submitted again just because the
      // independent workspace acknowledgement was lost.
      final loaded = await _refreshAndLoad(pending.fresh);
      if (loaded is! CapabilitySuccess<void>) {
        _errorCode = _code(loaded);
        return _failure(_errorCode!);
      }
      final outcome = pending.outcome!;
      _checkout = null;
      return CapabilitySuccess(outcome);
    } on Object {
      _errorCode = 'checkout_reconciliation_required';
      return _failure(_errorCode!);
    } finally {
      _busy = false;
      _changed();
    }
  }

  bool _freshAvailable(TicketDraft fresh, {String? finalizedId}) =>
      fresh.lines.isEmpty &&
      fresh.id != finalizedId &&
      !_drafts.held.any((held) => held.draft.id == fresh.id) &&
      !(operations.account.toJson()['sales']! as List)
          .cast<Map<String, Object?>>()
          .any((sale) => sale['id'] == fresh.id);

  Future<CapabilityResult<void>> _refreshAndLoad(
    TicketDraft fresh, {
    bool refreshAccount = true,
  }) async {
    if (_disposed) return _failure('disposed');
    // Resolve the existing owner's uncertainty, then inspect current authority.
    // This is explicit recovery, never a new store or recreated account.
    final resolved = await _projection.inner.resolvePendingWrite();
    if (resolved is! CapabilitySuccess<void>) return _failure(_code(resolved));
    final opened = refreshAccount
        ? await _repository.open()
        : const CapabilitySuccess(null);
    if (_disposed) return _failure('disposed');
    if (opened is! CapabilitySuccess) return _failure(_code(opened));
    final document = _projection.lastDocument;
    if (document == null) return _failure('no_document');
    final accepted = operations.acceptSnapshot(document);
    if (accepted is! CapabilitySuccess<void>) return accepted;
    if (_disposed) return _failure('disposed');
    final read = await _projection.readWorkspace(operations.authorityFence);
    if (_disposed) return _failure('disposed');
    if (read is! CapabilitySuccess<WorkspaceState>) {
      return _failure(_code(read));
    }
    final prior = read.value.snapshot;
    final envelope = prior == null
        ? WorkspaceDocument.empty()
        : WorkspaceDocument.decode(prior.payload);
    var workspace = TicketWorkspace.fromEnvelope(envelope, fresh);
    final finalized = (operations.account.toJson()['sales']! as List)
        .cast<Map<String, Object?>>()
        .map((sale) => sale['id'])
        .toSet();
    // Only the active finalized draft is disposable. Preserve held/form values,
    // and require explicit recovery for an unrelated finalized held identity.
    if (workspace.held.any((held) => finalized.contains(held.draft.id))) {
      return _failure('finalized_held_ticket');
    }
    if (finalized.contains(workspace.active.id)) {
      if (!_freshAvailable(fresh, finalizedId: workspace.active.id) ||
          workspace.held.any((held) => held.draft.id == fresh.id)) {
        return _failure('invalid_fresh_ticket');
      }
      workspace = TicketWorkspace(
        active: fresh,
        held: workspace.held,
        form: workspace.form,
      );
      final written = await _projection.writeWorkspace(
        workspace.toEnvelope().encode(),
        fence: operations.authorityFence,
        expectedRevision: prior?.revision,
        writeToken: _token(),
      );
      if (_disposed) return _failure('disposed');
      if (written is! CapabilitySuccess<WorkspaceSnapshot>) {
        return _failure(_code(written));
      }
    }
    // The existing model reloads the actual acknowledged workspace and rejects
    // finalized IDs rather than publishing a draft from a guessed local state.
    return _drafts.load(fresh);
  }

  static String _token() {
    final random = Random.secure();
    return List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static String _code(CapabilityResult<dynamic> result) =>
      result is CapabilityFailure ? result.code : 'unavailable';
  static CapabilityFailure<T> _failure<T>(String code) =>
      CapabilityFailure(code, 'Sales workflow was not confirmed.');

  void _changed() {
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
    _drafts.removeListener(_changed);
    operations.removeListener(_changed);
    _drafts.dispose();
    operations.dispose();
    if (_notificationDepth == 0) super.dispose();
  }
}

final class _Checkout {
  _Checkout(this.command, this.fresh);
  final CompleteSaleCommand command;
  final TicketDraft fresh;
  RestaurantJournalSaleOutcome? outcome;
}

/// Read projection for the existing schema-11 draft/catalog controller only.
/// All persistence still uses the same Madar owner. Account writes and recovery
/// through this projection are refused; the portable command owner owns them.
final class _PortableDraftStore implements LocalDocumentWorkspaceStore {
  _PortableDraftStore(this.inner, this.codec, this.fence, this.lineage);
  final LocalDocumentWorkspaceStore inner;
  final PortableJournalCodec codec;
  final StorageFence fence;
  final String lineage;
  DocumentSnapshot? lastDocument;

  @override
  Future<CapabilityResult<DocumentSnapshot?>> readDocument() async {
    final read = await inner.readDocument();
    if (read is! CapabilitySuccess<DocumentSnapshot?>) {
      return _failure(_code(read));
    }
    final snapshot = read.value;
    if (snapshot == null || snapshot.fence != fence) {
      return _failure('stale_generation');
    }
    try {
      final state = codec.decodeState(snapshot.payload);
      if (state.accountLineage != lineage) {
        return _failure('account_lineage_mismatch');
      }
      lastDocument = snapshot;
      return CapabilitySuccess(
        DocumentSnapshot(
          payload: jsonEncode(state.account.toJson()),
          revision: snapshot.revision,
          fence: snapshot.fence,
          writeToken: snapshot.writeToken,
        ),
      );
    } on Object {
      return _failure('invalid_portable_account');
    }
  }

  @override
  Future<CapabilityResult<WorkspaceState>> readWorkspace(
    StorageFence requested,
  ) async {
    if (requested != fence) return _failure('stale_generation');
    final read = await inner.readWorkspace(requested);
    if (read is CapabilitySuccess<WorkspaceState> &&
        read.value.fence != fence) {
      return _failure('stale_generation');
    }
    return read;
  }

  @override
  Future<CapabilityResult<WorkspaceSnapshot>> writeWorkspace(
    String payload, {
    required StorageFence fence,
    required int? expectedRevision,
    required String writeToken,
  }) {
    if (fence != this.fence) return Future.value(_failure('stale_generation'));
    return inner.writeWorkspace(
      payload,
      fence: fence,
      expectedRevision: expectedRevision,
      writeToken: writeToken,
    );
  }

  @override
  Future<CapabilityResult<void>> resolvePendingWrite() =>
      inner.resolvePendingWrite();
  @override
  Future<CapabilityResult<DocumentSnapshot>> writeDocument(
    String payload, {
    required String writeToken,
    DocumentSnapshot? expected,
    bool replaceGeneration = false,
  }) async => _failure('portable_account_owner_required');
  @override
  Future<CapabilityResult<DocumentSnapshot>> resumeInitialCreation(
    String payload, {
    required String writeToken,
  }) async => _failure('portable_account_owner_required');
  @override
  Future<CapabilityResult<PreviousDocument?>> readPrevious() async =>
      _failure('portable_account_owner_required');
  @override
  Future<CapabilityResult<String>> preserveSource(List<int> bytes) async =>
      _failure('portable_account_owner_required');
  @override
  Future<CapabilityResult<DocumentSnapshot>> recoverPrevious(
    PreviousDocument previous, {
    required String payload,
    required String writeToken,
  }) async => _failure('portable_account_owner_required');
  @override
  Future<void> close() async {} // Borrowed owner; caller closes it.

  static String _code(CapabilityResult<dynamic> result) =>
      result is CapabilityFailure ? result.code : 'unavailable';
  static CapabilityFailure<T> _failure<T>(String code) =>
      CapabilityFailure(code, 'Portable draft access refused.');
}
