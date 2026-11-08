import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';

import '../ui/dakhl_ui.dart';
import 'daily_metadata_controller.dart';

Future<void> showChickenEditor(
  BuildContext context, {
  required DailyMetadataController controller,
  required String date,
  required int used,
  required int left,
  required bool Function() canWrite,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _ChickenEditor(
    controller: controller,
    date: date,
    used: used,
    left: left,
    canWrite: canWrite,
  ),
);

class _ChickenEditor extends StatefulWidget {
  const _ChickenEditor({
    required this.controller,
    required this.date,
    required this.used,
    required this.left,
    required this.canWrite,
  });
  final DailyMetadataController controller;
  final String date;
  final int used, left;
  final bool Function() canWrite;
  @override
  State<_ChickenEditor> createState() => _ChickenEditorState();
}

class _ChickenEditorState extends State<_ChickenEditor> {
  late final _used = TextEditingController(text: '${widget.used}');
  late final _left = TextEditingController(text: '${widget.left}');
  bool _busy = false, _dirty = false;
  String? _error;
  Future<void> _save() async {
    if (_busy || (!widget.controller.needsReadback && !widget.canWrite())) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = widget.controller.needsReadback
          ? await widget.controller.reconcile()
          : await widget.controller.saveChicken(
              date: widget.date,
              used: _used.text,
              left: _left.text,
            );
      if (!mounted) return;
      if (result is CapabilitySuccess<void>) {
        Navigator.of(context).pop();
        return;
      }
      setState(
        () => _error = widget.controller.needsReadback
            ? 'لم يتأكد الحفظ. أعد القراءة للتحقق قبل أي تعديل.'
            : 'تعذّر الحفظ. راجع الأعداد أو أعد فتح النافذة بعد تحديث الحساب.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    if (_busy || widget.controller.needsReadback) return;
    if (!_dirty || await showDakhlDiscardDialog(context)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _used.dispose();
    _left.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: DakhlDialog(
      title: 'تتبّع الدجاج',
      subtitle: 'أعداد يوم ${widget.date}',
      onClose: _busy || widget.controller.needsReadback ? null : _close,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _used,
            enabled: !_busy && !widget.controller.needsReadback,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الدجاج المصروف'),
            onChanged: (_) => _dirty = true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _left,
            enabled: !_busy && !widget.controller.needsReadback,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الدجاج المتبقي'),
            onChanged: (_) => _dirty = true,
          ),
          const SizedBox(height: 16),
          const Text(
            'الأعداد للتتبّع فقط وما تدخل بمجموع المصاريف. المتبقي يتسجل حسب العدد اللي تحدده.',
          ),
          if (_error != null) Text(_error!),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy || widget.controller.needsReadback ? null : _close,
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(
            widget.controller.needsReadback ? 'التحقق من الحفظ' : 'حفظ التغيير',
          ),
        ),
      ],
    ),
  );
}
