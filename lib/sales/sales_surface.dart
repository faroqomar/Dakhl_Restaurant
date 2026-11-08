import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:madar_application/madar_application.dart';

import '../catalog/catalog_formatters.dart';
import '../catalog/catalog_read_model.dart';
import '../catalog/product_photo_draft_controller.dart';
import '../ui/components.dart';
import '../ui/dialogs.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import 'sales_view_model.dart';
import 'sales_workflow_session.dart';
import 'ticket_workspace.dart';
import 'held_orders_dialog.dart';
import 'sale_paid_dialog.dart';

/// Approved C2 core. Schema-11 mounting permits draft actions only. Only an
/// explicitly initialized portable session can display a paid confirmation.
class SalesSurface extends StatefulWidget {
  const SalesSurface({
    super.key,
    this.model,
    this.session,
    this.searchFocusNode,
    this.onPendingInputChanged,
    this.onOpenReceipt,
  }) : assert(model == null || session == null);
  final SalesViewModel? model;
  final SalesWorkflowSession? session;
  final FocusNode? searchFocusNode;

  /// Shell uses this signal to protect navigation while raw input awaits save.
  final ValueChanged<bool>? onPendingInputChanged;
  final ValueChanged<String>? onOpenReceipt;
  @override
  State<SalesSurface> createState() => _SalesSurfaceState();
}

class _SalesSurfaceState extends State<SalesSurface> {
  final _search = TextEditingController();
  final _date = TextEditingController();
  final _discount = TextEditingController();
  final _note = TextEditingController();
  final _localFocus = FocusNode(debugLabel: 'sales-catalog-search');
  final _quantities = <String, String>{};
  Timer? _debounce;
  TicketDraft? _pendingClear;
  String? _ticketId, _error;
  bool _detailsDirty = false, _working = false, _compact = false;
  Listenable? get _source => widget.session ?? widget.model;
  TicketDraft? get _ticket => widget.session?.active ?? widget.model?.active;
  bool get _busy =>
      _working ||
      (widget.session?.busy ?? widget.model?.busy ?? true) ||
      (widget.session?.externallyBlocked ?? false);
  bool get _needsDraftReadback =>
      widget.session?.draftNeedsReadback ??
      widget.model?.needsReadback ??
      false;
  bool get _editingBlocked =>
      _busy ||
      _needsDraftReadback ||
      (widget.session?.checkoutPending ?? false);
  CatalogPage? get _catalog => widget.session?.catalog ?? widget.model?.catalog;
  List<HeldTicket> get _held =>
      widget.session?.held ?? widget.model?.held ?? const [];
  SalesTicketQuote? get _quote => widget.session?.quote ?? widget.model?.quote;
  List<String> get _groups =>
      widget.session?.groups ?? widget.model?.groups ?? const [];
  List<String> get _types =>
      widget.session?.orderTypes ?? widget.model?.orderTypes ?? const [];

  @override
  void initState() {
    super.initState();
    _source?.addListener(_changed);
    _initialize();
  }

  @override
  void didUpdateWidget(SalesSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.session ?? oldWidget.model;
    if (old != _source) {
      old?.removeListener(_changed);
      _source?.addListener(_changed);
      _debounce?.cancel();
      _ticketId = null;
      _quantities.clear();
      _detailsDirty = false;
      _initialize();
    }
  }

  TicketDraft _fresh() => TicketDraft(
    id: CatalogFormatters.generateId('ticket'),
    date: CatalogFormatters.today().toString(),
    orderType: _types.isEmpty ? 'سفري' : _types.first,
    discount: '',
    note: '',
    lines: [],
  );

  Future<void> _initialize() async {
    final model = widget.model;
    if (model != null &&
        !model.loaded &&
        !model.busy &&
        model.authorityFence != null) {
      await model.load(_fresh());
    }
    _changed();
  }

  void _changed() {
    if (!mounted) return;
    final ticket = _ticket;
    if (ticket != null && ticket.id != _ticketId) {
      _ticketId = ticket.id;
      _date.text = ticket.date;
      _discount.text = ticket.discount;
      _note.text = ticket.note;
      _detailsDirty = false;
      _quantities.clear();
    }
    setState(() {});
  }

  void _queueDetails(String _) {
    _detailsDirty = true;
    widget.onPendingInputChanged?.call(true);
    _queue();
  }

  void _queue() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!_busy && mounted) {
        _run(() async => const CapabilitySuccess<void>(null));
      }
    });
  }

  Future<CapabilityResult<void>> _updateDetails() =>
      widget.session?.updateDetails(
        date: _date.text,
        discount: _discount.text,
        note: _note.text,
      ) ??
      widget.model!.updateDetails(
        date: _date.text,
        discount: _discount.text,
        note: _note.text,
      );
  Future<CapabilityResult<void>> _quantity(String id, String value) =>
      widget.session?.setQuantity(id, value) ??
      widget.model!.setQuantity(id, value);
  Future<bool> _flush() async {
    _debounce?.cancel();
    if (_detailsDirty) {
      final result = await _updateDetails();
      if (result is! CapabilitySuccess<void>) {
        _error = _message(result);
        return false;
      }
      _detailsDirty = false;
    }
    for (final entry in _quantities.entries.toList()) {
      final result = await _quantity(entry.key, entry.value);
      if (result is! CapabilitySuccess<void>) {
        _error = _message(result);
        return false;
      }
      _quantities.remove(entry.key);
    }
    widget.onPendingInputChanged?.call(false);
    return true;
  }

  Future<void> _run(Future<CapabilityResult<void>> Function() action) async {
    if (_busy) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      if (!await _flush() || !mounted) return;
      final result = await action();
      if (result is! CapabilitySuccess<void>) _error = _message(result);
    } on Object {
      _error = 'تعذّر تأكيد الحفظ. بقيت مدخلاتك؛ أعد المحاولة.';
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _message(CapabilityResult<dynamic> result) =>
      _salesError(result is CapabilityFailure ? result.code : 'unavailable');
  String _salesError(String? code) => switch (code) {
    'archived_product' => 'احذف الصنف الموقوف من الطلب حتى تكمل.',
    'insufficient_stock' =>
      'كمية الطلب أكثر من المتوفر بتاريخ البيع؛ عدّل الكمية.',
    'held_limit' => 'وصلت إلى الحد الأقصى للطلبات المعلقة (40).',
    'invalid_order_type' => 'اختار نوع طلب متاحاً قبل تأكيد البيع.',
    'finalized_ticket' => 'هذه الفاتورة محفوظة؛ افتحها من سجل المبيعات.',
    'commit_unknown' => 'تعذّر تأكيد الحفظ؛ أعد التحقق قبل تكرار العملية.',
    _ => CatalogFormatters.errorMessage(code),
  };

  Future<void> _reload() async {
    if (_busy || widget.session?.checkoutPending == true) return;
    setState(() => _working = true);
    try {
      final session = widget.session;
      final model = widget.model;
      final result = session != null
          ? (session.draftNeedsReadback
                ? await session.reconcileDraft()
                : await session.refreshAccount(fresh: _fresh()))
          : model!.needsReadback
          ? await model.reconcile()
          : await model.load(_ticket ?? _fresh());
      _error = result is CapabilitySuccess<void> ? null : _message(result);
      final pending = _pendingClear;
      if (result is CapabilitySuccess<void> && pending != null) {
        if (_ticket?.id == pending.id) {
          widget.onPendingInputChanged?.call(false);
        } else {
          _error = 'لم يُؤكّد تفريغ الفاتورة؛ بقيت مدخلاتك.';
        }
        _pendingClear = null;
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _clear() async {
    if (_editingBlocked) return;
    final confirmed = await showDakhlDialog<bool>(
      context: context,
      title: 'تفريغ الفاتورة الحالية؟',
      body: const Text(
        'الأصناف غير المحفوظة ستُحذف؛ الطلبات المعلقة والفواتير المحفوظة تبقى كما هي.',
      ),
      actions: [
        Builder(
          builder: (ctx) => DakhlButton(
            label: 'تفريغ الفاتورة',
            kind: DakhlButtonKind.danger,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    _debounce?.cancel();
    final fresh = _fresh();
    setState(() => _working = true);
    try {
      _pendingClear = fresh;
      final result =
          await (widget.session?.clear(fresh) ?? widget.model!.clear(fresh));
      if (result is CapabilitySuccess<void>) {
        _pendingClear = null;
        _error = null;
        widget.onPendingInputChanged?.call(false);
      } else {
        _error = _message(result);
        if (!_needsDraftReadback) _pendingClear = null;
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _stepLine(String id, int step) => _run(() {
    final current = _ticket!.lines.firstWhere((line) => line.productId == id);
    if (step > 0) {
      return widget.session?.addProduct(id) ?? widget.model!.addProduct(id);
    }
    if (current.quantityUnits <= BigInt.from(1000)) {
      return widget.session?.removeProduct(id) ??
          widget.model!.removeProduct(id);
    }
    return _quantity(
      id,
      CatalogFormatters.formatQuantity(
        current.quantityUnits - BigInt.from(1000),
      ),
    );
  });

  Future<void> _hold() async {
    if (_busy || _ticket?.lines.isEmpty != false) return;
    await _run(() async => const CapabilitySuccess<void>(null));
    if (!mounted || _error != null) return;
    final session = widget.session;
    final model = widget.model;
    await showHoldOrderDialog(
      context,
      updates: _source!,
      fresh: _fresh,
      active: () => session?.active ?? model?.active,
      held: () => session?.held ?? model?.held ?? const [],
      needsReadback: () =>
          session?.draftNeedsReadback ?? model?.needsReadback ?? false,
      onDirty: widget.onPendingInputChanged,
      reconcile: () => session?.reconcileDraft() ?? model!.reconcile(),
      hold: (label, id, fresh, stamp) =>
          session?.hold(
            label: label,
            heldId: id,
            fresh: fresh,
            savedAt: stamp,
          ) ??
          model!.hold(label: label, heldId: id, fresh: fresh, savedAt: stamp),
    );
  }

  Future<void> _showHeld() async {
    if (_busy) return;
    await _run(() async => const CapabilitySuccess<void>(null));
    if (!mounted || _error != null) return;
    final session = widget.session;
    final model = widget.model;
    await showHeldOrdersDialog(
      context,
      updates: _source!,
      active: () => session?.active ?? model?.active,
      held: () => session?.held ?? model?.held ?? const [],
      needsReadback: () =>
          session?.draftNeedsReadback ?? model?.needsReadback ?? false,
      reconcile: () => session?.reconcileDraft() ?? model!.reconcile(),
      delete: (id) => session?.deleteHeld(id) ?? model!.deleteHeld(id),
      resume: (id, swap, stamp) =>
          session?.resume(
            id,
            swapId: swap,
            swapLabel: 'طلب معلق',
            savedAt: stamp,
          ) ??
          model!.resume(
            id,
            swapId: swap,
            swapLabel: 'طلب معلق',
            savedAt: stamp,
          ),
    );
  }

  Future<void> _checkout() async {
    final session = widget.session;
    if (session == null || _busy) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      if (!await _flush() || !mounted) return;
      final result = session.checkoutPending
          ? await session.retryCheckout()
          : await session.checkout(
              fresh: _fresh(),
              operationId: CatalogFormatters.generateId('sale-op'),
              journalId: CatalogFormatters.generateId('sale-journal'),
              recordedAt: CatalogFormatters.currentIsoTimestamp(),
            );
      if (!mounted) return;
      if (result is CapabilitySuccess) {
        final outcome = session.operations.lastOutcome!;
        final action = await showSalePaidDialog(
          context,
          account: session.operations.account,
          saleId: outcome.saleId,
          canOpenDetails: widget.onOpenReceipt != null,
        );
        if (action == 'details' && mounted) {
          widget.onOpenReceipt?.call(outcome.saleId);
        }
      } else {
        _error = _message(result);
      }
    } on Object {
      _error = 'تعذّر تأكيد البيع؛ تحقق من الحالة قبل المحاولة.';
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    if (ticket == null) {
      return const Center(
        child: DakhlEmptyState(
          title: 'لا توجد فاتورة مفتوحة',
          message: 'افتح الحسابات من الإعدادات لبدء البيع.',
        ),
      );
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            (widget.searchFocusNode ?? _localFocus).requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            (widget.searchFocusNode ?? _localFocus).requestFocus,
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            _checkout,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _checkout,
      },
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.all(DakhlTokens.gutter(constraints.maxWidth)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 10,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'المبيعات / فاتورة جديدة',
                        style: TextStyle(color: DakhlTokens.muted),
                      ),
                      Text(
                        'بيع جديد',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      DakhlButton(
                        label: 'الطلبات المعلقة · ${_held.length}',
                        onPressed: _editingBlocked ? null : _showHeld,
                      ),
                      DakhlButton(
                        label: 'اختصارات البيع',
                        onPressed: () => showDakhlDialog<void>(
                          context: context,
                          title: 'اختصارات البيع',
                          body: const Text(
                            '⌘/Ctrl + K للبحث عن صنف. ⌘/Ctrl + Enter لتأكيد البيع النقدي. تبقى المدخلات عند تعذّر الحفظ.',
                          ),
                          actions: const [],
                        ),
                      ),
                      DakhlButton(
                        label: _compact ? 'عرض الصور' : 'عرض مدمج',
                        onPressed: () => setState(() => _compact = !_compact),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_error != null ||
                  widget.model?.errorCode != null ||
                  widget.session?.errorCode != null) ...[
                DakhlStatus(
                  message:
                      _error ??
                      _salesError(
                        widget.session?.errorCode ?? widget.model?.errorCode,
                      ),
                ),
                if (widget.model != null || widget.session != null)
                  DakhlButton(
                    label: 'إعادة قراءة الطلب المحفوظ',
                    onPressed: _busy ? null : _reload,
                  ),
                const SizedBox(height: 12),
              ],
              if (_busy)
                const LinearProgressIndicator(semanticsLabel: 'جارٍ حفظ الطلب'),
              if (constraints.maxWidth <= 760 ||
                  MediaQuery.textScalerOf(context).scale(16) >= 25.6)
                Column(
                  children: [
                    _catalogPanel(),
                    const SizedBox(height: 16),
                    _bill(ticket),
                  ],
                )
              else
                Row(
                  textDirection: TextDirection.ltr,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _catalogPanel()),
                    const SizedBox(width: 20),
                    SizedBox(width: 360, child: _bill(ticket)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _catalogPanel() {
    final catalog = _catalog;
    final counts =
        widget.session?.groupCounts ??
        widget.model?.groupCounts ??
        const <String, int>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final group in ['', ..._groups])
              Semantics(
                selected:
                    (widget.session?.group ?? widget.model?.group ?? '') ==
                    group,
                child: DakhlButton(
                  label:
                      '${group.isEmpty ? 'كل الأصناف' : group} · ${counts[group] ?? 0}',
                  kind:
                      (widget.session?.group ?? widget.model?.group ?? '') ==
                          group
                      ? DakhlButtonKind.primary
                      : DakhlButtonKind.secondary,
                  onPressed: _busy
                      ? null
                      : () => widget.session != null
                            ? widget.session!.filter(group: group)
                            : widget.model!.filter(group: group),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        DakhlField(
          label: 'ابحث باسم الصنف أو رمزه...',
          controller: _search,
          focusNode: widget.searchFocusNode ?? _localFocus,
          onChanged: (value) => widget.session != null
              ? widget.session!.filter(query: value)
              : widget.model!.filter(query: value),
        ),
        if (catalog == null || catalog.items.isEmpty)
          const DakhlEmptyState(
            title: 'لا توجد أصناف',
            message: 'جرّب تغيير البحث أو المجموعة.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / (_compact ? 140 : 160))
                  .floor()
                  .clamp(1, 6);
              final width =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in catalog.items)
                    SizedBox(width: width, child: _product(item)),
                ],
              );
            },
          ),
        if (catalog != null && catalog.pageCount > 1)
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DakhlButton(
                label: 'السابق',
                onPressed: _busy || catalog.page <= 1
                    ? null
                    : () => _page(catalog.page - 1),
              ),
              Text('${catalog.page} / ${catalog.pageCount}'),
              DakhlButton(
                label: 'التالي',
                onPressed: _busy || catalog.page >= catalog.pageCount
                    ? null
                    : () => _page(catalog.page + 1),
              ),
            ],
          ),
      ],
    );
  }

  void _page(int page) => widget.session != null
      ? widget.session!.selectPage(page)
      : widget.model!.selectPage(page);
  Widget _product(CatalogProduct item) {
    final inCart =
        _ticket?.lines
            .where((line) => line.productId == item.id)
            .map((line) => line.quantityUnits)
            .firstOrNull ??
        BigInt.zero;
    final unavailable = item.tracked && item.availableUnits <= inCart;
    final photo = ProductPhotoReference.assetPathFor(item.photo);
    return DakhlPanel(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: _compact ? 2.1 : 1.65,
                child: Image.asset(
                  photo,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          Text(item.group, style: Theme.of(context).textTheme.bodySmall),
          Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            '${CatalogFormatters.formatPrice(item.price)} د.ع',
            style: const TextStyle(
              color: DakhlTokens.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (item.tracked)
            Text(
              'بالمخزن ${CatalogFormatters.formatQuantity(item.availableUnits)} · بالطلب ${CatalogFormatters.formatQuantity(inCart)} ${item.unit}',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Text(
              inCart > BigInt.zero
                  ? 'بالطلب ${CatalogFormatters.formatQuantity(inCart)} ${item.unit}'
                  : item.unit,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          DakhlButton(
            label: 'إضافة ${item.name}',
            icon: DakhlIconKind.plus,
            kind: DakhlButtonKind.primary,
            onPressed: _editingBlocked || unavailable
                ? null
                : () => _run(
                    () =>
                        widget.session?.addProduct(item.id) ??
                        widget.model!.addProduct(item.id),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _bill(TicketDraft ticket) {
    final raw =
        widget.session?.operations.account.toJson() ??
        widget.model?.repository.document?.toJson();
    final products = (raw?['products'] as List? ?? const [])
        .cast<Map<String, Object?>>();
    final calculation = _quote?.calculation;
    final posting = widget.session?.operations.postingEnabled ?? false;
    return DakhlPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('تفاصيل الطلب', style: Theme.of(context).textTheme.titleLarge),
          const Divider(),
          if (ticket.lines.isEmpty) const Text('اختر صنفاً لإضافته إلى الطلب.'),
          for (final line in ticket.lines) ...[
            Text(
              products
                      .where((item) => item['id'] == line.productId)
                      .map((item) => item['name'] as String)
                      .firstOrNull ??
                  line.productId,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: DakhlQuantityControl(
                    label: 'كمية ${line.productId}',
                    showLabel: false,
                    value:
                        _quantities[line.productId] ??
                        CatalogFormatters.formatQuantity(line.quantityUnits),
                    enabled: !_editingBlocked,
                    onChanged: (value) {
                      _quantities[line.productId] = value;
                      widget.onPendingInputChanged?.call(true);
                      _queue();
                    },
                    onStep: (step) => _stepLine(line.productId, step),
                  ),
                ),
                IconButton(
                  tooltip: 'إزالة الصنف',
                  onPressed: _editingBlocked
                      ? null
                      : () => _run(
                          () =>
                              widget.session?.removeProduct(line.productId) ??
                              widget.model!.removeProduct(line.productId),
                        ),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              '${CatalogFormatters.formatPrice(line.price)} د.ع / وحدة',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(),
          ],
          Text(
            'المجموع: ${CatalogFormatters.formatPrice(calculation?.subtotal.toInt() ?? 0)} د.ع',
          ),
          const SizedBox(height: 12),
          DakhlSelect<String>(
            label: 'نوع الطلب',
            value: _types.contains(ticket.orderType) ? ticket.orderType : null,
            compact: true,
            enabled: !_editingBlocked,
            items: [
              for (final type in _types)
                DropdownMenuItem(value: type, child: Text(type)),
            ],
            onChanged: (type) {
              if (type != null) {
                _run(
                  () =>
                      widget.session?.updateDetails(orderType: type) ??
                      widget.model!.updateDetails(orderType: type),
                );
              }
            },
          ),
          DakhlField(
            label: 'تاريخ البيع',
            controller: _date,
            compact: true,
            enabled: !_editingBlocked,
            onChanged: _queueDetails,
          ),
          DakhlField(
            label: 'خصم · د.ع',
            controller: _discount,
            compact: true,
            enabled: !_editingBlocked,
            kind: DakhlFieldKind.money,
            onChanged: _queueDetails,
          ),
          DakhlField(
            label: 'ملاحظة',
            controller: _note,
            compact: true,
            enabled: !_editingBlocked,
            onChanged: _queueDetails,
          ),
          const Divider(),
          Text(
            '${CatalogFormatters.formatPrice(calculation?.net.toInt() ?? 0)} د.ع',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (ticket.lines.isNotEmpty && _quote?.errorCode != null)
            DakhlStatus(
              message: _salesError(_quote!.errorCode),
              kind: DakhlStatusKind.error,
            ),
          if (!posting && widget.session?.checkoutPending != true)
            const Text(
              'تأكيد البيع غير متاح حتى تفعيل الحسابات المالية.',
              style: TextStyle(color: DakhlTokens.muted),
            ),
          DakhlButton(
            label: widget.session?.checkoutPending == true
                ? 'إعادة التحقق من البيع'
                : 'تأكيد البيع النقدي',
            kind: DakhlButtonKind.primary,
            icon: DakhlIconKind.check,
            onPressed:
                _busy ||
                    (widget.session == null) ||
                    (!_quote!.eligible &&
                        widget.session?.checkoutPending != true) ||
                    (!posting && widget.session?.checkoutPending != true) ||
                    (ticket.lines.isEmpty &&
                        widget.session?.checkoutPending != true)
                ? null
                : _checkout,
          ),
          const SizedBox(height: 8),
          DakhlButton(
            label: 'تعليق الطلب',
            onPressed:
                _editingBlocked ||
                    ticket.lines.isEmpty ||
                    widget.session?.checkoutPending == true
                ? null
                : _hold,
          ),
          DakhlButton(
            label: 'تفريغ الفاتورة',
            onPressed:
                _editingBlocked ||
                    ticket.lines.isEmpty &&
                        !_detailsDirty &&
                        _quantities.isEmpty
                ? null
                : _clear,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _source?.removeListener(_changed);
    _debounce?.cancel();
    _search.dispose();
    _date.dispose();
    _discount.dispose();
    _note.dispose();
    _localFocus.dispose();
    super.dispose();
  }
}
