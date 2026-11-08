import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounting/restaurant_journal_sale_commands.dart';
import '../accounts/account_document.dart';
import '../catalog/catalog_formatters.dart';
import '../reports/restaurant_report.dart';
import '../reports/sales_report.dart';
import 'sales_operations_view_model.dart';
import 'return_proposal.dart';

final class SavedReturnAvailability {
  const SavedReturnAvailability(
    this.productId,
    this.name,
    this.unit,
    this.remainingUnits,
    this.tracked,
  );
  final String productId, name, unit;
  final BigInt remainingUnits;
  final bool tracked;
}

/// Saved-record presentation and guarded dispatch. It never changes legacy
/// accounts; financial actions require an explicitly activated operations owner.
final class SalesHistoryViewModel extends ChangeNotifier {
  SalesHistoryViewModel({
    AccountDocument? document,
    this.operations,
    this.compareText,
  }) {
    _document = document;
    operations?.addListener(_changed);
  }
  AccountDocument? _document;
  final SalesOperationsViewModel? operations;
  final int Function(String, String)? compareText;
  AccountDocument? get document => operations?.account ?? _document;
  SalesHistoryFilter _filter = const SalesHistoryFilter();
  String? _selectedId, _pendingVoidSale, _pendingReturnSale, errorCode;
  int _page = 1;
  bool _disposed = false;
  static const pageSize = 25;
  SalesHistoryFilter get filter => _filter;
  bool get busy => operations?.busy ?? false;
  bool get pendingVoid => _pendingVoidSale != null;
  bool get pendingReturn => _pendingReturnSale != null;
  bool get canReturn =>
      selected?['status'] == 'completed' &&
      returnAvailability.any((line) => line.remainingUnits > BigInt.zero) &&
      (operations?.postingEnabled ?? false) &&
      !pendingVoid &&
      !pendingReturn;
  bool get hasReturnable =>
      selected?['status'] == 'completed' &&
      returnAvailability.any((line) => line.remainingUnits > BigInt.zero);
  String? historyError;
  SalesReport? get history {
    if (document == null) {
      historyError = null;
      return null;
    }
    try {
      final value = SalesReport.build(
        document!,
        filter: _filter,
        compareText: compareText,
      );
      historyError = null;
      return value;
    } on Object {
      historyError = 'history_ordering_unavailable';
      return null;
    }
  }

  int get pageCount =>
      ((history?.sales.length ?? 0) / pageSize).ceil().clamp(1, 1 << 30);
  int get page => _page.clamp(1, pageCount);
  List<SaleHistoryRow> get rows =>
      history?.sales
          .skip((page - 1) * pageSize)
          .take(pageSize)
          .toList(growable: false) ??
      const [];
  List<String> get orderTypes => document?.preferences.orderTypes ?? const [];
  Map<String, Object?>? get selected {
    final raw = document?.toJson();
    if (raw == null) return null;
    return (raw['sales']! as List)
        .cast<Map<String, Object?>>()
        .where((sale) => sale['id'] == _selectedId)
        .firstOrNull;
  }

  List<Map<String, Object?>> get selectedReturns => document == null
      ? const []
      : (document!.toJson()['saleReturns']! as List)
            .cast<Map<String, Object?>>()
            .where((r) => r['saleId'] == _selectedId)
            .toList(growable: false);
  bool get canVoid =>
      selected?['status'] == 'completed' &&
      selectedReturns.isEmpty &&
      (operations?.postingEnabled ?? false) &&
      !pendingVoid &&
      !pendingReturn;

  void updateDocument(AccountDocument? document) {
    if (_disposed || identical(document, _document)) return;
    _document = document;
    _changed();
  }

  void select(String id) {
    if (_disposed || busy || pendingVoid || pendingReturn) return;
    _selectedId = id;
    errorCode = selected == null ? 'sale_not_found' : null;
    _changed();
  }

  void setPage(int value) {
    _page = value.clamp(1, pageCount);
    _changed();
  }

  CapabilityResult<void> setFilter(SalesHistoryFilter value) {
    try {
      SalesReport.validateFilter(value);
      _filter = value;
      _page = 1;
      errorCode = null;
      _changed();
      return const CapabilitySuccess(null);
    } on Object {
      errorCode = 'invalid_filter';
      _changed();
      return const CapabilityFailure(
        'invalid_filter',
        'Invalid saved-sales filter.',
      );
    }
  }

  /// Receipt composition preserves saved array order and does not collate.
  /// A future sorted section must fail closed if no reviewed comparator exists.
  RestaurantReport receipt() {
    if (selected == null) throw const FormatException('sale_not_found');
    return RestaurantReportComposer(
      document!,
      compareText: compareText ?? _noCollation,
    ).sale(_selectedId!);
  }

  RestaurantReport filteredReport() {
    if (document == null || compareText == null) {
      throw const FormatException('collation_unavailable');
    }
    return RestaurantReportComposer(
      document!,
      compareText: compareText!,
    ).sales(filter: filter);
  }

  static int _noCollation(String a, String b) =>
      throw const FormatException('collation_unavailable');

  List<SavedReturnAvailability> get returnAvailability {
    final sale = selected;
    if (sale == null) return const [];
    return _availabilityFor(sale);
  }

  List<SavedReturnAvailability> _availabilityFor(Map<String, Object?> sale) {
    final prior = (document!.toJson()['saleReturns']! as List)
        .cast<Map<String, Object?>>()
        .where((record) => record['saleId'] == sale['id'])
        .expand(
          (record) => (record['lines']! as List).cast<Map<String, Object?>>(),
        );
    BigInt units(Object? value) => ExactDecimal.parse(
      '$value',
      scale: 3,
      maxAbsUnits: BigInt.from(1000000000000),
      signed: false,
      positive: true,
    ).units;
    return [
      for (final line in (sale['lines']! as List).cast<Map<String, Object?>>())
        SavedReturnAvailability(
          line['productId']! as String,
          line['name']! as String,
          line['unit']! as String,
          units(line['quantity']) -
              ExactMath.binary64IntegerSum(
                prior
                    .where((r) => r['productId'] == line['productId'])
                    .map((r) => units(r['quantity'])),
              ),
          line['trackStock'] == true,
        ),
    ];
  }

  String stateLabel(Map<String, Object?> sale) {
    if (sale['status'] == 'void') return 'ملغاة';
    final hasReturns = (document!.toJson()['saleReturns']! as List)
        .cast<Map<String, Object?>>()
        .any((record) => record['saleId'] == sale['id']);
    if (!hasReturns) return 'مكتملة';
    return _availabilityFor(sale)
            .any((line) => line.remainingUnits > BigInt.zero)
        ? 'مرتجع جزئي'
        : 'مرتجعة بالكامل';
  }

  ReturnQuote quoteReturn(Iterable<ReturnLineRequest> lines) {
    if (document == null || _selectedId == null) {
      throw const FormatException('sale_not_found');
    }
    return ReturnProposal.quote(document!, saleId: _selectedId!, lines: lines);
  }

  bool validReturnDate(String value, String today) {
    try {
      DateOnly.parse(value, minimumYear: 1000, maximumYear: 9999);
      return selected != null &&
          value.compareTo(selected!['date']! as String) >= 0 &&
          value.compareTo(today) <= 0;
    } on Object {
      return false;
    }
  }

  Future<CapabilityResult<void>> returnSale({
    required String date,
    required String today,
    required String reason,
    required Iterable<ReturnLineRequest> lines,
    required bool cashConfirmed,
  }) async {
    if (_disposed) {
      return const CapabilityFailure('disposed', 'History closed.');
    }
    if (busy) {
      return const CapabilityFailure('busy', 'Sales action in progress.');
    }
    final owner = operations;
    if (owner == null || (!pendingReturn && !canReturn)) {
      return const CapabilityFailure(
        'return_unavailable',
        'Return posting is unavailable.',
      );
    }
    if (!cashConfirmed && !pendingReturn) {
      return const CapabilityFailure(
        'cash_confirmation_required',
        'Confirm cash returned before saving.',
      );
    }
    final DurableCommandResult<RestaurantJournalSaleOutcome> result;
    if (pendingReturn) {
      result = await owner.retry();
    } else {
      try {
        final intent = owner.returnIntent(
          operationId: CatalogFormatters.generateId('return-op'),
          saleId: _selectedId!,
          returnId: CatalogFormatters.generateId('return'),
          journalId: CatalogFormatters.generateId('return-journal'),
          date: DateOnly.parse(date, minimumYear: 1000, maximumYear: 9999),
          today: DateOnly.parse(today, minimumYear: 1000, maximumYear: 9999),
          reason: reason,
          recordedAt: CatalogFormatters.currentIsoTimestamp(),
          lines: lines,
        );
        _pendingReturnSale = _selectedId;
        result = await owner.submit(intent);
      } on Object {
        return const CapabilityFailure(
          'invalid_return',
          'Check return date, reason and quantities.',
        );
      }
    }
    if (_disposed) {
      return const CapabilityFailure('disposed', 'History closed.');
    }
    switch (result) {
      case DurableCommandSuccess() || DurableCommandReplayed():
        _pendingReturnSale = null;
        errorCode = null;
        _changed();
        return const CapabilitySuccess(null);
      case DurableCommandFailure(:final code):
        if (!owner.needsReadback) _pendingReturnSale = null;
        errorCode = code;
        _changed();
        return CapabilityFailure(code, 'Return was not confirmed.');
    }
  }

  Future<CapabilityResult<void>> voidSale(String reason) async {
    if (_disposed) {
      return const CapabilityFailure('disposed', 'History closed.');
    }
    if (busy) {
      return const CapabilityFailure('busy', 'Sales action in progress.');
    }
    final owner = operations;
    if (owner == null || (!pendingVoid && !canVoid)) {
      return const CapabilityFailure(
        'void_unavailable',
        'Sale cannot be voided.',
      );
    }
    final DurableCommandResult<RestaurantJournalSaleOutcome> result;
    if (pendingVoid) {
      result = await owner.retry();
    } else {
      try {
        final intent = owner.voidIntent(
          operationId: CatalogFormatters.generateId('void-op'),
          saleId: _selectedId!,
          reversalJournalId: CatalogFormatters.generateId('void-journal'),
          reason: reason,
          voidedAt: CatalogFormatters.currentIsoTimestamp(),
        );
        _pendingVoidSale = _selectedId;
        result = await owner.submit(intent);
      } on Object {
        return const CapabilityFailure(
          'required_reason',
          'Provide a void reason.',
        );
      }
    }
    if (_disposed) {
      return const CapabilityFailure('disposed', 'History closed.');
    }
    switch (result) {
      case DurableCommandSuccess() || DurableCommandReplayed():
        _pendingVoidSale = null;
        errorCode = null;
        _changed();
        return const CapabilitySuccess(null);
      case DurableCommandFailure(:final code):
        if (!owner.needsReadback) _pendingVoidSale = null;
        errorCode = code;
        _changed();
        return CapabilityFailure(code, 'Sale void was not confirmed.');
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    operations?.removeListener(_changed);
    super.dispose();
  }
}
