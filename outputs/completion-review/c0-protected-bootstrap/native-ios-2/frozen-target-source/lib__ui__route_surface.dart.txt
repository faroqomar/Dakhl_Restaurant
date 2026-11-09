import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'components.dart';
import 'dialogs.dart';
import 'icons.dart';
import 'theme.dart';

/// All prices/totals are fixed presentation strings. This is not a sale engine.
@immutable
class DakhlCatalogItem {
  const DakhlCatalogItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.photoAsset,
    required this.stockCaption,
  });
  final String id, name, category, price, photoAsset, stockCaption;
}

const phase01CatalogFixture = [
  DakhlCatalogItem(
    id: 'beef',
    name: 'كباب لحم',
    category: 'المشاوي',
    price: '12,000',
    photoAsset: 'assets/ui/beef-kebab-480.webp',
    stockCaption: 'بالمخزن 18 · بالطلب 2 قطعة',
  ),
  DakhlCatalogItem(
    id: 'chicken',
    name: 'كباب دجاج',
    category: 'المشاوي',
    price: '8,000',
    photoAsset: 'assets/ui/chicken-kebab-480.webp',
    stockCaption: 'بالمخزن 18 · بالطلب 0 قطعة',
  ),
  DakhlCatalogItem(
    id: 'grill',
    name: 'دجاج مشوي',
    category: 'الدجاج',
    price: '10,000',
    photoAsset: 'assets/ui/grilled-chicken-480.webp',
    stockCaption: 'بالمخزن 19 · بالطلب 0 قطعة',
  ),
  DakhlCatalogItem(
    id: 'rice-chicken',
    name: 'دليمية دجاج',
    category: 'الدليمية',
    price: '15,000',
    photoAsset: 'assets/ui/dulaimiya-480.webp',
    stockCaption: 'بالمخزن 20 · بالطلب 0 قطعة',
  ),
  DakhlCatalogItem(
    id: 'rice',
    name: 'تمن أحمر',
    category: 'الإضافات',
    price: '2,000',
    photoAsset: 'assets/ui/red-rice-480.webp',
    stockCaption: 'بالمخزن 20 · بالطلب 1 قطعة',
  ),
  DakhlCatalogItem(
    id: 'appetizers',
    name: 'صحن مقبلات',
    category: 'الإضافات',
    price: '3,000',
    photoAsset: 'assets/ui/appetizers-480.webp',
    stockCaption: 'بالمخزن 20 · بالطلب 0 قطعة',
  ),
  DakhlCatalogItem(
    id: 'water',
    name: 'ماء',
    category: 'المشروبات',
    price: '500',
    photoAsset: 'assets/ui/water-480.webp',
    stockCaption: 'بالمخزن 2 · بالطلب 0 قطعة',
  ),
  DakhlCatalogItem(
    id: 'cola',
    name: 'مشروب غازي',
    category: 'المشروبات',
    price: '1,000',
    photoAsset: 'assets/ui/cola-480.webp',
    stockCaption: 'بالمخزن 20 · بالطلب 0 قطعة',
  ),
];

class Phase01RouteSurface extends StatelessWidget {
  const Phase01RouteSurface({
    super.key,
    required this.routeId,
    this.formDraft = const {},
    this.onFormChanged,
    this.onFormDiscard,
    this.ticketPresentation = const {},
    this.onTicketChanged,
    this.searchFocusNode,
    this.onCheckout,
  });
  final String routeId;
  final Map<String, String> formDraft, ticketPresentation;
  final ValueChanged<Map<String, String>>? onFormChanged, onTicketChanged;
  final VoidCallback? onFormDiscard;
  final FocusNode? searchFocusNode;
  final VoidCallback? onCheckout;
  static const labels = {
    'sales': 'المبيعات',
    'sale-history': 'سجل المبيعات',
    'inventory': 'المخزن',
    'expenses': 'المصاريف اليومية',
    'statement': 'كشف الحساب',
    'suppliers': 'الموردون',
    'invoices': 'فواتير المشتريات',
    'materials': 'المواد والأسعار',
    'payments': 'التسديدات',
    'cash': 'القاصة',
    'categories': 'الخانات',
    'settings': 'الإعدادات',
  };
  @override
  Widget build(BuildContext context) {
    if (routeId == 'sales') {
      return DakhlSalesExample(
        ticketPresentation: ticketPresentation,
        onTicketChanged: onTicketChanged,
        searchFocusNode: searchFocusNode,
        onCheckout: onCheckout,
      );
    }
    if (routeId == 'invoices') {
      return _InvoiceExample(
        formDraft: formDraft,
        onFormChanged: onFormChanged,
        onFormDiscard: onFormDiscard,
      );
    }
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: EdgeInsets.all(DakhlTokens.gutter(c.maxWidth)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                labels[routeId] ?? labels['sales']!,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 20),
            const DakhlEmptyState(
              title: 'لا توجد بيانات للعرض',
              message: 'ستظهر البيانات هنا عند توفرها.',
            ),
          ],
        ),
      ),
    );
  }
}

class DakhlProductCard extends StatelessWidget {
  const DakhlProductCard({super.key, required this.item, this.onAdd});
  final DakhlCatalogItem item;
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) => DakhlPanel(
    padding: const EdgeInsets.all(8),
    radius: 12,
    borderColor: const Color(0xFFE9E8DF),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 1.65,
                child: Image.asset(
                  item.photoAsset,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
            ),
            PositionedDirectional(
              end: 2,
              top: 2,
              child: Tooltip(
                message: 'إضافة ${item.name}',
                excludeFromSemantics: true,
                child: Semantics(
                  label: 'إضافة ${item.name}',
                  button: true,
                  enabled: onAdd != null,
                  onTap: onAdd,
                  child: ExcludeSemantics(
                    child: SizedBox.square(
                      dimension: 44,
                      child: DakhlButton(
                        label: '',
                        icon: DakhlIconKind.plus,
                        kind: DakhlButtonKind.primary,
                        onPressed: onAdd,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          item.category,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
        Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text(
              item.price,
              textDirection: TextDirection.ltr,
              style: DakhlTokens.numberStyle.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: DakhlTokens.green,
              ),
            ),
            const Text('د.ع', style: TextStyle(color: DakhlTokens.green)),
          ],
        ),
        Text(
          item.stockCaption,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
        ),
      ],
    ),
  );
}

/// A bounded session presentation example. Quantity edits emit strings only;
/// fixed fixture amounts deliberately never recalculate or post a transaction.
class DakhlSalesExample extends StatefulWidget {
  const DakhlSalesExample({
    super.key,
    this.ticketPresentation = const {},
    this.onTicketChanged,
    this.searchFocusNode,
    this.onCheckout,
  });
  final FocusNode? searchFocusNode;
  final VoidCallback? onCheckout;
  final Map<String, String> ticketPresentation;
  final ValueChanged<Map<String, String>>? onTicketChanged;
  @override
  State<DakhlSalesExample> createState() => _DakhlSalesExampleState();
}

class _DakhlSalesExampleState extends State<DakhlSalesExample> {
  String _query = '', _category = 'كل الأصناف';
  final _localSearchFocus = FocusNode(debugLabel: 'catalog-search');
  FocusNode get _searchFocus => widget.searchFocusNode ?? _localSearchFocus;
  @override
  void dispose() {
    _localSearchFocus.dispose();
    super.dispose();
  }

  late Map<String, String> _ticket;
  @override
  void initState() {
    super.initState();
    _ticket = {...widget.ticketPresentation};
  }

  @override
  void didUpdateWidget(DakhlSalesExample oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ticketPresentation != widget.ticketPresentation) {
      _ticket = {...widget.ticketPresentation};
    }
  }

  void _change(String key, String value) {
    setState(() => _ticket[key] = value);
    widget.onTicketChanged?.call(Map.unmodifiable(_ticket));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final gutter = DakhlTokens.gutter(c.maxWidth);
      final stack =
          c.maxWidth <= 760 ||
          MediaQuery.textScalerOf(context).scale(16) >= 25.6;
      final catalog = _catalog();
      final bill = _bill();
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true):
              _searchFocus.requestFocus,
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
              _searchFocus.requestFocus,
          const SingleActivator(LogicalKeyboardKey.enter, control: true):
              widget.onCheckout ??
              () =>
                  showDakhlToast(context, 'مثال توضيحي فقط · لم يتم تسجيل بيع'),
          const SingleActivator(LogicalKeyboardKey.enter, meta: true):
              widget.onCheckout ??
              () =>
                  showDakhlToast(context, 'مثال توضيحي فقط · لم يتم تسجيل بيع'),
        },
        child: ColoredBox(
          color: const Color(0xFFF7F6F0),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'المبيعات / فاتورة جديدة',
                          style: TextStyle(color: DakhlTokens.muted),
                        ),
                        Semantics(
                          header: true,
                          child: Text(
                            'بيع جديد',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        const DakhlBadge('جاهز لاستقبال الطلبات'),
                        DakhlButton(
                          label: 'الطلبات المعلقة · 1',
                          onPressed: () => showDakhlToast(
                            context,
                            'طلب توضيحي محفوظ في الجلسة',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const DakhlStatus(
                  message: 'تمت استعادة فاتورتك غير المكتملة. راجع التاريخ والأسعار قبل تأكيد البيع.',
                ),
                const SizedBox(height: 16),
                if (stack) ...[
                  catalog,
                  const SizedBox(height: 16),
                  bill,
                ] else
                  Row(
                    textDirection: TextDirection.ltr,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: catalog),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: c.maxWidth <= 1100
                            ? (c.maxWidth * .34).clamp(300, 380)
                            : 380,
                        child: bill,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
  Widget _catalog() => Column(
    key: const ValueKey('sales-catalog'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final category in [
            'كل الأصناف',
            'المشاوي',
            'الدجاج',
            'الدليمية',
            'الإضافات',
            'المشروبات',
          ])
            Semantics(
              selected: _category == category,
              child: DakhlButton(
                label: category,
                backgroundColor: const Color(0xFF078657),
                kind: _category == category
                    ? DakhlButtonKind.primary
                    : DakhlButtonKind.secondary,
                onPressed: () => setState(() => _category = category),
              ),
            ),
        ],
      ),
      const SizedBox(height: 14),
      DakhlField(
        label: 'ابحث باسم الصنف أو رمزه...',
        focusNode: _searchFocus,
        onChanged: (value) => setState(() => _query = value),
      ),
      LayoutBuilder(
        builder: (context, c) {
          final large = MediaQuery.textScalerOf(context).scale(16) >= 25.6;
          final columns = large ? 1 : (c.maxWidth / 160).floor().clamp(1, 6);
          final width = (c.maxWidth - (columns - 1) * 10) / columns;
          final items = phase01CatalogFixture
              .where(
                (item) =>
                    (_category == 'كل الأصناف' || item.category == _category) &&
                    item.name.contains(_query),
              )
              .toList();
          if (items.isEmpty) return const DakhlEmptyState();
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in items)
                SizedBox(
                  width: width,
                  child: DakhlProductCard(
                    item: item,
                    onAdd: () {
                      _change('selectedItem', item.id);
                      showDakhlToast(
                        context,
                        'تم اختيار ${item.name} · مثال توضيحي',
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 8),
      const Text(
        'الصور مرجعية توضيحية',
        style: TextStyle(color: DakhlTokens.muted, fontSize: 14),
      ),
    ],
  );
  Widget _bill() => DakhlPanel(
    key: const ValueKey('sales-bill'),
    padding: const EdgeInsets.all(14),
    radius: 14,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(
              'تفاصيل الطلب',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontSize: 17),
            ),
            const DakhlBadge('صنفان'),
          ],
        ),
        const Divider(),
        _billLine('كباب لحم', '24,000', '2', 'beefQty'),
        const Divider(),
        _billLine('تمن أحمر', '2,000', '1', 'riceQty'),
        const SizedBox(height: 16),
        const _AmountLine(label: 'المجموع', amount: '26,000'),
        const SizedBox(height: 16),
        DakhlSelect<String>(
          label: 'نوع الطلب',
          compact: true,
          value: _ticket['orderType'] ?? 'صالة',
          items: [
            for (final value in ['صالة', 'سفري'])
              DropdownMenuItem(value: value, child: Text(value)),
          ],
          onChanged: (value) => _change('orderType', value ?? 'صالة'),
        ),
        DakhlField(
          label: 'تاريخ البيع',
          compact: true,
          kind: DakhlFieldKind.date,
          value: _ticket['date'] ?? '2026/10/27',
          onChanged: (v) => _change('date', v),
        ),
        DakhlField(
          label: 'خصم · د.ع',
          compact: true,
          kind: DakhlFieldKind.money,
          value: _ticket['discount'] ?? '1,000',
          onChanged: (v) => _change('discount', v),
        ),
        const Divider(),
        const _AmountLine(label: 'الإجمالي', amount: '25,000', prominent: true),
        const Text(
          'دينار عراقي',
          style: TextStyle(color: DakhlTokens.muted, fontSize: 14),
        ),
        const SizedBox(height: 14),
        DakhlButton(
          label: 'تأكيد البيع النقدي',
          backgroundColor: const Color(0xFF078657),
          icon: DakhlIconKind.check,
          kind: DakhlButtonKind.primary,
          onPressed:
              widget.onCheckout ??
              () =>
                  showDakhlToast(context, 'مثال توضيحي فقط · لم يتم تسجيل بيع'),
        ),
        const SizedBox(height: 10),
      ],
    ),
  );
  Widget _billLine(String label, String amount, String initial, String id) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 170,
                  child: DakhlQuantityControl(
                    label: 'كمية $label',
                    showLabel: false,
                    value: _ticket[id] ?? initial,
                    onChanged: (value) => _change(id, value),
                    onStep: widget.onTicketChanged == null
                        ? null
                        : (step) => _change('quantityIntent', '$id:$step'),
                  ),
                ),
                Text(
                  amount,
                  textDirection: TextDirection.ltr,
                  style: DakhlTokens.numberStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({
    required this.label,
    required this.amount,
    this.prominent = false,
  });
  final String label, amount;
  final bool prominent;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    children: [
      Text(label),
      Text(
        amount,
        textDirection: TextDirection.ltr,
        style: DakhlTokens.numberStyle.copyWith(
          fontSize: prominent ? 26 : 16,
          fontWeight: FontWeight.w600,
          color: DakhlTokens.green,
        ),
      ),
    ],
  );
}

class _InvoiceExample extends StatelessWidget {
  const _InvoiceExample({
    required this.formDraft,
    this.onFormChanged,
    this.onFormDiscard,
  });
  final Map<String, String> formDraft;
  final ValueChanged<Map<String, String>>? onFormChanged;
  final VoidCallback? onFormDiscard;
  Future<void> _open(BuildContext context) async {
    final draft = <String, String>{...formDraft};
    var dirty = false;
    Future<bool> dismiss() async {
      if (!dirty) return true;
      final discard = await showDakhlDiscardDialog(context);
      if (discard) {
        onFormDiscard?.call();
      }
      return discard;
    }

    await showDakhlDialog<void>(
      context: context,
      title: 'قائمة جديدة',
      subtitle: 'حساب مورد توضيحي',
      wide: true,
      canDismiss: dismiss,
      body: DakhlInvoiceForm(
        values: draft,
        onChanged: (key, value) {
          draft[key] = value;
          dirty = true;
          onFormChanged?.call(Map.unmodifiable(draft));
        },
      ),
      actions: [
        Builder(
          builder: (dialogContext) => DakhlButton(
            label: 'حفظ القائمة والتسديد',
            kind: DakhlButtonKind.primary,
            onPressed: () =>
                showDakhlToast(context, 'مثال توضيحي فقط · لم يتم حفظ قائمة'),
          ),
        ),
        Builder(
          builder: (dialogContext) => DakhlButton(
            label: 'إلغاء',
            onPressed: () async {
              if (await dismiss() && dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      padding: EdgeInsets.all(DakhlTokens.gutter(c.maxWidth)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 12,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'فواتير المشتريات',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              DakhlButton(
                label: 'قائمة جديدة',
                icon: DakhlIconKind.plus,
                kind: DakhlButtonKind.primary,
                onPressed: () => _open(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const DakhlEmptyState(message: 'ستظهر البيانات هنا عند توفرها.'),
        ],
      ),
    ),
  );
}

class DakhlInvoiceForm extends StatelessWidget {
  const DakhlInvoiceForm({
    super.key,
    required this.values,
    required this.onChanged,
    this.errors = const {},
    this.enabled = true,
  });
  final Map<String, String> values, errors;
  final void Function(String field, String value) onChanged;
  final bool enabled;
  Widget _field(
    String id,
    String label, {
    DakhlFieldKind kind = DakhlFieldKind.text,
    String? fallback,
    String? hint,
  }) => DakhlField(
    key: ValueKey(id),
    label: label,
    kind: kind,
    initialValue: values[id] ?? fallback,
    hintText: hint,
    errorText: errors[id],
    enabled: enabled,
    onChanged: (value) => onChanged(id, value),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final stack = DakhlTokens.stacked(context, c.maxWidth);
      Widget row(List<Widget> fields) => stack
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: fields,
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  Expanded(child: fields[i]),
                ],
              ],
            );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          row([
            _field('supplier', 'المورد', fallback: 'مورد توضيحي'),
            _field('number', 'رقم القائمة'),
            _field(
              'date',
              'تاريخ القائمة',
              kind: DakhlFieldKind.date,
              fallback: '2026/10/27',
            ),
          ]),
          const Divider(),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(
              'مواد القائمة',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          _field('material', 'المادة', hint: 'اختار أو اكتب اسم المادة'),
          row([
            _field('price', 'سعر القطعة', kind: DakhlFieldKind.money),
            _field(
              'quantity',
              'الكمية',
              kind: DakhlFieldKind.quantity,
              fallback: '0',
            ),
          ]),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('كارتون / وحدة القياس'),
            children: [
              row([
                _field(
                  'cartons',
                  'عدد الكارتونات',
                  kind: DakhlFieldKind.quantity,
                  fallback: '0',
                ),
                _field(
                  'cartonPrice',
                  'سعر الكارتون',
                  kind: DakhlFieldKind.money,
                  fallback: '0',
                ),
                _field('unit', 'وحدة القياس', fallback: 'قطعة'),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          _field('note', 'ملاحظة', hint: 'ملاحظة اختيارية للقائمة'),
          const Divider(),
          const _AmountLine(label: 'مجموع القائمة · د.ع', amount: '0'),
          const _AmountLine(label: 'الرصيد السابق · د.ع', amount: '137,500'),
        ],
      );
    },
  );
}
