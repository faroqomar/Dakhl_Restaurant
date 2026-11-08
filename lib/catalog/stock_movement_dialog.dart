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
import 'catalog_read_model.dart';
import 'catalog_view_model.dart';

enum MovementFormKind {
  restock('تزويد', StockEntryKind.restock),
  adjustment('تسوية', StockEntryKind.adjustment),
  loss('تالف أو هدر', StockEntryKind.adjustment);

  const MovementFormKind(this.label, this.entryKind);
  final String label;
  final StockEntryKind entryKind;
}

Future<bool?> showStockMovementDialog(
  BuildContext context, {
  required CatalogViewModel viewModel,
  required CatalogProduct product,
  ShellViewModel? shell,
  DateOnly? today,
}) {
  final formKey = GlobalKey<_StockMovementDialogState>();
  return showDakhlDialog<bool>(
    context: context,
    title: 'تزويد أو تسوية المخزون',
    subtitle:
        '${product.name} · المتوفر ${CatalogFormatters.formatQuantity(product.availableUnits)} ${product.unit}',
    wide: false,
    canDismiss: () async =>
        await formKey.currentState?._confirmDismiss() ?? false,
    body: StockMovementDialog(
      key: formKey,
      viewModel: viewModel,
      product: product,
      shell: shell,
      today: today ?? CatalogFormatters.today(),
    ),
    actions: const [],
  );
}

class StockMovementDialog extends StatefulWidget {
  const StockMovementDialog({
    super.key,
    required this.viewModel,
    required this.product,
    this.shell,
    required this.today,
  });

  final CatalogViewModel viewModel;
  final CatalogProduct product;
  final ShellViewModel? shell;
  final DateOnly today;

  @override
  State<StockMovementDialog> createState() => _StockMovementDialogState();
}

class _StockMovementDialogState extends State<StockMovementDialog> {
  MovementFormKind _kind = MovementFormKind.restock;
  late final TextEditingController _quantityController;
  late final TextEditingController _dateController;
  late final TextEditingController _notesController;

  late final CatalogEditSession? _session;
  bool _busy = false;
  bool _dirty = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    try {
      _session = widget.viewModel.beginEdit();
    } catch (_) {
      _session = null;
    }
    _quantityController = TextEditingController();
    _dateController = TextEditingController(text: widget.today.toString());
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
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

  Future<bool> _confirmDismiss() async {
    if (_busy) return false;
    if (!_dirty) return true;
    final discard = await showDakhlDiscardDialog(context);
    if (discard) {
      widget.shell?.markFormDirty(false);
    }
    return discard;
  }

  Future<void> _handleSave() async {
    if (_busy || widget.viewModel.busy) return;
    if (_session == null) {
      setState(
        () => _formError = CatalogFormatters.errorMessage('stale_revision'),
      );
      return;
    }
    final qtyText = _quantityController.text.trim();
    if (qtyText.isEmpty) {
      setState(() => _formError = 'يرجى إدخال كمية الحركة.');
      return;
    }

    BigInt parsedUnits;
    try {
      if (_kind == MovementFormKind.adjustment) {
        parsedUnits = CatalogFormatters.parseQuantity(qtyText, signed: true);
        if (parsedUnits == BigInt.zero) {
          setState(
            () => _formError = CatalogFormatters.errorMessage('zero_quantity'),
          );
          return;
        }
      } else {
        parsedUnits = CatalogFormatters.parseQuantity(qtyText, positive: true);
        if (parsedUnits <= BigInt.zero) {
          setState(
            () => _formError = CatalogFormatters.errorMessage('invalid_sign'),
          );
          return;
        }
      }
    } on Object {
      setState(
        () => _formError = CatalogFormatters.errorMessage(
          'invalid_stock_quantity',
        ),
      );
      return;
    }

    DateOnly effectiveDate;
    try {
      effectiveDate = CatalogFormatters.parseDate(_dateController.text);
    } on Object {
      setState(
        () => _formError = 'تاريخ الحركة غير صالح (استخدم صيغة YYYY-MM-DD).',
      );
      return;
    }

    final notes = _notesController.text.trim();
    if ((_kind == MovementFormKind.adjustment ||
            _kind == MovementFormKind.loss) &&
        notes.isEmpty) {
      setState(
        () => _formError = 'سبب الحركة مطلوب عند التسوية أو تسجيل التالف.',
      );
      return;
    }

    // Determine exact movement delta units based on kind
    final BigInt finalDeltaUnits = switch (_kind) {
      MovementFormKind.restock => parsedUnits,
      MovementFormKind.adjustment => parsedUnits,
      MovementFormKind.loss => -parsedUnits,
    };

    final finalNote =
        _kind == MovementFormKind.loss && !notes.startsWith('تالف')
        ? 'تالف: $notes'
        : notes;

    final movement = InventoryMovement(
      id: CatalogFormatters.generateId('m'),
      productId: widget.product.id,
      quantityUnits: finalDeltaUnits,
      effectiveDate: effectiveDate,
      kind: _kind.entryKind,
      createdAt: CatalogFormatters.currentIsoTimestamp(),
      note: finalNote,
    );

    setState(() {
      _busy = true;
      _formError = null;
    });

    final result = await widget.viewModel.postMovement(
      movement,
      session: _session,
    );
    if (!mounted) return;

    setState(() => _busy = false);

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

  @override
  Widget build(BuildContext context) => PopScope<void>(
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
                const SizedBox(height: 14),
              ],

              // Movement Kind Dropdown
              DakhlSelect<MovementFormKind>(
                label: 'نوع الحركة',
                value: _kind,
                items: [
                  for (final k in MovementFormKind.values)
                    DropdownMenuItem(value: k, child: Text(k.label)),
                ],
                onChanged: _busy
                    ? null
                    : (val) {
                        if (val != null) {
                          setState(() => _kind = val);
                          _markDirty();
                        }
                      },
              ),

              // Quantity & Date
              if (stacked) ...[
                DakhlField(
                  label: _kind == MovementFormKind.adjustment
                      ? 'الكمية (موجبة للزيادة أو سالبة للنقصان)'
                      : 'الكمية (${widget.product.unit})',
                  controller: _quantityController,
                  kind: DakhlFieldKind.quantity,
                  onChanged: (_) => _markDirty(),
                  enabled: !_busy,
                  autofocus: true,
                  hintText: _kind == MovementFormKind.adjustment
                      ? '+10 أو -5'
                      : '10',
                ),
                DakhlField(
                  label: 'التاريخ',
                  controller: _dateController,
                  kind: DakhlFieldKind.date,
                  onChanged: (_) => _markDirty(),
                  enabled: !_busy,
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: DakhlField(
                        label: _kind == MovementFormKind.adjustment
                            ? 'الكمية (+ أو -)'
                            : 'الكمية (${widget.product.unit})',
                        controller: _quantityController,
                        kind: DakhlFieldKind.quantity,
                        onChanged: (_) => _markDirty(),
                        enabled: !_busy,
                        autofocus: true,
                        hintText: _kind == MovementFormKind.adjustment
                            ? '+10 أو -5'
                            : '10',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: DakhlField(
                        label: 'التاريخ',
                        controller: _dateController,
                        kind: DakhlFieldKind.date,
                        onChanged: (_) => _markDirty(),
                        enabled: !_busy,
                      ),
                    ),
                  ],
                ),

              // Notes / Reason Field
              DakhlField(
                label: _kind == MovementFormKind.restock
                    ? 'ملاحظات (اختياري)'
                    : 'سبب الحركة (مطلوب)',
                controller: _notesController,
                onChanged: (_) => _markDirty(),
                enabled: !_busy,
                maxLines: 2,
                hintText: _kind == MovementFormKind.loss
                    ? 'مثال: تلف أثناء التحضير'
                    : _kind == MovementFormKind.adjustment
                    ? 'مثال: جرد فعلي'
                    : 'استلام شراء أو تحويل داخلي',
              ),

              const SizedBox(height: 8),

              // Information Notice
              Text(
                'هذه حركة كمية فقط؛ تسجيل قيمة الشراء أو دفع المورد يبقى في فواتير المشتريات والتسديدات.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: DakhlTokens.muted, height: 1.5),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  DakhlButton(
                    label: 'إلغاء',
                    kind: DakhlButtonKind.secondary,
                    onPressed: _busy
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
                    busy: _busy,
                    onPressed: _busy ? null : _handleSave,
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
