import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart' hide PaidSpendingStatement;

import '../accounts/account_document.dart';
import '../catalog/catalog_formatters.dart';
import '../reports/restaurant_report.dart';
import '../reports/reports_view_model.dart';
import '../ui/dakhl_ui.dart';
import 'daily_cash_controller.dart';
import 'daily_cash_queries.dart';
import 'expense_editor.dart';
import 'daily_register_editor.dart';
import 'cash_adjustment_editor.dart';
import 'daily_transfer_editor.dart';
import 'daily_transfer_editor_controller.dart';
import 'expense_editor_controller.dart';

/// Approved daily/cash reference content backed by saved account records.
/// Standalone external cash adjustments still require their accepted mapping;
/// derived expense/payment movements are never editable as separate records.
class DailyCashSurface extends StatefulWidget {
  const DailyCashSurface({
    super.key,
    required this.document,
    this.controller,
    this.cash = false,
    this.initialDate,
    this.onReview,
    this.onCategories,
    this.reportComposer,
    this.delivery,
    this.readAccount,
    this.onChickenEdit,
    this.onAddCategory,
    this.onPayments,
    this.onOpenPayment,
    this.onRegisterEdit,
    this.onDateCorrection,
    this.compareText,
  });
  final AccountDocument document;
  final int Function(String, String)? compareText;
  final AccountDocument Function()? readAccount;
  final Future<void> Function(String)? onChickenEdit;
  final Future<String?> Function()? onAddCategory;
  final VoidCallback? onPayments;
  final ValueChanged<String>? onOpenPayment;
  final Future<void> Function(DailyRegisterField, String)? onRegisterEdit;
  final Future<void> Function(String)? onDateCorrection;
  final DailyCashController? controller;
  final bool cash;
  final String? initialDate;
  final ValueChanged<String>? onReview;
  final VoidCallback? onCategories;
  final RestaurantReportComposer? reportComposer;
  final ReportDeliveryController? delivery;
  @override
  State<DailyCashSurface> createState() => _DailyCashSurfaceState();
}

class _DailyCashSurfaceState extends State<DailyCashSurface> {
  late String _date =
      widget.initialDate ?? CatalogFormatters.today().toString();
  String _from = '', _to = '', _type = '';
  int _page = 0;
  static const _pageSize = 25;
  DailyCashQueries get _queries => DailyCashQueries(
    widget.controller?.spending.account ??
        widget.readAccount?.call() ??
        widget.document,
  );
  String _money(BigInt? amount) => amount == null
      ? '—'
      : '${CatalogFormatters.formatPrice(amount.toInt())} د.ع';
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_changed);
  }

  @override
  void didUpdateWidget(DailyCashSurface old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_changed);
      widget.controller?.addListener(_changed);
    }
    if (old.cash != widget.cash) _page = 0;
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_changed);
    super.dispose();
  }

  void _shift(int days) {
    final date = DateTime.parse(_date).add(Duration(days: days));
    if (date.year < 1000 || date.year > 9999) return;
    _select(
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    );
  }

  void _select(String date) {
    widget.controller?.selectDate(date);
    setState(() => _date = date);
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_date),
      firstDate: DateTime(1000),
      lastDate: DateTime(9999, 12, 31),
    );
    if (result != null && mounted) {
      _select(
        '${result.year.toString().padLeft(4, '0')}-${result.month.toString().padLeft(2, '0')}-${result.day.toString().padLeft(2, '0')}',
      );
    }
  }

  Future<void> _pdf() async {
    final composer = widget.reportComposer, delivery = widget.delivery;
    if (composer == null || delivery == null) return;
    try {
      final report = widget.cash ? composer.cash() : composer.daily(_date);
      final result = await delivery.generate(report);
      if (!mounted) return;
      if (result is CapabilitySuccess<void>) {
        final saved = await delivery.save();
        if (mounted && saved is CapabilityFailure<void>) {
          showDakhlToast(
            context,
            'تعذّر تصدير التقرير؛ بقي التقرير لإعادة المحاولة.',
          );
        }
      } else {
        showDakhlToast(context, 'تعذّر تجهيز التقرير.');
      }
    } on Object {
      if (mounted) {
        showDakhlToast(
          context,
          'التقرير غير متاح الآن؛ ترتيب السجلات يحتاج خدمة مقارنة معتمدة.',
        );
      }
    }
  }

  void _openPayment(Map<String, Object?> row) {
    final id = row['id'];
    final account =
        widget.controller?.spending.account ??
        widget.readAccount?.call() ??
        widget.document;
    final matches = (account.toJson()['payments']! as List).where(
      (item) => (item as Map)['id'] == id,
    );
    if (id is! String || matches.length != 1) {
      showDakhlToast(context, 'تعذّر العثور على التسديد المحفوظ لهذه الحركة.');
      return;
    }
    if (widget.onOpenPayment != null) {
      widget.onOpenPayment!(id);
    } else {
      widget.onPayments?.call();
    }
  }

  Future<void> _editExpense([Map<String, Object?>? row]) async {
    if (row?['kind'] == 'supplier-payment') {
      _openPayment(row!);
      return;
    }
    final controller = widget.controller;
    if (controller == null || !controller.postingEnabled) return;
    await showExpenseEditor(
      context,
      controller: ExpenseEditorController(
        spending: controller.spending,
        date: _date,
        expense: row,
      ),
      onAddCategory: widget.onAddCategory,
    );
    _changed();
  }

  Future<void> _cashAdjustment([Map<String, Object?>? row]) async {
    await showCashAdjustmentEditor(
      context,
      model: widget.controller?.spending,
      source: row,
    );
    _changed();
  }

  Future<void> _transfer([Map<String, Object?>? transfer]) async {
    final controller = widget.controller;
    if (controller == null || !controller.postingEnabled) return;
    controller.selectDate(_date);
    await showDailyTransferEditor(
      context,
      controller: DailyTransferEditorController(
        spending: controller.spending,
        date: _date,
        transfer: transfer,
      ),
    );
    _changed();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, layout) {
      final day = _queries.day(_date);
      final expenses = _queries.expenses(_date);
      final document =
          widget.controller?.spending.account ??
          widget.readAccount?.call() ??
          widget.document;
      final categories = (document.toJson()['categories'] as List)
          .cast<Map<String, Object?>>();
      String category(Object? id) =>
          categories.where((c) => c['id'] == id).firstOrNull?['name']
              as String? ??
          'خانة';
      BigInt amount(Object? value) => BigInt.from(value as int? ?? 0);
      final dailyExpenses = expenses
          .where(
            (row) =>
                amount(
                  (row['funding'] as Map?)?['dailyAmount'] ?? row['amount'],
                ) >
                BigInt.zero,
          )
          .toList();
      final cashExpenses = expenses
          .where(
            (row) =>
                amount((row['funding'] as Map?)?['cashAmount']) > BigInt.zero,
          )
          .toList();
      final cashTotal = cashExpenses.fold(
        BigInt.zero,
        (sum, row) => sum + amount((row['funding'] as Map)['cashAmount']),
      );
      var ordered = <Map<String, Object?>>[];
      bool orderingUnavailable = false;
      if (widget.cash) {
        try {
          ordered = _queries.orderedCashMovements(widget.compareText);
        } on Object {
          orderingUnavailable = true;
        }
      }
      final balances = <(String, String), BigInt>{};
      var running = BigInt.zero;
      for (final row in ordered.reversed) {
        final delta =
            amount(row['amount']) *
            BigInt.from(row['type'] == 'withdrawal' ? -1 : 1);
        running = ExactMath.binary64IntegerSum([running, delta]);
        balances[(row['kind']! as String, row['id']! as String)] = running;
      }
      final movements = ordered
          .where(
            (row) =>
                (_from.isEmpty ||
                    (row['date'] as String).compareTo(_from) >= 0) &&
                (_to.isEmpty || (row['date'] as String).compareTo(_to) <= 0) &&
                (_type.isEmpty || row['type'] == _type),
          )
          .toList();
      final pageCount =
          ((widget.cash ? movements.length : dailyExpenses.length) / _pageSize)
              .ceil()
              .clamp(1, 1 << 30);
      final page = _page.clamp(0, pageCount - 1);
      final savedDay = (document.toJson()['days'] as Map)[_date] as Map?;
      Widget metric(String label, BigInt? value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Text(_money(value), style: Theme.of(context).textTheme.titleLarge),
        ],
      );
      Widget expensesPanel(
        List<Map<String, Object?>> rows,
        String title, {
        bool cashShare = false,
      }) => DakhlPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            if (rows.isEmpty) const Text('لا توجد مصاريف لهذا اليوم.'),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text(category(row['categoryId'])),
                    Text(
                      _money(
                        amount(
                          (row['funding'] as Map?)?[cashShare
                                  ? 'cashAmount'
                                  : 'dailyAmount'] ??
                              row['amount'],
                        ),
                      ),
                    ),
                    Text(row['note'] as String? ?? ''),
                    IconButton(
                      tooltip: 'تعديل المصروف',
                      onPressed: row['kind'] == 'supplier-payment'
                          ? (widget.onOpenPayment == null &&
                                    widget.onPayments == null
                                ? null
                                : () => _openPayment(row))
                          : widget.controller?.postingEnabled == true
                          ? () => _editExpense(row)
                          : null,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
      final primary = expensesPanel(
        dailyExpenses.skip(page * _pageSize).take(_pageSize).toList(),
        'مصاريف الرصيد اليومي',
      );
      final secondary = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          expensesPanel(cashExpenses, 'مصاريف القاصة', cashShare: true),
          const SizedBox(height: 16),
          DakhlPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                metric('مجموع مصاريف القاصة', cashTotal),
                const Divider(),
                metric('الرصيد المتبقي من اليومي', day.remaining),
                OutlinedButton(
                  onPressed: widget.onRegisterEdit == null
                      ? null
                      : () => widget.onRegisterEdit!(
                          DailyRegisterField.remaining,
                          _date,
                        ),
                  child: const Text('تسجيل الرصيد المتبقي'),
                ),
                const Text('التحويل للقاصة ينخصم من هذا الرصيد.'),
                FilledButton(
                  onPressed: widget.controller?.postingEnabled == true
                      ? _transfer
                      : null,
                  child: const Text('تحويل من رصيد اليوم'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DakhlPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'تتبّع الدجاج',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text('أعداد فقط · خارج مجموع المصاريف'),
                Text('الدجاج المصروف: ${savedDay?['chickenUsed'] ?? '—'}'),
                Text('الدجاج المتبقي: ${savedDay?['chickenLeft'] ?? '—'}'),
                if (widget.onChickenEdit != null)
                  OutlinedButton(
                    onPressed: () async {
                      await widget.onChickenEdit!(_date);
                      _changed();
                    },
                    child: const Text('تعديل الأعداد'),
                  ),
              ],
            ),
          ),
        ],
      );
      return SingleChildScrollView(
        padding: EdgeInsets.all(DakhlTokens.gutter(layout.maxWidth)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 12,
              children: [
                Text(
                  widget.cash ? 'القاصة' : 'المصاريف اليومية',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!widget.cash) ...[
                      IconButton(
                        tooltip: 'اليوم السابق',
                        onPressed: () => _shift(-1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                      OutlinedButton(onPressed: _pickDate, child: Text(_date)),
                      OutlinedButton(
                        onPressed: widget.onDateCorrection == null
                            ? null
                            : () => widget.onDateCorrection!(_date),
                        child: const Text('تصحيح التاريخ'),
                      ),
                      IconButton(
                        tooltip: 'اليوم التالي',
                        onPressed: () => _shift(1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      OutlinedButton(
                        onPressed: widget.onReview == null
                            ? null
                            : () => widget.onReview!(_date),
                        child: const Text('مراجعة اليوم'),
                      ),
                    ],
                    OutlinedButton(
                      onPressed:
                          widget.reportComposer != null &&
                              widget.delivery != null
                          ? _pdf
                          : null,
                      child: const Text('تصدير PDF'),
                    ),
                    if (widget.cash)
                      FilledButton.icon(
                        onPressed: () => _cashAdjustment(),
                        icon: const Icon(Icons.add),
                        label: const Text('إيداع أو سحب مباشر'),
                      ),
                    if (!widget.cash)
                      FilledButton.icon(
                        onPressed: widget.controller?.postingEnabled == true
                            ? () => _editExpense()
                            : null,
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة مصروف'),
                      ),
                    if (widget.onCategories != null)
                      OutlinedButton(
                        onPressed: widget.onCategories,
                        child: const Text('الخانات'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (widget.cash) ...[
              Text(
                'رصيد القاصة: ${_money(_queries.cashBalance)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'الإيداع والسحب الخارجي يحتاجان حساباً مقابلاً معتمداً قبل الترحيل.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 180,
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'من تاريخ YYYY-MM-DD',
                      ),
                      onChanged: (value) {
                        try {
                          if (value.isNotEmpty) {
                            DateOnly.parse(
                              value,
                              minimumYear: 1000,
                              maximumYear: 9999,
                            );
                          }
                          setState(() {
                            _from = value;
                            _page = 0;
                          });
                        } on Object {
                          /* Retain last valid filter. */
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'إلى تاريخ YYYY-MM-DD',
                      ),
                      onChanged: (value) {
                        try {
                          if (value.isNotEmpty) {
                            DateOnly.parse(
                              value,
                              minimumYear: 1000,
                              maximumYear: 9999,
                            );
                          }
                          setState(() {
                            _to = value;
                            _page = 0;
                          });
                        } on Object {
                          /* Retain last valid filter. */
                        }
                      },
                    ),
                  ),
                  DropdownButton<String>(
                    value: _type,
                    items: const [
                      DropdownMenuItem(value: '', child: Text('الكل')),
                      DropdownMenuItem(value: 'deposit', child: Text('إيداع')),
                      DropdownMenuItem(value: 'withdrawal', child: Text('سحب')),
                    ],
                    onChanged: (value) => setState(() {
                      _type = value ?? '';
                      _page = 0;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DakhlPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (orderingUnavailable)
                      const DakhlStatus(
                        message: 'ترتيب حركات القاصة غير متاح حالياً. بيانات الحساب محفوظة.',
                      ),
                    if (!orderingUnavailable && movements.isEmpty)
                      const Text('لا توجد حركات تطابق التصفية.'),
                    for (final row
                        in movements.skip(page * _pageSize).take(_pageSize))
                      ListTile(
                        title: Text(
                          '${row['type'] == 'deposit' ? 'إيداع' : 'سحب'} · ${_money(amount(row['amount']))}',
                        ),
                        subtitle: Text(
                          '${row['date']} · ${row['note'] ?? ''}\nالرصيد بعد الحركة: ${_money(balances[(row['kind']! as String, row['id']! as String)])}',
                        ),
                        trailing: row['kind'] == 'transfer'
                            ? IconButton(
                                tooltip: 'تعديل التحويل',
                                onPressed: widget.controller == null
                                    ? null
                                    : () {
                                        final original =
                                            (document.toJson()['transfers']
                                                    as List)
                                                .cast<Map<String, Object?>>()
                                                .where(
                                                  (e) => e['id'] == row['id'],
                                                )
                                                .firstOrNull;
                                        if (original != null) {
                                          _transfer(original);
                                        }
                                      },
                                icon: const Icon(Icons.edit_outlined),
                              )
                            : row['kind'] == 'cash'
                            ? IconButton(
                                tooltip: 'تعديل الحركة',
                                onPressed: () => _cashAdjustment(row),
                                icon: const Icon(Icons.edit_outlined),
                              )
                            : row['kind'] == 'supplier-payment'
                            ? IconButton(
                                tooltip: 'فتح التسديد',
                                onPressed:
                                    widget.onOpenPayment == null &&
                                        widget.onPayments == null
                                    ? null
                                    : () => _openPayment(row),
                                icon: const Icon(Icons.open_in_new),
                              )
                            : row['kind'] == 'expense'
                            ? IconButton(
                                tooltip: 'فتح المصروف',
                                onPressed: widget.controller == null
                                    ? null
                                    : () {
                                        final original = _queries
                                            .expenses(row['date']! as String)
                                            .where((e) => e['id'] == row['id'])
                                            .firstOrNull;
                                        if (original != null) {
                                          _select(row['date']! as String);
                                          _editExpense(original);
                                        }
                                      },
                                icon: const Icon(Icons.open_in_new),
                              )
                            : null,
                      ),
                  ],
                ),
              ),
            ] else ...[
              Text('صافي التحصيل لليوم بعد المرتجعات: ${_money(day.netSales)}'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 32,
                runSpacing: 12,
                children: [
                  metric('مصروف اليومي', day.dailySpent),
                  metric('الرصيد الكلي اليومي', day.recordedBalance),
                  metric('مجموع مصروف اليومي', day.total),
                ],
              ),
              Wrap(
                spacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: widget.onRegisterEdit == null
                        ? null
                        : () => widget.onRegisterEdit!(
                            DailyRegisterField.balance,
                            _date,
                          ),
                    child: const Text('تعديل الرصيد الكلي'),
                  ),
                  OutlinedButton(
                    onPressed: widget.onRegisterEdit == null
                        ? null
                        : () => widget.onRegisterEdit!(
                            DailyRegisterField.total,
                            _date,
                          ),
                    child: const Text('تعديل مجموع المصاريف'),
                  ),
                ],
              ),
              const Divider(height: 40),
              if (layout.maxWidth >= 1000)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: primary),
                    const SizedBox(width: 20),
                    Expanded(child: secondary),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [primary, const SizedBox(height: 16), secondary],
                ),
            ],
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: 'الصفحة السابقة',
                  onPressed: page > 0
                      ? () => setState(() => _page = page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                Text('${page + 1} / $pageCount'),
                IconButton(
                  tooltip: 'الصفحة التالية',
                  onPressed: page + 1 < pageCount
                      ? () => setState(() => _page = page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
