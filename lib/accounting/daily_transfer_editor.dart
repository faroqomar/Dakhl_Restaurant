import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';

import '../catalog/catalog_formatters.dart';
import '../ui/dakhl_ui.dart';
import 'daily_transfer_editor_controller.dart';

Future<void> showDailyTransferEditor(
  BuildContext context, {
  required DailyTransferEditorController controller,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _DailyTransferEditor(controller: controller),
);

class _DailyTransferEditor extends StatefulWidget {
  const _DailyTransferEditor({required this.controller});
  final DailyTransferEditorController controller;
  @override
  State<_DailyTransferEditor> createState() => _DailyTransferEditorState();
}

class _DailyTransferEditorState extends State<_DailyTransferEditor> {
  DailyTransferEditorController get model => widget.controller;
  late final _amount = TextEditingController(text: model.amount);
  final _reason = TextEditingController();
  bool _busy = false, _dirty = false;
  String? _error;
  Future<void> _close() async {
    if (_busy || model.pending) return;
    if (!_dirty || await showDakhlDiscardDialog(context)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _save({bool delete = false}) async {
    if (_busy) return;
    if (delete && !model.pending) {
      final confirmed = await showDakhlDialog<bool>(
        context: context,
        title: 'حذف إيداع الرصيد؟',
        body: const Text(
          'يرجع المبلغ للرصيد اليومي. يبقى أثر التصحيح محفوظاً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      );
      if (confirmed != true || !mounted) return;
    }
    model.amount = _amount.text;
    model.reason = _reason.text;
    setState(() => _busy = true);
    final result = await model.save(delete: delete);
    if (!mounted) return;
    if (result is CapabilitySuccess<void>) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = model.pending
          ? 'لم يتأكد الحفظ؛ أعد التحقق بنفس العملية.'
          : 'تعذّر الحفظ. راجع المبلغ المتاح وسبب التصحيح.';
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editable = !_busy && !model.pending && model.editable;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: DakhlDialog(
        title: model.original == null
            ? 'تحويل من رصيد اليوم للقاصة'
            : 'تعديل إيداع الرصيد',
        body: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('من رصيد يوم ${model.date}'),
              Text(
                'المتبقي المتاح من اليومي: ${model.available == null ? 'غير مسجل' : '${CatalogFormatters.formatPrice(model.available!.toInt())} د.ع'}',
              ),
              const Text('ينضاف للقاصة وينخصم من الرصيد المتبقي بعملية واحدة.'),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                enabled: editable,
                keyboardType: TextInputType.number,
                onChanged: (_) => _dirty = true,
                decoration: const InputDecoration(
                  labelText: 'مبلغ الإيداع · د.ع',
                ),
              ),
              if (model.original != null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _reason,
                  enabled: editable,
                  onChanged: (_) => _dirty = true,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'سبب التصحيح'),
                ),
              ],
              if (!model.editable)
                const Text('هذا السجل ما عنده قيد أصلي مؤهل للتصحيح.'),
              if (_error != null) Text(_error!, semanticsLabel: _error),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy || model.pending ? null : _close,
            child: const Text('إلغاء'),
          ),
          if (model.original != null)
            TextButton(
              onPressed: editable ? () => _save(delete: true) : null,
              child: const Text('حذف الإيداع'),
            ),
          FilledButton(
            onPressed: _busy || !model.editable ? null : _save,
            child: Text(
              model.pending
                  ? 'إعادة التحقق'
                  : model.original == null
                  ? 'تأكيد الإيداع'
                  : 'حفظ التعديل',
            ),
          ),
        ],
      ),
    );
  }
}
