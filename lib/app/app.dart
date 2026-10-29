import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_application/madar_application.dart';

import '../shell/shell_routes.dart';
import '../shell/shell_view_model.dart';
import '../ui/dakhl_ui.dart';
import 'ios_shell_back_gesture.dart';

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
  });
  final LocalPreferencesStore preferencesStore;
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
  bool _syncQueued = false;
  bool _mobileBackInProgress = false;

  @override
  void initState() {
    super.initState();
    _model = ShellViewModel(store: widget.preferencesStore);
    _router = GoRouter(
      navigatorKey: _navigatorKey,
      initialLocation: '/sales',
      redirect: (context, state) async {
        final path = state.uri.path;
        final requested = ShellRoutes.normalizeRoute(
          path.startsWith('/') ? path.substring(1) : path,
        );
        if (!_model.canNavigate) return path == '/sales' ? null : '/sales';
        if (requested != _model.routeId) {
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
            listenable: _model,
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
                child: child,
              ),
            ),
          ),
          routes: [
            for (final destination in ShellRoutes.destinations)
              GoRoute(
                path: '/${destination.id}',
                builder: (context, state) => ListenableBuilder(
                  listenable: _model,
                  builder: (context, _) => PopScope<void>(
                    canPop: _canPopShell,
                    onPopInvokedWithResult: (didPop, _) {
                      if (!didPop) unawaited(_mobileBack());
                    },
                    child: IosShellBackGesture(
                      canStart: _canStartIosBack,
                      onBack: _mobileBack,
                      child: Phase01RouteSurface(
                        routeId: destination.id,
                        onCheckout: () =>
                            showDakhlToast(context, 'عرض تجريبي فقط'),
                        searchFocusNode: _searchFocus,
                        formDraft: _model.formDraft,
                        onFormChanged: _model.setFormDraft,
                        onFormDiscard: _model.discardForm,
                        ticketPresentation: _model.ticketPresentation,
                        onTicketChanged: (value) {
                          final previous = _model.ticketPresentation;
                          _model.registerSessionUndo(
                            () => _model.setTicketPresentation(previous),
                          );
                          _model.setTicketPresentation(value);
                        },
                      ),
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
        if (!_model.dirtyForm &&
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
    final initialization = _model.initialize();
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

  Future<bool> _confirmDiscard() async {
    final context = _navigatorKey.currentContext;
    return context != null && mounted ? showDakhlDiscardDialog(context) : false;
  }

  bool get _canPopShell =>
      _model.routeId == ShellRoutes.sales &&
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

  void _navigate(String id) {
    unawaited(_model.navigate(id, confirmDiscard: _confirmDiscard));
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
        listenable: _model,
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
    _router.dispose();
    _model.dispose();
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
  });
  final Widget child;
  final ValueChanged<String> onNavigate;
  final VoidCallback onEditShortcuts, onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(shellViewModelProvider);
    return ListenableBuilder(
      listenable: model,
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
        final status = initializing
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
        return Scaffold(
          body: SafeArea(
            child: DakhlShellView(
              routeId: model.routeId,
              shortcuts: model.shortcuts,
              destinations: _destinations,
              onNavigate: onNavigate,
              busy: model.busy,
              statusMessage: status,
              statusKind: failed
                  ? DakhlStatusKind.error
                  : initializing || model.saveState == ShellSaveState.saving
                  ? DakhlStatusKind.saving
                  : unsaved
                  ? DakhlStatusKind.info
                  : DakhlStatusKind.saved,
              onRetry: failed
                  ? () => unawaited(
                      protected || model.saveState == ShellSaveState.conflict
                          ? model.retryRead()
                          : model.retrySave(),
                    )
                  : null,
              onEditShortcuts: model.canEditShortcuts ? onEditShortcuts : null,
              onUndo: () => model.dispatchUndo(),
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
