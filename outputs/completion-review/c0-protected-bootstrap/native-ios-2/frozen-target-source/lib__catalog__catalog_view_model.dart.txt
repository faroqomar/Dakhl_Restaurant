import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';
import '../accounts/accounts_repository.dart';
import '../inventory/inventory_commands.dart';
import '../inventory/stock_projection.dart';
import 'catalog_read_model.dart';
import 'catalog_stock_history.dart';

final class CatalogEditSession {
  CatalogEditSession._(this._account, this.snapshot);
  final AccountDocument _account;
  final DocumentSnapshot snapshot;
}

/// Session presentation and guarded dispatch; engine commands own validation.
final class CatalogViewModel extends ChangeNotifier {
  CatalogViewModel(this.repository) : _commands = InventoryCommands(repository);
  final AccountsRepository repository;
  final InventoryCommands _commands;
  bool _busy = false, _disposed = false;
  int _notificationDepth = 0;
  bool get busy => _busy;
  String? errorCode;
  String _query = '', _group = '';
  InventoryStatus _status = InventoryStatus.active;
  int _page = 1;
  String get query => _query;
  String get group => _group;
  InventoryStatus get status => _status;
  int get page => _page;
  void filter({String? query, String? group, InventoryStatus? status}) {
    if (_disposed) return;
    _query = query ?? _query;
    _group = group ?? _group;
    _status = status ?? _status;
    _page = 1;
    _notify();
  }

  void selectPage(int page) {
    if (_disposed) return;
    _page = page < 1 ? 1 : page;
    _notify();
  }

  CatalogEditSession beginEdit() {
    final account = repository.document;
    final snapshot = repository.snapshot;
    if (_disposed || account == null || snapshot == null) {
      throw StateError('Read accounts before editing catalog.');
    }
    return CatalogEditSession._(account, snapshot);
  }

  CatalogReadModel? inventoryModelAt(DateOnly through) {
    final account = repository.document;
    if (account == null) return null;
    return CatalogReadModel.fromAccount(
      account,
      balanceUnitsByProduct: RestaurantStockProjection(account)
          .balancesAt(through),
    );
  }

  CatalogPage? inventoryAt(DateOnly through) =>
      inventoryModelAt(through)
          ?.inventory(query: query, group: group, status: status, page: page);

  AccountDocument? _historyAccount;
  final _history = <(String, String), List<CatalogStockHistoryItem>>{};
  List<CatalogStockHistoryItem> stockHistoryAt(
    String productId, {
    required DateOnly today,
  }) {
    final account = repository.document;
    if (account == null) return const [];
    if (!identical(_historyAccount, account)) {
      _history.clear();
      _historyAccount = account;
    }
    return _history.putIfAbsent(
      (productId, today.toString()),
      () => CatalogStockHistory.compose(
        account,
        productId: productId,
        today: today,
      ),
    );
  }

  Future<CapabilityResult<AccountDocument>> setArchived(
    String id,
    bool value, {
    required CatalogEditSession session,
  }) => _run(
    session,
    (snapshot) => _commands.setArchived(id, value, expected: snapshot),
  );

  Future<CapabilityResult<AccountDocument>> createProduct(
    Map<String, Object?> product, {
    required CatalogEditSession session,
    InventoryMovement? opening,
  }) {
    final submitted = Map<String, Object?>.unmodifiable(product);
    return _run(
      session,
      (snapshot) => _commands.createProduct(
        submitted,
        expected: snapshot,
        opening: opening,
      ),
    );
  }

  Future<CapabilityResult<AccountDocument>> postMovement(
    InventoryMovement movement, {
    required CatalogEditSession session,
  }) => _run(
    session,
    (snapshot) => _commands.postMovement(movement, expected: snapshot),
  );

  Future<CapabilityResult<AccountDocument>> editProduct(
    Map<String, Object?> product, {
    required CatalogEditSession session,
  }) {
    final submitted = Map<String, Object?>.unmodifiable(product);
    return _run(
      session,
      (snapshot) => _commands.editProduct(submitted, expected: snapshot),
    );
  }

  Future<CapabilityResult<AccountDocument>> reverseMovement(
    String id, {
    required CatalogEditSession session,
    required String newId,
    required String reason,
    required String createdAt,
  }) => _run(
    session,
    (snapshot) => _commands.reverseMovement(
      id,
      newId: newId,
      reason: reason,
      createdAt: createdAt,
      expected: snapshot,
    ),
  );

  Future<CapabilityResult<AccountDocument>> _run(
    CatalogEditSession session,
    Future<CapabilityResult<AccountDocument>> Function(DocumentSnapshot) action,
  ) async {
    CapabilityFailure<AccountDocument> fail(
      String code, {
      bool notify = false,
    }) {
      if (!_disposed && errorCode != code) {
        errorCode = code;
        if (notify) _notify();
      }
      return CapabilityFailure(code, 'Catalog command unavailable.');
    }

    if (_disposed) {
      return const CapabilityFailure(
        'disposed',
        'Catalog command unavailable.',
      );
    }
    // A rejected competing call must not change the active command's state.
    if (_busy) {
      return const CapabilityFailure('busy', 'Catalog command unavailable.');
    }
    final snapshot = session.snapshot;
    final account = session._account;
    if (!identical(repository.document, account) ||
        repository.snapshot != snapshot) {
      return fail('stale_revision', notify: true);
    }
    _busy = true;
    errorCode = null;
    try {
      _notify();
      if (_disposed) return fail('disposed');
      if (!identical(repository.document, account) ||
          repository.snapshot != snapshot) {
        return fail('stale_revision');
      }
      final result = await action(snapshot);
      if (!_disposed) {
        errorCode = switch (result) {
          CapabilityFailure(:final code) => code,
          _ => null,
        };
      }
      return result;
    } finally {
      _busy = false;
      if (!_disposed) _notify();
    }
  }

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
    if (_notificationDepth == 0) super.dispose();
  }
}
