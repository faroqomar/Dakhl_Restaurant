import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';

import '../accounts/account_document.dart';
import '../catalog/catalog_formatters.dart';
import '../reports/reports_view_model.dart';
import '../reports/saved_report_pdf_viewer.dart';
import '../reports/sales_report.dart';
import '../ui/components.dart';
import '../ui/dialogs.dart';
import '../ui/theme.dart';
import 'sales_history_view_model.dart';
import 'sales_operations_view_model.dart';
import 'sale_return_dialog.dart';

/// Saved schema-11 history is read-only. Optional portable operations enable
/// eligible voids and source-reference-authorized returns through a durable owner.
class SalesHistorySurface extends StatefulWidget {
  const SalesHistorySurface({
    super.key,
    required this.document,
    this.operations,
    this.compareText,
    this.delivery,
    this.onNewSale,
    this.initialSaleId,
    this.onInitialSaleHandled,
  });
  final AccountDocument? document;
  final SalesOperationsViewModel? operations;
  final int Function(String, String)? compareText;
  final ReportDeliveryController? delivery;
  final VoidCallback? onNewSale;
  final String? initialSaleId;
  final ValueChanged<String>? onInitialSaleHandled;
  @override
  State<SalesHistorySurface> createState() => _SalesHistorySurfaceState();
}

class _SalesHistorySurfaceState extends State<SalesHistorySurface> {
  late SalesHistoryViewModel _model;
  late ReportDeliveryController _delivery;
  final _from = TextEditingController(),
      _to = TextEditingController(),
      _query = TextEditingController();
  String _status = '', _type = '';
  String? _error, _feedback;
  bool _exporting = false;
  AccountDocument? _preparedSource;
  String? _preparedKey;
  String? _openedInitialId;
  bool _initialScheduled = false;

  @override
  void initState() {
    super.initState();
    _bind();
    _queueInitialReceipt();
  }

  void _bind() {
    _model = SalesHistoryViewModel(
      document: widget.document,
      operations: widget.operations,
      compareText: widget.compareText,
    )..addListener(_changed);
    _delivery = widget.delivery ?? ReportDeliveryController();
  }

  @override
  void didUpdateWidget(SalesHistorySurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.operations != widget.operations ||
        oldWidget.compareText != widget.compareText ||
        oldWidget.delivery != widget.delivery) {
      _model.removeListener(_changed);
      _model.dispose();
      if (oldWidget.delivery == null) _delivery.dispose();
      _bind();
      _preparedKey = null;
      _preparedSource = null;
    } else {
      _model.updateDocument(widget.document);
    }
    if (widget.initialSaleId == null) _openedInitialId = null;
    _queueInitialReceipt();
  }

  void _changed() {
    if (mounted) {
      setState(() {});
      _queueInitialReceipt();
    }
  }

  void _queueInitialReceipt() {
    final id = widget.initialSaleId;
    if (!mounted ||
        id == null ||
        id == _openedInitialId ||
        _initialScheduled ||
        _model.document == null ||
        _model.busy ||
        (_model.pendingVoid || _model.pendingReturn)) {
      return;
    }
    _initialScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialScheduled = false;
      if (!mounted) return;
      final target = widget.initialSaleId;
      if (target == null ||
          target == _openedInitialId ||
          _model.document == null ||
          _model.busy ||
          (_model.pendingVoid || _model.pendingReturn)) {
        return;
      }
      _openedInitialId = target;
      final matches = (_model.document!.toJson()['sales']! as List)
          .cast<Map<String, Object?>>()
          .where((sale) => sale['id'] == target)
          .length;
      if (matches != 1) {
        setState(() => _error = 'تعذّر العثور على الفاتورة المحفوظة المطلوبة.');
        widget.onInitialSaleHandled?.call(target);
        return;
      }
      _receipt(target);
      widget.onInitialSaleHandled?.call(target);
    });
  }

  String _money(BigInt value) => CatalogFormatters.formatPrice(value.toInt());
  void _apply() {
    final result = _model.setFilter(
      SalesHistoryFilter(
        from: _from.text,
        to: _to.text,
        query: _query.text,
        status: _status,
        orderType: _type,
      ),
    );
    setState(
      () => _error = result is CapabilitySuccess<void>
          ? null
          : 'تحقق من الفترة والتصفية المدخلة.',
    );
  }

  void _period(String kind) {
    final today = CatalogFormatters.today().toString();
    _from.text = kind == 'all'
        ? ''
        : kind == 'month'
        ? '${today.substring(0, 8)}01'
        : today;
    _to.text = kind == 'all' ? '' : today;
    if (kind == 'all') {
      _query.clear();
      _status = '';
      _type = '';
    }
    _apply();
  }

  Future<void> _deliver(
    String action, {
    bool history = false,
    StateSetter? dialogSetState,
  }) async {
    if (_exporting || _delivery.isBusy) return;
    setState(() {
      _exporting = true;
      _feedback = null;
    });
    dialogSetState?.call(() {});
    try {
      final key = history
          ? 'history:${_model.filter.from}:${_model.filter.to}:${_model.filter.query}:${_model.filter.status}:${_model.filter.orderType}'
          : 'receipt:${_model.selected?['id']}';
      final source = _model.document;
      if (_preparedKey != key ||
          !identical(_preparedSource, source) ||
          _delivery.bytes == null) {
        final report = history ? _model.filteredReport() : _model.receipt();
        final generated = await _delivery.generate(report);
        if (generated is! CapabilitySuccess<void>) {
          _feedback = 'تعذّر إنشاء PDF. أعد المحاولة.';
          return;
        }
        _preparedKey = key;
        _preparedSource = source;
      }
      if (!mounted) return;
      final CapabilityResult<void> result = switch (action) {
        'open' => await openSavedReportPdf(
          context,
          title: _delivery.report!.title,
          bytes: _delivery.bytes!,
        ),
        'print' => await _delivery.print(),
        'share' => await _delivery.share(),
        _ => await _delivery.save(),
      };
      _feedback = switch (result) {
        CapabilitySuccess() =>
          action == 'open'
              ? 'تم فتح عرض PDF.'
              : action == 'print'
              ? 'تم إرسال الوصل للطباعة.'
              : action == 'share'
              ? 'تم تسليم PDF للنظام.'
              : 'تم حفظ PDF.',
        CapabilityCancelled() => 'أُلغي الطلب؛ لم تتغير الفاتورة.',
        CapabilityFailure() => 'تعذّر إكمال الطلب. أعد المحاولة بالنسخة نفسها.',
      };
    } on Object {
      _feedback = 'تعذّر إنشاء المستند أو إرساله. لم تتغير الفاتورة.';
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
        dialogSetState?.call(() {});
      }
    }
  }

  Future<void> _receipt(String id) async {
    _model.select(id);
    if (_model.selected == null) return;
    _feedback = null;
    final next = await showDakhlDialog<String>(
      context: context,
      title: _model.selected!['status'] == 'void'
          ? 'فاتورة ملغاة'
          : 'وصل بيع محفوظ',
      subtitle: '${_model.selected!['number']} · ${_model.selected!['date']}',
      body: _receiptBody(),
      actions: [
        StatefulBuilder(
          builder: (dialogContext, update) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DakhlButton(
                label: 'طباعة الوصل',
                onPressed: _exporting
                    ? null
                    : () => _deliver('print', dialogSetState: update),
              ),
              DakhlButton(
                label: 'فتح PDF',
                onPressed: _exporting
                    ? null
                    : () => _deliver('open', dialogSetState: update),
              ),
              DakhlButton(
                label: 'حفظ PDF',
                onPressed: _exporting
                    ? null
                    : () => _deliver('save', dialogSetState: update),
              ),
              DakhlButton(
                label: 'مشاركة PDF',
                onPressed: _exporting
                    ? null
                    : () => _deliver('share', dialogSetState: update),
              ),
              if (_model.hasReturnable)
                DakhlButton(
                  label: 'إرجاع أصناف',
                  onPressed: _exporting
                      ? null
                      : () => Navigator.of(dialogContext).pop('return'),
                ),
              if (_model.canVoid)
                DakhlButton(
                  label: 'إلغاء الوصل',
                  onPressed: _exporting
                      ? null
                      : () => Navigator.of(dialogContext).pop('void'),
                ),
              if (_feedback != null) Text(_feedback!),
            ],
          ),
        ),
      ],
      canDismiss: () async => !_exporting,
    );
    if (!mounted) return;
    if (next == 'return') await _returnSale();
    if (next == 'void') await _void();
  }

  Widget _receiptBody() {
    final report = _model.receipt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          report.identity['name']!.isEmpty ? 'دفتر' : report.identity['name']!,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (report.identity['contact']!.isNotEmpty)
          Text(report.identity['contact']!, textAlign: TextAlign.center),
        for (final section in report.sections) ...[
          if (section.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                section.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          for (final row in section.rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 4,
                    children: [for (final value in row) Text(value)],
                  ),
                  const Divider(),
                ],
              ),
            ),
        ],
        for (final refund in _model.selectedReturns) ...[
          const SizedBox(height: 12),
          Text(
            'مرتجع ${refund['date']}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final line
              in (refund['lines']! as List).cast<Map<String, Object?>>())
            Text(
              '${_savedLineName(line['productId']! as String)} · ${line['quantity']} · ${line['restock'] == true ? 'أعيد للمخزن' : 'بدون إعادة للمخزن'}',
            ),
        ],
        if (report.identity['footer']!.isNotEmpty)
          Text(report.identity['footer']!),
      ],
    );
  }

  String _savedLineName(String productId) =>
      (_model.selected?['lines'] as List? ?? const [])
          .cast<Map<String, Object?>>()
          .where((line) => line['productId'] == productId)
          .map((line) => line['name']! as String)
          .firstOrNull ??
      productId;

  Future<void> _returnSale() async {
    if (_model.hasReturnable) await showSaleReturnDialog(context, _model);
  }

  Future<void> _void() async {
    final sale = _model.selected;
    if (sale == null || !_model.canVoid) return;
    final reason = TextEditingController();
    String? error;
    bool saving = false;
    await showDakhlDialog<void>(
      context: context,
      title: 'إلغاء فاتورة ${sale['number']}',
      subtitle: 'يرجع المخزون ويستبعد مبلغ الفاتورة من المبيعات.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DakhlStatus(
            message: 'تأكد من إعادة المبلغ للزبون؛ يُعكس البيع بتاريخ الفاتورة الأصلي.',
          ),
          DakhlField(label: 'سبب الإلغاء', controller: reason),
        ],
      ),
      actions: [
        StatefulBuilder(
          builder: (dialogContext, update) => Column(
            children: [
              if (error != null)
                Text(error!, style: const TextStyle(color: DakhlTokens.red)),
              DakhlButton(
                label: _model.pendingVoid
                    ? 'إعادة التحقق من الإلغاء'
                    : 'إلغاء البيع وإرجاع الكمية',
                kind: DakhlButtonKind.primary,
                busy: saving,
                onPressed: saving
                    ? null
                    : () async {
                        update(() => saving = true);
                        final result = await _model.voidSale(reason.text);
                        if (!dialogContext.mounted) return;
                        update(() {
                          saving = false;
                          error = result is CapabilitySuccess<void>
                              ? null
                              : CatalogFormatters.errorMessage(
                                  result is CapabilityFailure
                                      ? result.code
                                      : 'unavailable',
                                );
                        });
                        if (result is CapabilitySuccess<void>) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
              ),
            ],
          ),
        ),
      ],
      canDismiss: () async => !saving && !_model.pendingVoid,
    );
    reason.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = _model.history;
    if (history == null && _model.document != null) {
      return const Center(
        child: DakhlEmptyState(
          title: 'ترتيب سجل المبيعات غير متاح حالياً',
          message: 'تعذّر تجهيز ترتيب الفواتير المحفوظة. بياناتك محفوظة، ويمكن فتح الوصل من مصدره.',
        ),
      );
    }
    if (history == null) {
      return const Center(
        child: DakhlEmptyState(
          title: 'لا توجد حسابات محفوظة',
          message: 'افتح الحسابات لعرض سجل المبيعات.',
        ),
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(
        DakhlTokens.gutter(MediaQuery.sizeOf(context).width),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'المبيعات / سجل الفواتير',
                    style: TextStyle(color: DakhlTokens.muted),
                  ),
                  Text(
                    'سجل المبيعات',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Text(
                    'الفواتير تحفظ سعر واسم الصنف وقت البيع، حتى لو عدّلته بعدين.',
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  DakhlButton(
                    label: 'بيع جديد',
                    kind: DakhlButtonKind.primary,
                    onPressed: widget.onNewSale,
                  ),
                  DakhlButton(
                    label: 'تصدير هذا العرض PDF',
                    onPressed: _exporting || widget.compareText == null
                        ? null
                        : () => _deliver('save', history: true),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          DakhlPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 180,
                      child: DakhlField(
                        label: 'من تاريخ',
                        controller: _from,
                        compact: true,
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: DakhlField(
                        label: 'إلى تاريخ',
                        controller: _to,
                        compact: true,
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: DakhlField(
                        label: 'رقم الفاتورة أو الصنف',
                        controller: _query,
                        compact: true,
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: DakhlSelect<String>(
                        label: 'الحالة',
                        value: _status,
                        compact: true,
                        items: const [
                          DropdownMenuItem(value: '', child: Text('الكل')),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Text('مكتملة'),
                          ),
                          DropdownMenuItem(value: 'void', child: Text('ملغاة')),
                        ],
                        onChanged: (value) =>
                            setState(() => _status = value ?? ''),
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: DakhlSelect<String>(
                        label: 'نوع الطلب',
                        value: _type,
                        compact: true,
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('الكل'),
                          ),
                          for (final type in _model.orderTypes)
                            DropdownMenuItem(value: type, child: Text(type)),
                        ],
                        onChanged: (value) =>
                            setState(() => _type = value ?? ''),
                      ),
                    ),
                  ],
                ),
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
                      onPressed: () => _period('today'),
                    ),
                    DakhlButton(
                      label: 'هذا الشهر',
                      onPressed: () => _period('month'),
                    ),
                    DakhlButton(
                      label: 'مسح / الكل',
                      onPressed: () => _period('all'),
                    ),
                  ],
                ),
                if (_error != null) DakhlStatus(message: _error!),
                if (_feedback != null) DakhlStatus(message: _feedback!),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 8,
                  spacing: 20,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('صافي حركة المبيعات'),
                        Text(
                          '${_money(history.netMovement)} د.ع',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const Text(
                          'بعد الخصم والإلغاءات والمرتجعات بتاريخها؛ ليس صافي الربح.',
                        ),
                      ],
                    ),
                    DakhlBadge('${history.completedCount} فواتير مكتملة'),
                    DakhlBadge('${history.voidCount} فواتير ملغاة'),
                    DakhlBadge(
                      'مرتجعات الفترة ${_money(history.refunded)} د.ع',
                    ),
                  ],
                ),
                if (history.returns.isNotEmpty) ...[
                  const Divider(),
                  const Text('مرتجعات هذه الفترة'),
                  for (final record in history.returns)
                    Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        onTap: () => _receipt(record['saleId']! as String),
                        title: Text('${record['date']} · ${record['reason']}'),
                        trailing: Text(
                          '${CatalogFormatters.formatPrice(record['amount']! as int)} د.ع',
                        ),
                      ),
                    ),
                ],
                const Divider(),
                if (_model.rows.isEmpty)
                  const DakhlEmptyState(
                    title: 'لا توجد فواتير',
                    message: 'لا توجد مبيعات ضمن هذه التصفية.',
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth < 700
                        ? Column(
                            children: [
                              for (final row in _model.rows)
                                Card(
                                  child: ListTile(
                                    title: Text(
                                      '${row.snapshot['number']} · ${row.snapshot['date']}',
                                    ),
                                    subtitle: Text(
                                      '${_money(row.total)} د.ع · ${_model.stateLabel(row.snapshot)}',
                                    ),
                                    trailing: DakhlButton(
                                      label: 'عرض الوصل',
                                      onPressed: () => _receipt(
                                        row.snapshot['id']! as String,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('الفاتورة')),
                                DataColumn(label: Text('التاريخ')),
                                DataColumn(label: Text('الأصناف')),
                                DataColumn(label: Text('الإجمالي · د.ع')),
                                DataColumn(label: Text('الحالة')),
                                DataColumn(label: Text('الوصل')),
                              ],
                              rows: [
                                for (final row in _model.rows)
                                  DataRow(
                                    cells: [
                                      DataCell(
                                        Text(row.snapshot['number']! as String),
                                      ),
                                      DataCell(
                                        Text(
                                          '${row.snapshot['date']} · ${row.snapshot['orderType']}',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${(row.snapshot['lines']! as List).length}',
                                        ),
                                      ),
                                      DataCell(Text(_money(row.total))),
                                      DataCell(
                                        DakhlBadge(
                                          _model.stateLabel(row.snapshot),
                                        ),
                                      ),
                                      DataCell(
                                        DakhlButton(
                                          label: 'عرض الوصل',
                                          onPressed: () => _receipt(
                                            row.snapshot['id']! as String,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                  ),
                if (_model.pageCount > 1)
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DakhlButton(
                        label: 'السابق',
                        onPressed: _model.page <= 1
                            ? null
                            : () => _model.setPage(_model.page - 1),
                      ),
                      Text('${_model.page} / ${_model.pageCount}'),
                      DakhlButton(
                        label: 'التالي',
                        onPressed: _model.page >= _model.pageCount
                            ? null
                            : () => _model.setPage(_model.page + 1),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _model.removeListener(_changed);
    _model.dispose();
    if (widget.delivery == null) _delivery.dispose();
    _from.dispose();
    _to.dispose();
    _query.dispose();
    super.dispose();
  }
}
