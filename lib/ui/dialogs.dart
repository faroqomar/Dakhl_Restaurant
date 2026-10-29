import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'components.dart';
import 'icons.dart';
import 'theme.dart';

/// DialogRoute supplies a modal barrier, closed-loop traversal and focus return.
/// The same dismissal guard is used by Escape, native back, close and barrier tap.
Future<T?> showDakhlDialog<T>({
  required BuildContext context,
  required String title,
  required Widget body,
  required List<Widget> actions,
  bool wide = false,
  String? subtitle,
  Future<bool> Function()? canDismiss,
}) => showDialog<T>(
  context: context,
  barrierDismissible: false,
  barrierLabel: 'إغلاق النافذة',
  barrierColor: const Color(0x570F1F17),
  traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  builder: (context) => _GuardedDialog<T>(
    title: title,
    subtitle: subtitle,
    body: body,
    actions: actions,
    wide: wide,
    canDismiss: canDismiss,
  ),
);

class _GuardedDialog<T> extends StatefulWidget {
  const _GuardedDialog({
    required this.title,
    required this.body,
    required this.actions,
    required this.wide,
    this.subtitle,
    this.canDismiss,
  });
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final bool wide;
  final Future<bool> Function()? canDismiss;
  @override
  State<_GuardedDialog<T>> createState() => _GuardedDialogState<T>();
}

class _GuardedDialogState<T> extends State<_GuardedDialog<T>> {
  bool _checking = false;
  Future<void> _dismiss() async {
    if (_checking) return;
    _checking = true;
    final allowed = await widget.canDismiss?.call() ?? true;
    _checking = false;
    if (allowed && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => PopScope<T>(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _dismiss();
    },
    child: CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _dismiss},
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: _dismiss,
            ),
          ),
          Center(
            child: DakhlDialog(
              title: widget.title,
              subtitle: widget.subtitle,
              body: widget.body,
              actions: widget.actions,
              wide: widget.wide,
              onClose: _dismiss,
            ),
          ),
        ],
      ),
    ),
  );
}

class DakhlDialog extends StatelessWidget {
  const DakhlDialog({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
    this.wide = false,
    this.subtitle,
    this.onClose,
  });
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final bool wide;
  final VoidCallback? onClose;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: EdgeInsets.symmetric(
      horizontal: MediaQuery.sizeOf(context).width < 620 ? 8 : 24,
      vertical: 16,
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: wide ? 1060 : 620),
      child: LayoutBuilder(
        builder: (context, c) {
          final stack = DakhlTokens.stacked(context, c.maxWidth);
          final header = Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        namesRoute: true,
                        header: true,
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (onClose != null)
                  DakhlIconButton(
                    label: 'إغلاق النافذة',
                    icon: DakhlIconKind.close,
                    onPressed: onClose,
                  ),
              ],
            ),
          );
          final footer = Padding(
            padding: const EdgeInsets.all(20),
            child: stack
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        actions[i],
                      ],
                    ],
                  )
                : Wrap(spacing: 12, runSpacing: 12, children: actions),
          );
          // Very short/zoomed viewports scroll the complete surface so no fixed
          // header/footer can consume all available keyboard-safe body height.
          if (c.maxHeight < 440 ||
              MediaQuery.textScalerOf(context).scale(16) >= 25.6) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const Divider(height: 1),
                  Padding(padding: const EdgeInsets.all(20), child: body),
                  const Divider(height: 1),
                  footer,
                ],
              ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: body,
                ),
              ),
              const Divider(height: 1),
              footer,
            ],
          );
        },
      ),
    ),
  );
}

Future<bool> showDakhlDiscardDialog(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'تغييرات غير محفوظة',
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      builder: (context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).pop(false),
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) Navigator.of(context).pop(false);
          },
          child: DakhlDialog(
            title: 'تغييرات غير محفوظة',
            body: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('هل تريد تجاهل التغييرات؟'),
                Text('إلغاء المغادرة يحتفظ بالمحتوى الحالي.'),
              ],
            ),
            actions: [
              DakhlButton(
                label: 'متابعة التعديل',
                autofocus: true,
                kind: DakhlButtonKind.primary,
                onPressed: () => Navigator.of(context).pop(false),
              ),
              DakhlButton(
                label: 'تجاهل التغييرات',
                kind: DakhlButtonKind.danger,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ),
    ) ??
    false;
