import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../ui/dakhl_ui.dart';
import 'expense_editor_controller.dart';

Future<void> showExpenseEditor(
  BuildContext context, {
  required ExpenseEditorController controller,
  Future<String?> Function()? onAddCategory,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _ExpenseEditor(controller: controller, onAddCategory: onAddCategory),
);

class _ExpenseEditor extends StatefulWidget {
  const _ExpenseEditor({required this.controller, this.onAddCategory});
  final ExpenseEditorController controller;
  final Future<String?> Function()? onAddCategory;
  @override
  State<_ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends State<_ExpenseEditor> {
  ExpenseEditorController get model => widget.controller;
  late final _amount = TextEditingController(text: model.amount),
      _daily = TextEditingController(text: model.daily),
      _cash = TextEditingController(text: model.cash),
      _note = TextEditingController(text: model.note),
      _date = TextEditingController(text: model.date),
      _reason = TextEditingController();
  bool _working = false, _dirty = false;
  String? _error;
  Future<void> _close() async {
    if (_working || model.pending) return;
    if (!_dirty || await showDakhlDiscardDialog(context)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _save({bool delete = false}) async {
    if (_working) return;
    if (delete) {
      final confirmed = await showDakhlDialog<bool>(
        context: context,
        title: 'حذف المصروف؟',
        body: const Text(
          'سيُحذف المصروف من سجل اليوم. يبقى أثر التصحيح محفوظاً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف المصروف'),
          ),
        ],
      );
      if (confirmed != true || !mounted) return;
    }
    model.amount = _amount.text;
    model.daily = _daily.text;
    model.cash = _cash.text;
    model.date = _date.text;
    model.note = _note.text;
    model.reason = _reason.text;
    setState(() => _working = true);
    final result = await model.save(delete: delete);
    if (!mounted) return;
    if (result is CapabilitySuccess<void>) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _working = false;
      _error = model.pending
          ? 'لم يتأكد الحفظ؛ أعد التحقق بنفس العملية.'
          : 'تعذّر الحفظ. راجع التاريخ والمبلغ وتوزيع الدفع وسبب التصحيح.';
    });
  }

  @override
  void dispose() {
    for (final c in [_amount, _daily, _cash, _note, _date, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_working && !model.pending;
    void changed(String _) {
      _dirty = true;
    }

    Widget field(
      TextEditingController controller,
      String label, {
      bool money = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: money ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        onChanged: changed,
      ),
    );
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: DakhlDialog(
        title: model.original == null ? 'إضافة مصروف' : 'تعديل مصروف',
        onClose: enabled ? _close : null,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field(_date, 'التاريخ YYYY-MM-DD'),
            DropdownButtonFormField<String>(
              key: ValueKey(model.categoryId),
              initialValue: model.categoryId,
              decoration: const InputDecoration(labelText: 'الخانة'),
              items: [
                for (final c in model.categories)
                  DropdownMenuItem(
                    value: c['id']! as String,
                    child: Text(c['name']! as String),
                  ),
              ],
              onChanged: enabled
                  ? (value) {
                      if (value != null) {
                        setState(() {
                          model.categoryId = value;
                          _dirty = true;
                        });
                      }
                    }
                  : null,
            ),
            if (widget.onAddCategory != null)
              TextButton(
                onPressed: enabled
                    ? () async {
                        final id = await widget.onAddCategory!();
                        if (mounted && id != null) {
                          setState(() {
                            model.categoryId = id;
                            _dirty = true;
                          });
                        }
                      }
                    : null,
                child: const Text('إضافة خانة'),
              ),
            const SizedBox(height: 14),
            field(_amount, 'المبلغ · د.ع', money: true),
            DropdownButtonFormField<FundingSource>(
              initialValue: model.source,
              decoration: const InputDecoration(labelText: 'مصدر الدفع'),
              items: const [
                DropdownMenuItem(
                  value: FundingSource.daily,
                  child: Text('من الرصيد اليومي'),
                ),
                DropdownMenuItem(
                  value: FundingSource.cash,
                  child: Text('من القاصة'),
                ),
                DropdownMenuItem(
                  value: FundingSource.shared,
                  child: Text('مشترك'),
                ),
              ],
              onChanged: enabled
                  ? (value) {
                      if (value != null) {
                        setState(() {
                          model.source = value;
                          _dirty = true;
                        });
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 14),
            if (model.source == FundingSource.shared) ...[
              field(_daily, 'حصة اليومي · د.ع', money: true),
              field(_cash, 'حصة القاصة · د.ع', money: true),
            ],
            field(_note, 'ملاحظات اختيارية'),
            if (model.original != null) field(_reason, 'سبب التصحيح'),
            if (!model.editable)
              const Text(
                'التعديل المالي يحتاج قيداً أصلياً موثّقاً؛ لم تتغيّر البيانات.',
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
          if (model.original != null)
            TextButton(
              onPressed: enabled && model.editable
                  ? () => _save(delete: true)
                  : null,
              child: const Text('حذف المصروف'),
            ),
          FilledButton(
            onPressed: !_working && model.editable ? _save : null,
            child: Text(model.pending ? 'إعادة التحقق' : 'حفظ المصروف'),
          ),
        ],
      ),
    );
  }
}
