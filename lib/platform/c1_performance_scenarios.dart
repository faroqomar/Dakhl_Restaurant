import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/accounts_repository.dart';
import '../app/accounts_store.dart';
import '../catalog/catalog_read_model.dart';
import '../catalog/catalog_stock_history.dart';
import '../catalog/catalog_view_model.dart';
import '../catalog/product_photo_draft_controller.dart';
import '../inventory/inventory_commands.dart';
import '../inventory/stock_projection.dart';

const c1QueryCases = {
  'c1.catalog.lookup',
  'c1.catalog.filter',
  'c1.catalog.page',
  'c1.stock.history',
};

const c1PerformanceCases = {
  ...c1QueryCases,
  'c1.product.create',
  'c1.product.edit',
  'c1.product.photo_select_save',
  'c1.stock.post',
  'c1.stock.reverse',
};

/// A bounded representative workload, not the maximum supported account size.
const c1PerformanceWorkload = {
  'id': 'c1-operations-v1',
  'products': 1000,
  'groups': 10,
  'openingEntries': 1000,
  'targetRestocks': 200,
  'targetHistoryRows': 201,
  'inventoryPageSize': 50,
  'photoAsset': 'assets/ui/chicken-kebab-480.webp',
  'photoBytes': 58554,
};

final class C1PerformanceOptions {
  const C1PerformanceOptions(this.operationId, this.iterations, this.runId);
  final String operationId, runId;
  final int iterations;

  factory C1PerformanceOptions.parse(List<String> arguments) {
    final values = <String, String>{};
    for (var i = 0; i < arguments.length; i += 2) {
      if (i + 1 >= arguments.length ||
          !{'--case', '--iterations', '--run-id'}.contains(arguments[i]) ||
          values.containsKey(arguments[i])) {
        throw const FormatException('Invalid C1 benchmark arguments.');
      }
      values[arguments[i]] = arguments[i + 1];
    }
    final operation = values['--case'] ?? '';
    final iterations = int.tryParse(values['--iterations'] ?? '1') ?? 0;
    final runId = values['--run-id'] ?? 'local';
    if (!c1PerformanceCases.contains(operation) ||
        iterations < 1 ||
        iterations > 100 ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(runId)) {
      throw const FormatException('Unsupported C1 benchmark options.');
    }
    return C1PerformanceOptions(operation, iterations, runId);
  }
}

/// C1 app commands and read models over one fresh real adapter per sample.
/// Setup, exact verification, close/reopen and cleanup are outside elapsed time.
/// The outer host resource window includes inter-iteration work.
final class C1PerformanceFixture {
  C1PerformanceFixture._(this.directory, this.operation) {
    store = AppAccountsStore(
      openStore: () => PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: directory.path,
      ),
    );
    repository = AccountsRepository(store: store);
  }

  static const targetProductId = 'c1-product-0001';
  static const _newProductId = 'c1-new-product';
  static const _photoKey = 'chicken-kebab';
  static final today = DateOnly.parse(
    '2026-01-03',
    minimumYear: 1000,
    maximumYear: 9999,
  );
  final Directory directory;
  final String operation;
  late final AppAccountsStore store;
  late final AccountsRepository repository;
  CatalogViewModel? _viewModel;
  ProductPhotoDraftController? _photo;
  late final CatalogEditSession _session;
  late final DocumentSnapshot _before;
  late final String _expectedPayload;
  CatalogPage? _pageResult;
  List<CatalogStockHistoryItem>? _historyResult;
  List<String> consumedIds = const [];
  int loadedPhotoBytes = 0;
  bool _ran = false, _verified = false, _closed = false;

  static Future<C1PerformanceFixture> create(
    String runId,
    String operation,
  ) async {
    C1PerformanceOptions.parse(['--case', operation, '--run-id', runId]);
    final directory = await Directory.systemTemp.createTemp(
      'dakhl-c1-bench-$runId-$pid-',
    );
    final fixture = C1PerformanceFixture._(directory, operation);
    try {
      await fixture._prepare();
      return fixture;
    } on Object {
      await fixture.close();
      rethrow;
    }
  }

  static void _ack<T>(CapabilityResult<T> result) {
    if (result is! CapabilitySuccess<T>) {
      throw StateError('C1 benchmark command was not acknowledged.');
    }
  }

  static String _productId(int i) =>
      'c1-product-${i.toString().padLeft(4, '0')}';
  static String _historyId(int i) =>
      'c1-history-${i.toString().padLeft(4, '0')}';
  static Map<String, Object?> _movement({
    required String id,
    required String productId,
    required num quantity,
    required String date,
    required String kind,
    required String createdAt,
    String note = '',
    String? reversesId,
  }) => {
    'id': id,
    'productId': productId,
    'quantity': quantity,
    'date': date,
    'kind': kind,
    'note': note,
    'createdAt': createdAt,
    'reversesId': ?reversesId,
  };

  Future<void> _prepare() async {
    _ack(await repository.open());
    final raw = Map<String, Object?>.from(repository.codec.empty().toJson());
    raw['products'] = [
      for (var i = 0; i < 1000; i++)
        {
          'id': _productId(i),
          'name': 'Synthetic product ${i.toString().padLeft(4, '0')}',
          'code': 'CODE-${i.toString().padLeft(4, '0')}',
          'unit': 'piece',
          'price': 1000 + i % 50,
          'group': 'group-${i % 10}',
          'minStock': i % 5 == 0 ? 150 : 2,
          'trackStock': true,
          'archived': i % 13 == 0,
          if (i == 1) 'photo': 'beef-kebab',
        },
    ];
    raw['stockEntries'] = [
      for (var i = 0; i < 1000; i++)
        _movement(
          id: 'c1-opening-$i',
          productId: _productId(i),
          quantity: 100,
          date: '2026-01-01',
          kind: 'opening',
          createdAt: '2026-01-01T00:00:00Z',
        ),
      for (var i = 0; i < 200; i++)
        _movement(
          id: _historyId(i),
          productId: targetProductId,
          quantity: 1,
          date: '2026-01-02',
          kind: 'restock',
          createdAt: DateTime.utc(2026, 1, 2, 0, 0, i).toIso8601String(),
        ),
    ];
    _ack(await repository.save(repository.codec.decodeJson(raw)));
    _ack(await repository.readWorkspace());
    _before = repository.snapshot!;
    final viewModel = _viewModel = CatalogViewModel(repository);
    _session = viewModel.beginEdit();
    if (operation == 'c1.product.create') {
      _photo = ProductPhotoDraftController.forNew(
        viewModel: viewModel,
        id: _newProductId,
        name: 'Synthetic created product',
        code: 'BENCH-NEW',
        unit: 'piece',
        price: 2500,
        group: 'group-new',
        minStock: 2,
      );
    } else if (operation.startsWith('c1.product.')) {
      _photo = ProductPhotoDraftController.forExisting(
        viewModel: viewModel,
        productId: targetProductId,
      );
      if (operation == 'c1.product.edit') {
        _photo!.draft
          ..name = 'Synthetic edited product'
          ..price = 3500;
      }
    }
    _expectedPayload = _expectedAccountPayload();
  }

  String _expectedAccountPayload() {
    final raw = (jsonDecode(_before.payload) as Map).cast<String, Object?>();
    final products = (raw['products'] as List).cast<Map<String, Object?>>();
    final stock = (raw['stockEntries'] as List).cast<Map<String, Object?>>();
    switch (operation) {
      case 'c1.product.create':
        products.add({
          'id': _newProductId,
          'name': 'Synthetic created product',
          'code': 'BENCH-NEW',
          'unit': 'piece',
          'price': 2500,
          'group': 'group-new',
          'minStock': 2,
          'trackStock': true,
          'archived': false,
        });
        stock.add(
          _movement(
            id: 'c1-new-opening',
            productId: _newProductId,
            quantity: 6.25,
            date: '2026-01-03',
            kind: 'opening',
            createdAt: '2026-01-03T12:00:00Z',
          ),
        );
      case 'c1.product.edit':
        final target = products.singleWhere((p) => p['id'] == targetProductId);
        target['name'] = 'Synthetic edited product';
        target['price'] = 3500;
      case 'c1.product.photo_select_save':
        products.singleWhere((p) => p['id'] == targetProductId)['photo'] =
            _photoKey;
      case 'c1.stock.post':
        stock.add(
          _movement(
            id: 'c1-restock-new',
            productId: targetProductId,
            quantity: 2.5,
            date: '2026-01-03',
            kind: 'restock',
            createdAt: '2026-01-03T12:00:00Z',
            note: 'Synthetic benchmark restock',
          ),
        );
      case 'c1.stock.reverse':
        stock.add(
          _movement(
            id: 'c1-reversal-new',
            productId: targetProductId,
            // The existing scale-three movement serializer emits -1.000 as
            // a JSON double; retain its exact wire representation here.
            quantity: -1.0,
            date: '2026-01-02',
            kind: 'adjustment',
            createdAt: '2026-01-03T12:00:00Z',
            note: 'Synthetic reversal',
            reversesId: _historyId(0),
          ),
        );
    }
    return utf8.decode(
      repository.codec.encode(repository.codec.decodeJson(raw)),
    );
  }

  /// Each fixture accepts exactly one measured command/query invocation.
  Future<void> run() async {
    if (_ran || _closed) {
      throw StateError('C1 benchmark fixture already consumed.');
    }
    _ran = true;
    final viewModel = _viewModel!;
    switch (operation) {
      case 'c1.catalog.lookup':
        viewModel.filter(query: 'CODE-0999');
        _pageResult = viewModel.inventoryAt(today)!;
        consumedIds = _pageResult!.items.map((p) => p.id).toList();
      case 'c1.catalog.filter':
        viewModel.filter(
          query: 'synthetic',
          group: 'group-5',
          status: InventoryStatus.low,
        );
        _pageResult = viewModel.inventoryAt(today)!;
        consumedIds = _pageResult!.items.map((p) => p.id).toList();
      case 'c1.catalog.page':
        viewModel.selectPage(2);
        _pageResult = viewModel.inventoryAt(today)!;
        consumedIds = _pageResult!.items.map((p) => p.id).toList();
      case 'c1.stock.history':
        _historyResult = viewModel.stockHistoryAt(
          targetProductId,
          today: today,
        );
        consumedIds = CatalogStockHistoryPage(
          _historyResult!,
          2,
        ).items.map((p) => p.id).toList();
      case 'c1.product.create':
        _ack(
          await _photo!.saveProduct(
            session: _session,
            opening: InventoryMovement(
              id: 'c1-new-opening',
              productId: _newProductId,
              quantityUnits: BigInt.from(6250),
              effectiveDate: today,
              kind: StockEntryKind.opening,
              createdAt: '2026-01-03T12:00:00Z',
            ),
          ),
        );
      case 'c1.product.edit':
        _ack(await _photo!.saveProduct(session: _session));
      case 'c1.product.photo_select_save':
        if (!_photo!.selectReferencePhoto(_photoKey)) {
          throw StateError('C1 photo selection rejected.');
        }
        final bytes = await rootBundle.load(_photo!.preview.assetPath!);
        loadedPhotoBytes = bytes.lengthInBytes;
        if (loadedPhotoBytes != c1PerformanceWorkload['photoBytes']) {
          throw StateError('C1 photo asset differs from workload.');
        }
        _ack(await _photo!.saveProduct(session: _session));
      case 'c1.stock.post':
        _ack(
          await viewModel.postMovement(
            InventoryMovement(
              id: 'c1-restock-new',
              productId: targetProductId,
              quantityUnits: BigInt.from(2500),
              effectiveDate: today,
              kind: StockEntryKind.restock,
              createdAt: '2026-01-03T12:00:00Z',
              note: 'Synthetic benchmark restock',
            ),
            session: _session,
          ),
        );
      case 'c1.stock.reverse':
        _ack(
          await viewModel.reverseMovement(
            _historyId(0),
            session: _session,
            newId: 'c1-reversal-new',
            reason: 'Synthetic reversal',
            createdAt: '2026-01-03T12:00:00Z',
          ),
        );
      default:
        throw StateError('Unsupported C1 benchmark operation.');
    }
  }

  void _verifyResults() {
    List<String>? expected;
    switch (operation) {
      case 'c1.catalog.lookup':
        expected = [_productId(999)];
        if (_pageResult?.total != 1) {
          throw StateError('C1 lookup total mismatch.');
        }
      case 'c1.catalog.filter':
        final all = [
          for (var i = 5; i < 1000; i += 10)
            if (i % 13 != 0) _productId(i),
        ];
        expected = all.take(50).toList();
        if (_pageResult?.total != all.length || _pageResult?.page != 1) {
          throw StateError('C1 filtered page mismatch.');
        }
      case 'c1.catalog.page':
        final all = [
          for (var i = 0; i < 1000; i++)
            if (i % 13 != 0) _productId(i),
        ];
        expected = all.skip(50).take(50).toList();
        if (_pageResult?.total != all.length || _pageResult?.page != 2) {
          throw StateError('C1 second page mismatch.');
        }
      case 'c1.stock.history':
        final history = _historyResult!;
        if (history.length != 201 ||
            history.first.id != 'c1-opening-1' ||
            history.first.deltaUnits != BigInt.from(100000) ||
            history.first.runningBalanceUnits != BigInt.from(100000)) {
          throw StateError('C1 opening history mismatch.');
        }
        for (var i = 0; i < 200; i++) {
          final row = history[i + 1];
          if (row.id != _historyId(i) ||
              row.deltaUnits != BigInt.from(1000) ||
              row.runningBalanceUnits != BigInt.from(101000 + i * 1000) ||
              row.isFuture ||
              !row.isReversible) {
            throw StateError('C1 history record mismatch.');
          }
        }
        expected = [for (var i = 149; i >= 100; i--) _historyId(i)];
    }
    if (expected != null && jsonEncode(consumedIds) != jsonEncode(expected)) {
      throw StateError('C1 consumed query IDs mismatch.');
    }
  }

  /// Full expected source bytes, exact revision/fence, independent known stock
  /// totals and fresh-owner reopen are checked before any sample is accepted.
  Future<void> verifyDurable() async {
    if (!_ran || _verified || _closed) {
      throw StateError('C1 verification order invalid.');
    }
    _verifyResults();
    final snapshot = repository.snapshot!;
    final expectedRevision =
        _before.revision + (c1QueryCases.contains(operation) ? 0 : 1);
    if (snapshot.payload != _expectedPayload ||
        snapshot.revision != expectedRevision ||
        snapshot.fence != _before.fence ||
        repository.hasUnknownWrite ||
        repository.hasUnknownWorkspaceWrite ||
        repository.workspaceSnapshot != null) {
      throw StateError('C1 complete source or authority mismatch.');
    }
    final projection = RestaurantStockProjection(repository.document!);
    final expectedTarget = switch (operation) {
      'c1.stock.post' => 302500,
      'c1.stock.reverse' => 299000,
      _ => 300000,
    };
    if (projection.balanceFor(targetProductId, through: today) !=
            BigInt.from(expectedTarget) ||
        (operation == 'c1.product.create' &&
            projection.balanceFor(_newProductId, through: today) !=
                BigInt.from(6250))) {
      throw StateError('C1 exact stock postcondition mismatch.');
    }
    if (_photo != null &&
        (_photo!.isBusy ||
            _photo!.errorCode != null ||
            _photo!.previousPhoto.key !=
                (operation == 'c1.product.photo_select_save'
                    ? _photoKey
                    : operation == 'c1.product.create'
                    ? null
                    : 'beef-kebab'))) {
      throw StateError('C1 product acknowledgement mismatch.');
    }
    await store.close();
    final reopenedStore = AppAccountsStore(
      openStore: () => PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: directory.path,
      ),
    );
    try {
      final reopened = AccountsRepository(store: reopenedStore);
      _ack(await reopened.open());
      _ack(await reopened.readWorkspace());
      final readback = reopened.snapshot!;
      if (readback.payload != snapshot.payload ||
          readback.revision != snapshot.revision ||
          readback.fence != snapshot.fence ||
          readback.writeToken != snapshot.writeToken ||
          reopened.workspaceSnapshot != null) {
        throw StateError('C1 complete durable readback mismatch.');
      }
    } finally {
      await reopenedStore.close();
    }
    _verified = true;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _photo?.dispose();
    _viewModel?.dispose();
    await store.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
