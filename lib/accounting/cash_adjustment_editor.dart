import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../catalog/catalog_formatters.dart';
import '../ui/components.dart';
import '../ui/dialogs.dart';
import 'journal_command_host.dart';
import 'restaurant_journal_external_cash_commands.dart';
import 'restaurant_journal_mapper.dart';
import 'spending_operations_view_model.dart';

Future<bool?> showCashAdjustmentEditor(
  BuildContext context, {
  SpendingOperationsViewModel? model,
  Map<String, Object?>? source,
  String initialType = 'deposit',
  ValueChanged<bool>? onPendingInputChanged,
}) {
  final key = GlobalKey<_CashAdjustmentFormState>();
  return showDakhlDialog<bool>(
    context: context,
    title: source == null ? 'حركة مباشرة للقاصة' : 'تعديل حركة القاصة',
    subtitle: 'إيداع أو سحب مباشر بتاريخ وملاحظة.',
    body: _CashAdjustmentForm(
      key: key,
      model: model,
      source: source == null ? null : freezeMap(source),
      initialType: initialType,
      onDirty: onPendingInputChanged,
    ),
    actions: const [],
    canDismiss: () async => await key.currentState?.canDismiss() ?? true,
  );
}

class _CashAdjustmentForm extends StatefulWidget {
  const _CashAdjustmentForm({
    super.key,
    required this.model,
    required this.source,
    required this.initialType,
    this.onDirty,
  });
  final SpendingOperationsViewModel? model;
  final Map<String, Object?>? source;
  final String initialType;
  final ValueChanged<bool>? onDirty;
  @override
  State<_CashAdjustmentForm> createState() => _CashAdjustmentFormState();
}

class _CashAdjustmentFormState extends State<_CashAdjustmentForm> {
  late final TextEditingController _date, _amount, _note;
  final _reason = TextEditingController();
  late String _type;
  bool _busy = false, _dirty = false;
  String? _error;
  ExternalCashCommand? _captured;
  SpendingOperationsViewModel? get _model => widget.model;
  bool get _unknown => _captured != null && (_model?.needsReadback ?? false);
  bool get _blocked =>
      _busy ||
      _unknown ||
      (_model?.busy ?? false) ||
      (_model?.externallyBlocked ?? false) ||
      (_model?.needsReadback ?? false);
  bool get _mapped => _model?.externalCashMappingAccepted ?? false;
  bool get _eligible =>
      widget.source == null ||
      _model?.activeExternalCashPosting(widget.source!['id']! as String) !=
          null;
  @override
  void initState() {
    super.initState();
    final row = widget.source;
    _date = TextEditingController(
      text: row?['date'] as String? ?? CatalogFormatters.today().toString(),
    );
    _amount = TextEditingController(text: row?['amount']?.toString() ?? '');
    _note = TextEditingController(text: row?['note'] as String? ?? '');
    _type = row?['type'] as String? ?? widget.initialType;
    _model?.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _edit(String _) {
    setState(() {
      _dirty = true;
      _error = null;
    });
    widget.onDirty?.call(true);
  }

  BigInt _value() => ExactDecimal.parse(
    _amount.text.trim(),
    scale: 0,
    maxAbsUnits: RestaurantJournalPolicies.defaultLimit,
    positive: true,
    signed: false,
    normalizeDigits: true,
    allowGrouping: true,
    allowArabicDecimal: true,
    allowExponent: true,
  ).units;
  bool get _valid {
    try {
      _value();
      CatalogFormatters.parseDate(_date.text);
      return ['deposit', 'withdrawal'].contains(_type) &&
          (widget.source == null || _reason.text.trim().isNotEmpty);
    } on Object {
      return false;
    }
  }

  Future<bool> canDismiss() async {
    if (_busy || _unknown) return false;
    if (!_dirty) return true;
    final discard = await showDakhlDiscardDialog(context);
    if (discard) widget.onDirty?.call(false);
    return discard;
  }

  Future<void> _save({bool deleting = false}) async {
    final model = _model;
    if (model == null || _busy || !_mapped) return;
    if (deleting && !_unknown) {
      final confirmed = await showDakhlDialog<bool>(
        context: context,
        title: 'حذف حركة القاصة؟',
        body: const Text('يُحفظ سبب الحذف ويُعكس أثر الحركة الأصلية.'),
        actions: [
          Builder(
            builder: (ctx) => DakhlButton(
              label: 'حذف الحركة',
              kind: DakhlButtonKind.danger,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ),
        ],
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_captured == null) {
        final id =
            widget.source?['id'] as String? ??
            CatalogFormatters.generateId('transaction');
        final operation = CatalogFormatters.generateId('operation'),
            journal = CatalogFormatters.generateId('journal'),
            stamp = CatalogFormatters.currentIsoTimestamp();
        final source = widget.source;
        if (source == null) {
          _captured = model.createExternalCashIntent(
            operationId: operation,
            transactionId: id,
            journalId: journal,
            date: CatalogFormatters.parseDate(_date.text),
            amount: _value(),
            type: _type,
            note: _note.text,
            recordedAt: stamp,
          );
        } else {
          final target = model.activeExternalCashPosting(id);
          if (target == null) throw const FormatException('missing_original');
          final inverse = CatalogFormatters.generateId('inverse');
          _captured = deleting
              ? model.deleteExternalCashIntent(
                  operationId: operation,
                  transactionId: id,
                  inverseJournalId: inverse,
                  expectedActiveJournalId: target.journal.id,
                  expectedSource: source,
                  reason: _reason.text,
                  recordedAt: stamp,
                )
              : model.editExternalCashIntent(
                  operationId: operation,
                  transactionId: id,
                  journalId: journal,
                  inverseJournalId: inverse,
                  expectedActiveJournalId: target.journal.id,
                  expectedSource: source,
                  reason: _reason.text,
                  date: CatalogFormatters.parseDate(_date.text),
                  amount: _value(),
                  type: _type,
                  note: _note.text,
                  recordedAt: stamp,
                );
        }
      }
      final result = await model.submitExternalCash(_captured!);
      if (!mounted) return;
      if (result is DurableCommandSuccess || result is DurableCommandReplayed) {
        _dirty = false;
        widget.onDirty?.call(false);
        Navigator.of(context).pop(true);
      } else {
        if (!model.needsReadback) _captured = null;
        _error = model.needsReadback
            ? 'تعذّر تأكيد الحفظ. أعد التحقق من الحركة نفسها قبل أي محاولة أخرى.'
            : 'لم تُحفظ الحركة. تحقق من البيانات وأهلية الحركة الأصلية ثم أعد المحاولة.';
      }
    } on Object {
      _error = 'تعذّر إعداد الحركة. تحقق من التاريخ والمبلغ وسبب التصحيح.';
      if (!(model.needsReadback)) _captured = null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _model?.removeListener(_changed);
    _date.dispose();
    _amount.dispose();
    _note.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!_mapped)
        const DakhlStatus(
          message: 'الحفظ غير متاح حتى تحديد المعالجة المحاسبية المعتمدة لهذه الحركة.',
        ),
      if (widget.source != null && !_eligible)
        const DakhlStatus(
          message:
              'لا يوجد قيد أصلي مؤهل لتصحيح هذه الحركة. بياناتها محفوظة للعرض.',
        ),
      DakhlSelect<String>(
        label: 'الحركة',
        enabled: !_blocked,
        value: ['deposit', 'withdrawal'].contains(_type) ? _type : null,
        items: const [
          DropdownMenuItem(value: 'deposit', child: Text('إيداع')),
          DropdownMenuItem(value: 'withdrawal', child: Text('سحب')),
        ],
        onChanged: (v) {
          if (v != null) {
            _type = v;
            _edit(v);
          }
        },
      ),
      DakhlField(
        label: 'المبلغ · د.ع',
        controller: _amount,
        kind: DakhlFieldKind.money,
        enabled: !_blocked,
        onChanged: _edit,
      ),
      DakhlField(
        label: 'التاريخ',
        kind: DakhlFieldKind.date,
        controller: _date,
        enabled: !_blocked,
        onChanged: _edit,
      ),
      DakhlField(
        label: 'ملاحظة',
        controller: _note,
        enabled: !_blocked,
        onChanged: _edit,
        maxLines: 2,
      ),
      if (widget.source != null)
        DakhlField(
          label: 'سبب التصحيح',
          controller: _reason,
          enabled: !_blocked,
          onChanged: _edit,
        ),
      if (_error != null) DakhlStatus(message: _error!),
      DakhlButton(
        label: _unknown ? 'إعادة التحقق من الحركة' : 'حفظ الحركة',
        kind: DakhlButtonKind.primary,
        busy: _busy,
        onPressed:
            _busy ||
                !_mapped ||
                (_model?.externallyBlocked ?? false) ||
                (_model?.busy ?? false) ||
                (_unknown
                    ? false
                    : !(_model?.postingEnabled ?? false) ||
                          !_eligible ||
                          !_valid)
            ? null
            : () => _save(),
      ),
      if (widget.source != null)
        DakhlButton(
          label: 'حذف الحركة',
          kind: DakhlButtonKind.danger,
          onPressed:
              _blocked ||
                  !_mapped ||
                  !_eligible ||
                  !(_model?.postingEnabled ?? false) ||
                  _reason.text.trim().isEmpty
              ? null
              : () => _save(deleting: true),
        ),
    ],
  );
}
