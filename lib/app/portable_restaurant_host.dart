import 'dart:async';

import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';

import '../accounts/portable_account_transfer_controller.dart';
import '../accounts/portable_accounts_surface.dart';
import '../sales/ticket_workspace.dart';
import '../shell/shell_view_model.dart';
import '../ui/components.dart';
import '../ui/theme.dart';
import 'app.dart';
import 'restaurant_operations_session.dart';

/// Top-level integration host for the portable restaurant application.
///
/// Borrows a caller-initialized [store] and [initialSnapshot], requiring an explicit
/// text [compareText] comparator and [freshTicket] factory.
///
/// It never bootstraps a normal account, runs live migration, or activates cutover.
///
/// Key responsibilities:
/// 1. Reuses existing [DakhlRestaurantApp] with [RestaurantOperationsSession] and
///    [PortableAccountsSurface] backed by [PortableAccountTransferController].
/// 2. Manages mutual exclusion: blocks peer session writes during file unknown/busy/import,
///    and blocks transfer import/export while session writers or dirty settings are pending.
/// 3. Propagates acknowledged session snapshot advances to [PortableAccountTransferController],
///    keeping file export view at the newest acknowledged session snapshot.
/// 4. On confirmed replacement import, disposes old controllers, rekeys [DakhlRestaurantApp]
///    by generation, preserves the committed snapshot, and displays a recoverable protected
///    failure if reopening fails (never re-importing as retry).
/// 5. Respects store ownership: the source caller owns borrowed store lifecycle.
class PortableRestaurantHost extends StatefulWidget {
  const PortableRestaurantHost({
    super.key,
    required this.store,
    required this.initialSnapshot,
    required this.compareText,
    required this.freshTicket,
    required this.preferencesStore,
    this.transfer,
    this.acceptedCashCounterAccountId,
    this.acceptedDebtCounterAccountId,
    this.acceptedOpeningEquityAccountId,
    this.compareMaterialNames,
    this.onShellReady,
  });

  /// Caller-initialized borrowed store; source caller owns store lifecycle.
  final LocalDocumentWorkspaceStore store;

  /// Explicit initial complete-envelope snapshot.
  final DocumentSnapshot initialSnapshot;

  /// Explicit text comparator for ordering/collation.
  final int Function(String, String) compareText;
  final int Function(String, String)? compareMaterialNames;

  /// Fresh ticket draft factory for sales workflow.
  final TicketDraft Function() freshTicket;

  /// Local preferences store.
  final LocalPreferencesStore preferencesStore;

  /// File transfer capability for import/export operations.
  final FileTransferCapability? transfer;

  /// Owner-approved journal mapping; absence keeps direct cash posting disabled.
  final String? acceptedCashCounterAccountId;
  final String? acceptedDebtCounterAccountId;
  final String? acceptedOpeningEquityAccountId;

  /// Optional observer notified when the shell view model is initialized.
  final ValueChanged<ShellViewModel>? onShellReady;

  @override
  State<PortableRestaurantHost> createState() => PortableRestaurantHostState();
}

class PortableRestaurantHostState extends State<PortableRestaurantHost> {
  late DocumentSnapshot _committedSnapshot;

  RestaurantOperationsSession? _session;
  PortableAccountTransferController? _transferController;

  int _generation = 0;
  late Key _appKey;

  bool _isOpening = false;
  String? _reopenError;
  bool _disposed = false;

  RestaurantOperationsSession? get session => _session;
  PortableAccountTransferController? get transferController =>
      _transferController;
  DocumentSnapshot get committedSnapshot => _committedSnapshot;
  int get generation => _generation;
  String? get reopenError => _reopenError;
  bool get isOpening => _isOpening;

  @override
  void initState() {
    super.initState();
    _committedSnapshot = widget.initialSnapshot;
    _appKey = ValueKey(
      'portable-app-gen-$_generation-${_committedSnapshot.fence}',
    );
    unawaited(_openSession());
  }

  @override
  void dispose() {
    _disposed = true;
    _disposeOldControllers();
    super.dispose();
  }

  void _disposeOldControllers() {
    if (_session != null) {
      _session!.removeListener(_onSessionChanged);
      _session!.dispose();
      _session = null;
    }
    if (_transferController != null) {
      _transferController!.removeListener(_onTransferChanged);
      _transferController!.dispose();
      _transferController = null;
    }
  }

  /// Blocks session writes when file transfer is busy, unknown (needs readback),
  /// or when an import candidate is prepared.
  bool _isTransferWritingOrPending() {
    final transfer = _transferController;
    if (transfer == null) return false;
    return transfer.busy || transfer.needsReadback || transfer.hasPendingImport;
  }

  /// Blocks file transfer / import when session writers are busy, uncertain writes
  /// are pending, or settings are dirty.
  bool _isSessionWritingOrPending() {
    final s = _session;
    if (s == null) return false;
    return s.busy ||
        s.sales.checkoutPending ||
        s.sales.operations.needsReadback ||
        s.sales.draftNeedsReadback ||
        s.settings.isDirty ||
        s.settings.needsReadback ||
        s.spending.needsReadback ||
        s.parties.needsReadback ||
        s.metadataBridge.needsReadback ||
        s.metadataRepository.hasUnknownWrite ||
        s.metadataRepository.hasUnknownWorkspaceWrite ||
        s.dailyRegister.needsReadback ||
        s.dayDates.needsReadback ||
        s.additionalDebts.needsReadback ||
        s.supplierOpenings.needsReadback;
  }

  Future<CapabilityResult<RestaurantOperationsSession>> _openSession() async {
    if (_disposed) {
      return const CapabilityFailure('disposed', 'Host disposed.');
    }
    _isOpening = true;
    _reopenError = null;
    if (mounted) setState(() {});

    try {
      final opened = await RestaurantOperationsSession.open(
        acceptedCashCounterAccountId: widget.acceptedCashCounterAccountId,
        acceptedDebtCounterAccountId: widget.acceptedDebtCounterAccountId,
        acceptedOpeningEquityAccountId: widget.acceptedOpeningEquityAccountId,
        store: widget.store,
        snapshot: _committedSnapshot,
        compareText: widget.compareText,
        fresh: widget.freshTicket(),
        isWriteBlocked: _isTransferWritingOrPending,
      );

      if (_disposed) {
        return const CapabilityFailure('disposed', 'Host disposed.');
      }

      if (opened is CapabilitySuccess<RestaurantOperationsSession>) {
        final activeSession = opened.value;
        _session = activeSession;
        _committedSnapshot = activeSession.snapshot;

        final transfer = PortableAccountTransferController(
          store: widget.store,
          snapshot: activeSession.snapshot,
          isWriteBlocked: _isSessionWritingOrPending,
        );
        _transferController = transfer;

        activeSession.addListener(_onSessionChanged);
        transfer.addListener(_onTransferChanged);

        _generation++;
        _appKey = ValueKey(
          'portable-app-gen-$_generation-${_committedSnapshot.fence}',
        );
        _reopenError = null;
        _isOpening = false;
        if (mounted) setState(() {});
        return opened;
      } else {
        final code = (opened as CapabilityFailure).code;
        _reopenError = code;
        _isOpening = false;
        if (mounted) setState(() {});
        return opened;
      }
    } on Object catch (error) {
      if (_disposed) {
        return const CapabilityFailure('disposed', 'Host disposed.');
      }
      _reopenError = error.toString();
      _isOpening = false;
      if (mounted) setState(() {});
      return CapabilityFailure(
        'operations_session_unavailable',
        error.toString(),
      );
    }
  }

  void _onSessionChanged() {
    if (_disposed || !mounted) return;
    final s = _session;
    final t = _transferController;
    if (s == null || t == null) return;

    final sessionSnapshot = s.snapshot;
    if (sessionSnapshot.revision > t.snapshot.revision &&
        sessionSnapshot.fence == t.snapshot.fence) {
      final accepted = t.acceptAcknowledgedSnapshot(sessionSnapshot);
      if (accepted is CapabilitySuccess) {
        _committedSnapshot = sessionSnapshot;
      }
    }
  }

  void _onTransferChanged() {
    if (_disposed || !mounted) return;
    setState(() {});
  }

  Future<void> _handleImportApplied(DocumentSnapshot importedSnapshot) async {
    if (_disposed) return;
    // 1. Preserve committed snapshot
    _committedSnapshot = importedSnapshot;

    // 2. Dispose old controllers
    _disposeOldControllers();

    // 3. Reopen session from preserved committed snapshot
    await _openSession();
  }

  /// Exposed for testing and manual application of confirmed imports.
  Future<void> handleImportApplied(DocumentSnapshot importedSnapshot) =>
      _handleImportApplied(importedSnapshot);

  /// Exposed for manual retry from the recoverable failure UI.
  Future<void> retryReopen() => _openSession();

  @override
  Widget build(BuildContext context) {
    if (_reopenError != null) {
      return _buildRecoverableFailure(context);
    }

    if (_session == null || _transferController == null) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Material(
          color: DakhlTokens.background,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return DakhlRestaurantApp(
      key: _appKey,
      preferencesStore: widget.preferencesStore,
      operations: _session,
      compareMaterialNames: widget.compareMaterialNames,
      portableDataSurface: PortableAccountsSurface(
        controller: _transferController!,
        transfer: widget.transfer,
        onImportApplied: _handleImportApplied,
      ),
      onShellReady: widget.onShellReady,
    );
  }

  Widget _buildRecoverableFailure(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: DakhlTokens.background,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: DakhlPanel(
                key: const Key('portable-reopen-failure-panel'),
                borderColor: DakhlTokens.focus,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'تعذر استئناف جلسة العمليات',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DakhlStatus(
                      key: const Key('portable-reopen-failure-status'),
                      message:
                          'تعذر فتح جلسة العمليات بعد الاستيراد ($_reopenError). '
                          'الحساب المحفوظ محمي بالكامل في وحدة التخزين ويمكن إعادة محاولة الفتح.',
                      kind: DakhlStatusKind.error,
                      onRetry: _openSession,
                    ),
                    const SizedBox(height: 16),
                    DakhlButton(
                      key: const Key('portable-reopen-retry-button'),
                      label: 'إعادة فتح الجلسة',
                      kind: DakhlButtonKind.primary,
                      busy: _isOpening,
                      onPressed: _isOpening ? null : _openSession,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
