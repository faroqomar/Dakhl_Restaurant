import 'dart:async';

import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';
import '../inventory/inventory_commands.dart';
import '../shell/shell_view_model.dart';
import '../ui/components.dart';
import '../ui/dialogs.dart';
import '../ui/theme.dart';
import 'catalog_formatters.dart';
import 'catalog_view_model.dart';
import 'product_photo_draft_controller.dart';

Future<bool?> showProductCreateDialog(
  BuildContext context, {
  required CatalogViewModel viewModel,
  ShellViewModel? shell,
  DateOnly? today,
}) {
  final formKey = GlobalKey<_ProductFormDialogState>();
  return showDakhlDialog<bool>(
    context: context,
    title: 'إضافة صنف',
    subtitle: 'سعر البيع والكمية مستقلّان عن مواد الموردين.',
    wide: true,
    canDismiss: () async =>
        await formKey.currentState?._confirmDismiss() ?? false,
    body: ProductFormDialog(
      key: formKey,
      viewModel: viewModel,
      productId: null,
      shell: shell,
      today: today ?? CatalogFormatters.today(),
    ),
    actions: const [], // Dialog actions are controlled inside form for dirty/save lifecycle
  );
}

Future<bool?> showProductEditDialog(
  BuildContext context, {
  required CatalogViewModel viewModel,
  required String productId,
  ShellViewModel? shell,
}) {
  final formKey = GlobalKey<_ProductFormDialogState>();
  return showDakhlDialog<bool>(
    context: context,
    title: 'تعديل الصنف',
    subtitle: 'سعر البيع والكمية مستقلّان عن مواد الموردين.',
    wide: true,
    canDismiss: () async =>
        await formKey.currentState?._confirmDismiss() ?? false,
    body: ProductFormDialog(
      key: formKey,
      viewModel: viewModel,
      productId: productId,
      shell: shell,
      today: CatalogFormatters.today(),
    ),
    actions: const [],
  );
}

class ProductFormDialog extends StatefulWidget {
  const ProductFormDialog({
    super.key,
    required this.viewModel,
    required this.productId,
    this.shell,
    required this.today,
  });

  final CatalogViewModel viewModel;
  final String? productId;
  final ShellViewModel? shell;
  final DateOnly today;

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  late ProductPhotoDraftController _controller;
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _unitController;
  late final TextEditingController _groupController;
  late final TextEditingController _priceController;
  late final TextEditingController _minStockController;
  late final TextEditingController _openingQtyController;
  late final TextEditingController _openingDateController;

  late CatalogEditSession _session;
  bool _isNew = true;
  bool _trackStock = true;
  bool _archived = false;
  bool _hasHistory = false;
  bool _dirty = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _session = widget.viewModel.beginEdit();
    _isNew = widget.productId == null;

    if (_isNew) {
      final generatedId = CatalogFormatters.generateId('p');
      _controller = ProductPhotoDraftController.forNew(
        viewModel: widget.viewModel,
        id: generatedId,
        unit: 'قطعة',
        trackStock: true,
      );
      _nameController = TextEditingController();
      _codeController = TextEditingController();
      _unitController = TextEditingController(text: 'قطعة');
      _groupController = TextEditingController();
      _priceController = TextEditingController(text: '0');
      _minStockController = TextEditingController(text: '0');
      _openingQtyController = TextEditingController(text: '0');
      _openingDateController = TextEditingController(
        text: widget.today.toString(),
      );
      _trackStock = true;
      _archived = false;
      _hasHistory = false;
    } else {
      _controller = ProductPhotoDraftController.forExisting(
        viewModel: widget.viewModel,
        productId: widget.productId!,
      );
      final draft = _controller.draft;
      _nameController = TextEditingController(text: draft.name);
      _codeController = TextEditingController(text: draft.code);
      _unitController = TextEditingController(text: draft.unit);
      _groupController = TextEditingController(text: draft.group);
      _priceController = TextEditingController(text: draft.price.toString());
      _minStockController = TextEditingController(
        text: draft.minStock.toInt().toString(),
      );
      _openingQtyController = TextEditingController();
      _openingDateController = TextEditingController();
      _trackStock = draft.trackStock;
      _archived = draft.archived;

      // Check whether product has history in stockEntries or sales
      final account = widget.viewModel.repository.document;
      if (account != null) {
        final entries = (account.toJson()['stockEntries'] as List?) ?? [];
        final sales = (account.toJson()['sales'] as List?) ?? [];
        _hasHistory =
            entries.any((e) => (e as Map)['productId'] == draft.id) ||
            sales.any(
              (s) =>
                  ((s as Map)['lines'] as List?)?.any(
                    (l) => (l as Map)['productId'] == draft.id,
                  ) ??
                  false,
            );
      }
    }

    _controller.addListener(_onControllerChange);
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  void _markDirty() {
    if (!_dirty) {
      _dirty = true;
      widget.shell?.markFormDirty(true);
    }
    if (_formError != null) {
      setState(() => _formError = null);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    _nameController.dispose();
    _codeController.dispose();
    _unitController.dispose();
    _groupController.dispose();
    _priceController.dispose();
    _minStockController.dispose();
    _openingQtyController.dispose();
    _openingDateController.dispose();
    super.dispose();
  }

  Future<bool> _confirmDismiss() async {
    if (_controller.isBusy || widget.viewModel.busy) return false;
    if (!_dirty) return true;
    final discard = await showDakhlDiscardDialog(context);
    if (discard) {
      widget.shell?.markFormDirty(false);
    }
    return discard;
  }

  Future<void> _handleSave() async {
    if (_controller.isBusy || widget.viewModel.busy) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(
        () => _formError = CatalogFormatters.errorMessage('required_name'),
      );
      return;
    }

    int price;
    num minStock;
    try {
      price = ExactDecimal.parse(
        _priceController.text.trim().isEmpty
            ? '0'
            : _priceController.text.trim(),
        scale: 0,
        maxAbsUnits: BigInt.from(1000000000000),
        signed: true,
        positive: false,
        normalizeDigits: true,
        allowGrouping: true,
      ).units.toInt();
    } on Object catch (error) {
      setState(
        () => _formError =
            error is DomainValidationException && error.code == 'invalid_sign'
            ? 'سعر البيع لا يمكن أن يكون سالباً.'
            : 'أدخل سعر بيع صحيحاً ضمن الحدود المسموحة.',
      );
      return;
    }
    if (price < 0) {
      setState(() => _formError = 'سعر البيع لا يمكن أن يكون سالباً.');
      return;
    }
    try {
      final minimumUnits = CatalogFormatters.parseQuantity(
        _minStockController.text.trim().isEmpty
            ? '0'
            : _minStockController.text,
      );
      minStock = num.parse(ExactDecimal.fromUnits(minimumUnits, 3).toString());
    } catch (_) {
      setState(
        () => _formError = 'أدخل حداً أدنى صحيحاً للمخزون ضمن الحدود المسموحة.',
      );
      return;
    }

    // Sync draft fields to controller
    final draft = _controller.draft;
    draft.name = name;
    draft.code = _codeController.text.trim();
    draft.group = _groupController.text.trim();
    draft.price = price;
    draft.archived = _archived;
    if (!_hasHistory) {
      draft.unit = _unitController.text.trim().isEmpty
          ? 'قطعة'
          : _unitController.text.trim();
      draft.trackStock = _trackStock;
    }
    draft.minStock = _trackStock ? minStock : 0;

    InventoryMovement? openingMovement;
    if (_isNew && _trackStock) {
      final openingText = _openingQtyController.text.trim();
      if (openingText.isNotEmpty && openingText != '0') {
        BigInt openingUnits;
        try {
          openingUnits = CatalogFormatters.parseQuantity(
            openingText,
            positive: false,
          );
        } on Object {
          setState(
            () => _formError = CatalogFormatters.errorMessage(
              'invalid_stock_quantity',
            ),
          );
          return;
        }

        if (openingUnits > BigInt.zero) {
          DateOnly effectiveDate;
          try {
            effectiveDate = CatalogFormatters.parseDate(
              _openingDateController.text,
            );
          } on Object {
            setState(() => _formError = 'تاريخ الكمية الافتتاحية غير صالح.');
            return;
          }

          openingMovement = InventoryMovement(
            id: CatalogFormatters.generateId('m'),
            productId: draft.id,
            quantityUnits: openingUnits,
            effectiveDate: effectiveDate,
            kind: StockEntryKind.opening,
            createdAt: CatalogFormatters.currentIsoTimestamp(),
            note: 'كمية افتتاحية',
          );
        }
      }
    }

    setState(() => _formError = null);

    final result = await _controller.saveProduct(
      session: _session,
      opening: openingMovement,
    );
    if (!mounted) return;

    switch (result) {
      case CapabilitySuccess<AccountDocument>(:final value):
        if (!identical(widget.viewModel.repository.document, value)) {
          setState(
            () => _formError = CatalogFormatters.errorMessage('stale_revision'),
          );
          return;
        }
        widget.shell?.markFormDirty(false);
        if (mounted) Navigator.of(context).pop(true);
      case CapabilityFailure(:final code):
        if (mounted) {
          setState(() => _formError = CatalogFormatters.errorMessage(code));
        }
      case CapabilityCancelled():
        if (mounted) setState(() => _formError = 'تم إلغاء عملية الحفظ.');
    }
  }

  Future<void> _handleArchiveToggle() async {
    if (_controller.isBusy || widget.viewModel.busy) return;
    if (_isNew) {
      setState(() {
        _archived = !_archived;
        _markDirty();
      });
      return;
    }

    // Direct toggle on persisted product
    final next = !_archived;

    final result = await widget.viewModel.setArchived(
      _controller.draft.id,
      next,
      session: _session,
    );
    if (!mounted) return;

    switch (result) {
      case CapabilitySuccess<AccountDocument>(:final value):
        if (!identical(widget.viewModel.repository.document, value)) {
          setState(
            () => _formError = CatalogFormatters.errorMessage('stale_revision'),
          );
          return;
        }
        final selectedPhoto = _controller.draft.photo;
        _controller.removeListener(_onControllerChange);
        _controller.dispose();
        _controller = ProductPhotoDraftController.forExisting(
          viewModel: widget.viewModel,
          productId: _controller.draft.id,
        );
        _controller.selectReferencePhoto(selectedPhoto);
        _controller.addListener(_onControllerChange);
        _session = widget.viewModel.beginEdit();
        setState(() => _archived = next);
      case CapabilityFailure(:final code):
        if (mounted) {
          setState(() => _formError = CatalogFormatters.errorMessage(code));
        }
      case CapabilityCancelled():
        if (mounted) setState(() => _formError = 'تم إلغاء العملية.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _controller.preview;
    final isBusy = _controller.isBusy || widget.viewModel.busy;

    return PopScope<void>(
      canPop: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = DakhlTokens.stacked(context, constraints.maxWidth);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_formError != null) ...[
                  DakhlStatus(
                    message: _formError!,
                    kind: DakhlStatusKind.error,
                    onRetry: _handleSave,
                  ),
                  const SizedBox(height: 16),
                ],

                // Product Name & Barcode
                if (stacked) ...[
                  DakhlField(
                    label: 'اسم الصنف',
                    controller: _nameController,
                    onChanged: (_) => _markDirty(),
                    enabled: !isBusy,
                    autofocus: true,
                  ),
                  DakhlField(
                    label: 'رمز الصنف / الباركود (اختياري)',
                    controller: _codeController,
                    onChanged: (_) => _markDirty(),
                    enabled: !isBusy,
                  ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: DakhlField(
                          label: 'اسم الصنف',
                          controller: _nameController,
                          onChanged: (_) => _markDirty(),
                          enabled: !isBusy,
                          autofocus: true,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: DakhlField(
                          label: 'رمز الصنف / الباركود (اختياري)',
                          controller: _codeController,
                          onChanged: (_) => _markDirty(),
                          enabled: !isBusy,
                        ),
                      ),
                    ],
                  ),

                // Unit, Group & Price
                if (stacked) ...[
                  DakhlField(
                    label: 'الوحدة',
                    controller: _unitController,
                    onChanged: (_) => _markDirty(),
                    enabled: !isBusy && !_hasHistory,
                    helperText: _hasHistory
                        ? 'الوحدة ثابتة لوجود حركات سابقة'
                        : null,
                  ),
                  DakhlField(
                    label: 'المجموعة (اختياري)',
                    controller: _groupController,
                    onChanged: (_) => _markDirty(),
                    enabled: !isBusy,
                  ),
                  DakhlField(
                    label: 'سعر البيع بالدينار · د.ع',
                    controller: _priceController,
                    kind: DakhlFieldKind.money,
                    onChanged: (_) => _markDirty(),
                    enabled: !isBusy,
                  ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DakhlField(
                          label: 'الوحدة',
                          controller: _unitController,
                          onChanged: (_) => _markDirty(),
                          enabled: !isBusy && !_hasHistory,
                          helperText: _hasHistory
                              ? 'الوحدة ثابتة لوجود حركات سابقة'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: DakhlField(
                          label: 'المجموعة (اختياري)',
                          controller: _groupController,
                          onChanged: (_) => _markDirty(),
                          enabled: !isBusy,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: DakhlField(
                          label: 'سعر البيع بالدينار · د.ع',
                          controller: _priceController,
                          kind: DakhlFieldKind.money,
                          onChanged: (_) => _markDirty(),
                          enabled: !isBusy,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),

                // Reference Photo Selector
                Semantics(
                  header: true,
                  child: Text(
                    'صورة مرجعية للصنف',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  preview.hasPhoto
                      ? 'الصورة المختارة: ${preview.label}'
                      : 'بدون صورة مرجعية',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: DakhlTokens.muted),
                ),
                const SizedBox(height: 8),

                // 8 Canonical Reference Photos Selector Grid
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final key in ProductPhotoReference.canonicalKeys)
                      _PhotoReferenceThumbnail(
                        photoKey: key,
                        isSelected: preview.key == key,
                        enabled: !isBusy,
                        onTap: () {
                          _controller.selectReferencePhoto(key);
                          _markDirty();
                        },
                      ),
                    _NoPhotoThumbnail(
                      isSelected: !preview.hasPhoto,
                      enabled: !isBusy,
                      onTap: () {
                        _controller.removePhoto();
                        _markDirty();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Track Stock Checkbox / Option
                DakhlPanel(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _trackStock,
                            onChanged: isBusy || _hasHistory
                                ? null
                                : (v) {
                                    setState(() => _trackStock = v ?? true);
                                    _markDirty();
                                  },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تتبّع كمية هذا الصنف',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  _hasHistory
                                      ? 'التتبّع ثابت لوجود حركات أو مبيعات مسجلة.'
                                      : 'ألغِ التتبّع للوجبات التي لا تبيعها بكمية مخزنية محددة. بعد تسجيل حركة تبقى طريقة التتبّع ثابتة.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: DakhlTokens.muted,
                                        fontSize: 12,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (_trackStock) ...[
                        const SizedBox(height: 14),
                        if (_isNew) ...[
                          if (stacked) ...[
                            DakhlField(
                              label: 'الكمية الافتتاحية',
                              controller: _openingQtyController,
                              kind: DakhlFieldKind.quantity,
                              onChanged: (_) => _markDirty(),
                              enabled: !isBusy,
                            ),
                            DakhlField(
                              label: 'تاريخ الكمية',
                              controller: _openingDateController,
                              kind: DakhlFieldKind.date,
                              onChanged: (_) => _markDirty(),
                              enabled: !isBusy,
                            ),
                            DakhlField(
                              label: 'تنبيه عند وصول الكمية إلى (الحد الأدنى)',
                              controller: _minStockController,
                              kind: DakhlFieldKind.quantity,
                              onChanged: (_) => _markDirty(),
                              enabled: !isBusy,
                            ),
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: DakhlField(
                                    label: 'الكمية الافتتاحية',
                                    controller: _openingQtyController,
                                    kind: DakhlFieldKind.quantity,
                                    onChanged: (_) => _markDirty(),
                                    enabled: !isBusy,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: DakhlField(
                                    label: 'تاريخ الكمية',
                                    controller: _openingDateController,
                                    kind: DakhlFieldKind.date,
                                    onChanged: (_) => _markDirty(),
                                    enabled: !isBusy,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: DakhlField(
                                    label: 'الحد الأدنى للمخزون',
                                    controller: _minStockController,
                                    kind: DakhlFieldKind.quantity,
                                    onChanged: (_) => _markDirty(),
                                    enabled: !isBusy,
                                  ),
                                ),
                              ],
                            ),
                        ] else ...[
                          DakhlField(
                            label: 'تنبيه عند وصول الكمية إلى (الحد الأدنى للمخزون)',
                            controller: _minStockController,
                            kind: DakhlFieldKind.quantity,
                            onChanged: (_) => _markDirty(),
                            enabled: !isBusy,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Archive / Restore status on existing product
                if (!_isNew) ...[
                  Row(
                    children: [
                      DakhlButton(
                        label: _archived
                            ? 'استعادة الصنف للبيع'
                            : 'إيقاف الصنف مؤقتاً',
                        kind: _archived
                            ? DakhlButtonKind.primary
                            : DakhlButtonKind.danger,
                        onPressed: isBusy ? null : _handleArchiveToggle,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _archived
                              ? 'الصنف موقوف حالياً ولا يظهر في شاشة البيع.'
                              : 'إيقاف الصنف يخفيه من المبيعات مع الاحتفاظ بكافة سجلاته.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: DakhlTokens.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 8),

                // Action Buttons: Save & Cancel
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    DakhlButton(
                      label: 'إلغاء',
                      kind: DakhlButtonKind.secondary,
                      onPressed: isBusy
                          ? null
                          : () async {
                              final navigator = Navigator.of(context);
                              if (await _confirmDismiss() && mounted) {
                                navigator.pop(false);
                              }
                            },
                    ),
                    DakhlButton(
                      label: 'حفظ التغيير',
                      kind: DakhlButtonKind.primary,
                      busy: isBusy,
                      onPressed: isBusy ? null : _handleSave,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PhotoReferenceThumbnail extends StatelessWidget {
  const _PhotoReferenceThumbnail({
    required this.photoKey,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final String photoKey;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final assetPath = ProductPhotoReference.assetPaths[photoKey];
    final label = ProductPhotoReference.labels[photoKey] ?? photoKey;

    return Semantics(
      label: 'اختيار صورة $label',
      selected: isSelected,
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(DakhlTokens.photoRadius),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DakhlTokens.photoRadius),
            border: Border.all(
              color: isSelected ? DakhlTokens.green : DakhlTokens.line,
              width: isSelected ? 3 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (assetPath != null)
                Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.image,
                      size: 24,
                      color: DakhlTokens.muted,
                    ),
                  ),
                ),
              if (isSelected)
                Container(
                  color: DakhlTokens.green.withValues(alpha: 0.25),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.check_circle,
                    color: DakhlTokens.paper,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoPhotoThumbnail extends StatelessWidget {
  const _NoPhotoThumbnail({
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'بدون صورة',
    selected: isSelected,
    button: true,
    enabled: enabled,
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(DakhlTokens.photoRadius),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DakhlTokens.photoRadius),
          color: DakhlTokens.background,
          border: Border.all(
            color: isSelected ? DakhlTokens.green : DakhlTokens.line,
            width: isSelected ? 3 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: ExcludeSemantics(
          child: Text(
            'بدون\nصورة',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: isSelected ? DakhlTokens.green : DakhlTokens.muted,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    ),
  );
}
