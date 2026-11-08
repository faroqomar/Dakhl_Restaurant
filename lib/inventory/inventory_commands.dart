import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';
import '../accounts/accounts_repository.dart';
import '../accounts/legacy_account_codec.dart';
import 'stock_projection.dart';

/// Caller-owned identity/time and exact thousandths; no hidden clock or ID.
final class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.productId,
    required this.quantityUnits,
    required this.effectiveDate,
    required this.kind,
    required this.createdAt,
    this.note = '',
  });
  final String id, productId, createdAt, note;
  final BigInt quantityUnits;
  final DateOnly effectiveDate;
  final StockEntryKind kind;
}

/// Nonvisual restaurant composition. Madar owns stock invariants and storage.
/// Callers retain an acknowledged snapshot; no automatic authority refresh.
final class InventoryCommands {
  InventoryCommands(this.repository);
  final AccountsRepository repository;
  bool _busy = false;
  bool get busy => _busy;
  static final _limit = BigInt.from(1000000000000);

  Future<CapabilityResult<AccountDocument>> createProduct(
    Map<String, Object?> product, {
    required DocumentSnapshot expected,
    InventoryMovement? opening,
  }) => _run(expected, (current) {
    final raw = Map<String, Object?>.from(current.toJson());
    final products = _records(current, 'products').toList();
    if (products.any((p) => p['id'] == product['id'])) {
      throw const DomainValidationException('duplicate_product');
    }
    final next = Map<String, Object?>.from(product);
    if (next['trackStock'] == false) next['minStock'] = 0;
    products.add(next);
    raw['products'] = products;
    if (opening != null) {
      if (opening.productId != next['id'] ||
          opening.kind != StockEntryKind.opening ||
          next['trackStock'] != true) {
        throw const DomainValidationException('invalid_opening_stock');
      }
      raw['stockEntries'] = [
        ..._records(current, 'stockEntries'),
        _movementJson(opening),
      ];
    }
    return raw;
  });

  Future<CapabilityResult<AccountDocument>> editProduct(
    Map<String, Object?> product, {
    required DocumentSnapshot expected,
  }) => _run(expected, (current) {
    final raw = Map<String, Object?>.from(current.toJson());
    final products = _records(current, 'products').toList();
    final index = products.indexWhere((p) => p['id'] == product['id']);
    if (index < 0) throw const DomainValidationException('missing_product');
    final old = products[index];
    final hasHistory =
        _records(
          current,
          'stockEntries',
        ).any((e) => e['productId'] == old['id']) ||
        _records(current, 'sales').any(
          (s) => (s['lines'] as List).any(
            (l) => (l as Map)['productId'] == old['id'],
          ),
        );
    final next = Map<String, Object?>.from(product);
    // Frozen commerce.js retains locked values rather than applying form edits.
    if (hasHistory) {
      next['unit'] = old['unit'];
      next['trackStock'] = old['trackStock'];
    }
    if (next['trackStock'] == false) next['minStock'] = 0;
    products[index] = next;
    raw['products'] = products;
    return raw;
  });

  Future<CapabilityResult<AccountDocument>> setArchived(
    String productId,
    bool archived, {
    required DocumentSnapshot expected,
  }) => _run(expected, (current) {
    final products = _records(current, 'products').toList();
    final index = products.indexWhere((p) => p['id'] == productId);
    if (index < 0) throw const DomainValidationException('missing_product');
    products[index] = {...products[index], 'archived': archived};
    return {...current.toJson(), 'products': products};
  });

  Future<CapabilityResult<AccountDocument>> postMovement(
    InventoryMovement movement, {
    required DocumentSnapshot expected,
  }) => _run(
    expected,
    (current) => {
      ...current.toJson(),
      'stockEntries': [
        ..._records(current, 'stockEntries'),
        _movementJson(movement),
      ],
    },
  );

  Future<CapabilityResult<AccountDocument>> reverseMovement(
    String entryId, {
    required String newId,
    required String reason,
    required String createdAt,
    required DocumentSnapshot expected,
    String? archiveCreatedProductId,
  }) => _run(expected, (current) {
    final entries = _records(current, 'stockEntries').toList();
    final matching = entries.where((e) => e['id'] == entryId);
    if (matching.length != 1) {
      throw const DomainValidationException('missing_stock_entry');
    }
    final original = matching.single;
    if (original['reversesId'] != null ||
        entries.any((e) => e['reversesId'] == entryId)) {
      throw const DomainValidationException('invalid_stock_reversal');
    }
    final inverse = InventoryMovement(
      id: newId,
      productId: original['productId'] as String,
      quantityUnits: -_units(original['quantity']),
      effectiveDate: _date(original['date']),
      kind: StockEntryKind.adjustment,
      createdAt: createdAt,
      note: LegacyText.trimJavaScript(reason),
    );
    entries.add({..._movementJson(inverse), 'reversesId': entryId});
    final next = {...current.toJson(), 'stockEntries': entries};
    if (archiveCreatedProductId != null) {
      if (original['productId'] != archiveCreatedProductId ||
          original['kind'] != 'opening') {
        throw const DomainValidationException('invalid_product_creation_undo');
      }
      final products = _records(current, 'products').toList();
      final index = products.indexWhere(
        (p) => p['id'] == archiveCreatedProductId,
      );
      if (index < 0) throw const DomainValidationException('missing_product');
      products[index] = {...products[index], 'archived': true};
      next['products'] = products;
    }
    return next;
  });

  Future<CapabilityResult<AccountDocument>> _run(
    DocumentSnapshot expected,
    Map<String, Object?> Function(AccountDocument) transform,
  ) async {
    if (_busy) {
      return const CapabilityFailure('busy', 'Inventory save in progress.');
    }
    if (repository.hasUnknownWrite || repository.hasUnknownWorkspaceWrite) {
      return const CapabilityFailure(
        'commit_unknown',
        'Read back before retrying.',
      );
    }
    final current = repository.document;
    final actual = repository.snapshot;
    if (current == null || actual == null) {
      return const CapabilityFailure('not_initialized', 'Read accounts first.');
    }
    if (actual.fence != expected.fence ||
        actual.revision != expected.revision ||
        actual.writeToken != expected.writeToken ||
        actual.payload != expected.payload) {
      return const CapabilityFailure(
        'stale_revision',
        'Read current accounts first.',
      );
    }
    _busy = true;
    try {
      final candidate = repository.codec.decodeJson(transform(current));
      _validateStock(candidate);
      // Repository sends this same acknowledged snapshot to the shared store;
      // competing writers are still checked by the engine's durable fence/CAS.
      return await repository.save(candidate);
    } on DomainValidationException catch (error) {
      return CapabilityFailure(error.code, 'Inventory validation failed.');
    } on AccountCodecException catch (error) {
      return CapabilityFailure(error.code, 'Inventory validation failed.');
    } on Object {
      return const CapabilityFailure(
        'invalid_inventory',
        'Inventory input is invalid.',
      );
    } finally {
      _busy = false;
    }
  }

  static Iterable<Map<String, Object?>> _records(
    AccountDocument doc,
    String key,
  ) => (doc.toJson()[key] as List).cast<Map<String, Object?>>();
  static DateOnly _date(Object? raw) =>
      DateOnly.parse(raw as String, minimumYear: 1000, maximumYear: 9999);
  static BigInt _units(Object? raw) => ExactDecimal.parse(
    raw.toString(),
    scale: 3,
    maxAbsUnits: _limit,
    signed: true,
    positive: false,
    allowExponent: true,
  ).units;
  static Map<String, Object?> _movementJson(InventoryMovement m) => {
    'id': m.id,
    'productId': m.productId,
    'quantity': num.parse(
      ExactDecimal.fromUnits(m.quantityUnits, 3).toString(),
    ),
    'date': m.effectiveDate.toString(),
    'kind': m.kind.name,
    'note': m.note,
    'createdAt': m.createdAt,
  };
  static void _validateStock(AccountDocument doc) {
    final products = {for (final p in _records(doc, 'products')) p['id']: p};
    StockEntries.validate(
      _records(doc, 'stockEntries').map(
        (e) => StockEntry(
          id: e['id'] as String,
          itemId: e['productId'] as String,
          unitId: products[e['productId']]!['unit'] as String,
          effectiveDate: _date(e['date']),
          deltaUnits: _units(e['quantity']),
          kind: StockEntryKind.values.byName(e['kind'] as String),
          reversesId: e['reversesId'] as String?,
          reason: e['note'] as String,
        ),
      ),
      maximumMovement: _limit,
    );
    RestaurantStockProjection(doc).validateHistory();
  }
}
