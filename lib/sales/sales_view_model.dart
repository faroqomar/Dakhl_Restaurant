import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/accounts_repository.dart';
import '../catalog/catalog_read_model.dart';
import '../inventory/stock_projection.dart';
import 'ticket_workspace.dart';

/// A current catalog/stock eligibility result and the immutable captured-price
/// quote. This is presentation data, never permission to post a sale.
final class SalesTicketQuote {
  const SalesTicketQuote({this.calculation, this.errorCode});
  final SaleCalculation? calculation;
  final String? errorCode;
  bool get eligible => calculation != null && errorCode == null;
}

/// Observable restaurant composition over the existing typed workspace owner.
///
/// The model is bound to one storage generation. After account replacement,
/// dispose it and create a new model; late callbacks cannot publish into it.
/// Draft transitions never write the account document or complete checkout.
final class SalesViewModel extends ChangeNotifier {
  SalesViewModel(this.repository)
    : _workspace = TicketWorkspaceController(repository),
      authorityFence = repository.snapshot?.fence;

  final AccountsRepository repository;
  final TicketWorkspaceController _workspace;
  final StorageFence? authorityFence;
  static final _limit = BigInt.from(1000000000000);
  static final _safe = BigInt.parse('9007199254740991');
  static final _money = ExactIntegerPolicy(
    maxAbs: _limit,
    signed: false,
    positive: false,
    maxSafeInteger: _safe,
  );
  static final _policy = CommercePolicy(
    quantityScale: 3,
    maximumQuantityUnits: _limit,
    maximumMoney: _limit,
    maximumSafeInteger: _safe,
    rounding: DecimalRounding.halfTowardPositiveInfinity,
  );

  TicketWorkspace? _state;
  bool _busy = false, _disposed = false;
  int _notificationDepth = 0;
  String? _errorCode;
  String _query = '', _group = '';
  int _page = 1;

  bool get _current =>
      !_disposed &&
      authorityFence != null &&
      repository.snapshot?.fence == authorityFence &&
      repository.document != null;
  bool get busy => _busy;
  bool get loaded => _current && _state != null;
  bool get needsReadback => _current && repository.hasUnknownWorkspaceWrite;
  String? get errorCode => _errorCode;
  TicketDraft? get active => _current ? _state?.active : null;
  List<HeldTicket> get held => _current ? _state?.held ?? const [] : const [];
  String get query => _query;
  String get group => _group;
  int get page => _page;
  List<String> get orderTypes =>
      _current ? repository.document!.preferences.orderTypes : const [];

  CatalogReadModel? get _catalogModel {
    final ticket = active;
    if (ticket == null) return null;
    final account = repository.document!;
    return CatalogReadModel.fromAccount(
      account,
      balanceUnitsByProduct: RestaurantStockProjection(account).balancesAt(
        DateOnly.parse(ticket.date, minimumYear: 1000, maximumYear: 9999),
      ),
    );
  }

  CatalogPage? get catalog =>
      _catalogModel?.sales(query: _query, group: _group, page: _page);
  List<String> get groups => _catalogModel?.groups ?? const [];

  /// Eligible catalog counts match the frozen source tabs: all unarchived
  /// products, independent of the current query, group selection and page.
  Map<String, int> get groupCounts {
    final catalog = _catalogModel;
    if (catalog == null) return const {};
    final counts = <String, int>{'': 0};
    for (final product in catalog.products) {
      if (product.archived) continue;
      counts[''] = counts['']! + 1;
      if (product.group.isNotEmpty) {
        counts[product.group] = (counts[product.group] ?? 0) + 1;
      }
    }
    return Map.unmodifiable(counts);
  }

  void filter({String? query, String? group}) {
    if (_disposed) return;
    _query = query ?? _query;
    _group = group ?? _group;
    _page = 1;
    _notify();
  }

  void selectPage(int page) {
    if (_disposed) return;
    _page = page < 1 ? 1 : page;
    _notify();
  }

  /// Re-evaluate catalog/quote after an external account update. Does not load,
  /// repair, normalize, or write workspace data.
  void refresh() {
    if (_disposed) return;
    if (!_current) _errorCode = 'stale_generation';
    _notify();
  }

  BigInt _discount(TicketDraft ticket) {
    final text = LegacyText.trimJavaScript(ticket.discount);
    return text.isEmpty
        ? BigInt.zero
        : _money.parse(text, normalizeDigits: true, allowGrouping: true);
  }

  SalesTicketQuote get quote {
    final ticket = active;
    if (ticket == null) {
      return SalesTicketQuote(
        errorCode: _current ? 'not_loaded' : 'stale_generation',
      );
    }
    if (ticket.lines.isEmpty) {
      return const SalesTicketQuote(errorCode: 'empty_ticket');
    }
    try {
      final calculation = CommerceCalculations.saleQuote(
        ticket.lines.map(
          (line) => CommerceCalculations.lineTotal(
            QuantityPrice(
              quantityUnits: line.quantityUnits,
              price: BigInt.from(line.price),
            ),
            policy: _policy,
          ),
        ),
        discount: _discount(ticket),
        policy: _policy,
      );
      String? eligibility;
      final seen = <String>{};
      if (!orderTypes.contains(ticket.orderType)) {
        eligibility = 'invalid_order_type';
      }
      for (final line in ticket.lines) {
        if (!seen.add(line.productId)) {
          eligibility ??= 'duplicate_product';
        }
        eligibility ??= _productEligibility(
          ticket,
          line.productId,
          line.quantityUnits,
        );
      }
      return SalesTicketQuote(calculation: calculation, errorCode: eligibility);
    } on DomainValidationException catch (error) {
      return SalesTicketQuote(errorCode: error.code);
    } on Object {
      return const SalesTicketQuote(errorCode: 'invalid_ticket');
    }
  }

  String? _productEligibility(
    TicketDraft ticket,
    String productId,
    BigInt units,
  ) {
    final account = repository.document!;
    final products = (account.toJson()['products'] as List)
        .cast<Map<String, Object?>>()
        .where((p) => p['id'] == productId);
    if (products.isEmpty) return 'missing_product';
    final product = products.first;
    if (product['archived'] == true) return 'archived_product';
    if (product['trackStock'] == true &&
        units >
            RestaurantStockProjection(account).balanceFor(
              productId,
              through: DateOnly.parse(
                ticket.date,
                minimumYear: 1000,
                maximumYear: 9999,
              ),
            )) {
      return 'insufficient_stock';
    }
    return null;
  }

  TicketDraft _copy(
    TicketDraft old, {
    String? date,
    String? orderType,
    String? discount,
    String? note,
    Iterable<TicketLine>? lines,
  }) => TicketDraft(
    id: old.id,
    date: date ?? old.date,
    orderType: orderType ?? old.orderType,
    discount: discount ?? old.discount,
    note: note ?? old.note,
    heldLabel: old.heldLabel,
    lines: lines ?? old.lines,
  );

  CapabilityFailure<void> _failure(String code) =>
      CapabilityFailure(code, 'Sales draft operation was not confirmed.');

  CapabilityResult<void>? _guard({bool recovery = false}) {
    if (_disposed) return _failure('disposed');
    if (_busy) return _failure('busy');
    if (!_current) {
      return _reject(
        authorityFence == null ? 'no_document' : 'stale_generation',
      );
    }
    if (repository.hasUnknownWrite &&
        !(recovery && repository.hasUnknownWorkspaceWrite)) {
      return _reject('commit_unknown');
    }
    return null;
  }

  CapabilityResult<void> _reject(String code) {
    _errorCode = code;
    // A listener's rejected re-entrant action must not recursively notify.
    if (_notificationDepth == 0) _notify();
    return _failure(code);
  }

  Future<CapabilityResult<void>> _run(
    Future<CapabilityResult<void>> Function() action, {
    bool recovery = false,
    bool requireLoaded = true,
  }) async {
    final blocked = _guard(recovery: recovery);
    if (blocked != null) return blocked;
    if (requireLoaded && _state == null) return _reject('not_loaded');
    _busy = true;
    _errorCode = null;
    try {
      _notify();
      if (_disposed) return _failure('disposed');
      if (!_current) return _failure('stale_generation');
      final result = await action();
      if (_disposed) return _failure('disposed');
      if (!_current) {
        _state = null;
        _errorCode = 'stale_generation';
        return _failure('stale_generation');
      }
      if (result is CapabilitySuccess<void>) {
        _state = _workspace.state;
      }
      _errorCode = switch (result) {
        CapabilityFailure(:final code) => code,
        CapabilityCancelled() => 'unavailable',
        _ => null,
      };
      return result;
    } on DomainValidationException catch (error) {
      _errorCode = error.code;
      return _failure(error.code);
    } on Object {
      _errorCode = 'unavailable';
      return _failure('unavailable');
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<CapabilityResult<void>> load(TicketDraft initial) =>
      _run(() => _workspace.load(initial), requireLoaded: false);
  Future<CapabilityResult<void>> saveFormDraft(Map<String, String> form) {
    final submitted = Map<String, String>.unmodifiable(form);
    return _run(() => _workspace.saveFormDraft(submitted));
  }

  Future<CapabilityResult<void>> _edit(
    TicketDraft Function(TicketDraft) change,
  ) async {
    final blocked = _guard();
    if (blocked != null) return blocked;
    final old = active;
    if (old == null) return _reject('not_loaded');
    // Construct/freeze the complete candidate before any listener callback.
    final TicketDraft submitted;
    try {
      submitted = change(old);
    } on _SalesInputFailure catch (error) {
      return _reject(error.code);
    } on DomainValidationException catch (error) {
      return _reject(error.code);
    } on Object {
      return _reject('invalid_ticket');
    }
    return _run(() => _workspace.saveActive(submitted));
  }

  Future<CapabilityResult<void>> addProduct(
    String productId, {
    BigInt? quantityUnits,
  }) => _edit((old) {
    final requested = quantityUnits ?? BigInt.from(1000);
    final matches = old.lines.where((line) => line.productId == productId);
    final previous = matches.isEmpty ? null : matches.first;
    if (requested <= BigInt.zero || requested > _limit) {
      throw const _SalesInputFailure('invalid_quantity');
    }
    final product = (repository.document!.toJson()['products'] as List)
        .cast<Map<String, Object?>>()
        .firstWhere(
          (p) => p['id'] == productId,
          orElse: () => throw const _SalesInputFailure('missing_product'),
        );
    var units = requested;
    if (quantityUnits == null && product['trackStock'] == true) {
      // Frozen sale-add uses min(1, max(0, dated stock minus this line)).
      final available = RestaurantStockProjection(repository.document!)
          .balanceFor(
            productId,
            through: DateOnly.parse(
              old.date,
              minimumYear: 1000,
              maximumYear: 9999,
            ),
          );
      final remaining = available - (previous?.quantityUnits ?? BigInt.zero);
      units = remaining < BigInt.zero
          ? BigInt.zero
          : remaining < requested
          ? remaining
          : requested;
    }
    final nextUnits = (previous?.quantityUnits ?? BigInt.zero) + units;
    final eligibility = _productEligibility(old, productId, nextUnits);
    if (eligibility != null) throw _SalesInputFailure(eligibility);
    if (units == BigInt.zero) return old;
    final line = TicketLine(
      productId: productId,
      quantityUnits: nextUnits,
      price: previous?.price ?? product['price'] as int,
    );
    // Validate quote arithmetic with Madar, not an app-side total algorithm.
    CommerceCalculations.lineTotal(
      QuantityPrice(
        quantityUnits: line.quantityUnits,
        price: BigInt.from(line.price),
      ),
      policy: _policy,
    );
    return _copy(
      old,
      lines: [
        for (final item in old.lines)
          if (item.productId != productId) item else line,
        if (previous == null) line,
      ],
    );
  });

  Future<CapabilityResult<void>> setQuantity(
    String productId,
    String quantity,
  ) => _edit((old) {
    final units = ExactDecimal.parse(
      quantity,
      scale: 3,
      maxAbsUnits: _limit,
      signed: false,
      positive: true,
      normalizeDigits: true,
      allowGrouping: true,
      allowArabicDecimal: true,
    ).units;
    if (!old.lines.any((line) => line.productId == productId)) {
      throw const _SalesInputFailure('missing_line');
    }
    final eligibility = _productEligibility(old, productId, units);
    if (eligibility != null) throw _SalesInputFailure(eligibility);
    return _copy(
      old,
      lines: [
        for (final line in old.lines)
          if (line.productId == productId)
            TicketLine(
              productId: productId,
              quantityUnits: units,
              price: line.price,
            )
          else
            line,
      ],
    );
  });

  Future<CapabilityResult<void>> removeProduct(String productId) =>
      _edit((old) {
        if (!old.lines.any((line) => line.productId == productId)) {
          throw const _SalesInputFailure('missing_line');
        }
        return _copy(
          old,
          lines: old.lines.where((line) => line.productId != productId),
        );
      });

  Future<CapabilityResult<void>> updateDetails({
    String? date,
    String? orderType,
    String? discount,
    String? note,
  }) => _edit((old) {
    if (orderType != null && !orderTypes.contains(orderType)) {
      throw const _SalesInputFailure('invalid_order_type');
    }
    final next = _copy(
      old,
      date: date,
      orderType: orderType,
      discount: discount,
      note: note,
    );
    _discount(next);
    return next;
  });

  Future<CapabilityResult<void>> clear(TicketDraft fresh) {
    if (fresh.lines.isNotEmpty) {
      return Future.value(_reject('fresh_ticket_required'));
    }
    return _run(() => _workspace.saveActive(fresh));
  }

  Future<CapabilityResult<void>> hold({
    required String label,
    required String heldId,
    required TicketDraft fresh,
    required String savedAt,
  }) => _run(
    () => _workspace.hold(
      label: label,
      heldId: heldId,
      fresh: fresh,
      savedAt: savedAt,
    ),
  );

  Future<CapabilityResult<void>> resume(
    String id, {
    required String swapId,
    required String swapLabel,
    required String savedAt,
  }) => _run(
    () => _workspace.resume(
      id,
      swapId: swapId,
      swapLabel: swapLabel,
      savedAt: savedAt,
    ),
  );

  Future<CapabilityResult<void>> deleteHeld(String id) =>
      _run(() => _workspace.deleteHeld(id));
  Future<CapabilityResult<void>> reconcile() =>
      _run(_workspace.reconcile, recovery: true);

  void _notify() {
    if (_disposed) return;
    _notificationDepth++;
    try {
      notifyListeners();
    } finally {
      _notificationDepth--;
      if (_disposed && _notificationDepth == 0) super.dispose();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _state = null;
    if (_notificationDepth == 0) super.dispose();
  }
}

final class _SalesInputFailure implements Exception {
  const _SalesInputFailure(this.code);
  final String code;
}
