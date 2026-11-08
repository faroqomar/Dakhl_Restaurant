import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'components.dart';
import 'icons.dart';
import 'theme.dart';

@immutable
class DakhlDestination {
  const DakhlDestination({
    required this.id,
    required this.label,
    required this.group,
    this.navigationLabel,
  });
  final String id, label, group;
  final String? navigationLabel;
}

/// Presentation shell; navigation, persistence and dirty decisions stay outside.
class DakhlShellView extends StatefulWidget {
  const DakhlShellView({
    super.key,
    required this.routeId,
    required this.shortcuts,
    required this.destinations,
    required this.onNavigate,
    required this.child,
    this.busy = false,
    this.statusMessage = 'محفوظ على جهازك',
    this.statusKind = DakhlStatusKind.saved,
    this.onRetry,
    this.onEditShortcuts,
    this.onUndo,
    this.onSearch,
    this.onCheckout,
  });
  final String routeId;
  final List<String> shortcuts;
  final List<DakhlDestination> destinations;
  final ValueChanged<String> onNavigate;
  final Widget child;
  final bool busy;
  final String statusMessage;
  final DakhlStatusKind statusKind;
  final VoidCallback? onRetry, onEditShortcuts, onUndo, onSearch, onCheckout;
  @override
  State<DakhlShellView> createState() => _DakhlShellViewState();
}

class _DakhlShellViewState extends State<DakhlShellView> {
  final _menuFocus = FocusNode(debugLabel: 'main-menu-opener');
  bool _menuOpen = false;
  @override
  void dispose() {
    _menuFocus.dispose();
    super.dispose();
  }

  DakhlDestination? _destination(String id) {
    for (final d in widget.destinations) {
      if (d.id == id) return d;
    }
    return null;
  }

  Future<void> _openMenu() async {
    if (_menuOpen || widget.busy) return;
    _menuOpen = true;
    final id = await showDialog<String>(
      context: context,
      barrierColor: const Color(0x570F1F17),
      barrierLabel: 'إغلاق القائمة',
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      builder: (context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).pop(),
        },
        child: SafeArea(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: Padding(
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width <= 760 ? 12 : 18,
              ),
              child: Material(
                color: DakhlTokens.paper,
                borderRadius: BorderRadius.circular(14),
                elevation: 4,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 310,
                    maxHeight: MediaQuery.sizeOf(context).height - 40,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const _DakhlBrandMark(),
                                  const SizedBox(width: 16),
                                  Semantics(
                                    namesRoute: true,
                                    child: Text(
                                      'دفتر',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(fontSize: 29),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DakhlIconButton(
                              label: 'إغلاق القائمة',
                              icon: DakhlIconKind.menu,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 8, bottom: 14),
                          child: Text(
                            'حسابات المطعم',
                            style: TextStyle(
                              fontSize: 14,
                              color: DakhlTokens.muted,
                            ),
                          ),
                        ),
                        for (final group
                            in widget.destinations
                                .map((e) => e.group)
                                .toSet()) ...[
                          const Divider(),
                          Semantics(
                            header: true,
                            child: Text(
                              group,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          for (final d in widget.destinations.where(
                            (e) => e.group == group,
                          ))
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Semantics(
                                selected: widget.routeId == d.id,
                                child: DakhlButton(
                                  label: d.navigationLabel ?? d.label,
                                  icon: _routeIcon(d.id),
                                  alignment: AlignmentDirectional.centerStart,
                                  kind: widget.routeId == d.id
                                      ? DakhlButtonKind.primary
                                      : DakhlButtonKind.quiet,
                                  onPressed: () =>
                                      Navigator.of(context).pop(d.id),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _menuOpen = false;
    if (!mounted) return;
    _menuFocus.requestFocus();
    if (id != null) widget.onNavigate(id);
  }

  bool get _textOwnsFocus {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    return focusContext?.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _menuOpen) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (_textOwnsFocus || widget.onUndo == null) {
        return KeyEventResult.ignored;
      }
      widget.onUndo!();
      return KeyEventResult.handled;
    }
    if (_textOwnsFocus) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.keyK &&
        widget.onSearch != null) {
      widget.onSearch!();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        widget.onCheckout != null) {
      widget.onCheckout!();
      return KeyEventResult.handled;
    }
    final digit = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
    ].indexOf(event.logicalKey);
    if (digit >= 0 && digit < widget.shortcuts.length && !widget.busy) {
      final id = widget.shortcuts[digit];
      if (_destination(id) != null) {
        widget.onNavigate(id);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: _handleKey,
    child: LayoutBuilder(
      builder: (context, c) {
        final gutter = DakhlTokens.gutter(c.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: c.maxHeight * .4),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 14, gutter, 14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DakhlIconButton(
                        label: 'القائمة الرئيسية',
                        icon: DakhlIconKind.menu,
                        focusNode: _menuFocus,
                        onPressed: widget.busy ? null : _openMenu,
                      ),
                      const Text(
                        'وصول سريع',
                        style: TextStyle(color: DakhlTokens.muted),
                      ),
                      for (var i = 0; i < widget.shortcuts.length && i < 6; i++)
                        if (_destination(widget.shortcuts[i]) case final d?)
                          Semantics(
                            selected: widget.routeId == d.id,
                            child: DakhlButton(
                              label: d.label,
                              shortcutHint: c.maxWidth > 760
                                  ? '⌘${i + 1}'
                                  : null,
                              kind: widget.routeId == d.id
                                  ? DakhlButtonKind.primary
                                  : DakhlButtonKind.secondary,
                              onPressed: widget.busy
                                  ? null
                                  : () => widget.onNavigate(d.id),
                            ),
                          ),
                      if (widget.onEditShortcuts != null)
                        DakhlIconButton(
                          label: 'تخصيص الاختصارات',
                          icon: DakhlIconKind.settings,
                          onPressed: widget.busy
                              ? null
                              : widget.onEditShortcuts,
                        ),
                      if (widget.onUndo != null)
                        DakhlIconButton(
                          label: 'تراجع',
                          icon: DakhlIconKind.undo,
                          onPressed: widget.busy ? null : widget.onUndo,
                        ),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          widget.statusMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: widget.statusKind == DakhlStatusKind.error
                                ? DakhlTokens.red
                                : DakhlTokens.muted,
                          ),
                        ),
                      ),
                      if (widget.onRetry != null)
                        DakhlButton(
                          label: 'إعادة المحاولة',
                          onPressed: widget.busy ? null : widget.onRetry,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: const Divider(height: 1),
            ),
            Expanded(child: widget.child),
          ],
        );
      },
    ),
  );
}

class DakhlShortcutEditor extends StatelessWidget {
  const DakhlShortcutEditor({
    super.key,
    required this.choices,
    required this.destinations,
    required this.onChanged,
    required this.onSave,
    required this.onCancel,
    this.busy = false,
    this.errorMessage,
    this.onRetry,
    this.retryLabel = 'إعادة المحاولة',
    this.canSave = true,
  });
  final List<String> choices;
  final List<DakhlDestination> destinations;
  final void Function(int slot, String id) onChanged;
  final VoidCallback onSave, onCancel;
  final bool busy;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool canSave;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < 6; i++)
        DakhlSelect<String>(
          label: 'الاختصار ${i + 1}',
          value:
              i < choices.length &&
                  (choices[i].isEmpty ||
                      destinations.any((d) => d.id == choices[i]))
              ? choices[i]
              : '',
          enabled: !busy,
          items: [
            const DropdownMenuItem(value: '', child: Text('بدون اختصار')),
            for (final d in destinations)
              DropdownMenuItem(value: d.id, child: Text(d.label)),
          ],
          onChanged: (value) => onChanged(i, value ?? ''),
        ),
      if (errorMessage != null)
        DakhlStatus(message: errorMessage!, kind: DakhlStatusKind.error),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          DakhlButton(
            label: 'حفظ الاختصارات',
            busy: busy,
            onPressed: canSave ? onSave : null,
            kind: DakhlButtonKind.primary,
          ),
          if (onRetry != null)
            DakhlButton(label: retryLabel, onPressed: busy ? null : onRetry),
          DakhlButton(label: 'إلغاء', onPressed: busy ? null : onCancel),
        ],
      ),
    ],
  );
}

DakhlIconKind _routeIcon(String id) => switch (id) {
  'sales' || 'materials' || 'categories' => DakhlIconKind.grid,
  'inventory' || 'suppliers' => DakhlIconKind.supplier,
  'payments' => DakhlIconKind.transfer,
  'cash' => DakhlIconKind.wallet,
  'settings' => DakhlIconKind.settings,
  _ => DakhlIconKind.ledger,
};

/// Frozen sidebar brand geometry; decoration is excluded from semantics.
class _DakhlBrandMark extends StatelessWidget {
  const _DakhlBrandMark();
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 42,
      height: 46,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DakhlTokens.green,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ColoredBox(color: DakhlTokens.lime, child: SizedBox(height: 1)),
          const SizedBox(height: 7),
          const ColoredBox(color: DakhlTokens.lime, child: SizedBox(height: 1)),
          const SizedBox(height: 7),
          FractionallySizedBox(
            widthFactor: .7,
            alignment: AlignmentDirectional.centerEnd,
            child: const ColoredBox(
              color: DakhlTokens.lime,
              child: SizedBox(height: 1),
            ),
          ),
        ],
      ),
    ),
  );
}
