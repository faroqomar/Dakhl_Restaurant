import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';

import '../ui/dakhl_ui.dart';

enum DailyRegisterField { remaining, balance, total }

typedef DailyRegisterCommit = Future<CapabilityResult<void>> Function({
  required String amount,
  required bool automatic,
  required bool clear,
  required String reason,
});
Future<void> showDailyRegisterEditor(
  BuildContext context, {
  required DailyRegisterField field,
  required String date,
  required String initialAmount,
  required DailyRegisterCommit commit,
  required bool Function() needsReadback,
  bool automatic = false,
  bool canClear = false,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _DailyRegisterEditor(
    field: field,
    date: date,
    initialAmount: initialAmount,
    commit: commit,
    needsReadback: needsReadback,
    automatic: automatic,
    canClear: canClear,
  ),
);

class _DailyRegisterEditor extends StatefulWidget {
  const _DailyRegisterEditor({
    required this.field,
    required this.date,
    required this.initialAmount,
    required this.commit,
    required this.needsReadback,
    required this.automatic,
    required this.canClear,
  });
  final DailyRegisterField field;
  final String date, initialAmount;
  final DailyRegisterCommit commit;
  final bool Function() needsReadback;
  final bool automatic, canClear;
  @override
  State<_DailyRegisterEditor> createState() => _DailyRegisterEditorState();
}

class _DailyRegisterEditorState extends State<_DailyRegisterEditor> {
  late final _amount = TextEditingController(text: widget.initialAmount);
  final _reason = TextEditingController();
  late bool _automatic = widget.automatic;
  bool _working = false, _dirty = false;
  String? _error;
  bool get _pending => widget.needsReadback();
  String get _title => switch (widget.field) {
    DailyRegisterField.remaining => 'الرصيد المتبقي',
    DailyRegisterField.balance => 'الرصيد الكلي',
    DailyRegisterField.total => 'مجموع المصاريف',
  };
  Future<void> _close() async {
    if (_working || _pending) return;
    if (!_dirty || await showDakhlDiscardDialog(context)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _save({bool clear = false}) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final result = await widget.commit(
        amount: _amount.text,
        automatic: _automatic,
        clear: clear,
        reason: _reason.text,
      );
      if (!mounted) return;
      if (result is CapabilitySuccess<void>) {
        Navigator.of(context).pop();
        return;
      }
      setState(
        () => _error = _pending
            ? 'لم يتأكد الحفظ؛ أعد التحقق قبل أي تغيير.'
            : 'تعذّر الحفظ. راجع المبلغ وسبب التصحيح ثم أعد المحاولة.',
      );
    } on Object {
      if (mounted) setState(() => _error = 'تعذّر إكمال الحفظ. بقيت مدخلاتك.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_working && !_pending;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: DakhlDialog(
        title: _title,
        subtitle: 'سجل يوم ${widget.date}',
        onClose: enabled ? _close : null,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.field == DailyRegisterField.total)
              CheckboxListTile(
                title: const Text('اعتماد مجموع الخانات تلقائياً'),
                value: _automatic,
                onChanged: enabled
                    ? (value) => setState(() {
                        _automatic = value ?? false;
                        _dirty = true;
                      })
                    : null,
              ),
            TextField(
              controller: _amount,
              enabled:
                  enabled &&
                  !(widget.field == DailyRegisterField.total && _automatic),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: InputDecoration(
                labelText: widget.field == DailyRegisterField.remaining
                    ? 'المبلغ المتبقي · د.ع'
                    : widget.field == DailyRegisterField.total
                    ? 'المجموع اليدوي · د.ع'
                    : 'الرصيد الكلي لليومي · د.ع',
              ),
              onChanged: (_) => _dirty = true,
            ),
            const SizedBox(height: 16),
            if (widget.field != DailyRegisterField.remaining)
              TextField(
                controller: _reason,
                enabled: enabled,
                decoration: const InputDecoration(labelText: 'سبب التصحيح'),
                onChanged: (_) => _dirty = true,
              ),
            const SizedBox(height: 16),
            Text(switch (widget.field) {
              DailyRegisterField.remaining => 'سجّل الباقي الفعلي بعد المصاريف المسجّلة حالياً. التغييرات اللاحقة في المصاريف والمبيعات والتحويلات تعدّل الباقي تلقائياً.',
              DailyRegisterField.balance => 'يبقى الرصيد المسجّل ثابتاً بعد الإيداع، ولا يغيّر أي حساب آخر.',
              DailyRegisterField.total => 'المجموع اليدوي يبقى ثابتاً حتى تغيّره أو ترجع للحساب التلقائي.',
            }),
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
          if (widget.field == DailyRegisterField.balance && widget.canClear)
            TextButton(
              onPressed: enabled ? () => _save(clear: true) : null,
              child: const Text('إزالة الرصيد المسجّل'),
            ),
          FilledButton(
            onPressed: _working ? null : _save,
            child: Text(_pending ? 'إعادة التحقق' : 'حفظ التغيير'),
          ),
        ],
      ),
    );
  }
}
