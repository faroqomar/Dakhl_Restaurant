import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';

import '../accounts/account_document.dart';
import '../catalog/catalog_formatters.dart';
import '../ui/components.dart';
import '../reports/reports_view_model.dart';
import '../reports/saved_report_pdf_viewer.dart';
import '../reports/restaurant_report.dart';
import '../reports/source_event_order.dart';
import '../ui/dialogs.dart';
import '../ui/theme.dart';
import 'parties_operations_view_model.dart';
import 'additional_debt_controller.dart';
import 'supplier_opening_controller.dart';
import 'parties_surface_controller.dart';
import 'parties_view_model.dart';
import 'purchase_operations_controller.dart';
import 'purchase_analysis.dart';
import 'purchase_proposal.dart';

/// Approved C5/C6 frames only. Metadata edits use the fenced metadata owner;
/// invoice/payment writes require explicitly initialized durable operations.
class PartiesSurface extends StatefulWidget {
  const PartiesSurface({
    super.key,
    required this.routeId,
    this.account,
    this.metadata,
    this.operations,
    this.additionalDebts,
    this.supplierOpenings,
    this.purchaseController,
    this.compareText,
    this.compareMaterialNames,
    this.onEditInvoice,
    this.onPendingInputChanged,
    this.onNavigate,
    this.initialPaymentId,
    this.onInitialPaymentHandled,
  });
  final String routeId;
  final AccountDocument? account;
  final PartiesViewModel? metadata;
  final PartiesOperationsViewModel? operations;
  final AdditionalDebtController? additionalDebts;
  final SupplierOpeningController? supplierOpenings;
  final PurchaseOperationsController? purchaseController;
  final int Function(String, String)? compareText;
  final int Function(String, String)? compareMaterialNames;
  final SaveInvoiceCorrection? onEditInvoice;
  final ValueChanged<bool>? onPendingInputChanged;
  final ValueChanged<String>? onNavigate;
  final String? initialPaymentId;
  final ValueChanged<String>? onInitialPaymentHandled;
  @override
  State<PartiesSurface> createState() => _PartiesSurfaceState();
}

class _PartiesSurfaceState extends State<PartiesSurface> {
  late PartiesSurfaceController _model;
  final _query = TextEditingController(),
      _from = TextEditingController(),
      _to = TextEditingController();
  String? _selectedSupplier;
  bool _archived = false;
  String? _error;
  int _page = 1, _pricePage = 1;
  final _delivery = ReportDeliveryController();
  String? _reportKey, _feedback;
  AccountDocument? _reportSource;
  bool _reportBusy = false;
  String _tab = 'invoices';
  String? _handledPaymentId;
  String _acceptedFrom = '',
      _acceptedTo = '',
      _selectedMaterial = '',
      _invoiceSupplier = '';
  @override
  void initState() {
    super.initState();
    _bind();
    widget.additionalDebts?.addListener(_changed);
    _handleInitialPayment();
  }

  void _bind() {
    _model = PartiesSurfaceController(
      metadata: widget.metadata,
      supplierOpenings: widget.supplierOpenings,
      operations: widget.operations ?? widget.purchaseController?.parties,
      readAccount: () => widget.additionalDebts?.account ?? widget.account,
      compareText: widget.compareText,
      onEditInvoice: widget.onEditInvoice,
    )..addListener(_changed);
  }

  @override
  void didUpdateWidget(PartiesSurface old) {
    super.didUpdateWidget(old);
    if (old.additionalDebts != widget.additionalDebts) {
      old.additionalDebts?.removeListener(_changed);
      widget.additionalDebts?.addListener(_changed);
    }
    if (old.supplierOpenings != widget.supplierOpenings ||
        old.metadata != widget.metadata ||
        old.operations != widget.operations ||
        old.purchaseController != widget.purchaseController ||
        old.compareText != widget.compareText ||
        old.onEditInvoice != widget.onEditInvoice) {
      _model.removeListener(_changed);
      _model.dispose();
      _bind();
    }
    if (old.routeId != widget.routeId) {
      _query.clear();
      _from.clear();
      _to.clear();
      _page = 1;
      _pricePage = 1;
      _acceptedFrom = '';
      _acceptedTo = '';
      _selectedMaterial = '';
      _invoiceSupplier = '';
    }
    if (widget.initialPaymentId == null) _handledPaymentId = null;
    _handleInitialPayment();
  }

  void _handleInitialPayment() {
    final id = widget.initialPaymentId;
    if (widget.routeId != 'payments' || id == null || id == _handledPaymentId) {
      return;
    }
    _handledPaymentId = id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          widget.routeId != 'payments' ||
          widget.initialPaymentId != id) {
        return;
      }
      final matches = _model
          .rows('payments')
          .where((row) => row['id'] == id)
          .toList();
      widget.onInitialPaymentHandled?.call(id);
      if (matches.length != 1 || _model.busy || _model.needsReadback) {
        setState(
          () => _feedback =
              'تعذّر فتح التسديد المحفوظ؛ أعد التحقق من مصدر الحركة.',
        );
        return;
      }
      await _paymentEditor(matches.single);
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  String _money(BigInt value) => CatalogFormatters.formatPrice(value.toInt());
  List<Map<String, Object?>> get _categories =>
      _model.account?.categories ?? const [];
  String? get _supplierId =>
      _model.suppliers.any((s) => s.id == _selectedSupplier)
      ? _selectedSupplier
      : _model.suppliers
                .where((s) => !s.archived)
                .map((s) => s.id)
                .firstOrNull ??
            _model.suppliers.map((s) => s.id).firstOrNull;
  String? get _creationSupplierId =>
      _model.suppliers
          .where((s) => !s.archived && s.id == _supplierId)
          .map((s) => s.id)
          .firstOrNull ??
      _model.suppliers.where((s) => !s.archived).map((s) => s.id).firstOrNull;
  bool _matches(String value) =>
      PartiesSurfaceController.matches(value, _query.text);
  List<Map<String, Object?>>? _financialRows(String key, {String? supplierId}) {
    final filtered = _model
        .rows(key)
        .where(
          (r) =>
              (supplierId == null || r['supplierId'] == supplierId) &&
              (key != 'invoices' ||
                  supplierId != null ||
                  _invoiceSupplier.isEmpty ||
                  r['supplierId'] == _invoiceSupplier) &&
              (_acceptedFrom.isEmpty ||
                  (r['date']! as String).compareTo(_acceptedFrom) >= 0) &&
              (_acceptedTo.isEmpty ||
                  (r['date']! as String).compareTo(_acceptedTo) <= 0) &&
              (key != 'invoices' ||
                  _selectedMaterial.isEmpty ||
                  (r['lines']! as List).cast<Map<String, Object?>>().any(
                    (line) =>
                        PurchaseProposals.sourceMaterialNameKey(
                          line['name']! as String,
                        ) ==
                        PurchaseProposals.sourceMaterialNameKey(
                          _selectedMaterial,
                        ),
                  )) &&
              _matches(
                '${_model.supplierName(r['supplierId']! as String)} ${r['number'] ?? ''} ${r['note'] ?? ''}',
              ),
        )
        .toList();
    try {
      return orderSourceEvents(
        filtered,
        keys: key == 'debts' || (key == 'invoices' && supplierId == null)
            ? const ['date']
            : const ['date', 'createdAt'],
        descending:
            key == 'payments' || (key == 'invoices' && supplierId != null),
        compareText: widget.compareText,
      );
    } on Object {
      return null;
    }
  }

  List<String>? _materialChoices() {
    final names = <String>{
      for (final invoice in _model.rows('invoices'))
        for (final line
            in (invoice['lines']! as List).cast<Map<String, Object?>>())
          line['name']! as String,
    };
    try {
      return orderSourceEvents(
        names.map((name) => <String, Object?>{'name': name}),
        keys: const ['name'],
        descending: false,
        compareText: widget.compareMaterialNames,
      ).map((r) => r['name']! as String).toList();
    } on Object {
      return null;
    }
  }

  Future<void> _editor({
    required String title,
    required Widget Function(StateSetter, VoidCallback, bool) fields,
    required Future<CapabilityResult<void>> Function() save,
    required bool Function() enabled,
    bool Function()? unresolved,
    String saveLabel = 'حفظ',
    bool wide = false,
  }) async {
    bool dirty = false, saving = false;
    String? error;
    StateSetter? bodyUpdate, actionUpdate;
    void update() {
      if (!mounted) return;
      bodyUpdate?.call(() {});
      actionUpdate?.call(() {});
    }

    void touch() {
      dirty = true;
      widget.onPendingInputChanged?.call(true);
      update();
    }

    final result = await showDakhlDialog<bool>(
      context: context,
      title: title,
      wide: wide,
      body: StatefulBuilder(
        builder: (ctx, set) {
          bodyUpdate = set;
          return fields(set, touch, saving || unresolved?.call() == true);
        },
      ),
      actions: [
        StatefulBuilder(
          builder: (ctx, set) {
            actionUpdate = set;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) DakhlStatus(message: error!),
                DakhlButton(
                  label: unresolved?.call() == true
                      ? 'إعادة التحقق من الحفظ'
                      : saveLabel,
                  kind: DakhlButtonKind.primary,
                  busy: saving,
                  onPressed:
                      saving || (!enabled() && unresolved?.call() != true)
                      ? null
                      : () async {
                          saving = true;
                          update();
                          CapabilityResult<void> outcome;
                          try {
                            outcome = await save();
                          } on Object {
                            outcome = const CapabilityFailure(
                              'invalid_input',
                              'Invalid input.',
                            );
                          }
                          if (!ctx.mounted) return;
                          saving = false;
                          if (outcome is CapabilitySuccess<void>) {
                            dirty = false;
                            widget.onPendingInputChanged?.call(false);
                            Navigator.of(ctx).pop(true);
                          } else {
                            final code = outcome is CapabilityFailure
                                ? outcome.code
                                : 'unavailable';
                            error = switch (code) {
                              'unmapped_financial_gap' => 'الحساب المقابل للدين لم يُعتمد بعد؛ لم تتغيّر الحسابات.',
                              'supplier_opening_underfunds_settlement' => 'الدين بعد التعديل لا يغطي الدفعات المحفوظة؛ لم تتغيّر الحسابات.',
                              'unmapped_supplier_opening_equity' => 'حساب الرصيد الافتتاحي لم يُعتمد بعد؛ لم تتغيّر الحسابات.',
                              'invalid_supplier_opening_history' => 'تعذر التحقق من تعديلات الدين الافتتاحي. السجلات الحالية محفوظة.',
                              'cross_cutover_source_has_no_post_cutover_journal' => 'هذا السجل السابق لا يملك قيداً أصلياً متحققاً منه؛ التصحيح غير متاح.',
                              _ => CatalogFormatters.errorMessage(code),
                            };
                            update();
                          }
                        },
                ),
              ],
            );
          },
        ),
      ],
      canDismiss: () async {
        if (saving || unresolved?.call() == true) return false;
        if (!dirty) return true;
        final discard = await showDakhlDialog<bool>(
          context: context,
          title: 'إهمال التغييرات؟',
          body: const Text('تغييراتك لم تُحفظ بعد.'),
          actions: [
            Builder(
              builder: (ctx) => DakhlButton(
                label: 'إهمال التغييرات',
                kind: DakhlButtonKind.danger,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ),
          ],
        );
        if (discard == true) widget.onPendingInputChanged?.call(false);
        return discard == true;
      },
    );
    bodyUpdate = null;
    actionUpdate = null;
    if (result == true && mounted) setState(() => _error = null);
  }

  Future<CapabilityResult<void>> _metadataSave(
    PartyDraft draft,
    Future<CapabilityResult<AccountDocument>> Function() save,
    bool Function(AccountDocument) matches,
  ) async {
    final repo = widget.metadata!.repository;
    if (repo.hasUnknownWrite) {
      final read = await repo.reconcile();
      if (read is CapabilitySuccess<AccountDocument> && matches(read.value)) {
        return const CapabilitySuccess(null);
      }
      return CapabilityFailure(
        read is CapabilityFailure<AccountDocument> ? read.code : 'conflict',
        'Readback did not confirm this edit.',
      );
    }
    final result = await save();
    return result is CapabilitySuccess<AccountDocument>
        ? const CapabilitySuccess(null)
        : CapabilityFailure(
            result is CapabilityFailure<AccountDocument>
                ? result.code
                : 'unavailable',
            'Metadata save not confirmed.',
          );
  }

  Future<void> _supplierEditor([String? id]) async {
    final owner = widget.metadata;
    if (owner == null || _categories.isEmpty) return;
    final draft = id == null
        ? owner.newSupplier(
            id: CatalogFormatters.generateId('supplier'),
            categoryId: _categories.first['id']! as String,
          )
        : owner.editSupplier(id);
    if (draft == null) return;
    final openingOwner = widget.supplierOpenings;
    final openingSnapshot = openingOwner?.snapshot;
    final initialOpening = id == null
        ? 0
        : _model.suppliers
                  .where((s) => s.id == id)
                  .firstOrNull
                  ?.openingBalance ??
              0;
    var openingText = initialOpening.toString(), openingReason = '';
    final openingAllowed = openingOwner?.canWrite == true;

    await _editor(
      title: id == null ? 'إضافة مورد' : 'تعديل المورد',
      enabled: () => !_model.busy,
      unresolved: () =>
          owner.repository.hasUnknownWrite ||
          (openingOwner?.needsReadback ?? false),
      fields: (set, touch, blocked) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DakhlField(
            label: 'اسم المورد',
            initialValue: draft.name,
            enabled: !blocked,
            onChanged: (v) {
              draft.name = v;
              touch();
            },
          ),
          DakhlField(
            label: 'الهاتف',
            initialValue: draft.phone,
            enabled: !blocked,
            onChanged: (v) {
              draft.phone = v;
              touch();
            },
          ),
          DakhlSelect<String>(
            label: 'خانة المصروف',
            value: draft.categoryId,
            enabled: !blocked,
            items: [
              for (final c in _categories)
                DropdownMenuItem(
                  value: c['id']! as String,
                  child: Text(c['name']! as String),
                ),
            ],
            onChanged: (v) {
              if (v != null) {
                draft.categoryId = v;
                touch();
              }
            },
          ),
          DakhlField(
            label: 'ملاحظات',
            initialValue: draft.note,
            maxLines: 3,
            enabled: !blocked,
            onChanged: (v) {
              draft.note = v;
              touch();
            },
          ),
          if (id != null)
            CheckboxListTile(
              value: draft.archived,
              onChanged: blocked
                  ? null
                  : (v) {
                      draft.archived = v ?? false;
                      touch();
                    },
              title: const Text('إيقاف اختيار المورد بالقوائم الجديدة'),
            ),
          DakhlField(
            label: 'الديون السابقة عند تسجيل المورد',
            kind: DakhlFieldKind.money,
            initialValue: openingText,
            enabled: openingAllowed && !blocked,
            onChanged: (value) {
              openingText = value;
              touch();
            },
          ),
          if (openingAllowed) ...[
            DakhlField(
              label: 'سبب تعديل الدين الافتتاحي',
              initialValue: openingReason,
              enabled: !blocked,
              onChanged: (value) {
                openingReason = value;
                touch();
              },
            ),
            const Text(
              'تعديل الدين الافتتاحي لا يغيّر النقد أو سجل المصروفات المدفوعة. يلزم سبب للتعديل.',
            ),
            const Text(
              'تُصحّح أرصدة الافتتاح بتعديل موثّق، ولا يشملها التراجع السريع.',
            ),
          ] else
            const Text(
              'تغيير الدين الافتتاحي يتطلب مسار الأرصدة الافتتاحية المتحقّق منها. هذا النموذج يحفظ بيانات المورد فقط.',
            ),
        ],
      ),
      save: () async {
        if (openingOwner?.needsReadback == true) {
          return _debtResult(await openingOwner!.retry());
        }
        try {
          final amount = PartiesSurfaceController.money(openingText);
          if (amount != initialOpening) {
            if (!openingAllowed || openingOwner == null) {
              return const CapabilityFailure(
                'unmapped_supplier_opening_equity',
                'Opening equity is not accepted.',
              );
            }
            if (openingSnapshot == null ||
                openingOwner.snapshot.fence != openingSnapshot.fence ||
                openingOwner.snapshot.revision != openingSnapshot.revision ||
                openingOwner.snapshot.payload != openingSnapshot.payload) {
              return const CapabilityFailure(
                'stale_revision',
                'Supplier editor source changed.',
              );
            }
            final command = openingOwner.capture(
              operationId: CatalogFormatters.generateId('opening-op'),
              supplierId: draft.id,
              openingBalance: BigInt.from(amount),
              reason: openingReason,
              recordedAt: CatalogFormatters.currentIsoTimestamp(),
              supplierValues: {
                'name': draft.name,
                'phone': draft.phone,
                'note': draft.note,
                'categoryId': draft.categoryId,
                'archived': draft.archived,
              },
            );
            return _debtResult(await openingOwner.submit(command));
          }
          return await _metadataSave(
            draft,
            () => owner.saveSupplier(draft),
            (doc) => (doc.toJson()['suppliers']! as List)
                .cast<Map<String, Object?>>()
                .any(
                  (s) =>
                      s['id'] == draft.id &&
                      s['name'] == draft.name.trim() &&
                      s['phone'] == draft.phone.trim() &&
                      s['categoryId'] == draft.categoryId &&
                      s['note'] == draft.note.trim() &&
                      (s['archived'] == true) == draft.archived,
                ),
          );
        } on FormatException catch (error) {
          return CapabilityFailure(
            error.message,
            'Supplier opening is unavailable.',
          );
        }
      },
    );
  }

  Future<void> _materialEditor([String? id]) async {
    final owner = widget.metadata;
    if (owner == null) return;
    final draft = id == null
        ? owner.newMaterial(id: CatalogFormatters.generateId('material'))
        : owner.editMaterial(id);
    if (draft == null) return;
    if (draft.unit.isEmpty) draft.unit = 'قطعة';
    var carton = '${draft.priceCarton}', piece = '${draft.pricePiece}';
    await _editor(
      title: id == null ? 'إضافة مادة مشتركة' : 'تعديل مادة مشتركة',
      enabled: () => !_model.busy,
      unresolved: () => owner.repository.hasUnknownWrite,
      fields: (set, touch, blocked) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DakhlField(
            label: 'اسم المادة',
            initialValue: draft.name,
            enabled: !blocked,
            onChanged: (v) {
              draft.name = v;
              touch();
            },
          ),
          DakhlField(
            label: 'وحدة القياس',
            initialValue: draft.unit,
            enabled: !blocked,
            onChanged: (v) {
              draft.unit = v;
              touch();
            },
          ),
          DakhlField(
            label: 'سعر الكارتون · د.ع',
            initialValue: carton,
            enabled: !blocked,
            kind: DakhlFieldKind.money,
            onChanged: (v) {
              carton = v;
              touch();
            },
          ),
          DakhlField(
            label: 'سعر القطعة · د.ع',
            initialValue: piece,
            enabled: !blocked,
            kind: DakhlFieldKind.money,
            onChanged: (v) {
              piece = v;
              touch();
            },
          ),
          if (id != null)
            CheckboxListTile(
              value: draft.archived,
              onChanged: blocked
                  ? null
                  : (v) {
                      draft.archived = v ?? false;
                      touch();
                    },
              title: const Text('إيقاف اختيار المادة بالفواتير الجديدة'),
            ),
          const Text(
            'تعديل السعر الافتراضي لا يغيّر أي فاتورة محفوظة؛ كل فاتورة تحتفظ بأسعارها وقت تسجيلها.',
          ),
        ],
      ),
      save: () async {
        draft.priceCarton = PartiesSurfaceController.money(carton);
        draft.pricePiece = PartiesSurfaceController.money(piece);
        return _metadataSave(
          draft,
          () => owner.saveMaterial(draft),
          (doc) => (doc.toJson()['materials']! as List)
              .cast<Map<String, Object?>>()
              .any(
                (m) =>
                    m['id'] == draft.id &&
                    m['name'] == draft.name.trim() &&
                    m['unit'] == draft.unit.trim() &&
                    m['priceCarton'] == draft.priceCarton &&
                    m['pricePiece'] == draft.pricePiece &&
                    m['archived'] == draft.archived,
              ),
        );
      },
    );
  }

  Future<void> _invoiceEditor([Map<String, Object?>? original]) async {
    if (_model.suppliers.isEmpty ||
        _model.needsReadback ||
        (original == null && _creationSupplierId == null)) {
      return;
    }
    final id =
        original?['id'] as String? ?? CatalogFormatters.generateId('invoice');
    var supplier = original?['supplierId'] as String? ?? _creationSupplierId!;
    var number = original?['number'] as String? ?? '',
        date =
            original?['date'] as String? ??
            CatalogFormatters.today().toString();
    var reason = '';
    var note = original?['note'] as String? ?? '',
        paid = '0',
        source = 'daily',
        daily = '0',
        cash = '0';
    final lines = <InvoiceLineForm>[
      if (original != null)
        for (final l
            in (original['lines']! as List).cast<Map<String, Object?>>())
          InvoiceLineForm(
            id: l['materialId'] as String?,
            name: l['name']! as String,
            unit: l['unit']! as String,
            pieces: '${l['quantityPieces'] ?? l['quantity'] ?? 0}',
            piecePrice: '${l['pricePiece'] ?? l['price'] ?? 0}',
            cartons: '${l['quantityCartons'] ?? 0}',
            cartonPrice: '${l['priceCarton'] ?? 0}',
          ),
      if (original == null) InvoiceLineForm(),
    ];
    final paymentId = CatalogFormatters.generateId('payment');
    InvoiceEditorSubmission capture() => InvoiceEditorSubmission(
      id: id,
      supplierId: supplier,
      number: number,
      date: date,
      note: note,
      reason: reason,
      lines: lines.map((l) => l.capture()),
      expectedSource: original,
      immediatePayment:
          original != null || PartiesSurfaceController.money(paid) == 0
          ? null
          : PurchasePayment(
              id: paymentId,
              amount: PartiesSurfaceController.money(paid),
              source: source,
              dailyAmount: source == 'daily'
                  ? PartiesSurfaceController.money(paid)
                  : source == 'cash'
                  ? 0
                  : PartiesSurfaceController.money(daily),
              cashAmount: source == 'cash'
                  ? PartiesSurfaceController.money(paid)
                  : source == 'daily'
                  ? 0
                  : PartiesSurfaceController.money(cash),
            ),
    );
    String linePreview(InvoiceLineForm line) {
      try {
        return '${_model.lineTotal(line)} د.ع';
      } on Object {
        return '—';
      }
    }

    String preview() {
      try {
        return _money(_model.previewInvoiceTotal(capture()));
      } on Object {
        return '—';
      }
    }

    await _editor(
      title: original == null ? 'قائمة جديدة' : 'تفاصيل وتعديل القائمة',
      wide: true,
      saveLabel: original == null ? 'حفظ القائمة والتسديد' : 'حفظ القائمة',
      enabled: () =>
          !_model.busy &&
          (original == null ? _model.postingEnabled : _model.canEditInvoice),
      unresolved: () => _model.needsReadback,
      fields: (set, touch, blocked) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DakhlSelect<String>(
            label: 'المورد',
            value: supplier,
            enabled: !blocked && original == null,
            items: [
              for (final s in _model.suppliers.where(
                (s) => !s.archived || original != null && s.id == supplier,
              ))
                DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) {
              if (v != null) {
                supplier = v;
                touch();
              }
            },
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 220,
                child: DakhlField(
                  label: 'رقم القائمة',
                  initialValue: number,
                  enabled: !blocked,
                  onChanged: (v) {
                    number = v;
                    touch();
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: DakhlField(
                  label: 'تاريخ القائمة',
                  initialValue: date,
                  enabled: !blocked,
                  onChanged: (v) {
                    date = v;
                    touch();
                  },
                ),
              ),
            ],
          ),
          Text('مواد القائمة', style: Theme.of(context).textTheme.titleLarge),
          for (final entry in lines.indexed) ...[
            DakhlPanel(
              key: ValueKey(entry.$2.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DakhlSelect<String>(
                    label: 'مادة محفوظة',
                    value:
                        _model.materials.any((m) => m.id == entry.$2.materialId)
                        ? entry.$2.materialId
                        : null,
                    enabled: !blocked,
                    items: [
                      for (final m in _model.materials.where(
                        (m) =>
                            !m.archived || m.id == entry.$2.selectedMaterialId,
                      ))
                        DropdownMenuItem(value: m.id, child: Text(m.name)),
                    ],
                    onChanged: (v) {
                      final m = _model.materials.firstWhere((m) => m.id == v);
                      entry.$2.selectedMaterialId = m.id;
                      entry.$2.name = m.name;
                      entry.$2.unit = m.unit;
                      entry.$2.piecePrice = '${m.pricePiece}';
                      entry.$2.cartonPrice = '${m.priceCarton}';
                      touch();
                    },
                  ),
                  DakhlField(
                    key: ValueKey('name-${entry.$2.id}'),
                    label: 'اسم المادة',
                    value: entry.$2.name,
                    enabled: !blocked,
                    onChanged: (v) {
                      entry.$2.name = v;
                      final selected = _model.materials
                          .where((m) => m.id == entry.$2.selectedMaterialId)
                          .firstOrNull;
                      if (selected != null &&
                          PurchaseProposals.sourceMaterialNameKey(v.trim()) !=
                              PurchaseProposals.sourceMaterialNameKey(
                                selected.name,
                              )) {
                        entry.$2.selectedMaterialId = null;
                      }
                      touch();
                    },
                  ),
                  DakhlField(
                    label: 'وحدة القياس',
                    value: entry.$2.unit,
                    enabled: !blocked,
                    onChanged: (v) {
                      entry.$2.unit = v;
                      touch();
                    },
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 180,
                        child: DakhlField(
                          label: 'الكمية قطعة',
                          initialValue: entry.$2.pieces,
                          enabled: !blocked,
                          kind: DakhlFieldKind.quantity,
                          onChanged: (v) {
                            entry.$2.pieces = v;
                            touch();
                          },
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DakhlField(
                          key: ValueKey('price-${entry.$2.id}'),
                          label: 'سعر القطعة · د.ع',
                          value: entry.$2.piecePrice,
                          enabled: !blocked,
                          kind: DakhlFieldKind.money,
                          onChanged: (v) {
                            entry.$2.piecePrice = v;
                            touch();
                          },
                        ),
                      ),
                    ],
                  ),
                  Material(
                    color: Colors.transparent,
                    child: ExpansionTile(
                      title: const Text('كارتون / وحدة القياس'),
                      initiallyExpanded: entry.$2.cartons != '0',
                      children: [
                        DakhlField(
                          label: 'الكمية كارتون',
                          initialValue: entry.$2.cartons,
                          enabled: !blocked,
                          kind: DakhlFieldKind.quantity,
                          onChanged: (v) {
                            entry.$2.cartons = v;
                            touch();
                          },
                        ),
                        DakhlField(
                          label: 'سعر الكارتون · د.ع',
                          value: entry.$2.cartonPrice,
                          enabled: !blocked,
                          kind: DakhlFieldKind.money,
                          onChanged: (v) {
                            entry.$2.cartonPrice = v;
                            touch();
                          },
                        ),
                      ],
                    ),
                  ),
                  Text('المبلغ الكلي: ${linePreview(entry.$2)}'),
                  DakhlButton(
                    label: 'إزالة المادة',
                    onPressed: blocked
                        ? null
                        : () {
                            lines.removeAt(entry.$1);
                            touch();
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          DakhlButton(
            label: 'إضافة مادة',
            onPressed: blocked || lines.length >= 200
                ? null
                : () {
                    lines.add(InvoiceLineForm());
                    touch();
                  },
          ),
          const Text(
            'الكمية تقبل كسوراً حتى 3 خانات؛ مبلغ المادة يقرّب لأقرب دينار.',
          ),
          Text(
            'مجموع القائمة: ${preview()} د.ع',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (original == null) ...[
            DakhlField(
              label: 'التسديد الآن · صفر إذا آجل',
              initialValue: paid,
              enabled: !blocked,
              kind: DakhlFieldKind.money,
              onChanged: (v) {
                paid = v;
                touch();
              },
            ),
            DakhlSelect<String>(
              label: 'مصدر التسديد',
              value: source,
              enabled: !blocked,
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('اليومي')),
                DropdownMenuItem(value: 'cash', child: Text('القاصة')),
                DropdownMenuItem(value: 'shared', child: Text('مشترك')),
              ],
              onChanged: (v) {
                if (v != null) {
                  source = v;
                  touch();
                }
              },
            ),
            if (source == 'shared') ...[
              DakhlField(
                label: 'من اليومي',
                initialValue: daily,
                enabled: !blocked,
                onChanged: (v) {
                  daily = v;
                  touch();
                },
              ),
              DakhlField(
                label: 'من القاصة',
                initialValue: cash,
                enabled: !blocked,
                onChanged: (v) {
                  cash = v;
                  touch();
                },
              ),
            ],
          ] else
            const Text('التسديدات المسجّلة تتعدّل من كشف الحساب أو التسديدات.'),
          DakhlField(
            label: 'ملاحظات',
            initialValue: note,
            enabled: !blocked,
            maxLines: 3,
            onChanged: (v) {
              note = v;
              touch();
            },
          ),
          if (original != null)
            DakhlField(
              label: 'سبب التصحيح',
              initialValue: reason,
              enabled: !blocked,
              onChanged: (v) {
                reason = v;
                touch();
              },
            ),
          if (original == null && !_model.postingEnabled ||
              original != null && !_model.canEditInvoice)
            const Text(
              'الحفظ المالي غير متاح حالياً؛ البيانات المحفوظة تبقى دون تغيير.',
            ),
        ],
      ),
      save: () => _model.saveInvoice(capture()),
    );
  }

  Future<void> _paymentEditor([Map<String, Object?>? original]) async {
    if (_model.needsReadback) return;
    if (original == null && _creationSupplierId == null) return;
    var supplier = original?['supplierId'] as String? ?? _creationSupplierId!,
        invoice = original?['invoiceId'] as String? ?? '',
        category = original?['categoryId'] as String? ?? '';
    if (category.isEmpty) {
      category = _model.suppliers
          .firstWhere((s) => s.id == supplier)
          .categoryId;
    }
    var amount = original == null ? '' : '${original['amount']}',
        date =
            original?['date'] as String? ??
            CatalogFormatters.today().toString(),
        note = original?['note'] as String? ?? '',
        reason = '';
    final funding = original?['funding'] as Map<String, Object?>?;
    var source = funding?['source'] as String? ?? 'daily',
        daily = '${funding?['dailyAmount'] ?? 0}',
        cash = '${funding?['cashAmount'] ?? 0}';
    final q = _model.paymentQueries(excluding: original?['id'] as String?);
    String availability() {
      try {
        final due = invoice.isEmpty ? BigInt.zero : q.invoiceDue(invoice);
        final rawDebt = q.debtAvailable(supplier, date: date);
        final debt = rawDebt.isNegative ? BigInt.zero : rawDebt;
        var allocation = '';
        try {
          final candidate = PurchaseProposals(_model.account!).payment(
            payment: PurchasePayment(
              id: original?['id'] as String? ?? 'payment-preview',
              amount: PartiesSurfaceController.money(amount),
              source: source,
              dailyAmount: source == 'daily'
                  ? PartiesSurfaceController.money(amount)
                  : source == 'cash'
                  ? 0
                  : PartiesSurfaceController.money(daily),
              cashAmount: source == 'cash'
                  ? PartiesSurfaceController.money(amount)
                  : source == 'daily'
                  ? 0
                  : PartiesSurfaceController.money(cash),
            ),
            supplierId: supplier,
            invoiceId: invoice.isEmpty ? null : invoice,
            categoryId: category,
            date: date,
            createdAt:
                original?['createdAt'] as String? ??
                CatalogFormatters.currentIsoTimestamp(),
            editing: original != null,
          );
          final row = (candidate.toJson()['payments']! as List)
              .cast<Map<String, Object?>>()
              .last;
          allocation =
              '\nمن القائمة: ${row['invoiceAmount']} د.ع · من الديون: ${row['debtAmount']} د.ع';
        } on Object {
          allocation = '\nأدخل مبلغاً ومصدر دفع صالحين ضمن المتاح.';
        }
        return 'المتبقي من القائمة: $due د.ع · الديون المتاحة: $debt د.ع\nأقصى مبلغ متاح للتسديد: ${due + debt} د.ع$allocation';
      } on Object {
        return 'أدخل تاريخاً صحيحاً لعرض المبلغ المتاح.';
      }
    }

    await _editor(
      title: original == null ? 'تسجيل تسديد' : 'تعديل التسديد',
      saveLabel: 'حفظ التسديد',
      enabled: () => !_model.busy && _model.postingEnabled,
      unresolved: () => _model.needsReadback,
      fields: (set, touch, blocked) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DakhlSelect<String>(
            label: 'المورد',
            value: supplier,
            enabled: !blocked,
            items: [
              for (final s in _model.suppliers)
                DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) {
              if (v != null) {
                supplier = v;
                invoice = '';
                category = _model.suppliers
                    .firstWhere((s) => s.id == v)
                    .categoryId;
                touch();
              }
            },
          ),
          DakhlSelect<String>(
            label: 'القائمة / الديون',
            value: invoice,
            enabled: !blocked,
            items: [
              const DropdownMenuItem(value: '', child: Text('الديون')),
              for (final i
                  in _model
                      .rows('invoices')
                      .where(
                        (i) =>
                            i['supplierId'] == supplier &&
                            (q.invoiceDue(i['id']! as String) > BigInt.zero ||
                                i['id'] == original?['invoiceId']),
                      ))
                DropdownMenuItem(
                  value: i['id']! as String,
                  child: Text('${i['number']} · ${i['date']}'),
                ),
            ],
            onChanged: (v) {
              invoice = v ?? '';
              touch();
            },
          ),
          DakhlStatus(message: availability()),
          DakhlField(
            label: 'مبلغ التسديد',
            initialValue: amount,
            enabled: !blocked,
            kind: DakhlFieldKind.money,
            onChanged: (v) {
              amount = v;
              touch();
            },
          ),
          DakhlField(
            label: 'تاريخ التسديد',
            initialValue: date,
            enabled: !blocked,
            onChanged: (v) {
              date = v;
              touch();
            },
          ),
          DakhlSelect<String>(
            label: 'خانة المصروف عند التسديد',
            value: category,
            enabled: !blocked,
            items: [
              for (final c in _categories)
                DropdownMenuItem(
                  value: c['id']! as String,
                  child: Text(c['name']! as String),
                ),
            ],
            onChanged: (v) {
              if (v != null) {
                category = v;
                touch();
              }
            },
          ),
          DakhlSelect<String>(
            label: 'مصدر التسديد',
            value: source,
            enabled: !blocked,
            items: const [
              DropdownMenuItem(value: 'daily', child: Text('اليومي')),
              DropdownMenuItem(value: 'cash', child: Text('القاصة')),
              DropdownMenuItem(value: 'shared', child: Text('مشترك')),
            ],
            onChanged: (v) {
              if (v != null) {
                source = v;
                touch();
              }
            },
          ),
          if (source == 'shared') ...[
            DakhlField(
              label: 'من اليومي',
              initialValue: daily,
              enabled: !blocked,
              onChanged: (v) {
                daily = v;
                touch();
              },
            ),
            DakhlField(
              label: 'من القاصة',
              initialValue: cash,
              enabled: !blocked,
              onChanged: (v) {
                cash = v;
                touch();
              },
            ),
          ],
          DakhlField(
            label: 'ملاحظات',
            initialValue: note,
            enabled: !blocked,
            maxLines: 3,
            onChanged: (v) {
              note = v;
              touch();
            },
          ),
          if (original != null)
            DakhlField(
              label: 'سبب التصحيح',
              initialValue: reason,
              enabled: !blocked,
              onChanged: (v) {
                reason = v;
                touch();
              },
            ),
          if (!_model.postingEnabled)
            const Text(
              'الحفظ المالي غير متاح حالياً؛ التسديد المحفوظ يبقى دون تغيير.',
            ),
        ],
      ),
      save: () => original == null
          ? _model.savePaymentCreate(
              supplierId: supplier,
              invoiceId: invoice.isEmpty ? null : invoice,
              categoryId: category,
              dateText: date,
              amountText: amount,
              source: source,
              dailyText: daily,
              cashText: cash,
              note: note,
            )
          : _model.savePaymentEdit(
              original: original,
              supplierId: supplier,
              invoiceId: invoice.isEmpty ? null : invoice,
              categoryId: category,
              dateText: date,
              amountText: amount,
              source: source,
              dailyText: daily,
              cashText: cash,
              note: note,
              reason: reason,
            ),
    );
  }

  Future<void> _deleteFinancial(
    Map<String, Object?> original, {
    required bool invoice,
  }) async {
    if (_model.busy || _model.needsReadback) return;
    var reason = '';
    await _editor(
      title: invoice ? 'حذف القائمة' : 'حذف التسديد',
      saveLabel: 'تأكيد الحذف',
      enabled: () => _model.postingEnabled && !_model.busy,
      unresolved: () => _model.needsReadback,
      fields: (set, touch, blocked) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            invoice
                ? 'لا يمكن حذف قائمة لها تسديدات مرتبطة؛ احذف أو عدّل التسديد أولاً.'
                : 'الحذف يعيد مبلغ التسديد إلى مصدره ويحفظ أثر التصحيح.',
          ),
          DakhlField(
            label: 'سبب التصحيح',
            initialValue: reason,
            enabled: !blocked,
            onChanged: (v) {
              reason = v;
              touch();
            },
          ),
        ],
      ),
      save: () => _model.deleteFinancial(
        original: original,
        invoice: invoice,
        reason: reason,
      ),
    );
  }

  Future<void> _saveReport(
    String kind,
    String id, {
    String action = 'save',
  }) async {
    if (_reportBusy) return;
    setState(() {
      _reportBusy = true;
      _feedback = null;
    });
    try {
      final account = _model.account!;
      final key = '$kind:$id';
      if (_reportKey != key ||
          !identical(_reportSource, account) ||
          _delivery.bytes == null) {
        final composer = RestaurantReportComposer(
          account,
          compareText:
              widget.compareText ??
              (a, b) => throw const FormatException('collation_unavailable'),
        );
        final report = kind == 'invoice'
            ? composer.invoice(id)
            : composer.payment(id);
        final generated = await _delivery.generate(report);
        if (generated is! CapabilitySuccess<void>) {
          _feedback = 'تعذّر إنشاء PDF. أعد المحاولة.';
          return;
        }
        _reportKey = key;
        _reportSource = account;
      }
      if (!mounted) return;
      final result = switch (action) {
        'open' => await openSavedReportPdf(
          context,
          title: _delivery.report!.title,
          bytes: _delivery.bytes!,
        ),
        'share' => await _delivery.share(),
        'print' => await _delivery.print(),
        _ => await _delivery.save(),
      };
      _feedback = switch (result) {
        CapabilitySuccess() =>
          action == 'save'
              ? 'تم حفظ PDF.'
              : action == 'open'
              ? 'تم فتح عرض PDF.'
              : 'تم تسليم PDF.',
        CapabilityCancelled() => 'أُلغي التصدير؛ لم تتغير الحسابات.',
        CapabilityFailure() => 'تعذّر التصدير. أعد المحاولة بالنسخة نفسها.',
      };
    } on Object {
      _feedback = 'تصدير هذا المستند غير متاح حالياً.';
    } finally {
      if (mounted) setState(() => _reportBusy = false);
    }
  }

  Future<void> _retryFinancial() async {
    final owner = _model.operations;
    if (owner == null || owner.busy) return;
    final result = await owner.retry();
    if (!mounted) return;
    setState(
      () => _error = result is DurableCommandFailure
          ? CatalogFormatters.errorMessage(result.code)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_model.account == null) {
      return const Center(
        child: DakhlEmptyState(
          title: 'لا توجد حسابات محفوظة',
          message: 'افتح الحسابات لعرض الموردين والمشتريات.',
        ),
      );
    }
    final material = widget.routeId == 'materials',
        payments = widget.routeId == 'payments',
        invoices = widget.routeId == 'invoices';
    final materialChoices = invoices ? _materialChoices() : const <String>[];
    final title = material
        ? 'المواد والأسعار'
        : payments
        ? 'التسديدات'
        : invoices
        ? 'قوائم المشتريات'
        : 'الموردون';
    return SingleChildScrollView(
      padding: EdgeInsets.all(
        DakhlTokens.gutter(MediaQuery.sizeOf(context).width),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الموردون / $title',
                    style: const TextStyle(color: DakhlTokens.muted),
                  ),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
              DakhlButton(
                label: material
                    ? 'إضافة مادة'
                    : payments
                    ? 'تسجيل تسديد'
                    : invoices
                    ? 'إضافة فاتورة'
                    : 'إضافة مورد',
                kind: DakhlButtonKind.primary,
                onPressed: _model.busy || _model.needsReadback
                    ? null
                    : payments
                    ? (_creationSupplierId == null
                          ? null
                          : () => _paymentEditor())
                    : material
                    ? (widget.metadata == null ? null : () => _materialEditor())
                    : invoices
                    ? (_model.suppliers.isEmpty ? null : () => _invoiceEditor())
                    : (widget.metadata == null
                          ? null
                          : () => _supplierEditor()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null) DakhlStatus(message: _error!),
          if (_feedback != null) DakhlStatus(message: _feedback!),
          if (_model.needsReadback)
            DakhlButton(
              label: 'إعادة التحقق من العملية السابقة',
              onPressed: _model.busy ? null : _retryFinancial,
            ),
          DakhlPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 260,
                      child: DakhlField(
                        label: material
                            ? 'بحث المواد'
                            : 'بحث المورد أو الملاحظة',
                        controller: _query,
                        onChanged: (_) => setState(() => _page = 1),
                      ),
                    ),
                    if (invoices)
                      SizedBox(
                        width: 260,
                        child: materialChoices == null
                            ? const DakhlStatus(
                                message: 'ترتيب أسماء المواد غير متاح حالياً.',
                              )
                            : DakhlSelect<String>(
                                label: 'المادة في القوائم',
                                value:
                                    materialChoices.contains(_selectedMaterial)
                                    ? _selectedMaterial
                                    : '',
                                items: [
                                  const DropdownMenuItem(
                                    value: '',
                                    child: Text('كل المواد'),
                                  ),
                                  for (final name in materialChoices)
                                    DropdownMenuItem(
                                      value: name,
                                      child: Text(name),
                                    ),
                                ],
                                onChanged: (value) => setState(() {
                                  _selectedMaterial = value ?? '';
                                  _page = 1;
                                  _pricePage = 1;
                                }),
                              ),
                      ),
                    if (invoices)
                      SizedBox(
                        width: 240,
                        child: DakhlSelect<String>(
                          label: 'المورد في القوائم',
                          value: _invoiceSupplier,
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('كل الموردين'),
                            ),
                            for (final supplier in _model.suppliers)
                              DropdownMenuItem(
                                value: supplier.id,
                                child: Text(supplier.name),
                              ),
                          ],
                          onChanged: (value) => setState(() {
                            _invoiceSupplier = value ?? '';
                            _page = 1;
                            _pricePage = 1;
                          }),
                        ),
                      ),
                    if (invoices ||
                        payments ||
                        (!material && _tab == 'ledger')) ...[
                      SizedBox(
                        width: 180,
                        child: DakhlField(label: 'من تاريخ', controller: _from),
                      ),
                      SizedBox(
                        width: 180,
                        child: DakhlField(label: 'إلى تاريخ', controller: _to),
                      ),
                      DakhlButton(
                        label: 'تطبيق التصفية',
                        onPressed: () {
                          try {
                            if (_from.text.isNotEmpty) {
                              PartiesSurfaceController.date(_from.text);
                            }
                            if (_to.text.isNotEmpty) {
                              PartiesSurfaceController.date(_to.text);
                            }
                            if (_from.text.isNotEmpty &&
                                _to.text.isNotEmpty &&
                                _from.text.compareTo(_to.text) > 0) {
                              throw const FormatException('invalid_range');
                            }
                            setState(() {
                              _acceptedFrom = _from.text;
                              _acceptedTo = _to.text;
                              _page = 1;
                              _pricePage = 1;
                              _error = null;
                            });
                          } on Object {
                            setState(
                              () => _error = 'تحقق من التواريخ المدخلة.',
                            );
                          }
                        },
                      ),
                    ] else
                      SizedBox(
                        width: 240,
                        child: Row(
                          children: [
                            Checkbox(
                              value: _archived,
                              onChanged: (v) =>
                                  setState(() => _archived = v ?? false),
                            ),
                            const Expanded(child: Text('عرض الموقوفة')),
                          ],
                        ),
                      ),
                  ],
                ),
                if (material)
                  _materials()
                else if (payments)
                  _payments()
                else if (invoices)
                  _invoices()
                else
                  _suppliers(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _materials() => Column(
    children: [
      for (final m in _model.materials.where(
        (m) => (_archived || !m.archived) && _matches('${m.name} ${m.unit}'),
      ))
        ListTile(
          title: Text(m.name),
          subtitle: Text(
            '${m.unit} · كارتون ${CatalogFormatters.formatPrice(m.priceCarton)} / قطعة ${CatalogFormatters.formatPrice(m.pricePiece)} د.ع${m.archived ? ' · موقوفة' : ''}',
          ),
          trailing: DakhlButton(
            label: 'تعديل المادة',
            onPressed: widget.metadata == null
                ? null
                : () => _materialEditor(m.id),
          ),
        ),
      if (_model.materials.isEmpty)
        const DakhlEmptyState(
          title: 'لا توجد مواد محفوظة',
          message: 'أضف مادة وأسعارها الافتراضية لاستخدامها مع الموردين.',
        ),
    ],
  );
  Widget _suppliers() {
    final supplierId = _supplierId;
    final selected = _model.suppliers
        .where((s) => s.id == supplierId)
        .firstOrNull;
    if (selected == null) {
      return const DakhlEmptyState(
        title: 'لا يوجد موردون',
        message: 'أضف مورداً لبدء قوائم المشتريات.',
      );
    }
    final ledger = _tab == 'ledger' ? _model.ledger(selected.id) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DakhlSelect<String>(
          label: 'اختار المورد',
          value: supplierId,
          items: [
            for (final s in _model.suppliers.where(
              (s) =>
                  s.id == supplierId ||
                  ((_archived || !s.archived) &&
                      _matches('${s.name} ${s.phone}')),
            ))
              DropdownMenuItem(value: s.id, child: Text(s.name)),
          ],
          onChanged: (v) => setState(() => _selectedSupplier = v),
        ),
        Text(selected.name, style: Theme.of(context).textTheme.headlineSmall),
        Text(selected.phone),
        Text(selected.note),
        _openingHistory(selected.id),
        Text(
          'الرصيد الحالي عليك: ${_money(_model.supplierBalance(selected.id))} د.ع',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DakhlButton(
              label: 'تعديل المورد',
              onPressed: widget.metadata == null
                  ? null
                  : () => _supplierEditor(selected.id),
            ),
            DakhlButton(
              label: 'قائمة جديدة',
              onPressed: () => _invoiceEditor(),
            ),
            DakhlButton(
              label: 'التسديدات',
              onPressed: () => widget.onNavigate?.call('payments'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            for (final tab in [
              ('invoices', 'القوائم'),
              ('debts', 'الديون'),
              ('materials', 'كتالوج المواد المشترك'),
              ('ledger', 'كشف الحساب'),
            ])
              DakhlButton(
                label: tab.$2,
                kind: _tab == tab.$1
                    ? DakhlButtonKind.primary
                    : DakhlButtonKind.secondary,
                onPressed: () => setState(() => _tab = tab.$1),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_tab == 'invoices') _invoices(supplierId: selected.id),
        if (_tab == 'materials') _materials(),
        if (_tab == 'debts') _debts(selected.id),
        if (_tab == 'ledger') ...[
          if (ledger == null)
            const DakhlStatus(
              message: 'كشف الحساب المرتّب غير متاح حالياً. بياناتك محفوظة.',
            ),
          if (ledger != null)
            for (final row in ledger.reversed.where(
              (row) =>
                  (_acceptedFrom.isEmpty ||
                      row.date.compareTo(_acceptedFrom) >= 0) &&
                  (_acceptedTo.isEmpty || row.date.compareTo(_acceptedTo) <= 0),
            ))
              ListTile(
                title: Text('${row.date} · ${row.type}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الرصيد السابق ${_money(row.before)} · الرصيد ${_money(row.balance)}',
                    ),
                    Text(
                      '${row.type == 'payment' ? '−' : '+'} ${_money(row.amount)} د.ع',
                    ),
                  ],
                ),
                trailing: IconButton(
                  tooltip: 'تعديل الحركة',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    final source = _model
                        .rows(
                          row.type == 'payment'
                              ? 'payments'
                              : row.type == 'invoice'
                              ? 'invoices'
                              : 'debts',
                        )
                        .where((r) => r['id'] == row.id)
                        .firstOrNull;
                    if (source == null) return;
                    if (row.type == 'invoice') _invoiceEditor(source);
                    if (row.type == 'payment') _paymentEditor(source);
                    if (row.type == 'debt') _debtEditor(original: source);
                  },
                ),
              ),
        ],
      ],
    );
  }

  Widget _openingHistory(String supplierId) {
    final owner = widget.supplierOpenings;
    if (owner == null) return const SizedBox.shrink();
    try {
      final entries = owner.amendments(supplierId);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (owner.needsReadback)
            DakhlButton(
              label: 'إعادة التحقق من تعديل الدين الافتتاحي',
              onPressed: owner.busy
                  ? null
                  : () async {
                      final result = _debtResult(await owner.retry());
                      if (!mounted) return;
                      setState(() {
                        _error = result is CapabilityFailure
                            ? result.code
                            : null;
                      });
                    },
            ),
          if (entries.isNotEmpty)
            Material(
              color: Colors.transparent,
              child: ExpansionTile(
                title: const Text('تعديلات الدين الافتتاحي'),
                children: [
                  for (final entry in entries)
                    ListTile(
                      title: Text(
                        'من ${CatalogFormatters.formatPrice(entry.beforeAmount.toInt())} إلى ${CatalogFormatters.formatPrice(entry.afterAmount.toInt())} د.ع',
                      ),
                      subtitle: Text(
                        '${entry.cutoverDate} · ${entry.reason.trim()}',
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    } on Object {
      return const DakhlStatus(
        message: 'تعذر التحقق من سجل تعديلات الدين الافتتاحي. السجلات الحالية محفوظة.',
      );
    }
  }

  Widget _debts(String id) {
    final rows = _financialRows('debts', supplierId: id);
    if (rows == null) {
      return const DakhlStatus(
        message: 'ترتيب الديون غير متاح حالياً. بياناتك محفوظة.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.additionalDebts?.acceptedCounterAccountId == null)
          const DakhlStatus(
            message: 'حفظ الديون الإضافية يتطلب حساباً مقابلاً معتمداً. السجلات الحالية محفوظة.',
          ),
        DakhlButton(
          label: 'إضافة دين',
          onPressed: () => _debtEditor(supplierId: id),
        ),
        if (widget.additionalDebts?.needsReadback == true)
          DakhlButton(
            label: 'إعادة التحقق من الدين السابق',
            onPressed: widget.additionalDebts!.busy ? null : _retryDebt,
          ),
        for (final d in rows)
          _financialCard(
            title: Text('${d['date']} · ${d['note']}'),
            subtitle: Text(
              '${CatalogFormatters.formatPrice(d['amount']! as int)} د.ع',
            ),
            trailing: Wrap(
              spacing: 8,
              children: [
                DakhlButton(
                  label: 'تعديل الدين',
                  onPressed: () => _debtEditor(original: d),
                ),
                DakhlButton(
                  label: 'حذف الدين',
                  kind: DakhlButtonKind.danger,
                  onPressed: () => _debtEditor(original: d, deleting: true),
                ),
              ],
            ),
          ),
      ],
    );
  }

  CapabilityResult<void> _debtResult(Object result) => switch (result) {
    DurableCommandSuccess() ||
    DurableCommandReplayed() => const CapabilitySuccess(null),
    DurableCommandFailure(:final code, :final message) => CapabilityFailure(
      code,
      message,
    ),
    _ => const CapabilityFailure(
      'commit_unknown',
      'Additional debt outcome is unresolved.',
    ),
  };

  Future<void> _retryDebt() async {
    final owner = widget.additionalDebts;
    if (owner == null || owner.busy) return;
    final result = _debtResult(await owner.retry());
    if (!mounted) return;
    setState(
      () => _feedback = result is CapabilitySuccess<void>
          ? 'تم التحقق من حفظ الدين.'
          : 'تعذّر التحقق؛ أعد المحاولة بالعملية نفسها.',
    );
  }

  Future<void> _debtEditor({
    String? supplierId,
    Map<String, Object?>? original,
    bool deleting = false,
  }) async {
    final owner = widget.additionalDebts;
    final editorSnapshot = owner?.snapshot;
    final selected =
        supplierId ?? original?['supplierId'] as String? ?? _supplierId;
    if (selected == null) return;
    final debtId =
        original?['id'] as String? ?? CatalogFormatters.generateId('debt');
    var date =
        original?['date'] as String? ?? CatalogFormatters.today().toString();
    var amount = '${original?['amount'] ?? 0}',
        note = original?['note'] as String? ?? '',
        reason = '';
    final allowed =
        owner != null &&
        owner.acceptedCounterAccountId?.trim().isNotEmpty == true;
    await _editor(
      title: deleting
          ? 'حذف الدين'
          : original == null
          ? 'إضافة دين'
          : 'تعديل الدين',
      enabled: () => allowed && !owner.busy,
      unresolved: () => owner?.needsReadback ?? false,
      saveLabel: deleting ? 'تأكيد حذف الدين' : 'حفظ الدين',
      fields: (set, touch, blocked) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_model.supplierName(selected)),
          if (!allowed)
            const DakhlStatus(
              message: 'الحفظ غير متاح قبل اعتماد الحساب المقابل للدين. لا تتغيّر حساباتك من هذه المعاينة.',
            ),
          DakhlField(
            label: 'تاريخ الدين',
            initialValue: date,
            enabled: !blocked && !deleting,
            onChanged: (v) {
              date = v;
              touch();
            },
          ),
          DakhlField(
            label: 'مبلغ الدين',
            initialValue: amount,
            enabled: !blocked && !deleting,
            onChanged: (v) {
              amount = v;
              touch();
            },
          ),
          DakhlField(
            label: 'ملاحظة الدين',
            initialValue: note,
            enabled: !blocked && !deleting,
            onChanged: (v) {
              note = v;
              touch();
            },
          ),
          if (original != null)
            DakhlField(
              label: 'سبب التصحيح',
              initialValue: reason,
              enabled: !blocked,
              onChanged: (v) {
                reason = v;
                touch();
              },
            ),
        ],
      ),
      save: () async {
        if (owner == null || !allowed) {
          return const CapabilityFailure(
            'unmapped_financial_gap',
            'Debt counteraccount is not approved.',
          );
        }
        if (owner.needsReadback) return _debtResult(await owner.retry());
        if (original != null &&
            editorSnapshot != null &&
            (owner.snapshot.fence != editorSnapshot.fence ||
                owner.snapshot.revision != editorSnapshot.revision ||
                owner.snapshot.payload != editorSnapshot.payload)) {
          return const CapabilityFailure(
            'stale_revision',
            'Debt editor source changed.',
          );
        }
        try {
          final command = owner.capture(
            operationId: CatalogFormatters.generateId('debt-op'),
            kind: deleting
                ? 'delete'
                : original == null
                ? 'create'
                : 'edit',
            debtId: debtId,
            supplierId: selected,
            date: deleting ? null : date,
            amount: deleting
                ? null
                : BigInt.from(PartiesSurfaceController.money(amount)),
            note: note,
            reason: reason,
            recordedAt: CatalogFormatters.currentIsoTimestamp(),
          );
          return _debtResult(await owner.submit(command));
        } on FormatException catch (error) {
          return CapabilityFailure(error.message, 'Debt is unavailable.');
        }
      },
    );
  }

  Widget _financialCard({
    required Widget title,
    required Widget subtitle,
    required Widget trailing,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DakhlPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DefaultTextStyle(
            style: Theme.of(context).textTheme.titleMedium!,
            child: title,
          ),
          const SizedBox(height: 6),
          subtitle,
          const SizedBox(height: 12),
          trailing,
        ],
      ),
    ),
  );

  Widget _invoices({String? supplierId}) {
    final rows = _financialRows('invoices', supplierId: supplierId);
    if (rows == null) {
      return const DakhlStatus(
        message: 'ترتيب قوائم المشتريات غير متاح حالياً. بياناتك محفوظة.',
      );
    }
    return Column(
      children: [
        if (rows.isEmpty)
          const DakhlEmptyState(
            title: 'لا توجد قوائم',
            message: 'أضف قائمة للمورد أو غيّر التصفية.',
          ),
        if (supplierId == null) _purchaseAnalysis(rows),
        for (final row
            in (supplierId == null ? rows.reversed : rows)
                .skip((_page - 1) * 25)
                .take(25))
          _financialCard(
            title: Text(
              '${row['number']} · ${_model.supplierName(row['supplierId']! as String)}',
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${row['date']} · القيمة ${_money(_model.invoiceTotal(row))} · المسدّد ${_money(_model.invoicePaid(row['id']! as String))} · المتبقي ${_money(_model.invoiceDue(row['id']! as String))} د.ع',
                ),
                Material(
                  type: MaterialType.transparency,
                  child: ExpansionTile(
                    title: const Text('بنود القائمة المحفوظة'),
                    initiallyExpanded: _selectedMaterial.isNotEmpty,
                    children: [
                      for (final line
                          in (row['lines']! as List)
                              .cast<Map<String, Object?>>()
                              .where(
                                (line) =>
                                    _selectedMaterial.isEmpty ||
                                    PurchaseProposals.sourceMaterialNameKey(
                                          line['name']! as String,
                                        ) ==
                                        PurchaseProposals.sourceMaterialNameKey(
                                          _selectedMaterial,
                                        ),
                              ))
                        ListTile(
                          title: Text('${line['name']} · ${line['unit']}'),
                          subtitle: Text(
                            'كارتون ${line['quantityCartons'] ?? 0} · كمية الوحدة ${line['quantityPieces'] ?? line['quantity'] ?? 0}\nسعر الكارتون ${line['priceCarton'] ?? 0} / الوحدة ${line['pricePiece'] ?? line['price'] ?? 0}',
                          ),
                          trailing: Text(
                            '${_money(_model.queries.invoiceTotal({
                              'lines': [line],
                            }))} د.ع',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            trailing: Wrap(
              spacing: 8,
              children: [
                DakhlButton(
                  label: 'PDF',
                  onPressed: _reportBusy
                      ? null
                      : () => _saveReport('invoice', row['id']! as String),
                ),
                DakhlButton(
                  label: 'فتح PDF',
                  onPressed: _reportBusy
                      ? null
                      : () => _saveReport(
                          'invoice',
                          row['id']! as String,
                          action: 'open',
                        ),
                ),
                DakhlButton(
                  label: 'مشاركة PDF',
                  onPressed: _reportBusy
                      ? null
                      : () => _saveReport(
                          'invoice',
                          row['id']! as String,
                          action: 'share',
                        ),
                ),
                DakhlButton(
                  label: 'طباعة PDF',
                  onPressed: _reportBusy
                      ? null
                      : () => _saveReport(
                          'invoice',
                          row['id']! as String,
                          action: 'print',
                        ),
                ),
                DakhlButton(
                  label: 'تفاصيل وتعديل القائمة',
                  onPressed: () => _invoiceEditor(row),
                ),
                DakhlButton(
                  label: 'حذف القائمة',
                  kind: DakhlButtonKind.danger,
                  onPressed: _model.postingEnabled
                      ? () => _deleteFinancial(row, invoice: true)
                      : null,
                ),
              ],
            ),
          ),
        if (rows.length > 25) _paging(rows.length),
      ],
    );
  }

  Widget _purchaseAnalysis(List<Map<String, Object?>> visible) {
    final PurchaseAnalysis analysis;
    try {
      analysis = PurchaseAnalysis.build(
        _model.account!,
        supplierId: _invoiceSupplier,
        material: _selectedMaterial,
        from: _acceptedFrom,
        to: _acceptedTo,
        compareText: widget.compareText,
        visibleInvoiceIds: visible.map((r) => r['id']! as String).toSet(),
      );
    } on Object {
      return const DakhlStatus(
        message: 'تحليل المشتريات المرتّب غير متاح حالياً. بياناتك محفوظة.',
      );
    }
    String delta(int value) =>
        '${value >= 0 ? '+' : ''}${CatalogFormatters.formatPrice(value)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('تحليل المشتريات', style: Theme.of(context).textTheme.titleLarge),
        for (final unit in analysis.units)
          Text(
            '${unit.name} · ${unit.unit}: ${CatalogFormatters.formatQuantity(unit.cartons)} كارتون · ${CatalogFormatters.formatQuantity(unit.pieces)} ${unit.unit}',
          ),
        Text(
          'المبلغ الكلي ${_money(analysis.amount)} د.ع · عدد الفواتير ${analysis.invoiceCount}',
        ),
        Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            title: const Text('تغيّر الأسعار'),
            children: [
              if (analysis.changes.length > 25)
                Wrap(
                  spacing: 8,
                  children: [
                    DakhlButton(
                      label: 'الأسعار السابقة',
                      onPressed: _pricePage <= 1
                          ? null
                          : () => setState(() => _pricePage--),
                    ),
                    Text(
                      '$_pricePage / ${(analysis.changes.length / 25).ceil()}',
                    ),
                    DakhlButton(
                      label: 'الأسعار التالية',
                      onPressed: _pricePage * 25 >= analysis.changes.length
                          ? null
                          : () => setState(() => _pricePage++),
                    ),
                  ],
                ),
              if (analysis.changes.isEmpty)
                const Text(
                  'تغيّر السعر يظهر بعد تسجيل أكثر من شراء للمادة بأسعار مختلفة.',
                ),
              for (final change
                  in analysis.changes.skip((_pricePage - 1) * 25).take(25))
                ListTile(
                  title: Text(
                    '${change.date} · ${_model.supplierName(change.supplierId)} · ${change.name}',
                  ),
                  subtitle: Text(
                    'سعر الكارتون ${CatalogFormatters.formatPrice(change.cartonPrice)} · سعر القطعة ${CatalogFormatters.formatPrice(change.piecePrice)}\nالتغيّر ${delta(change.cartonDelta)} للكارتون · ${delta(change.pieceDelta)} للقطعة',
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _payments() {
    final rows = _financialRows('payments');
    if (rows == null) {
      return const DakhlStatus(
        message: 'ترتيب التسديدات غير متاح حالياً. بياناتك محفوظة.',
      );
    }
    return Column(
      children: [
        if (rows.isEmpty)
          const DakhlEmptyState(
            title: 'لا توجد تسديدات',
            message: 'تظهر هنا الدفعات المحفوظة للموردين.',
          ),
        for (final row in rows.skip((_page - 1) * 25).take(25))
          _financialCard(
            title: Text(
              '${_model.supplierName(row['supplierId']! as String)} · ${row['invoiceId'] ?? 'الديون'}',
            ),
            subtitle: Text(
              '${row['date']} · ${row['note']} · ${(row['funding']! as Map)['source']}',
            ),
            trailing: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${CatalogFormatters.formatPrice(row['amount']! as int)} د.ع',
                ),
                DakhlButton(
                  label: 'وصل PDF',
                  onPressed: _reportBusy
                      ? null
                      : () => _saveReport('payment', row['id']! as String),
                ),
                DakhlButton(
                  label: 'فتح PDF',
                  onPressed: _reportBusy
                      ? null
                      : () => _saveReport(
                          'payment',
                          row['id']! as String,
                          action: 'open',
                        ),
                ),
                DakhlButton(
                  label: 'مشاركة PDF',
                  onPressed: _reportBusy
                      ? null
                      : () => _saveReport(
                          'payment',
                          row['id']! as String,
                          action: 'share',
                        ),
                ),
                DakhlButton(
                  label: 'طباعة PDF',
                  onPressed: _reportBusy
                      ? null
                      : () => _saveReport(
                          'payment',
                          row['id']! as String,
                          action: 'print',
                        ),
                ),
                DakhlButton(
                  label: 'تعديل التسديد',
                  onPressed: () => _paymentEditor(row),
                ),
                DakhlButton(
                  label: 'حذف التسديد',
                  kind: DakhlButtonKind.danger,
                  onPressed: _model.postingEnabled
                      ? () => _deleteFinancial(row, invoice: false)
                      : null,
                ),
              ],
            ),
          ),
        if (rows.length > 25) _paging(rows.length),
      ],
    );
  }

  Widget _paging(int count) => Wrap(
    spacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      DakhlButton(
        label: 'السابق',
        onPressed: _page <= 1 ? null : () => setState(() => _page--),
      ),
      Text('$_page / ${(count / 25).ceil()}'),
      DakhlButton(
        label: 'التالي',
        onPressed: _page * 25 >= count ? null : () => setState(() => _page++),
      ),
    ],
  );
  @override
  void dispose() {
    _model.removeListener(_changed);
    _model.dispose();
    _delivery.dispose();
    widget.additionalDebts?.removeListener(_changed);
    _query.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }
}
