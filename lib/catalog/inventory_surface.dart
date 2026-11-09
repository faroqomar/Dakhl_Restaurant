import 'package:flutter/material.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/accounts_view_model.dart';
import '../shell/shell_routes.dart';
import '../shell/shell_view_model.dart';
import '../ui/components.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import 'catalog_formatters.dart';
import 'catalog_read_model.dart';
import 'catalog_view_model.dart';
import 'product_form_dialog.dart';
import 'product_photo_draft_controller.dart';
import 'stock_history_dialog.dart';
import 'stock_movement_dialog.dart';

/// Account-scoped inventory route surface for single-restaurant catalog management.
class InventorySurface extends StatefulWidget {
  const InventorySurface({
    super.key,
    required this.model,
    this.accounts,
    this.shell,
    this.today,
    this.onOpenSale,
  });

  final CatalogViewModel? model;
  final AccountsViewModel? accounts;
  final ShellViewModel? shell;
  final DateOnly? today;
  final ValueChanged<String>? onOpenSale;

  @override
  State<InventorySurface> createState() => _InventorySurfaceState();
}

class _InventorySurfaceState extends State<InventorySurface> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.model?.query ?? '');
    widget.model?.addListener(_onModelChange);
    widget.accounts?.addListener(_onModelChange);
  }

  @override
  void didUpdateWidget(InventorySurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model) {
      oldWidget.model?.removeListener(_onModelChange);
      widget.model?.addListener(_onModelChange);
      if (widget.model != null &&
          _searchController.text != widget.model!.query) {
        _searchController.text = widget.model!.query;
      }
    }
    if (oldWidget.accounts != widget.accounts) {
      oldWidget.accounts?.removeListener(_onModelChange);
      widget.accounts?.addListener(_onModelChange);
    }
  }

  @override
  void dispose() {
    widget.model?.removeListener(_onModelChange);
    widget.accounts?.removeListener(_onModelChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onModelChange() {
    if (mounted) setState(() {});
  }

  DateOnly get _effectiveToday => widget.today ?? CatalogFormatters.today();

  void _openCreateDialog() {
    final model = widget.model;
    if (model == null) return;
    showProductCreateDialog(
      context,
      viewModel: model,
      shell: widget.shell,
      today: _effectiveToday,
    );
  }

  void _openEditDialog(String productId) {
    final model = widget.model;
    if (model == null) return;
    showProductEditDialog(
      context,
      viewModel: model,
      productId: productId,
      shell: widget.shell,
    );
  }

  void _openStockMovementDialog(CatalogProduct product) {
    final model = widget.model;
    if (model == null) return;
    showStockMovementDialog(
      context,
      viewModel: model,
      product: product,
      shell: widget.shell,
      today: _effectiveToday,
    );
  }

  void _openStockHistoryDialog(CatalogProduct product) {
    final model = widget.model;
    if (model == null) return;
    showStockHistoryDialog(
      context,
      viewModel: model,
      product: product,
      shell: widget.shell,
      today: _effectiveToday,
      onNavigateSale: widget.onOpenSale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.accounts;
    final model = widget.model;

    // Loading / uninitialized account state
    if (accounts != null && accounts.state == AccountsState.loading) {
      return const Center(
        child: DakhlLoadingState(message: 'جارٍ تحميل بيانات المخزن…'),
      );
    }

    // Absent or protected state
    if (accounts != null && accounts.state == AccountsState.absent) {
      return const Center(
        child: DakhlEmptyState(
          title: 'لا توجد حسابات محفوظة',
          message: 'افتح الإعدادات لإعداد الحسابات أو استيراد نسخة محفوظة.',
        ),
      );
    }

    final doc = accounts?.document;
    if (model == null || doc == null) {
      return const Center(
        child: DakhlEmptyState(
          title: 'لا توجد بيانات للعرض',
          message: 'ستظهر بيانات المخزن هنا عند توفرها.',
        ),
      );
    }

    final inventory = model.inventoryModelAt(_effectiveToday);
    final catalogPage = inventory?.inventory(
      query: model.query,
      group: model.group,
      status: model.status,
      page: model.page,
    );
    if (catalogPage == null) {
      return const Center(
        child: DakhlEmptyState(
          title: 'لا توجد بيانات للعرض',
          message: 'ستظهر بيانات المخزن هنا عند توفرها.',
        ),
      );
    }

    final allProductsCount = inventory!.products.length;
    final groups = inventory.inventoryGroups;
    final lowStockCount = inventory.lowStockCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = DakhlTokens.gutter(constraints.maxWidth);
        final stacked = DakhlTokens.stacked(context, constraints.maxWidth);

        return SingleChildScrollView(
          padding: EdgeInsets.all(gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row: Title, Subtitle, and Add Product Button
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'المخزن',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: DakhlTokens.ink,
                              ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'أصناف البيع وكمياتها. كل فاتورة محفوظة تخصم من المخزون تلقائياً.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: DakhlTokens.muted),
                      ),
                    ],
                  ),
                  DakhlButton(
                    label: 'إضافة صنف',
                    icon: DakhlIconKind.plus,
                    kind: DakhlButtonKind.primary,
                    onPressed: _openCreateDialog,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Low-Stock Attention Banner (if any item needs restock)
              if (lowStockCount > 0) ...[
                DakhlPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: DakhlTokens.green,
                            size: 22,
                          ),
                          Text(
                            '$lowStockCount أصناف تحتاج تزويد',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: DakhlTokens.ink,
                                ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          DakhlButton(
                            label: 'عرض النواقص',
                            kind: DakhlButtonKind.quiet,
                            onPressed: () {
                              model.filter(status: InventoryStatus.low);
                            },
                          ),
                          if (widget.shell != null)
                            DakhlButton(
                              label: 'فتح المبيعات',
                              kind: DakhlButtonKind.quiet,
                              onPressed: () {
                                widget.shell?.navigate(ShellRoutes.sales);
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Filter Bar: Search, Status Dropdown, Group Dropdown
              DakhlFilterBar(
                actions: [
                  if (model.query.isNotEmpty ||
                      model.group.isNotEmpty ||
                      model.status != InventoryStatus.active)
                    DakhlButton(
                      label: 'إعادة ضبط التصفية',
                      kind: DakhlButtonKind.quiet,
                      onPressed: () {
                        _searchController.clear();
                        model.filter(
                          query: '',
                          group: '',
                          status: InventoryStatus.active,
                        );
                      },
                    ),
                ],
                children: [
                  // Search Field
                  DakhlField(
                    label: 'بحث الأصناف',
                    controller: _searchController,
                    hintText: 'ابحث بالاسم أو الرمز أو المجموعة…',
                    compact: true,
                    onChanged: (text) {
                      model.filter(query: text);
                    },
                  ),

                  // Status Selector
                  DakhlSelect<InventoryStatus>(
                    label: 'الحالة',
                    value: model.status,
                    compact: true,
                    items: const [
                      DropdownMenuItem(
                        value: InventoryStatus.active,
                        child: Text('النشطة'),
                      ),
                      DropdownMenuItem(
                        value: InventoryStatus.all,
                        child: Text('الكل'),
                      ),
                      DropdownMenuItem(
                        value: InventoryStatus.low,
                        child: Text('مخزون قليل'),
                      ),
                      DropdownMenuItem(
                        value: InventoryStatus.out,
                        child: Text('نافد'),
                      ),
                      DropdownMenuItem(
                        value: InventoryStatus.archived,
                        child: Text('الموقوفة'),
                      ),
                    ],
                    onChanged: (status) {
                      if (status != null) {
                        model.filter(status: status);
                      }
                    },
                  ),

                  // Group Selector
                  DakhlSelect<String>(
                    label: 'المجموعة',
                    value: model.group,
                    compact: true,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('الكل')),
                      for (final g in groups)
                        DropdownMenuItem(value: g, child: Text(g)),
                    ],
                    onChanged: (group) {
                      if (group != null) {
                        model.filter(group: group);
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Main Content: Empty State, Search Miss, Table / Cards
              if (allProductsCount == 0)
                // empty-inventory panel (approved panel 9)
                DakhlPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 36,
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: DakhlTokens.green,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'أضف أول صنف للمخزن',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: DakhlTokens.ink,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'سجّل الاسم وسعر البيع والكمية، ويصير جاهز للبيع.',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: DakhlTokens.muted),
                      ),
                      const SizedBox(height: 20),
                      DakhlButton(
                        label: 'إضافة صنف',
                        icon: DakhlIconKind.plus,
                        kind: DakhlButtonKind.primary,
                        onPressed: _openCreateDialog,
                      ),
                    ],
                  ),
                )
              else if (catalogPage.items.isEmpty)
                // Filter Miss
                DakhlPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 36,
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.search_off_outlined,
                        size: 44,
                        color: DakhlTokens.muted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'لا توجد أصناف مطابقة',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'جرّب تغيير عبارة البحث أو اختيار حالة تصفية أخرى.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: DakhlTokens.muted),
                      ),
                    ],
                  ),
                )
              else if (stacked)
                // Phone / Narrow Card List
                Column(
                  children: [
                    for (final product in catalogPage.items)
                      _ProductCardNarrow(
                        product: product,
                        onEdit: () => _openEditDialog(product.id),
                        onStock: () => _openStockMovementDialog(product),
                        onHistory: () => _openStockHistoryDialog(product),
                      ),
                  ],
                )
              else
                // Wide Desktop Table
                DakhlPanel(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      DakhlTokens.panelRadius,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth - (gutter * 2),
                        ),
                        child: DataTable(
                          headingRowColor: const WidgetStatePropertyAll(
                            DakhlTokens.soft,
                          ),
                          horizontalMargin: 16,
                          columnSpacing: 20,
                          columns: const [
                            DataColumn(label: Text('الصنف / الرمز')),
                            DataColumn(
                              label: Text('سعر البيع · د.ع'),
                              numeric: true,
                            ),
                            DataColumn(label: Text('المتوفر'), numeric: true),
                            DataColumn(label: Text('الحالة')),
                            DataColumn(label: Text('الإدارة')),
                          ],
                          rows: [
                            for (final product in catalogPage.items)
                              DataRow(
                                cells: [
                                  // Product name, group, code & photo thumbnail
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (product.photo != null &&
                                            ProductPhotoReference.assetPaths
                                                .containsKey(product.photo))
                                          Padding(
                                            padding:
                                                const EdgeInsetsDirectional.only(
                                                  end: 10,
                                                ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: Image.asset(
                                                ProductPhotoReference
                                                    .assetPaths[product.photo]!,
                                                width: 36,
                                                height: 36,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    const SizedBox(
                                                      width: 36,
                                                      height: 36,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            Text(
                                              '${product.group.isNotEmpty ? product.group : 'عام'}${product.code.isNotEmpty ? ' · ${product.code}' : ''}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: DakhlTokens.muted,
                                                    fontSize: 12,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Price
                                  DataCell(
                                    Text(
                                      CatalogFormatters.formatPrice(
                                        product.price,
                                      ),
                                      textDirection: TextDirection.ltr,
                                      style: DakhlTokens.numberStyle.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),

                                  // Available Units
                                  DataCell(
                                    Text(
                                      product.tracked
                                          ? '${CatalogFormatters.formatQuantity(product.availableUnits)} ${product.unit}'
                                          : 'غير متتبّع',
                                      textDirection: TextDirection.ltr,
                                      style: DakhlTokens.numberStyle.copyWith(
                                        color: product.tracked && product.low
                                            ? DakhlTokens.red
                                            : DakhlTokens.ink,
                                        fontWeight:
                                            product.tracked && product.low
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),

                                  // Status Badge
                                  DataCell(
                                    DakhlBadge(
                                      product.statusLabel,
                                      error: product.low || product.archived,
                                    ),
                                  ),

                                  // Action Buttons
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        DakhlButton(
                                          label: 'تعديل',
                                          kind: DakhlButtonKind.quiet,
                                          onPressed: () =>
                                              _openEditDialog(product.id),
                                        ),
                                        if (product.tracked) ...[
                                          const SizedBox(width: 4),
                                          DakhlButton(
                                            label: 'تزويد / تسوية',
                                            kind: DakhlButtonKind.quiet,
                                            onPressed: () =>
                                                _openStockMovementDialog(
                                                  product,
                                                ),
                                          ),
                                          const SizedBox(width: 4),
                                          DakhlButton(
                                            label: 'الحركة',
                                            kind: DakhlButtonKind.quiet,
                                            onPressed: () =>
                                                _openStockHistoryDialog(
                                                  product,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Pagination Controls
              if (catalogPage.pageCount > 1) ...[
                DakhlPagination(
                  caption:
                      'صفحة ${catalogPage.page} من ${catalogPage.pageCount} (إجمالي ${catalogPage.total} صنف)',
                  onPrevious: catalogPage.page > 1
                      ? () => model.selectPage(catalogPage.page - 1)
                      : null,
                  onNext: catalogPage.page < catalogPage.pageCount
                      ? () => model.selectPage(catalogPage.page + 1)
                      : null,
                ),
                const SizedBox(height: 16),
              ],

              // Footer notice from approved design
              Text(
                'المخزن يتتبّع أصناف البيع بوحدتها المحددة. مواد وفواتير الموردين مستقلة؛ استلام شراء أو تحويل مكوّنات إلى وجبات يُسجّل هنا كتزويد بالكمية الفعلية.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: DakhlTokens.muted, height: 1.5),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductCardNarrow extends StatelessWidget {
  const _ProductCardNarrow({
    required this.product,
    required this.onEdit,
    required this.onStock,
    required this.onHistory,
  });

  final CatalogProduct product;
  final VoidCallback onEdit;
  final VoidCallback onStock;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DakhlPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.photo != null &&
                  ProductPhotoReference.assetPaths.containsKey(product.photo))
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      ProductPhotoReference.assetPaths[product.photo]!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const SizedBox(width: 50, height: 50),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${product.group.isNotEmpty ? product.group : 'عام'}${product.code.isNotEmpty ? ' · ${product.code}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: DakhlTokens.muted),
                    ),
                  ],
                ),
              ),
              DakhlBadge(
                product.statusLabel,
                error: product.low || product.archived,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'السعر: ${CatalogFormatters.formatPrice(product.price)} د.ع',
                style: DakhlTokens.numberStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                product.tracked
                    ? 'المتوفر: ${CatalogFormatters.formatQuantity(product.availableUnits)} ${product.unit}'
                    : 'غير متتبّع',
                style: DakhlTokens.numberStyle.copyWith(
                  color: product.tracked && product.low
                      ? DakhlTokens.red
                      : DakhlTokens.ink,
                  fontWeight: product.tracked && product.low
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              DakhlButton(
                label: 'تعديل',
                kind: DakhlButtonKind.quiet,
                onPressed: onEdit,
              ),
              if (product.tracked) ...[
                DakhlButton(
                  label: 'تزويد / تسوية',
                  kind: DakhlButtonKind.quiet,
                  onPressed: onStock,
                ),
                DakhlButton(
                  label: 'الحركة',
                  kind: DakhlButtonKind.quiet,
                  onPressed: onHistory,
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}
