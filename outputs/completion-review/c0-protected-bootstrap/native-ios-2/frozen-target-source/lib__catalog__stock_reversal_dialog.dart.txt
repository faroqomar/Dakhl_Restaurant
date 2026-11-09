import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';

import '../accounts/account_document.dart';
import '../shell/shell_view_model.dart';
import '../ui/components.dart';
import '../ui/dialogs.dart';
import 'catalog_formatters.dart';
import 'catalog_read_model.dart';
import 'catalog_view_model.dart';

Future<bool?> showStockReversalDialog(
  BuildContext context, {
  required CatalogViewModel viewModel,
  required CatalogProduct product,
  required Map<String, Object?> originalEntry,
  ShellViewModel? shell,
}) {
  final formKey = GlobalKey<_StockReversalDialogState>();
  return showDakhlDialog<bool>(
    context: context,
    title: 'تصحيح حركة المخزن',
    subtitle: product.name,
    wide: false,
    canDismiss: () async =>
        await formKey.currentState?._confirmDismiss() ?? false,
    body: StockReversalDialog(
      key: formKey,
      viewModel: viewModel,
      product: product,
      originalEntry: originalEntry,
      shell: shell,
    ),
    actions: const [],
  );
}

class StockReversalDialog extends StatefulWidget {
  const StockReversalDialog({
    super.key,
    required this.viewModel,
    required this.product,
    required this.originalEntry,
    this.shell,
  });

  final CatalogViewModel viewModel;
  final CatalogProduct product;
  final Map<String, Object?> originalEntry;
  final ShellViewModel? shell;

  @override
  State<StockReversalDialog> createState() => _StockReversalDialogState();
}

class _StockReversalDialogState extends State<StockReversalDialog> {
  late final TextEditingController _reasonController;
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
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
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
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _formError = 'يرجى إدخال سبب التصحيح.');
      return;
    }

    setState(() {
      _busy = true;
      _formError = null;
    });

    final originalId = widget.originalEntry['id'] as String;
    final newId = CatalogFormatters.generateId('rev');
    final createdAt = CatalogFormatters.currentIsoTimestamp();

    final result = await widget.viewModel.reverseMovement(
      originalId,
      session: _session,
      newId: newId,
      reason: reason,
      createdAt: createdAt,
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
        if (mounted) setState(() => _formError = 'تم إلغاء عملية التصحيح.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.originalEntry;
    final quantity = entry['quantity']?.toString() ?? '0';
    final date = entry['date']?.toString() ?? '';

    return PopScope<void>(
      canPop: true,
      child: SingleChildScrollView(
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

            Text(
              'نعكس كمية $quantity بتاريخها الأصلي $date، مع الاحتفاظ بالحركة الأصلية. بعدها تگدر تسجل الكمية الصحيحة.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(height: 1.6),
            ),
            const SizedBox(height: 16),

            DakhlField(
              label: 'سبب التصحيح',
              controller: _reasonController,
              onChanged: (_) => _markDirty(),
              enabled: !_busy,
              autofocus: true,
              maxLines: 2,
              hintText: 'مثال: خطأ في إدخال الكمية',
            ),

            const SizedBox(height: 20),

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
                  label: 'تسجيل التصحيح',
                  kind: DakhlButtonKind.primary,
                  busy: _busy,
                  onPressed: _busy ? null : _handleSave,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
