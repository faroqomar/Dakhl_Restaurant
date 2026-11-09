import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';

import '../catalog/catalog_formatters.dart';
import '../ui/components.dart';
import '../ui/dialogs.dart';
import 'return_proposal.dart';
import 'sales_history_view_model.dart';

Future<bool?> showSaleReturnDialog(
  BuildContext context,
  SalesHistoryViewModel model,
) {
  final key = GlobalKey<_SaleReturnFormState>();
  return showDakhlDialog<bool>(
    context: context,
    title: 'مرتجع فاتورة ${model.selected?['number'] ?? ''}',
    subtitle: 'رد نقدي من اليومي مع حفظ الفاتورة الأصلية.',
    body: _SaleReturnForm(key: key, model: model),
    actions: const [],
    canDismiss: () async => await key.currentState?.canDismiss() ?? true,
  );
}

class _SaleReturnForm extends StatefulWidget {
  const _SaleReturnForm({super.key, required this.model});
  final SalesHistoryViewModel model;
  @override
  State<_SaleReturnForm> createState() => _SaleReturnFormState();
}

class _SaleReturnFormState extends State<_SaleReturnForm> {
  final _quantities = <String, TextEditingController>{};
  final _restock = <String>{};
  final _reason = TextEditingController();
  late final TextEditingController _date;
  bool _confirmed = false, _dirty = false, _saving = false;
  String? _error;
  String get _today => CatalogFormatters.today().toString();
  @override
  void initState() {
    super.initState();
    _date = TextEditingController(text: _today);
    for (final line in widget.model.returnAvailability.where(
      (line) => line.remainingUnits > BigInt.zero,
    )) {
      _quantities[line.productId] = TextEditingController(text: '0');
    }
    widget.model.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _edited() {
    setState(() {
      _dirty = true;
      _confirmed = false;
      _error = null;
    });
  }

  List<ReturnLineRequest> _requests() => [
    for (final entry in _quantities.entries)
      if (CatalogFormatters.parseQuantity(
            entry.value.text.isEmpty ? '0' : entry.value.text,
          ) >
          BigInt.zero)
        ReturnLineRequest(
          productId: entry.key,
          quantityUnits: CatalogFormatters.parseQuantity(entry.value.text),
          restock: _restock.contains(entry.key),
        ),
  ];
  ReturnQuote? _quote() {
    final lines = _requests();
    return lines.isEmpty ? null : widget.model.quoteReturn(lines);
  }

  Future<bool> canDismiss() async {
    if (_saving || widget.model.pendingReturn) return false;
    if (!_dirty) return true;
    return await showDakhlDialog<bool>(
          context: context,
          title: 'إهمال التغييرات؟',
          body: const Text('المرتجع لم يُحفظ بعد؛ إغلاقه لا يغيّر الفاتورة.'),
          actions: [
            Builder(
              builder: (ctx) => DakhlButton(
                label: 'إهمال التغييرات',
                kind: DakhlButtonKind.danger,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ),
          ],
        ) ==
        true;
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.model.returnSale(
        date: _date.text,
        today: _today,
        reason: _reason.text,
        lines: widget.model.pendingReturn ? const [] : _requests(),
        cashConfirmed: _confirmed,
      );
      if (!mounted) return;
      if (result is CapabilitySuccess<void>) {
        _dirty = false;
        Navigator.of(context).pop(true);
      } else {
        setState(
          () => _error = _returnError(
            result is CapabilityFailure ? result.code : 'unavailable',
          ),
        );
      }
    } on Object {
      if (mounted) {
        setState(() => _error = 'تحقق من التاريخ والسبب والكميات قبل الحفظ.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _returnError(String? code) => switch (code) {
    'cash_confirmation_required' => 'أكد رد المبلغ الظاهر للزبون قبل الحفظ.',
    'cross_cutover_source_has_no_post_cutover_journal' =>
      'لا يوجد قيد أصلي مؤهل لهذه الفاتورة؛ لم يُسجّل مرتجع.',
    'cutover_gated' ||
    'return_unavailable' => 'تسجيل المرتجع غير متاح لهذا الحساب حالياً.',
    'commit_unknown' =>
      'تعذّر تأكيد الحفظ. أعد التحقق؛ لا تكرر رد النقد للزبون.',
    'stale_authority_fence' || 'account_lineage_mismatch' =>
      'تغيّرت الحسابات؛ أعد فتح الفاتورة من الحساب الحالي.',
    _ => 'تعذّر حفظ المرتجع؛ بقيت مدخلاتك. تحقق من الكميات والتاريخ والسبب.',
  };
  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final blocked = _saving || model.busy || model.pendingReturn;
    ReturnQuote? quote;
    String? previewError;
    try {
      quote = _quote();
    } on Object {
      previewError = 'تحقق من الكميات المتاحة؛ لا يمكن إرجاع أكثر من المباع.';
    }
    final validDate = model.validReturnDate(_date.text, _today);
    final canSubmit =
        model.pendingReturn ||
        (quote != null &&
            previewError == null &&
            _confirmed &&
            _reason.text.trim().isNotEmpty &&
            validDate &&
            model.canReturn);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'اختار الكمية المرتجعة. المبلغ محسوب بسعر البيع وبعد حصة الخصم؛ الفاتورة الأصلية تبقى محفوظة.',
        ),
        for (final line in model.returnAvailability.where(
          (line) => _quantities.containsKey(line.productId),
        )) ...[
          const SizedBox(height: 16),
          Text(line.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            'متاح للإرجاع ${CatalogFormatters.formatQuantity(line.remainingUnits)} ${line.unit}',
          ),
          DakhlField(
            label: 'كمية ${line.name}',
            controller: _quantities[line.productId],
            enabled: !blocked,
            kind: DakhlFieldKind.quantity,
            onChanged: (_) => _edited(),
          ),
          Row(
            children: [
              Checkbox(
                value: _restock.contains(line.productId),
                onChanged: blocked || !line.tracked
                    ? null
                    : (value) {
                        if (value == true) {
                          _restock.add(line.productId);
                        } else {
                          _restock.remove(line.productId);
                        }
                        _edited();
                      },
              ),
              Expanded(
                child: Text(
                  line.tracked ? 'إعادة للمخزن' : 'إعادة للمخزن · غير متتبّع',
                ),
              ),
            ],
          ),
          const Divider(),
        ],
        DakhlField(
          label: 'تاريخ المرتجع',
          controller: _date,
          enabled: !blocked,
          onChanged: (_) => _edited(),
          errorText: validDate
              ? null
              : 'اختر تاريخاً من تاريخ البيع حتى اليوم.',
        ),
        DakhlField(
          label: 'سبب المرتجع',
          controller: _reason,
          enabled: !blocked,
          maxLines: 2,
          onChanged: (_) => _edited(),
        ),
        Semantics(
          liveRegion: true,
          child: DakhlStatus(
            message:
                previewError ??
                (quote == null
                    ? 'حدد كمية حتى يظهر المبلغ.'
                    : 'المبلغ المطلوب رده: ${CatalogFormatters.formatPrice(quote.amount.toInt())} د.ع'),
          ),
        ),
        const Text('الرد من نقد اليومي بتاريخ المرتجع، ولا يخصم من القاصة.'),
        Row(
          children: [
            Checkbox(
              key: const ValueKey('return-cash-confirmation'),
              value: _confirmed,
              onChanged: blocked || quote == null || previewError != null
                  ? null
                  : (value) => setState(() {
                      _confirmed = value ?? false;
                      _dirty = true;
                    }),
            ),
            const Expanded(
              child: Text('أؤكد رد المبلغ الظاهر للزبون من نقد اليومي'),
            ),
          ],
        ),
        if (_error != null)
          DakhlStatus(message: _error!, kind: DakhlStatusKind.error),
        if (model.operations == null)
          const Text('تسجيل المرتجع غير متاح لهذا الحساب حالياً.'),
        const SizedBox(height: 16),
        DakhlButton(
          label: model.pendingReturn
              ? 'إعادة التحقق من المرتجع'
              : 'تسجيل المرتجع ورد المبلغ',
          kind: DakhlButtonKind.primary,
          busy: _saving,
          onPressed: _saving || model.busy || !canSubmit ? null : _submit,
        ),
      ],
    );
  }

  @override
  void dispose() {
    widget.model.removeListener(_changed);
    for (final controller in _quantities.values) {
      controller.dispose();
    }
    _date.dispose();
    _reason.dispose();
    super.dispose();
  }
}
