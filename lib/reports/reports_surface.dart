import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart' show ExactMath;

import '../accounting/daily_cash_queries.dart';
import '../catalog/catalog_formatters.dart';
import '../ui/components.dart';
import '../ui/dialogs.dart';
import '../ui/theme.dart';
import 'restaurant_report.dart';
import 'reports_view_model.dart';
import 'saved_report_pdf_viewer.dart';

String _money(BigInt value) =>
    '${CatalogFormatters.formatPrice(value.toInt())} د.ع';
String _category(ReportsViewModel model, Object? id) =>
    model.account.categories
        .where((c) => c['id'] == id)
        .map((c) => c['name']! as String)
        .firstOrNull ??
    'خانة';

/// Approved statement filter/ranking/detail references. Filters stage locally;
/// generation always uses the applied saved-record query, never edited totals.
class ReportsSurface extends StatefulWidget {
  const ReportsSurface({
    super.key,
    required this.model,
    required this.selectedDate,
    this.onRecordRemaining,
    this.onTransfer,
    this.onPendingChanged,
  });
  final ReportsViewModel model;
  final String selectedDate;
  final ValueChanged<String>? onRecordRemaining, onTransfer;
  final ValueChanged<bool>? onPendingChanged;
  @override
  State<ReportsSurface> createState() => _ReportsSurfaceState();
}

class _ReportsSurfaceState extends State<ReportsSurface> {
  late final TextEditingController _from, _to;
  String _categoryId = '';
  SpendingSource _source = SpendingSource.all;
  String? _error;
  bool _staged = false;
  @override
  void initState() {
    super.initState();
    _from = TextEditingController(text: widget.model.from);
    _to = TextEditingController(text: widget.model.to);
    _categoryId = widget.model.categoryId;
    _source = widget.model.source;
  }

  void _stage() {
    setState(() {
      _staged = true;
    });
    widget.onPendingChanged?.call(true);
  }

  void _apply() {
    final result = widget.model.setFilter(
      from: _from.text.trim(),
      to: _to.text.trim(),
      categoryId: _categoryId,
      source: _source,
    );
    setState(() {
      _error = result is CapabilitySuccess<void>
          ? null
          : 'اختار فترة صحيحة للتقرير.';
      if (_error == null) _staged = false;
    });
    widget.onPendingChanged?.call(_staged);
  }

  void _preset(String kind) {
    final today = CatalogFormatters.today().toString();
    _from.text = kind == 'all'
        ? ''
        : kind == 'today'
        ? today
        : '${today.substring(0, 8)}01';
    _to.text = kind == 'all' ? '' : today;
    if (kind == 'all') {
      _categoryId = '';
      _source = SpendingSource.all;
    }
    _apply();
  }

  Future<void> _pick(TextEditingController input) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(input.text) ?? DateTime.now(),
      firstDate: DateTime(1000),
      lastDate: DateTime(9999),
    );
    if (date != null && mounted) {
      input.text =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      _stage();
    }
  }

  Widget _dateField(String label, TextEditingController input) => SizedBox(
    width: 205,
    child: TextField(
      controller: input,
      textDirection: TextDirection.ltr,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'YYYY-MM-DD',
        suffixIcon: IconButton(
          tooltip: 'اختيار التاريخ',
          icon: const Icon(Icons.calendar_today_outlined),
          onPressed: () => _pick(input),
        ),
      ),
      onChanged: (_) => _stage(),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final model = widget.model, statement = model.statement;
      final categories = model.account.categories;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 20,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'كشف الحساب',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const Text(
                      'راجع مصروفاتك خلال الفترة، واختار الخانة ومصدر الدفع لمعرفة أين يذهب المبلغ.',
                    ),
                  ],
                ),
                DakhlButton(
                  label: 'تصدير هذا العرض PDF',
                  onPressed: () => buildAndShowRestaurantReport(
                    context,
                    model.statementReport,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            DakhlPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'تصفية الكشف',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text('الترتيب يبين أعلى الخانات صرفاً ضمن اختياراتك.'),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _dateField('من تاريخ', _from),
                      _dateField('إلى تاريخ', _to),
                      SizedBox(
                        width: 205,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('category-$_categoryId'),
                          initialValue: _categoryId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'الخانة',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('كل الخانات'),
                            ),
                            for (final c in categories)
                              DropdownMenuItem(
                                value: c['id']! as String,
                                child: Text(c['name']! as String),
                              ),
                          ],
                          onChanged: (v) {
                            _categoryId = v!;
                            _stage();
                          },
                        ),
                      ),
                      SizedBox(
                        width: 205,
                        child: DropdownButtonFormField<SpendingSource>(
                          key: ValueKey('source-$_source'),
                          initialValue: _source,
                          decoration: const InputDecoration(
                            labelText: 'مصدر الدفع',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: SpendingSource.all,
                              child: Text('الكل'),
                            ),
                            DropdownMenuItem(
                              value: SpendingSource.daily,
                              child: Text('اليومي'),
                            ),
                            DropdownMenuItem(
                              value: SpendingSource.cash,
                              child: Text('القاصة'),
                            ),
                          ],
                          onChanged: (v) {
                            _source = v!;
                            _stage();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      DakhlButton(
                        label: 'تطبيق التصفية',
                        kind: DakhlButtonKind.primary,
                        onPressed: _apply,
                      ),
                      DakhlButton(
                        label: 'اليوم',
                        onPressed: () => _preset('today'),
                      ),
                      DakhlButton(
                        label: 'هذا الشهر',
                        onPressed: () => _preset('month'),
                      ),
                      DakhlButton(
                        label: 'مسح / الكل',
                        onPressed: () => _preset('all'),
                      ),
                    ],
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(color: DakhlTokens.red),
                    ),
                  const Divider(height: 36),
                  Wrap(
                    spacing: 42,
                    runSpacing: 20,
                    children: [
                      _total(
                        context,
                        'المجموع حسب الفلتر',
                        _money(statement.total),
                      ),
                      _total(
                        context,
                        'حصة اليومي',
                        _money(statement.dailyShare),
                      ),
                      _total(
                        context,
                        'حصة القاصة',
                        _money(statement.cashShare),
                      ),
                      _total(context, 'عدد البنود', '${statement.rows.length}'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'الفترة المعروضة: ${model.from.isEmpty ? 'بداية السجل' : model.from} — ${model.to.isEmpty ? 'نهاية السجل' : model.to} · التصفية تتغير بعد التطبيق',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            DakhlPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'أعلى المصاريف حسب الخانة',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (model.rankedCategories.isEmpty)
                    const Text('لا توجد مصروفات ضمن هذه الفترة.'),
                  for (final row in model.rankedCategories.indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Wrap(
                        spacing: 26,
                        runSpacing: 8,
                        children: [
                          Text('${row.$1 + 1}'),
                          Text(_category(model, row.$2.key)),
                          Text(_money(row.$2.value)),
                          Text(
                            statement.total == BigInt.zero
                                ? '0%'
                                : '${(row.$2.value.toDouble() / statement.total.toDouble() * 100).round()}%',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            DakhlPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'تفاصيل الحركات',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (model.pageRows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('ماكو مصاريف مسجلة ضمن هذا العرض.'),
                    ),
                  for (final row in model.pageRows)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${row['date']} · ${_category(model, row['categoryId'])}',
                      ),
                      subtitle: Text(
                        '${row['note'] ?? ''}\n${_money(BigInt.from(row['amount']! as int))}',
                      ),
                      onTap: () => showDakhlDialog<void>(
                        context: context,
                        title: 'تفاصيل المصروف',
                        body: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${row['date']} · ${_category(model, row['categoryId'])}',
                            ),
                            Text(_money(BigInt.from(row['amount']! as int))),
                            Text('المبلغ الأصلي: ${row['originalAmount']} د.ع'),
                            Text(
                              'توزيع الدفع: ${(row['funding'] as Map)['dailyAmount']} يومي · ${(row['funding'] as Map)['cashAmount']} قاصة',
                            ),
                            Text('${row['note'] ?? ''}'),
                          ],
                        ),
                        actions: [
                          DakhlButton(
                            label: 'إغلاق',
                            onPressed: () => Navigator.of(
                              context,
                              rootNavigator: true,
                            ).pop(),
                          ),
                        ],
                      ),
                    ),
                  Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DakhlButton(
                        label: 'السابق',
                        onPressed: model.page == 0
                            ? null
                            : () => model.setPage(model.page - 1),
                      ),
                      Text('${model.page + 1} / ${model.pageCount}'),
                      DakhlButton(
                        label: 'التالي',
                        onPressed: model.page + 1 >= model.pageCount
                            ? null
                            : () => model.setPage(model.page + 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }
}

Widget _total(BuildContext context, String label, String value) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(label, style: Theme.of(context).textTheme.bodySmall),
    Text(value, style: Theme.of(context).textTheme.titleLarge),
  ],
);

/// Informational review with window-local checkboxes. Context links retain the
/// selected day and never create a closing, posting or lock themselves.
Future<void> showDayReview(
  BuildContext context, {
  required ReportsViewModel model,
  required String date,
  ValueChanged<String>? onRecordRemaining,
  ValueChanged<String>? onTransfer,
}) async {
  await showDakhlDialog<void>(
    context: context,
    title: 'مراجعة اليوم',
    wide: true,
    body: _DayReview(
      model: model,
      date: date,
      onRecordRemaining: onRecordRemaining,
      onTransfer: onTransfer,
    ),
    actions: const [],
  );
}

class _DayReview extends StatefulWidget {
  const _DayReview({
    required this.model,
    required this.date,
    this.onRecordRemaining,
    this.onTransfer,
  });
  final ReportsViewModel model;
  final String date;
  final ValueChanged<String>? onRecordRemaining, onTransfer;
  @override
  State<_DayReview> createState() => _DayReviewState();
}

class _DayReviewState extends State<_DayReview> {
  bool _expenses = false, _remaining = false;
  @override
  Widget build(BuildContext context) {
    final day = widget.model.reviewDay(widget.date);
    final cash = DailyCashQueries(widget.model.account).statement(
      from: widget.date,
      to: widget.date,
      source: SpendingSource.cash,
    );
    final refunds = ExactMath.binary64IntegerSum(
      (widget.model.account.toJson()['saleReturns']! as List)
          .cast<Map<String, Object?>>()
          .where((r) => r['date'] == widget.date)
          .map((r) => BigInt.from(r['amount']! as int)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.date),
        const SizedBox(height: 20),
        const Text(
          'مراجعة سريعة للسجل، بدون إقفال اليوم أو تغيير الحسابات. علامات المراجعة مؤقتة لهذه النافذة.',
        ),
        const SizedBox(height: 24),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _expenses,
          onChanged: (v) => setState(() {
            _expenses = v!;
          }),
          title: const Text('راجعت المبيعات والمصاريف'),
        ),
        Wrap(
          spacing: 32,
          runSpacing: 20,
          children: [
            _total(context, 'صافي حركة المبيعات', _money(day.netSales)),
            _total(context, 'المرتجعات بتاريخ اليوم', _money(refunds)),
            _total(context, 'مصروف اليومي', _money(day.dailySpent)),
            _total(context, 'مصروف القاصة', _money(cash.cashShare)),
          ],
        ),
        const SizedBox(height: 16),
        const Text('هذه مبالغ السجل، مو صافي الربح.'),
        const SizedBox(height: 24),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _remaining,
          onChanged: (v) => setState(() {
            _remaining = v!;
          }),
          title: const Text('عدّيت الباقي الفعلي'),
        ),
        Text(
          day.remaining == null
              ? 'الباقي غير مسجّل بعد'
              : '${_money(day.remaining!)} مسجّل. لا تضيف المبيعات مرة ثانية إلى العد الفعلي.',
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DakhlButton(
            label: 'تسجيل الباقي ومعاينة الإجمالي',
            kind: DakhlButtonKind.primary,
            onPressed: widget.onRecordRemaining == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    widget.onRecordRemaining!(widget.date);
                  },
          ),
        ),
        const SizedBox(height: 24),
        const Text('تحويل للقاصة · اختياري'),
        const Text('يخصم من اليومي ويضيف للقاصة مرة واحدة.'),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DakhlButton(
            label: 'تحويل من رصيد اليوم',
            onPressed:
                widget.onTransfer == null ||
                    day.remaining == null ||
                    day.remaining! <= BigInt.zero
                ? null
                : () {
                    Navigator.of(context).pop();
                    widget.onTransfer!(widget.date);
                  },
          ),
        ),
        const SizedBox(height: 24),
        const Text('احتفظ بالتقرير'),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DakhlButton(
            label: 'تصدير مصاريف اليوم PDF',
            onPressed: () => buildAndShowRestaurantReport(
              context,
              () => widget.model.composer.daily(widget.date),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared saved-document surface for all seven approved report kinds.
Future<void> buildAndShowRestaurantReport(
  BuildContext context,
  RestaurantReport Function() compose,
) async {
  try {
    final report = compose();
    if (context.mounted) await showRestaurantReport(context, report);
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذّر إعداد التقرير على هذا الجهاز. بياناتك المحفوظة لم تتغير.',
          ),
        ),
      );
    }
  }
}

Future<void> showRestaurantReport(
  BuildContext context,
  RestaurantReport report, {
  ReportDeliveryController? delivery,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _ReportModal(report: report, delivery: delivery),
);

class _ReportModal extends StatefulWidget {
  const _ReportModal({required this.report, this.delivery});
  final RestaurantReport report;
  final ReportDeliveryController? delivery;
  @override
  State<_ReportModal> createState() => _ReportModalState();
}

class _ReportModalState extends State<_ReportModal> {
  late final ReportDeliveryController _delivery;
  String? _message;
  @override
  void initState() {
    super.initState();
    _delivery = widget.delivery ?? ReportDeliveryController();
    unawaited(_generate());
  }

  Future<void> _generate() async {
    final result = await _delivery.generate(widget.report);
    if (mounted) {
      setState(() {
        _message = result is CapabilitySuccess
            ? null
            : 'تعذّر إنشاء التقرير. أعد المحاولة.';
      });
    }
  }

  Future<void> _handoff(
    Future<CapabilityResult<void>> Function() action,
  ) async {
    final result = await action();
    if (mounted) {
      setState(() {
        _message = result is CapabilitySuccess
            ? 'تم تسليم الملف للنظام.'
            : result is CapabilityCancelled
            ? 'أُلغيت العملية.'
            : 'تعذّر تأكيد العملية. التقرير المحفوظ لم يتغير.';
      });
    }
  }

  Future<void> _openPdf() async {
    final bytes = _delivery.bytes;
    if (_delivery.isBusy || bytes == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) =>
          SavedReportPdfViewer(title: widget.report.title, bytes: bytes),
    );
  }

  void _close() {
    if (!_delivery.isBusy) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _delivery,
    builder: (context, _) => PopScope(
      canPop: !_delivery.isBusy,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
        child: DakhlDialog(
          title: widget.report.title,
          wide: true,
          onClose: _close,
          subtitle: '${widget.report.period} · ${widget.report.reference}',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_delivery.isBusy) const LinearProgressIndicator(),
              if (_message != null)
                Semantics(liveRegion: true, child: Text(_message!)),
              Text(
                widget.report.identity['name'] ?? '',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(widget.report.identity['contact'] ?? ''),
              const Divider(),
              for (final section in widget.report.sections) ...[
                if (section.title.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      section.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                if (section.rows.isEmpty)
                  const Text('لا توجد سجلات ضمن هذا العرض.'),
                if (section.rows.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: const WidgetStatePropertyAll(
                        DakhlTokens.soft,
                      ),
                      columns: [
                        for (final header in section.headers)
                          DataColumn(label: Text(header)),
                      ],
                      rows: [
                        for (final row in section.rows)
                          DataRow(
                            cells: [
                              for (final cell in row)
                                DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 270,
                                    ),
                                    child: Text(cell, softWrap: true),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              Text(widget.report.identity['footer'] ?? ''),
            ],
          ),
          actions: [
            DakhlButton(
              label: 'فتح PDF',
              onPressed: _delivery.isBusy || _delivery.report == null
                  ? null
                  : _openPdf,
            ),
            DakhlButton(
              label: 'حفظ PDF',
              onPressed: _delivery.isBusy || _delivery.report == null
                  ? null
                  : () => _handoff(_delivery.save),
            ),
            DakhlButton(
              label: 'مشاركة',
              onPressed: _delivery.isBusy || _delivery.report == null
                  ? null
                  : () => _handoff(_delivery.share),
            ),
            DakhlButton(
              label: 'طباعة',
              onPressed: _delivery.isBusy || _delivery.report == null
                  ? null
                  : () => _handoff(_delivery.print),
            ),
            if (!_delivery.isBusy && _delivery.report == null)
              DakhlButton(label: 'إعادة المحاولة', onPressed: _generate),
            DakhlButton(
              label: 'إغلاق',
              onPressed: _delivery.isBusy ? null : _close,
            ),
          ],
        ),
      ),
    ),
  );
  @override
  void dispose() {
    if (widget.delivery == null) _delivery.dispose();
    super.dispose();
  }
}
