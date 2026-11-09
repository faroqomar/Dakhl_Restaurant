import 'dart:async';
import 'dart:convert';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_application/madar_application.dart';

import '../accounts/accounts_view_model.dart';
import '../accounts/accounts_surface.dart';
import '../accounts/workspace_document.dart';
import '../catalog/catalog_view_model.dart';
import '../catalog/inventory_surface.dart';
import '../accounting/categories_surface.dart';
import '../accounting/categories_view_model.dart';
import '../sales/sales_view_model.dart';
import '../sales/sales_surface.dart';
import '../sales/sales_history_surface.dart';
import '../accounting/daily_cash_surface.dart';
import '../accounting/daily_metadata_controller.dart';
import '../accounting/chicken_editor.dart';
import '../accounting/daily_register_editor.dart';
import '../accounting/day_date_editor.dart';
import '../accounting/daily_transfer_editor.dart';
import '../accounting/daily_transfer_editor_controller.dart';
import '../accounting/financial_session_undo.dart';
import '../parties/additional_debt_session_undo_adapter.dart';
import '../accounting/spending_session_undo_adapter.dart';
import '../accounting/daily_register_session_undo_adapter.dart';
import '../accounting/day_date_session_undo_adapter.dart';
import '../parties/parties_session_undo_adapter.dart';
import '../accounting/journal_command_host.dart' show canonicalIdentity;
import '../accounts/portable_journal_codec.dart';
import '../accounts/metadata_session_undo.dart';
import '../accounts/legacy_session_undo.dart';
import '../inventory/stock_session_undo.dart';

import 'package:madar_domain/madar_domain.dart';

import '../settings/account_settings_controller.dart';
import '../settings/settings_surface.dart';
import '../reports/reports_view_model.dart';
import '../reports/reports_surface.dart';
import '../reports/restaurant_report.dart';
import '../parties/parties_surface.dart';
import '../parties/parties_view_model.dart';
import '../sales/ticket_workspace.dart';
import '../shell/shell_routes.dart';
import '../shell/shell_view_model.dart';
import '../ui/dakhl_ui.dart';
import 'ios_shell_back_gesture.dart';
import 'restaurant_operations_session.dart';

final shellViewModelProvider = Provider<ShellViewModel>(
  (ref) => throw StateError('Shell composition must supply its ViewModel.'),
);

/// Development composition; views consume app ViewModels, never storage APIs.
class DakhlRestaurantApp extends StatefulWidget {
  const DakhlRestaurantApp({
    super.key,
    required this.preferencesStore,
    this.closePreferences,
    this.onShellReady,
    this.accounts,
    this.accountTransfer,
    this.closeAccounts,
    this.operations,
    this.portableDataSurface,
    this.sourceCollation,
    this.compareMaterialNames,
    this.closeSourceCollation,
  }) : assert(accounts == null || operations == null);
  final LocalPreferencesStore preferencesStore;
  final AccountsViewModel? accounts;

  /// Explicit caller-initialized complete-state composition. Never enrolls or
  /// migrates the normal account store. Recreate with a new key after replacement.
  final RestaurantOperationsSession? operations;

  /// Complete-envelope file UI only; never schema11 projected export/import.
  final Widget? portableDataSurface;
  final CollationSession? sourceCollation;
  final int Function(String, String)? compareMaterialNames;
  final VoidCallback? closeSourceCollation;
  final FileTransferCapability? accountTransfer;
  final Future<void> Function()? closeAccounts;
  final Future<void> Function()? closePreferences;

  /// Optional development observation after bootstrap and shell frame build.
  /// Normal composition supplies no observer and retains its original path.
  final ValueChanged<ShellViewModel>? onShellReady;

  @override
  State<DakhlRestaurantApp> createState() => _DakhlRestaurantAppState();
}

class _DakhlRestaurantAppState extends State<DakhlRestaurantApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _searchFocus = FocusNode(debugLabel: 'sales-catalog-search');
  late final ShellViewModel _model;
  late final GoRouter _router;
  late final AppLifecycleListener _lifecycle;
  bool _acceptingRouterIntent = false;
  bool _initialRouterSynchronized = false;
  bool _syncQueued = false;
  bool _mobileBackInProgress = false;
  bool _salesPendingInput = false;
  StorageFence? _accountFence;
  String? _accountSlots;
  String? _attemptedWorkspace;
  bool _syncingAccount = false;
  bool _workspaceQueued = false;
  bool _accountBootstrapComplete = false;
  bool _initialAccountReadProtected = false;
  Map<String, String>? _invalidWorkspaceForm, _invalidWorkspaceTicket;
  CatalogViewModel? _catalogViewModel;
  CategoriesViewModel? _categoriesViewModel;
  SalesViewModel? _salesViewModel;
  PartiesViewModel? _partiesViewModel;
  AccountSettingsController? _settingsController;
  ReportsViewModel? _reportsViewModel;
  final _reportDelivery = ReportDeliveryController();
  AccountsViewModel? _portableAccounts;
  AccountsViewModel? get _accounts => widget.accounts ?? _portableAccounts;
  String? _attemptedPortableForm;
  String? _pendingSaleId;
  String? _pendingPaymentId;
  FinancialSessionUndoController? _undo;
  LegacySessionUndoController? _legacyUndo;
  DocumentSnapshot? _legacySettingsSnapshot;
  DocumentSnapshot? _undoSnapshot;
  bool _undoInProgress = false;
  int _sourceTextComparison(String a, String b) {
    final comparator =
        widget.operations?.reports.compareText ??
        widget.sourceCollation?.compare;
    if (comparator != null) return comparator(a, b);
    if (a == b) return 0;
    throw StateError('collation_unavailable');
  }

  @override
  void initState() {
    super.initState();
    final operations = widget.operations;
    if (operations != null) {
      _portableAccounts = AccountsViewModel(
        repository: operations.metadataRepository,
      );
    }
    if (operations != null) {
      _undoSnapshot = operations.snapshot;
      _undo = FinancialSessionUndoController(
        readSnapshot: () => operations.snapshot,
        isWriteBlocked: () =>
            operations.busy ||
            operations.sales.checkoutPending ||
            operations.sales.draftNeedsReadback ||
            (!(_undo?.needsReadback ?? false) &&
                (operations.sales.operations.needsReadback ||
                    operations.spending.needsReadback ||
                    operations.parties.needsReadback ||
                    operations.settings.needsReadback ||
                    operations.dailyRegister.needsReadback ||
                    operations.dayDates.needsReadback ||
                    operations.additionalDebts.needsReadback ||
                    operations.supplierOpenings.needsReadback ||
                    operations.metadataBridge.needsReadback)),
      );
    }
    final accounts = _accounts;
    if (operations == null && accounts != null) {
      _legacyUndo = LegacySessionUndoController(
        repository: accounts.repository,
        isWriteBlocked: () => accounts.busy,
      );
    }
    if (accounts != null) {
      _catalogViewModel = CatalogViewModel(accounts.repository)
        ..addListener(_legacySourceChanged);
      _categoriesViewModel?.dispose();
      _categoriesViewModel = CategoriesViewModel(accounts.repository)
        ..addListener(_legacySourceChanged);
    }
    _model = ShellViewModel(
      store: widget.preferencesStore,
      accountShortcuts: () => _accounts?.accountShortcuts,
      saveAccountShortcuts: _accounts?.saveShortcuts,
    );
    _accounts?.confirmAuthorityReload = () async {
      if (_undoBlocksNavigation) return false;
      if (!_salesPendingInput &&
          !_model.dirtyForm &&
          _model.ticketPresentation.isEmpty &&
          _model.shortcutDraft == null) {
        return true;
      }
      return _confirmDiscard();
    };
    _accounts?.addListener(_syncAccount);
    _model.addListener(_queueWorkspace);
    _router = GoRouter(
      navigatorKey: _navigatorKey,
      initialLocation: '/sales',
      redirect: (context, state) async {
        final path = state.uri.path;
        final requested = ShellRoutes.normalizeRoute(
          path.startsWith('/') ? path.substring(1) : path,
        );
        if (!_model.canNavigate) return path == '/sales' ? null : '/sales';
        // The initial /sales placeholder cannot overwrite a route restored by
        // asynchronous native account/preferences bootstrap.
        if (!_initialRouterSynchronized) {
          _initialRouterSynchronized = true;
          final restored = '/${_model.routeId}';
          return path == restored ? null : restored;
        }
        if (requested != _model.routeId) {
          final observedRoute = _model.routeId;
          if (!await _confirmSalesNavigation()) return '/${_model.routeId}';
          if (_model.routeId != observedRoute ||
              _router.routeInformationProvider.value.uri.path != path) {
            return '/${_model.routeId}';
          }
          _acceptingRouterIntent = true;
          try {
            await _model.navigate(requested, confirmDiscard: _confirmDiscard);
          } finally {
            _acceptingRouterIntent = false;
          }
        }
        final accepted = '/${_model.routeId}';
        return path == accepted ? null : accepted;
      },
      routes: [
        ShellRoute(
          builder: (context, state, child) => ListenableBuilder(
            listenable: Listenable.merge([
              _model,
              if (widget.operations != null) widget.operations!,
            ]),
            builder: (context, _) => PopScope<void>(
              // Android derives platform Back registration from the outer
              // Navigator too. Its shell page must report the same guard as
              // the selected destination, including after a modal closes.
              canPop: _canPopShell,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) unawaited(_mobileBack());
              },
              child: _ShellFrame(
                onNavigate: _navigate,
                onEditShortcuts: () => _editShortcuts(context),
                onSearch: _search,
                onUndo: _dispatchSessionUndo,
                accounts: _accounts,
                operations: widget.operations,
                undo: _undo,
                legacyUndo: _legacyUndo,
                onRetryUndo: _dispatchSessionUndo,
                catalog: _catalogViewModel,
                child: child,
              ),
            ),
          ),
          routes: [
            for (final destination in ShellRoutes.destinations)
              GoRoute(
                path: '/${destination.id}',
                builder: (context, state) => ListenableBuilder(
                  listenable: Listenable.merge([
                    _model,
                    if (widget.operations != null) widget.operations!,
                  ]),
                  builder: (context, _) => PopScope<void>(
                    canPop: _canPopShell,
                    onPopInvokedWithResult: (didPop, _) {
                      if (!didPop) unawaited(_mobileBack());
                    },
                    child: IosShellBackGesture(
                      canStart: _canStartIosBack,
                      onBack: _mobileBack,
                      child: _routeContent(destination.id, context),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        if (_undoBlocksNavigation) return AppExitResponse.cancel;
        if (!_salesPendingInput &&
            !_model.dirtyForm &&
            !(_model.shortcutDraft != null && _model.hasUnsavedPreferences)) {
          return AppExitResponse.exit;
        }
        if (!await _confirmDiscard()) return AppExitResponse.cancel;
        _model.discardForm();
        _model.cancelShortcutEditing();
        return AppExitResponse.exit;
      },
    );
    _model.addListener(_syncRoute);
    widget.operations?.addListener(_operationsChanged);
    _undo?.addListener(_undoChanged);
    _legacyUndo?.addListener(_undoChanged);
    final initialization = () async {
      await _accounts?.initialize();
      await _model.initialize();
      _accounts?.seedDeviceFallback(_model.shortcuts);
      _syncAccount();
      _accountBootstrapComplete = true;
    }();
    if (widget.onShellReady == null) {
      unawaited(initialization);
    } else {
      unawaited(
        initialization.then((_) async {
          await WidgetsBinding.instance.endOfFrame;
          if (mounted) widget.onShellReady?.call(_model);
        }),
      );
    }
  }

  Widget _routeContent(String routeId, BuildContext context) {
    final accounts = _accounts;
    final operations = widget.operations;
    if (routeId == 'settings' && accounts != null) {
      final Widget data = operations == null
          ? AccountsSurface(model: accounts, transfer: widget.accountTransfer)
          : widget.portableDataSurface ??
                const Center(
                  child: Text('خدمة ملفات الحساب الكامل غير متاحة.'),
                );
      if (operations != null) {
        return SettingsSurface(
          portableController: operations.settings,
          dataSurface: data,
          onNavigate: _navigate,
          onPendingChanged: (pending) {
            _salesPendingInput = pending;
          },
          onUndo: _undo?.canUndo == true ? _dispatchSessionUndo : null,
          onSave: operations.saveSettings,
          onReconcile: operations.reconcileSettings,
        );
      }
      return ListenableBuilder(
        listenable: accounts,
        builder: (context, _) {
          final controller = _settingsController;
          if (accounts.document == null || controller == null) return data;
          return SettingsSurface(
            controller: controller,
            dataSurface: data,
            onNavigate: _navigate,
            onPendingChanged: (pending) {
              _salesPendingInput = pending;
            },
            onUndo: _legacyUndo?.canUndo == true ? _dispatchSessionUndo : null,
            onSave: () async {
              final result = await controller.save();
              if (mounted && result is CapabilitySuccess<void>) _syncAccount();
              return result;
            },
          );
        },
      );
    }
    if (const [
          'suppliers',
          'materials',
          'invoices',
          'payments',
        ].contains(routeId) &&
        accounts != null) {
      return ListenableBuilder(
        listenable: accounts,
        builder: (context, _) => AbsorbPointer(
          absorbing: !accounts.canMutate,
          child: PartiesSurface(
            routeId: routeId,
            account: operations?.parties.account ?? accounts.document,
            operations: operations?.parties,
            purchaseController: operations?.purchases,
            additionalDebts: operations?.additionalDebts,
            supplierOpenings: operations?.supplierOpenings,
            initialPaymentId: routeId == 'payments' ? _pendingPaymentId : null,
            onInitialPaymentHandled: (id) {
              if (_pendingPaymentId == id) _pendingPaymentId = null;
            },
            compareText:
                operations?.reports.compareText ??
                widget.sourceCollation?.compare,
            compareMaterialNames: widget.compareMaterialNames,
            metadata: accounts.document == null ? null : _partiesViewModel,
            onNavigate: _navigate,
            onPendingInputChanged: (pending) {
              _salesPendingInput = pending;
            },
          ),
        ),
      );
    }
    if (routeId == 'sale-history' && accounts != null) {
      return ListenableBuilder(
        listenable: accounts,
        builder: (context, _) => SalesHistorySurface(
          document: operations?.sales.operations.account ?? accounts.document,
          operations: operations?.sales.operations,
          compareText:
              operations?.reports.compareText ??
              widget.sourceCollation?.compare,
          delivery: _reportDelivery,
          initialSaleId: _pendingSaleId,
          onInitialSaleHandled: (id) {
            if (_pendingSaleId == id) _pendingSaleId = null;
          },
          onNewSale: () => _navigate(ShellRoutes.sales),
        ),
      );
    }
    if (routeId == 'statement' &&
        accounts?.document != null &&
        _reportsViewModel != null) {
      final date = DateTime.now().toIso8601String().substring(0, 10);
      return ReportsSurface(
        model: _reportsViewModel!,
        selectedDate: date,
        onRecordRemaining: operations == null
            ? null
            : (value) =>
                  _editDailyRegister(DailyRegisterField.remaining, value),
        onTransfer: operations == null ? null : _transferFromDay,
        onPendingChanged: (pending) {
          _salesPendingInput = pending;
        },
      );
    }
    if ((routeId == 'expenses' || routeId == 'cash') && accounts != null) {
      return ListenableBuilder(
        listenable: accounts,
        builder: (context, _) {
          final document = operations?.spending.account ?? accounts.document;
          if (document == null) {
            return const Center(child: Text('افتح حساباً من الإعدادات أولاً.'));
          }
          return DailyCashSurface(
            document: document,
            controller: operations?.dailyCash,
            compareText:
                operations?.reports.compareText ??
                widget.sourceCollation?.compare,
            readAccount: () => accounts.document ?? document,
            onChickenEdit: (date) async {
              final day =
                  accounts.document?.days[date] as Map<String, Object?>?;
              await showChickenEditor(
                context,
                controller: DailyMetadataController(accounts.repository),
                date: date,
                used: day?['chickenUsed'] as int? ?? 0,
                left: day?['chickenLeft'] as int? ?? 0,
                canWrite: () => accounts.canMutate,
              );
              _legacySourceChanged();
            },
            cash: routeId == 'cash',
            onCategories: () => _navigate('categories'),
            onPayments: () => _navigate('payments'),
            onOpenPayment: _openSavedPayment,
            onRegisterEdit: operations == null ? null : _editDailyRegister,
            onDateCorrection: operations == null
                ? null
                : (date) => showDayDateEditor(
                    context,
                    controller: operations.dayDates,
                    initialDate: date,
                    onApplied: () async {
                      await operations.synchronize();
                    },
                  ),
            onAddCategory: _categoriesViewModel == null
                ? null
                : () async {
                    final model = _categoriesViewModel!;
                    final record = await showCategoryEditor(
                      context,
                      model: model,
                      draft: model.newCategoryDraft(),
                      canWrite: () => accounts.canMutate,
                    );
                    if (record != null && operations != null) {
                      await operations.synchronize();
                    }
                    return record?.id;
                  },
            reportComposer: RestaurantReportComposer(
              document,
              compareText: _sourceTextComparison,
            ),
            delivery: _reportDelivery,
            onReview: _reportsViewModel == null
                ? null
                : (date) {
                    showDayReview(
                      context,
                      model: _reportsViewModel!,
                      date: date,
                      onTransfer: operations == null ? null : _transferFromDay,
                      onRecordRemaining: operations == null
                          ? null
                          : (value) {
                              _editDailyRegister(
                                DailyRegisterField.remaining,
                                value,
                              );
                            },
                    );
                  },
          );
        },
      );
    }
    if (routeId == 'sales' && accounts != null) {
      return ListenableBuilder(
        listenable: accounts,
        builder: (context, _) => AbsorbPointer(
          absorbing: !accounts.canMutate,
          child: SalesSurface(
            model: operations == null && accounts.document != null
                ? _salesViewModel
                : null,
            session: operations?.sales,
            onOpenReceipt: _openSavedSale,
            searchFocusNode: _searchFocus,
            onPendingInputChanged: (pending) {
              _salesPendingInput = pending;
            },
          ),
        ),
      );
    }
    if (routeId == 'categories' && accounts != null) {
      return ListenableBuilder(
        listenable: accounts,
        builder: (context, _) =>
            accounts.document == null || _categoriesViewModel == null
            ? const Center(child: Text('افتح حساباً من الإعدادات أولاً.'))
            : CategoriesSurface(
                model: _categoriesViewModel!,
                canWrite: () => accounts.canMutate && accounts.document != null,
              ),
      );
    }
    if (routeId == 'inventory' && accounts != null) {
      return ListenableBuilder(
        listenable: accounts,
        builder: (context, _) => InventorySurface(
          model: _catalogViewModel,
          accounts: accounts,
          shell: _model,
          onOpenSale: _openSavedSale,
        ),
      );
    }
    final origin = accounts?.fence;
    bool current() => accounts == null || accounts.fence == origin;
    return Phase01RouteSurface(
      routeId: routeId,
      onCheckout: () => showDakhlToast(context, 'عرض تجريبي فقط'),
      searchFocusNode: _searchFocus,
      formDraft: _model.formDraft,
      onFormChanged: (value) {
        if (current()) _model.setFormDraft(value);
      },
      onFormDiscard: () {
        if (current()) _model.discardForm();
      },
      ticketPresentation: _model.ticketPresentation,
      onTicketChanged: (value) {
        if (!current()) return;
        final previous = _model.ticketPresentation;
        _model.registerSessionUndo(() {
          if (current()) _model.setTicketPresentation(previous);
        });
        _model.setTicketPresentation(value);
      },
    );
  }

  void _syncAccount() {
    final accounts = _accounts;
    if (!mounted || accounts == null || _syncingAccount) return;
    if (_accountFence == null && accounts.state == AccountsState.protected) {
      _initialAccountReadProtected = true;
    }
    if ((accounts.state == AccountsState.saved ||
            accounts.state == AccountsState.importReady) &&
        accounts.fence != null) {
      _syncingAccount = true;
      try {
        final hadFence = _accountFence != null;
        final changedFence = _accountFence != accounts.fence;
        if (changedFence) {
          _accountFence = accounts.fence;
          _attemptedWorkspace = accounts.workspace.encode();
          _catalogViewModel?.dispose();
          _catalogViewModel = CatalogViewModel(accounts.repository)
            ..addListener(_legacySourceChanged);
          _categoriesViewModel?.dispose();
          _categoriesViewModel = CategoriesViewModel(accounts.repository)
            ..addListener(_legacySourceChanged);
          _bindSales(accounts);
          // A retry can reveal the first existing account after bootstrap.
          // Preserve local drafts only for a genuine first account creation.
          if (hadFence ||
              !_accountBootstrapComplete ||
              _initialAccountReadProtected) {
            _model.restoreAccountWorkspace(
              form: accounts.workspace.form,
              ticket: accounts.workspace.active,
            );
          }
          _initialAccountReadProtected = false;
        } else if (_catalogViewModel == null ||
            _catalogViewModel!.repository != accounts.repository) {
          _catalogViewModel?.dispose();
          _catalogViewModel = CatalogViewModel(accounts.repository)
            ..addListener(_legacySourceChanged);
          _categoriesViewModel?.dispose();
          _categoriesViewModel = CategoriesViewModel(accounts.repository)
            ..addListener(_legacySourceChanged);
          _bindSales(accounts);
        }
        final slots = accounts.accountShortcuts?.join('|');
        if (slots != _accountSlots) {
          _accountSlots = slots;
          unawaited(
            _model.refreshAccountSettings(
              cache: hadFence && _model.shortcutDraft == null,
            ),
          );
        }
      } finally {
        _syncingAccount = false;
      }
    }
    _queueWorkspace();
    _legacySourceChanged();
  }

  void _bindSales(AccountsViewModel accounts) {
    _salesPendingInput = false;
    _pendingSaleId = null;
    _pendingPaymentId = null;
    _partiesViewModel?.dispose();
    _partiesViewModel = PartiesViewModel(accounts.repository)
      ..addListener(_legacySourceChanged);
    _settingsController = widget.operations == null
        ? AccountSettingsController(accounts.repository)
        : null;
    _legacySettingsSnapshot = accounts.repository.snapshot;
    if (widget.operations == null) _reportsViewModel?.dispose();
    _reportsViewModel =
        widget.operations?.reports ??
        ReportsViewModel(
          accounts.repository,
          compareText: _sourceTextComparison,
        );
    _salesViewModel?.dispose();
    if (widget.operations != null) return;
    final sales = SalesViewModel(accounts.repository)
      ..addListener(_queueWorkspace);
    _salesViewModel = sales;
    final types = sales.orderTypes;
    if (types.isEmpty) return;
    final now = DateTime.now();
    unawaited(
      sales.load(
        TicketDraft(
          id: 'ticket-${now.microsecondsSinceEpoch}',
          date:
              '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          orderType: types.first,
          discount: '',
          note: '',
          lines: const [],
        ),
      ),
    );
  }

  void _queueWorkspace() {
    final accounts = _accounts;
    if (!mounted ||
        _syncingAccount ||
        _workspaceQueued ||
        accounts == null ||
        !accounts.canMutate ||
        accounts.fence == null ||
        accounts.pendingImport != null ||
        accounts.recoverySelection != null) {
      return;
    }
    final portable = widget.operations;
    if (portable != null) {
      if (portable.busy ||
          portable.sales.checkoutPending ||
          portable.sales.draftNeedsReadback ||
          portable.sales.operations.needsReadback) {
        return;
      }
      final form = Map<String, String>.unmodifiable(_model.formDraft);
      final encoded = jsonEncode(form);
      if (_attemptedPortableForm == encoded) return;
      if (_attemptedPortableForm == null &&
          jsonEncode(accounts.workspace.form) == encoded) {
        _attemptedPortableForm = encoded;
        return;
      }
      _attemptedPortableForm = encoded;
      _workspaceQueued = true;
      scheduleMicrotask(() async {
        try {
          if (mounted) await portable.sales.saveFormDraft(form);
        } finally {
          _workspaceQueued = false;
          if (mounted) _queueWorkspace();
        }
      });
      return;
    }
    final sales = _salesViewModel;
    if (sales != null && (sales.busy || sales.needsReadback)) return;
    if (sales != null) {
      final savedForm = accounts.workspace.form;
      final currentForm = _model.formDraft;
      if (savedForm.length == currentForm.length &&
          savedForm.entries.every(
            (entry) => currentForm[entry.key] == entry.value,
          )) {
        // Sales owns ticket persistence. Loading a fresh in-memory fallback
        // must not normalize an acknowledged legacy workspace during reopen.
        return;
      }
    }
    final ticket = sales?.active;
    final workspace = ticket != null
        ? TicketWorkspace(
            active: ticket,
            held: sales!.held,
            form: _model.formDraft,
          ).toEnvelope()
        : WorkspaceDocument(
            active: _model.ticketPresentation,
            form: _model.formDraft,
            held: accounts.workspace.held,
          );
    final String encoded;
    try {
      encoded = workspace.encode();
      // Navigation must preserve the workspace already saved by sales.
      if (accounts.repository.workspaceSnapshot?.payload == encoded) {
        _attemptedWorkspace = encoded;
        return;
      }
    } on FormatException {
      if (identical(_invalidWorkspaceForm, _model.formDraft) &&
          identical(_invalidWorkspaceTicket, _model.ticketPresentation)) {
        return;
      }
      _invalidWorkspaceForm = _model.formDraft;
      _invalidWorkspaceTicket = _model.ticketPresentation;
      unawaited(accounts.saveWorkspace(workspace, accounts.fence!));
      return;
    }
    _invalidWorkspaceForm = null;
    _invalidWorkspaceTicket = null;
    if (_attemptedWorkspace == encoded) return;
    final origin = accounts.fence!;
    _attemptedWorkspace = encoded;
    _workspaceQueued = true;
    scheduleMicrotask(() async {
      try {
        if (mounted && accounts.fence == origin) {
          await accounts.saveWorkspace(workspace, origin);
        }
      } finally {
        _workspaceQueued = false;
        if (mounted) _queueWorkspace();
      }
    });
  }

  void _operationsChanged() {
    if (!mounted) return;
    _observeSessionUndo();
    _queueWorkspace();
    _router.refresh();
  }

  void _legacySourceChanged() {
    if (!mounted || _legacyUndo == null) return;
    final repository = _accounts?.repository;
    final editor = _settingsController;
    if (repository?.document != null &&
        editor != null &&
        !editor.isDirty &&
        !editor.isBusy &&
        repository!.snapshot != _legacySettingsSnapshot) {
      _settingsController = AccountSettingsController(repository);
      _legacySettingsSnapshot = repository.snapshot;
    }
    _legacyUndo!.observe();
    _router.refresh();
  }

  void _undoChanged() {
    if (mounted) _router.refresh();
  }

  void _observeSessionUndo() {
    final session = widget.operations, undo = _undo, before = _undoSnapshot;
    if (session == null ||
        undo == null ||
        before == null ||
        session.busy ||
        undo.busy ||
        undo.needsReadback ||
        _undoInProgress) {
      return;
    }
    final after = session.snapshot;
    if (after.fence == before.fence &&
        after.revision == before.revision &&
        after.writeToken == before.writeToken &&
        after.payload == before.payload) {
      return;
    }
    final codec = const PortableJournalCodec();
    final old = codec.decodeState(before.payload),
        next = codec.decodeState(after.payload);
    final added = next.receipts
        .where(
          (r) => !old.receipts.any(
            (a) => a.identity.operationId == r.identity.operationId,
          ),
        )
        .toList();
    final FinancialUndoAdapter adapter;
    if (added.length == 1) {
      final identity = added.single.identity;
      final intent = (jsonDecode(identity.canonicalPayloadIdentity) as Map)
          .cast<String, Object?>();
      if (intent['commandType'] == 'supplier_opening_amendment' &&
          added.single.status == DurableCommandStatus.committed) {
        // Opening revisions retain immutable financial proof and require a
        // reasoned revision through the opening editor. They are a deliberate
        // quick-undo boundary, including for supplier creation with an opening.
        undo.reset();
        _undoSnapshot = after;
        return;
      }
      if ([
        'additional_debt_create',
        'additional_debt_edit',
        'additional_debt_delete',
      ].contains(intent['commandType'])) {
        adapter = AdditionalDebtSessionUndoAdapter(
          controller: session.additionalDebts,
          identity: identity,
        );
      } else if (intent['commandType'] == 'day_date_correction') {
        adapter = DayDateSessionUndoAdapter(
          dates: session.dayDates,
          identity: identity,
        );
      } else if ([
        'record_remaining',
        'record_balance',
        'record_total',
      ].contains(intent['type'])) {
        adapter = DailyRegisterSessionUndoAdapter(
          register: session.dailyRegister,
          identity: identity,
        );
      } else if ([
        'purchase_invoice',
        'edit_purchase_invoice',
        'delete_purchase_invoice',
        'supplier_payment',
        'edit_supplier_payment',
        'delete_supplier_payment',
      ].contains(intent['commandType'])) {
        adapter = PartiesSessionUndoAdapter(
          parties: session.parties,
          identity: identity,
        );
      } else {
        adapter = SpendingSessionUndoAdapter(
          spending: session.spending,
          identity: identity,
        );
      }
    } else if (canonicalIdentity({
          'stock': old.account.toJson()['stockEntries'],
        }) !=
        canonicalIdentity({'stock': next.account.toJson()['stockEntries']})) {
      adapter = StockMovementSessionUndoAdapter(
        repository: session.metadataRepository,
        bridge: session.metadataBridge,
        reason: 'تراجع عن حركة المخزن السابقة',
      );
    } else {
      adapter = MetadataSessionUndoAdapter(
        repository: session.metadataRepository,
        bridge: session.metadataBridge,
      );
    }
    undo.registerTransition(before: before, after: after, adapter: adapter);
    _undoSnapshot = after;
  }

  void _dispatchSessionUndo() {
    final undo = _undo, session = widget.operations;
    if (undo == null || session == null) {
      final legacy = _legacyUndo;
      if (legacy == null) {
        _model.dispatchUndo();
        return;
      }
      if (!legacy.canUndo && !legacy.needsReadback) return;
      unawaited(() async {
        final result = await legacy.undo();
        _syncAccount();
        final context = _navigatorKey.currentContext;
        if (mounted && context != null && context.mounted) {
          showDakhlToast(
            context,
            result is CapabilitySuccess<void>
                ? 'تم التراجع مع حفظ السجل.'
                : 'تعذّر التراجع بأمان. بقيت السجلات والمدخلات.',
          );
        }
      }());
      return;
    }
    if (_undoInProgress || (!undo.canUndo && !undo.needsReadback)) return;
    unawaited(() async {
      _undoInProgress = true;
      try {
        final result = await undo.undo();
        if (result is CapabilitySuccess<void>) {
          await session.synchronize();
          _undoSnapshot = session.snapshot;
        }
        final context = _navigatorKey.currentContext;
        if (mounted && context != null && context.mounted) {
          showDakhlToast(
            context,
            result is CapabilitySuccess<void>
                ? 'تم التراجع مع حفظ سجل التغيير.'
                : 'تعذّر التراجع بأمان. بقي السجل؛ قد يحتاج التغيير إلى استعادة تصحيح مرتبطة أو إعادة تحقق.',
          );
        }
      } finally {
        _undoInProgress = false;
        if (mounted) _router.refresh();
      }
    }());
  }

  @override
  void didUpdateWidget(DakhlRestaurantApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.operations, widget.operations)) {
      throw StateError(
        'Recreate the app with a new key after portable account replacement.',
      );
    }
  }

  Future<bool> _confirmDiscard() async {
    final context = _navigatorKey.currentContext;
    return context != null && mounted ? showDakhlDiscardDialog(context) : false;
  }

  bool get _undoBlocksNavigation =>
      _undoInProgress ||
      (_undo?.busy ?? false) ||
      (_undo?.needsReadback ?? false) ||
      (_legacyUndo?.busy ?? false) ||
      (_legacyUndo?.needsReadback ?? false);

  bool get _canPopShell =>
      _model.routeId == ShellRoutes.sales &&
      !_undoBlocksNavigation &&
      !_salesPendingInput &&
      !_model.dirtyForm &&
      _model.shortcutDraft == null;

  bool _canStartIosBack() =>
      mounted &&
      _model.canNavigate &&
      !_model.busy &&
      !_mobileBackInProgress &&
      _model.routeId != ShellRoutes.sales &&
      !(_navigatorKey.currentState?.canPop() ?? true);

  Future<void> _mobileBack() async {
    if (!mounted || !_model.canNavigate || _mobileBackInProgress) return;
    _mobileBackInProgress = true;
    try {
      if (!await _confirmSalesNavigation()) return;
      if (_model.routeId != ShellRoutes.sales) {
        await _model.navigate(
          ShellRoutes.sales,
          confirmDiscard: _confirmDiscard,
        );
        return;
      }
      if (_model.dirtyForm || _model.shortcutDraft != null) {
        if (!await _confirmDiscard() || !mounted) return;
        _model.discardForm();
        _model.cancelShortcutEditing();
      }
      await SystemNavigator.pop();
    } finally {
      _mobileBackInProgress = false;
    }
  }

  Future<void> _transferFromDay(String date) async {
    final session = widget.operations;
    if (session == null) return;
    await showDailyTransferEditor(
      _navigatorKey.currentContext ?? context,
      controller: DailyTransferEditorController(
        spending: session.spending,
        date: date,
      ),
    );
    await session.synchronize();
  }

  Future<void> _editDailyRegister(DailyRegisterField field, String date) async {
    final session = widget.operations;
    if (session == null) return;
    final owner = session.dailyRegister;
    final day = owner.daySnapshot(date);
    final saved = owner.account.days[date] as Map<String, Object?>?;
    final initial = switch (field) {
      DailyRegisterField.remaining => day.remaining,
      DailyRegisterField.balance => day.recordedBalance,
      DailyRegisterField.total => day.total,
    };
    await showDailyRegisterEditor(
      _navigatorKey.currentContext ?? context,
      field: field,
      date: date,
      initialAmount: '${initial ?? BigInt.zero}',
      automatic: saved?['totalOverride'] == null,
      canClear: day.recordedBalance != null,
      needsReadback: () => owner.needsReadback,
      commit:
          ({
            required amount,
            required automatic,
            required clear,
            required reason,
          }) async {
            try {
              final units =
                  owner.needsReadback ||
                      clear ||
                      (field == DailyRegisterField.total && automatic)
                  ? null
                  : ExactIntegerPolicy(
                      maxAbs: BigInt.from(1000000000000),
                      maxSafeInteger: BigInt.parse('9007199254740991'),
                      signed: field == DailyRegisterField.balance,
                      positive: false,
                    ).parse(amount, normalizeDigits: true, allowGrouping: true);
              final result = owner.needsReadback
                  ? await owner.retry()
                  : switch (field) {
                      DailyRegisterField.remaining =>
                        await owner.recordRemaining(date: date, amount: units!),
                      DailyRegisterField.balance => await owner.recordBalance(
                        date: date,
                        amount: units,
                        reason: reason,
                      ),
                      DailyRegisterField.total => await owner.recordTotal(
                        date: date,
                        amount: units,
                        reason: reason,
                      ),
                    };
              if (result is DurableCommandSuccess ||
                  result is DurableCommandReplayed) {
                await session.synchronize();
                return const CapabilitySuccess<void>(null);
              }
              return CapabilityFailure<void>(
                (result as DurableCommandFailure).code,
                'Register change was not confirmed.',
              );
            } on Object {
              return const CapabilityFailure<void>(
                'invalid_register_input',
                'Enter a valid register amount.',
              );
            }
          },
    );
  }

  void _openSavedPayment(String paymentId) {
    final fence = _accounts?.fence;
    if (fence == null) return;
    unawaited(() async {
      if (!await _confirmSalesNavigation() ||
          !mounted ||
          _accounts?.fence != fence) {
        return;
      }
      _pendingPaymentId = paymentId;
      await _model.navigate('payments', confirmDiscard: _confirmDiscard);
      if (!mounted) return;
      if (_model.routeId != 'payments') _pendingPaymentId = null;
      _router.refresh();
    }());
  }

  void _openSavedSale(String saleId) {
    final fence = _accounts?.fence;
    if (fence == null) return;
    unawaited(() async {
      if (!await _confirmSalesNavigation() ||
          !mounted ||
          _accounts?.fence != fence) {
        return;
      }
      _pendingSaleId = saleId;
      await _model.navigate('sale-history', confirmDiscard: _confirmDiscard);
      if (!mounted) return;
      if (_model.routeId != 'sale-history') _pendingSaleId = null;
      _router.refresh();
    }());
  }

  Future<bool> _confirmSalesNavigation() async {
    if (_undoBlocksNavigation) {
      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) {
        showDakhlToast(context, 'أكمل التحقق من التراجع قبل مغادرة الصفحة.');
      }
      return false;
    }
    if (!_salesPendingInput) return true;
    if (_model.routeId == 'settings') {
      final portable = widget.operations?.settings;
      final local = _settingsController;
      if ((portable?.busy ?? local?.isBusy ?? false) ||
          (portable?.needsReadback ??
              local?.repository.hasUnknownWrite ??
              false)) {
        return false;
      }
    }
    if (!await _confirmDiscard() || !mounted) return false;
    if (_model.routeId == 'settings') {
      final portable = widget.operations?.settings;
      if (portable != null) {
        if (portable.busy || portable.needsReadback) return false;
        portable.discard();
      } else {
        final local = _settingsController;
        if (local != null) {
          if (local.isBusy || local.repository.hasUnknownWrite) return false;
          local.discard();
        }
      }
    }
    _salesPendingInput = false;
    return true;
  }

  void _navigate(String id) {
    unawaited(() async {
      if (id != _model.routeId && !await _confirmSalesNavigation()) return;
      await _model.navigate(id, confirmDiscard: _confirmDiscard);
    }());
  }

  void _syncRoute() {
    if (!mounted ||
        !_model.canNavigate ||
        _acceptingRouterIntent ||
        _syncQueued) {
      return;
    }
    if (_router.routeInformationProvider.value.uri.path ==
        '/${_model.routeId}') {
      return;
    }
    _syncQueued = true;
    scheduleMicrotask(() {
      _syncQueued = false;
      if (!mounted || _acceptingRouterIntent) return;
      _router.go('/${_model.routeId}');
    });
  }

  void _search() {
    unawaited(() async {
      if (!await _confirmSalesNavigation()) return;
      final result = await _model.navigate(
        ShellRoutes.sales,
        confirmDiscard: _confirmDiscard,
      );
      if (!mounted || result != ShellNavigationResult.changed) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }());
  }

  Future<void> _editShortcuts(BuildContext context) async {
    if (!_model.beginShortcutEditing()) return;
    final original = List<String>.of(_model.shortcuts);
    Future<bool> discardDraft() async {
      if (_model.busy) return false;
      final draft = _model.shortcutDraft;
      final changed =
          draft != null &&
          List.generate(6, (i) => i).any((i) => draft[i] != original[i]);
      if (changed && !await _confirmDiscard()) return false;
      _model.cancelShortcutEditing();
      return true;
    }

    await showDakhlDialog<void>(
      context: context,
      title: 'اختصارات الشريط العلوي',
      body: ListenableBuilder(
        listenable: Listenable.merge([
          _model,
          if (widget.operations != null) widget.operations!,
        ]),
        builder: (context, _) => DakhlShortcutEditor(
          choices: _model.shortcutDraft ?? _model.shortcuts,
          destinations: _destinations,
          onChanged: _model.setShortcut,
          busy: _model.busy,
          canSave: _model.canEditShortcuts,
          onRetry:
              _model.saveState == ShellSaveState.failed ||
                  _model.saveState == ShellSaveState.commitUnknown ||
                  _model.saveState == ShellSaveState.conflict
              ? () async {
                  final reread =
                      _model.bootstrapState ==
                          ShellBootstrapState.protectedReadFailure ||
                      _model.saveState == ShellSaveState.conflict;
                  if (reread) {
                    await _model.retryRead();
                    return;
                  }
                  await _model.retrySave();
                  if (context.mounted && _model.shortcutDraft == null) {
                    Navigator.of(context).pop();
                  }
                }
              : null,
          retryLabel:
              _model.bootstrapState ==
                      ShellBootstrapState.protectedReadFailure ||
                  _model.saveState == ShellSaveState.conflict
              ? 'إعادة قراءة الإعدادات'
              : 'إعادة المحاولة',
          errorMessage:
              _model.saveState == ShellSaveState.failed ||
                  _model.saveState == ShellSaveState.conflict ||
                  _model.saveState == ShellSaveState.commitUnknown
              ? _model.saveState == ShellSaveState.conflict
                    ? 'تغيّرت الإعدادات المحفوظة؛ أعد قراءتها ثم راجع اختياراتك قبل الحفظ.'
                    : 'تعذّر حفظ الاختصارات. بقيت اختياراتك؛ أعد المحاولة.'
              : null,
          onSave: () async {
            await _model.saveShortcuts();
            if (context.mounted && _model.shortcutDraft == null) {
              Navigator.of(context).pop();
            }
          },
          onCancel: () async {
            if (await discardDraft() && context.mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      actions: const [],
      canDismiss: discardDraft,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _model.removeListener(_syncRoute);
    widget.operations?.removeListener(_operationsChanged);
    _undo?.removeListener(_undoChanged);
    _undo?.dispose();
    _legacyUndo?.removeListener(_undoChanged);
    _legacyUndo?.dispose();
    _router.dispose();
    _accounts?.confirmAuthorityReload = null;
    _accounts?.removeListener(_syncAccount);
    _model.removeListener(_queueWorkspace);
    _model.dispose();
    _catalogViewModel?.dispose();
    _categoriesViewModel?.dispose();
    _salesViewModel?.dispose();
    if (widget.operations == null) _reportsViewModel?.dispose();
    _portableAccounts?.dispose();
    _partiesViewModel?.dispose();
    _reportDelivery.dispose();
    widget.closeSourceCollation?.call();
    final closeAccounts = widget.closeAccounts;
    if (closeAccounts != null) unawaited(closeAccounts());
    _searchFocus.dispose();
    final close = widget.closePreferences;
    if (close != null) {
      unawaited(
        close().catchError((Object _, StackTrace _) {
          debugPrint(
            '{"event":"preferences_close","level":"error","code":"close_failed"}',
          );
        }),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [shellViewModelProvider.overrideWithValue(_model)],
    child: MaterialApp.router(
      title: 'Dakhl_Restaurant Dev',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: DakhlTheme.light,
      routerConfig: _router,
    ),
  );
}

final _destinations = [
  for (final group in ShellRoutes.groupOrder)
    for (final item in ShellRoutes.destinations.where(
      (item) => item.group == group,
    ))
      DakhlDestination(
        id: item.id,
        label: item.label,
        group: item.group,
        navigationLabel: item.navigationLabel,
      ),
];

class _ShellFrame extends ConsumerWidget {
  const _ShellFrame({
    required this.child,
    required this.onNavigate,
    required this.onEditShortcuts,
    required this.onSearch,
    this.accounts,
    this.catalog,
    this.onUndo,
    this.operations,
    this.undo,
    this.legacyUndo,
    this.onRetryUndo,
  });
  final Widget child;
  final ValueChanged<String> onNavigate;
  final VoidCallback onEditShortcuts, onSearch;
  final VoidCallback? onUndo, onRetryUndo;
  final RestaurantOperationsSession? operations;
  final FinancialSessionUndoController? undo;
  final LegacySessionUndoController? legacyUndo;
  final AccountsViewModel? accounts;
  final CatalogViewModel? catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(shellViewModelProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([
        model,
        ?accounts,
        ?catalog,
        ?operations,
        ?undo,
        ?legacyUndo,
      ]),
      builder: (context, _) {
        final initializing =
            model.bootstrapState == ShellBootstrapState.initializing;
        final protected =
            model.bootstrapState == ShellBootstrapState.protectedReadFailure;
        final failed =
            protected ||
            model.saveState == ShellSaveState.failed ||
            model.saveState == ShellSaveState.conflict ||
            model.saveState == ShellSaveState.commitUnknown;
        final unsaved = model.hasUnsavedPreferences;
        final shellStatus = initializing
            ? 'جارٍ تحميل إعدادات العرض…'
            : protected
            ? 'تعذّرت قراءة الإعدادات؛ التنقل لهذه الجلسة فقط.'
            : model.saveState == ShellSaveState.saving
            ? 'جارٍ حفظ إعدادات العرض…'
            : model.saveState == ShellSaveState.conflict
            ? 'تغيّرت الإعدادات المحفوظة؛ أعد قراءتها قبل الحفظ.'
            : model.saveState == ShellSaveState.commitUnknown
            ? 'تعذّر تأكيد الحفظ؛ أعد التحقق.'
            : failed
            ? 'تعذّر الحفظ. بقيت تغييراتك؛ أعد المحاولة.'
            : unsaved
            ? 'تغييرات العرض لهذه الجلسة فقط؛ لم تُحفظ على جهازك.'
            : 'محفوظ على جهازك';
        final account = accounts;
        final session = operations;
        final undoPending =
            (undo?.needsReadback ?? false) ||
            (legacyUndo?.needsReadback ?? false);
        final operationPending =
            session != null &&
            (session.sales.checkoutPending ||
                session.sales.operations.needsReadback ||
                session.sales.draftNeedsReadback ||
                session.spending.needsReadback ||
                session.parties.needsReadback ||
                session.settings.needsReadback ||
                session.dailyRegister.needsReadback ||
                session.dayDates.needsReadback ||
                session.additionalDebts.needsReadback ||
                session.supplierOpenings.needsReadback ||
                session.metadataBridge.needsReadback);
        final operationBusy =
            (session?.busy ?? false) ||
            (undo?.busy ?? false) ||
            (legacyUndo?.busy ?? false);
        // Catalog writes share the repository without changing account-page state.
        final accountNeedsReadback = account?.needsWriteReadback ?? false;
        final accountProtected =
            account != null &&
            (accountNeedsReadback ||
                account.state == AccountsState.protected ||
                account.state == AccountsState.failed ||
                account.state == AccountsState.conflict ||
                account.state == AccountsState.commitUnknown);
        final status = undoPending || operationPending
            ? 'هناك عملية غير مؤكدة؛ أعد التحقق من العملية نفسها.'
            : operationBusy
            ? 'جارٍ حفظ العملية…'
            : accountNeedsReadback
            ? 'تعذّر تأكيد الحفظ؛ أعد التحقق.'
            : account == null
            ? shellStatus
            : account.state == AccountsState.saved &&
                  (failed || model.busy || unsaved)
            ? shellStatus
            : accountStatus(account);
        return Scaffold(
          body: SafeArea(
            child: DakhlShellView(
              routeId: model.routeId,
              shortcuts: model.shortcuts,
              destinations: _destinations,
              onNavigate: onNavigate,
              busy: model.busy || (accounts?.busy ?? false) || operationBusy,
              statusMessage: status,
              statusKind:
                  failed || accountProtected || undoPending || operationPending
                  ? DakhlStatusKind.error
                  : operationBusy ||
                        initializing ||
                        model.saveState == ShellSaveState.saving ||
                        accounts?.state == AccountsState.saving ||
                        accounts?.state == AccountsState.loading
                  ? DakhlStatusKind.saving
                  : unsaved
                  ? DakhlStatusKind.info
                  : DakhlStatusKind.saved,
              onRetry: undoPending
                  ? onRetryUndo
                  : operationPending
                  ? null
                  : accountProtected
                  ? () => unawaited(
                      accountNeedsReadback ||
                              account.state == AccountsState.commitUnknown
                          ? account.reconcile()
                          : account.state == AccountsState.protected
                          ? account.initialize()
                          : account.retry(),
                    )
                  : failed
                  ? () => unawaited(
                      protected || model.saveState == ShellSaveState.conflict
                          ? model.retryRead()
                          : model.retrySave(),
                    )
                  : null,
              onEditShortcuts: model.canEditShortcuts ? onEditShortcuts : null,
              onUndo: onUndo ?? () => model.dispatchUndo(),
              onSearch: onSearch,
              onCheckout: () => showDakhlToast(context, 'عرض تجريبي فقط'),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
