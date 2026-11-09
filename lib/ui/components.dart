import 'package:flutter/material.dart';

import 'theme.dart';
import 'icons.dart';

enum DakhlButtonKind { primary, secondary, danger, quiet }

class DakhlButton extends StatelessWidget {
  const DakhlButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = DakhlButtonKind.secondary,
    this.icon,
    this.busy = false,
    this.focusNode,
    this.autofocus = false,
    this.backgroundColor,
    this.shortcutHint,
    this.alignment = Alignment.center,
  });
  final String label;
  final VoidCallback? onPressed;
  final DakhlButtonKind kind;
  final DakhlIconKind? icon;
  final bool busy;
  final FocusNode? focusNode;
  final bool autofocus;
  final Color? backgroundColor;
  final String? shortcutHint;
  final AlignmentGeometry alignment;
  @override
  Widget build(BuildContext context) {
    final primary = kind == DakhlButtonKind.primary;
    final danger = kind == DakhlButtonKind.danger;
    final foreground = primary
        ? DakhlTokens.paper
        : danger
        ? DakhlTokens.red
        : DakhlTokens.ink;
    return Semantics(
      label: busy ? 'جارٍ $label' : null,
      liveRegion: busy,
      child: _FocusOutline(
        child: TextButton(
          focusNode: focusNode,
          autofocus: autofocus,
          onPressed: busy ? null : onPressed,
          style: ButtonStyle(
            alignment: alignment,
            minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(
                horizontal: label.isEmpty ? 10 : 17,
                vertical: 10,
              ),
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.disabled)
                  ? DakhlTokens.muted
                  : foreground,
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.disabled)
                  ? DakhlTokens.line
                  : primary
                  ? backgroundColor ?? DakhlTokens.green
                  : kind == DakhlButtonKind.quiet
                  ? Colors.transparent
                  : DakhlTokens.paper,
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
            side: WidgetStateProperty.resolveWith(
              (s) => BorderSide(
                color: s.contains(WidgetState.focused)
                    ? DakhlTokens.focus
                    : primary || kind == DakhlButtonKind.quiet
                    ? Colors.transparent
                    : DakhlTokens.line,
                width: s.contains(WidgetState.focused) ? 3 : 1,
              ),
            ),
            overlayColor: WidgetStatePropertyAll(
              DakhlTokens.ink.withValues(alpha: .06),
            ),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontFamily: 'Amiri', fontSize: 16, height: 1.5),
            ),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 9,
            children: [
              if (busy)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: 'جارٍ الحفظ',
                  ),
                )
              else if (icon != null)
                DakhlIcon(icon!, color: foreground),
              if (shortcutHint != null)
                Text(
                  shortcutHint!,
                  textDirection: TextDirection.ltr,
                  style: DakhlTokens.numberStyle.copyWith(
                    fontSize: 12,
                    color: foreground,
                  ),
                ),
              if (label.isNotEmpty) Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class DakhlIconButton extends StatelessWidget {
  const DakhlIconButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.focusNode,
  });
  final String label;
  final DakhlIconKind icon;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    excludeFromSemantics: true,
    child: Semantics(
      label: label,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: DakhlButton(
          label: '',
          icon: icon,
          onPressed: onPressed,
          focusNode: focusNode,
          kind: DakhlButtonKind.quiet,
        ),
      ),
    ),
  );
}

enum DakhlFieldKind { text, money, quantity, date }

/// Text presentation only: validation and values are supplied by the consumer.
class DakhlField extends StatefulWidget {
  const DakhlField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.value,
    this.onChanged,
    this.kind = DakhlFieldKind.text,
    this.errorText,
    this.hintText,
    this.helperText,
    this.enabled = true,
    this.readOnly = false,
    this.focusNode,
    this.autofocus = false,
    this.onTap,
    this.maxLines = 1,
    this.compact = false,
  }) : assert(value == null || controller == null),
       assert(value == null || initialValue == null);
  final String label;
  final TextEditingController? controller;
  final String? initialValue;

  /// Controlled presentation; unchanged supplied values preserve active edits.
  final String? value;
  final ValueChanged<String>? onChanged;
  final DakhlFieldKind kind;
  final String? errorText, hintText, helperText;
  final bool enabled, readOnly, autofocus;
  final FocusNode? focusNode;
  final VoidCallback? onTap;
  final int maxLines;
  final bool compact;
  @override
  State<DakhlField> createState() => _DakhlFieldState();
}

class _DakhlFieldState extends State<DakhlField> {
  late final TextEditingController _controlled;
  @override
  void initState() {
    super.initState();
    _controlled = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(DakhlField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != null &&
        oldWidget.value != widget.value &&
        _controlled.text != widget.value) {
      _controlled.value = TextEditingValue(
        text: widget.value!,
        selection: TextSelection.collapsed(offset: widget.value!.length),
      );
    }
  }

  @override
  void dispose() {
    _controlled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final compact = widget.compact;
    final kind = widget.kind;
    final numeric = kind != DakhlFieldKind.text;
    final effectiveController =
        widget.controller ?? (widget.value == null ? null : _controlled);
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: compact ? 12 : 14,
              height: compact ? 1.4 : 1.6,
            ),
          ),
          const SizedBox(height: 5),
          Semantics(
            label: label,
            child: TextFormField(
              controller: effectiveController,
              initialValue: effectiveController == null
                  ? widget.initialValue
                  : null,
              onChanged: widget.onChanged,
              enabled: widget.enabled,
              readOnly: widget.readOnly,
              onTap: widget.onTap,
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              maxLines: widget.maxLines,
              textDirection: numeric ? TextDirection.ltr : TextDirection.rtl,
              textAlign: TextAlign.right,
              keyboardType:
                  kind == DakhlFieldKind.money ||
                      kind == DakhlFieldKind.quantity
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : kind == DakhlFieldKind.date
                  ? TextInputType.datetime
                  : TextInputType.text,
              style: numeric
                  ? DakhlTokens.numberStyle.copyWith(
                      fontSize: 16,
                      color: DakhlTokens.ink,
                    )
                  : null,
              decoration: InputDecoration(
                hintText: widget.hintText,
                errorText: widget.errorText,
                helperText: widget.helperText,
                suffixIcon: kind == DakhlFieldKind.date
                    ? const ExcludeSemantics(
                        child: Icon(Icons.calendar_today_outlined, size: 18),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DakhlSelect<T> extends StatelessWidget {
  const DakhlSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    this.onChanged,
    this.errorText,
    this.enabled = true,
    this.compact = false,
  });
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? errorText;
  final bool enabled;
  final bool compact;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: compact ? 10 : 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: compact ? 12 : 14,
            height: compact ? 1.4 : 1.6,
          ),
        ),
        const SizedBox(height: 5),
        Semantics(
          label: label,
          child: DropdownButtonFormField<T>(
            key: ValueKey(Object.hash(label, value)),
            initialValue: value,
            items: items,
            onChanged: enabled ? onChanged : null,
            isExpanded: true,
            decoration: InputDecoration(errorText: errorText),
            style: Theme.of(context).textTheme.bodyMedium,
            borderRadius: BorderRadius.circular(7),
            itemHeight: null,
          ),
        ),
      ],
    ),
  );
}

class DakhlPanel extends StatelessWidget {
  const DakhlPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = DakhlTokens.panelRadius,
    this.borderColor = DakhlTokens.line,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color borderColor;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: DakhlTokens.paper,
      border: Border.all(color: borderColor),
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class DakhlBadge extends StatelessWidget {
  const DakhlBadge(this.label, {super.key, this.error = false});
  final String label;
  final bool error;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: DakhlTokens.soft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: error ? DakhlTokens.red : DakhlTokens.green),
      ),
    ),
  );
}

enum DakhlStatusKind { info, saving, saved, error }

class DakhlStatus extends StatelessWidget {
  const DakhlStatus({
    super.key,
    required this.message,
    this.kind = DakhlStatusKind.info,
    this.onRetry,
    this.onCancel,
  });
  final String message;
  final DakhlStatusKind kind;
  final VoidCallback? onRetry, onCancel;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    container: true,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DakhlTokens.soft,
        borderRadius: BorderRadius.circular(7),
        border: kind == DakhlStatusKind.error
            ? Border.all(color: DakhlTokens.red)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: TextStyle(
              color: kind == DakhlStatusKind.error
                  ? DakhlTokens.red
                  : DakhlTokens.green,
            ),
          ),
          if (onRetry != null || onCancel != null)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (onRetry != null)
                  DakhlButton(
                    label: 'إعادة المحاولة',
                    onPressed: onRetry,
                    kind: DakhlButtonKind.primary,
                  ),
                if (onCancel != null)
                  DakhlButton(label: 'إلغاء', onPressed: onCancel),
              ],
            ),
        ],
      ),
    ),
  );
}

void showDakhlToast(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Semantics(
        liveRegion: true,
        child: Text(message, style: const TextStyle(color: DakhlTokens.paper)),
      ),
      backgroundColor: error ? DakhlTokens.red : DakhlTokens.green,
      action: SnackBarAction(
        label: 'إغلاق',
        onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
      ),
    ),
  );
}

class DakhlEmptyState extends StatelessWidget {
  const DakhlEmptyState({
    super.key,
    this.title = 'لا توجد بيانات للعرض',
    this.message = 'ستظهر البيانات هنا عند توفرها.',
    this.onRetry,
  });
  final String title, message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => DakhlPanel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          DakhlButton(label: 'إعادة المحاولة', onPressed: onRetry),
        ],
      ],
    ),
  );
}

/// Static reduced-motion loading shell; no decorative perpetual animation.
class DakhlLoadingState extends StatelessWidget {
  const DakhlLoadingState({super.key, this.message = 'جارٍ التحميل...'});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: message,
    child: ExcludeSemantics(
      child: DakhlPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message),
            const SizedBox(height: 12),
            for (final factor in [1.0, .9, .8])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FractionallySizedBox(
                  widthFactor: factor,
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: DakhlTokens.soft,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class DakhlFilterBar extends StatelessWidget {
  const DakhlFilterBar({
    super.key,
    required this.children,
    this.actions = const [],
  });
  final List<Widget> children, actions;
  @override
  Widget build(BuildContext context) => DakhlPanel(
    child: LayoutBuilder(
      builder: (context, c) {
        final narrow = DakhlTokens.stacked(context, c.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final child in children)
                  SizedBox(width: narrow ? c.maxWidth : 220, child: child),
              ],
            ),
            if (actions.isNotEmpty)
              Wrap(spacing: 12, runSpacing: 8, children: actions),
          ],
        );
      },
    ),
  );
}

class DakhlPagination extends StatelessWidget {
  const DakhlPagination({
    super.key,
    required this.caption,
    this.onPrevious,
    this.onNext,
  });
  final String caption;
  final VoidCallback? onPrevious, onNext;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'صفحات النتائج',
    child: Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DakhlButton(label: 'السابق', onPressed: onPrevious),
        Text(caption),
        DakhlButton(label: 'التالي', onPressed: onNext),
      ],
    ),
  );
}

/// Rows are presentation strings; caller supplies ordering/filtering/pagination.
class DakhlTable extends StatelessWidget {
  const DakhlTable({
    super.key,
    required this.columns,
    required this.rows,
    this.numericColumns = const {},
  });
  final List<String> columns;
  final List<List<String>> rows;
  final Set<int> numericColumns;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (rows.isEmpty) return const DakhlEmptyState();
      if (DakhlTokens.stacked(context, c.maxWidth)) {
        return Column(
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DakhlPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < columns.length; i++)
                        Semantics(
                          label: columns[i],
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  columns[i],
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  i < row.length ? row[i] : '',
                                  textDirection: numericColumns.contains(i)
                                      ? TextDirection.ltr
                                      : null,
                                  style: numericColumns.contains(i)
                                      ? DakhlTokens.numberStyle
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: c.maxWidth),
          child: DataTable(
            headingRowColor: const WidgetStatePropertyAll(DakhlTokens.soft),
            columns: [
              for (final label in columns) DataColumn(label: Text(label)),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    for (var i = 0; i < columns.length; i++)
                      DataCell(
                        Text(
                          i < row.length ? row[i] : '',
                          textDirection: numericColumns.contains(i)
                              ? TextDirection.ltr
                              : null,
                          style: numericColumns.contains(i)
                              ? DakhlTokens.numberStyle
                              : null,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Paints the approved three-pixel focus outline outside filled buttons, with
/// a two-pixel gap so primary actions retain a distinct keyboard indicator.
class _FocusOutline extends StatefulWidget {
  const _FocusOutline({required this.child});
  final Widget child;
  @override
  State<_FocusOutline> createState() => _FocusOutlineState();
}

class _FocusOutlineState extends State<_FocusOutline> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (value) => setState(() => _focused = value),
    child: CustomPaint(
      foregroundPainter: _focused ? _FocusPainter() : null,
      child: widget.child,
    ),
  );
}

class _FocusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => canvas.drawRRect(
    RRect.fromRectAndRadius(
      (Offset.zero & size).inflate(3.5),
      const Radius.circular(12.5),
    ),
    Paint()
      ..color = DakhlTokens.focus
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3,
  );
  @override
  bool shouldRepaint(_FocusPainter oldDelegate) => false;
}

/// Controlled quantity presentation. Steps are intents; the consumer owns the
/// resulting value and validation. This widget performs no numeric calculation.
class DakhlQuantityControl extends StatefulWidget {
  const DakhlQuantityControl({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onStep,
    this.enabled = true,
    this.showLabel = true,
  });
  final String label, value;
  final ValueChanged<String> onChanged;
  final ValueChanged<int>? onStep;
  final bool enabled, showLabel;
  @override
  State<DakhlQuantityControl> createState() => _DakhlQuantityControlState();
}

class _DakhlQuantityControlState extends State<DakhlQuantityControl> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(DakhlQuantityControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _step(String label, String symbol, int step) => Semantics(
    label: label,
    button: true,
    enabled: widget.enabled && widget.onStep != null,
    onTap: widget.enabled && widget.onStep != null
        ? () => widget.onStep!(step)
        : null,
    child: ExcludeSemantics(
      child: DakhlButton(
        label: symbol,
        onPressed: widget.enabled && widget.onStep != null
            ? () => widget.onStep!(step)
            : null,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.showLabel) ...[
        Text(widget.label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 5),
      ],
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            _step('تقليل ${widget.label}', '−', -1),
            Expanded(
              child: Semantics(
                label: widget.label,
                child: TextFormField(
                  controller: _controller,
                  enabled: widget.enabled,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: DakhlTokens.numberStyle.copyWith(fontSize: 16),
                  onChanged: widget.onChanged,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),
            _step('زيادة ${widget.label}', '+', 1),
          ],
        ),
      ),
    ],
  );
}
