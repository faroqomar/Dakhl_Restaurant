import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';

import '../catalog/catalog_formatters.dart';
import '../ui/dakhl_ui.dart';
import 'day_date_correction_controller.dart';
import 'day_date_correction_commands.dart';

Future<void> showDayDateEditor(
  BuildContext context, {
  required DayDateCorrectionController controller,
  required String initialDate,
  required Future<void> Function() onApplied,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _DayDateEditor(
    controller: controller,
    initialDate: initialDate,
    onApplied: onApplied,
  ),
);

class _DayDateEditor extends StatefulWidget {
  const _DayDateEditor({
    required this.controller,
    required this.initialDate,
    required this.onApplied,
  });
  final DayDateCorrectionController controller;
  final String initialDate;
  final Future<void> Function() onApplied;
  @override
  State<_DayDateEditor> createState() => _DayDateEditorState();
}

class _DayDateEditorState extends State<_DayDateEditor> {
  late final _from = TextEditingController(text: widget.initialDate);
  late final _end = TextEditingController(text: widget.initialDate);
  late final _to = TextEditingController(text: widget.initialDate);
  final _reason = TextEditingController();
  bool _range = false, _busy = false, _dirty = false;
  String? _error;
  DayDateCorrectionCommand? _captured;
  bool get _pending => widget.controller.needsReadback;
  Map<String, String> get _mapping => widget.controller
      .preview(
        from: _from.text.trim(),
        to: _to.text.trim(),
        end: _range ? _end.text.trim() : null,
      )
      .mapping;
  Future<void> _close() async {
    if (_busy || _pending) return;
    if (!_dirty || await showDakhlDiscardDialog(context)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!_pending) {
        _captured = widget.controller.capture(
          operationId: CatalogFormatters.generateId('day-date'),
          from: _from.text.trim(),
          to: _to.text.trim(),
          end: _range ? _end.text.trim() : null,
          reason: _reason.text.trim(),
          recordedAt: CatalogFormatters.currentIsoTimestamp(),
        );
      }
      final result = _pending
          ? await widget.controller.retry()
          : await widget.controller.submit(_captured!);
      if (result is DurableCommandSuccess || result is DurableCommandReplayed) {
        await widget.onApplied();
        if (mounted) Navigator.of(context).pop();
      } else if (mounted) {
        setState(
          () => _error = 'تعذّر تأكيد تصحيح التاريخ. بقيت المدخلات؛ لا يمكن نقل سجل مالي بلا قيده الأصلي أو دمج يومين مسجّلين.',
        );
      }
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'راجع التواريخ وسبب التصحيح. يجب اختيار يوم مسجّل وتاريخ جديد خالٍ من التعارض.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _from.dispose();
    _end.dispose();
    _to.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_busy && !_pending;
    Map<String, String>? mapping;
    try {
      mapping = _mapping;
    } on Object {
      /* Invalid draft stays editable. */
    }
    void changed() => setState(() {
      _dirty = true;
      _error = null;
    });
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: DakhlDialog(
        title: 'تصحيح تاريخ اليوم',
        subtitle: 'نقل سجل يوم أو فترة بالتواريخ مع حفظ أثر التصحيح.',
        onClose: enabled ? _close : null,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _from,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'اليوم الأصلي · YYYY-MM-DD',
              ),
              onChanged: (_) => changed(),
            ),
            CheckboxListTile(
              title: const Text('تصحيح فترة أيام'),
              value: _range,
              onChanged: enabled
                  ? (value) {
                      _range = value ?? false;
                      changed();
                    }
                  : null,
            ),
            if (_range)
              TextField(
                controller: _end,
                enabled: enabled,
                decoration: const InputDecoration(
                  labelText: 'نهاية الفترة · YYYY-MM-DD',
                ),
                onChanged: (_) => changed(),
              ),
            TextField(
              controller: _to,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'التاريخ الجديد لأول يوم · YYYY-MM-DD',
              ),
              onChanged: (_) => changed(),
            ),
            const SizedBox(height: 12),
            if (mapping != null) ...[
              const Text('معاينة نقل الأيام'),
              for (final entry in mapping.entries.take(20))
                Text(
                  '${entry.key} ← ${entry.value}',
                  textDirection: TextDirection.ltr,
                ),
              if (mapping.length > 20)
                Text('ومعها ${mapping.length - 20} يوم ضمن الفترة.'),
            ] else
              const Text('اختر يوماً مسجّلاً وتاريخاً جديداً لعرض المعاينة.'),
            TextField(
              controller: _reason,
              enabled: enabled,
              decoration: const InputDecoration(labelText: 'سبب تصحيح التاريخ'),
              onChanged: (_) => changed(),
            ),
            const SizedBox(height: 12),
            const Text(
              'يشمل سجل اليوم ومصاريفه والتسديدات والتحويلات والحركات المباشرة المؤهلة. تبقى تواريخ المبيعات والفواتير المستقلة كما سُجّلت.',
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: enabled ? _close : null,
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: _busy || (!_pending && mapping == null) ? null : _save,
            child: Text(_pending ? 'إعادة التحقق' : 'تأكيد تصحيح التاريخ'),
          ),
        ],
      ),
    );
  }
}
