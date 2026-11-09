import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';
import '../accounts/legacy_account_codec.dart';
import '../inventory/inventory_commands.dart';
import 'catalog_view_model.dart';

/// Conformance specification for product photo references, frozen schema constraints,
/// and image byte verification.
final class ProductPhotoReference {
  ProductPhotoReference._();

  /// Canonical photo identifiers accepted by [LegacyAccountCodec] and frozen Electron schema.
  static const List<String> canonicalKeys = [
    'beef-kebab',
    'chicken-kebab',
    'grilled-chicken',
    'dulaimiya',
    'red-rice',
    'appetizers',
    'water',
    'cola',
  ];

  /// Arabic localized labels from preserved reference `app/ui/commerce.js`.
  static const Map<String, String> labels = {
    'beef-kebab': 'كباب لحم',
    'chicken-kebab': 'كباب دجاج',
    'grilled-chicken': 'دجاج مشوي',
    'dulaimiya': 'دليمية',
    'red-rice': 'تمن أحمر',
    'appetizers': 'مقبلات',
    'water': 'ماء',
    'cola': 'مشروب غازي',
  };

  /// Preserved asset paths in `assets/ui/` (480px WebP images).
  static const Map<String, String> assetPaths = {
    'beef-kebab': 'assets/ui/beef-kebab-480.webp',
    'chicken-kebab': 'assets/ui/chicken-kebab-480.webp',
    'grilled-chicken': 'assets/ui/grilled-chicken-480.webp',
    'dulaimiya': 'assets/ui/dulaimiya-480.webp',
    'red-rice': 'assets/ui/red-rice-480.webp',
    'appetizers': 'assets/ui/appetizers-480.webp',
    'water': 'assets/ui/water-480.webp',
    'cola': 'assets/ui/cola-480.webp',
  };

  /// Returns true if [key] is null, empty (no photo), or one of the 8 canonical keys.
  static bool isValidKey(String? key) {
    if (key == null || key.isEmpty) return true;
    return canonicalKeys.contains(key);
  }

  /// Returns the Arabic label for [key], or 'بدون صورة' if null/empty/unknown.
  static String labelFor(String? key) {
    if (key == null || key.isEmpty) return 'بدون صورة';
    return labels[key] ?? 'بدون صورة';
  }

  /// Returns the asset path for [key], or null if null/empty/unknown.
  static String? assetPathFor(String? key) {
    if (key == null || key.isEmpty) return null;
    return assetPaths[key];
  }
}

/// A bundled photo preview; persisted data contains only a frozen reference key.
@immutable
final class ProductPhotoPreview {
  const ProductPhotoPreview._(this.key, this.label, this.assetPath);
  const ProductPhotoPreview.none() : this._(null, 'بدون صورة', null);

  factory ProductPhotoPreview.fromReference(String key) {
    if (!ProductPhotoReference.canonicalKeys.contains(key)) {
      throw const DomainValidationException('invalid_photo');
    }
    return ProductPhotoPreview._(
      key,
      ProductPhotoReference.labelFor(key),
      ProductPhotoReference.assetPathFor(key),
    );
  }

  static ProductPhotoPreview _forKey(String? key) => key == null || key.isEmpty
      ? const ProductPhotoPreview.none()
      : ProductPhotoPreview.fromReference(key);

  final String? key, assetPath;
  final String label;
  bool get hasPhoto => key != null;
}

/// Editable product metadata. Identity is caller-owned; photo edits use the
/// controller so preview and submitted schema key cannot diverge.
final class ProductDraft {
  ProductDraft._({
    required this.id,
    this.name = '',
    this.code = '',
    this.unit = 'قطعة',
    this.group = '',
    this.price = 0,
    this._photo,
    this.trackStock = true,
    this.minStock = 0,
    this.archived = false,
  });

  final String id;
  String name, code, unit, group;
  int price;
  String? _photo;
  String? get photo => _photo;
  bool trackStock, archived;
  num minStock;

  ProductDraft copy() => ProductDraft._(
    id: id,
    name: name,
    code: code,
    unit: unit,
    group: group,
    price: price,
    photo: photo,
    trackStock: trackStock,
    minStock: minStock,
    archived: archived,
  );

  Map<String, Object?> toProductMap() => {
    if (photo != null && photo!.isNotEmpty) 'photo': photo,
    'id': id,
    'name': name.trim(),
    'code': code.trim(),
    'unit': unit.trim(),
    'price': price,
    'group': group.trim(),
    'minStock': minStock,
    'trackStock': trackStock,
    'archived': archived,
  };

  Map<String, Object?> toImmutableSnapshot() =>
      Map<String, Object?>.unmodifiable(toProductMap());
}

/// Account-scoped reference-photo editing over existing catalog commands.
/// No file picker, image bytes, hidden clock/ID, or stock arithmetic lives here.
final class ProductPhotoDraftController extends ChangeNotifier {
  ProductPhotoDraftController._({
    required this.viewModel,
    required bool isNewProduct,
    required this.draft,
  }) : _isNewProduct = isNewProduct,
       _preview = ProductPhotoPreview._forKey(draft.photo),
       _previousPhoto = isNewProduct
           ? const ProductPhotoPreview.none()
           : ProductPhotoPreview._forKey(draft.photo),
       _account =
           viewModel.repository.document ??
           (throw StateError('Read accounts before opening a product form.')),
       _snapshot =
           viewModel.repository.snapshot ??
           (throw StateError('Read accounts before opening a product form.'));

  factory ProductPhotoDraftController.forNew({
    required CatalogViewModel viewModel,
    required String id,
    String name = '',
    String code = '',
    String unit = 'قطعة',
    String group = '',
    int price = 0,
    String? initialPhoto,
    bool trackStock = true,
    num minStock = 0,
  }) => ProductPhotoDraftController._(
    viewModel: viewModel,
    isNewProduct: true,
    draft: ProductDraft._(
      id: id,
      name: name,
      code: code,
      unit: unit,
      group: group,
      price: price,
      photo: initialPhoto,
      trackStock: trackStock,
      minStock: minStock,
    ),
  );

  factory ProductPhotoDraftController.forExisting({
    required CatalogViewModel viewModel,
    required String productId,
  }) {
    final account = viewModel.repository.document;
    if (account == null) {
      throw StateError('Read accounts before editing a product.');
    }
    final row = (account.toJson()['products'] as List)
        .cast<Map<String, Object?>>()
        .firstWhere((row) => row['id'] == productId);
    return ProductPhotoDraftController._(
      viewModel: viewModel,
      isNewProduct: false,
      draft: ProductDraft._(
        id: row['id']! as String,
        name: row['name']! as String,
        code: row['code']! as String,
        unit: row['unit']! as String,
        group: row['group']! as String,
        price: row['price']! as int,
        photo: row['photo'] as String?,
        trackStock: row['trackStock']! as bool,
        minStock: row['minStock']! as num,
        archived: row['archived']! as bool,
      ),
    );
  }

  final CatalogViewModel viewModel;
  final ProductDraft draft;
  AccountDocument _account;
  DocumentSnapshot _snapshot;
  bool _isNewProduct, _busy = false, _disposed = false;
  int _notificationDepth = 0;
  String? _errorCode;
  ProductPhotoPreview _preview, _previousPhoto;

  bool get isNewProduct => _isNewProduct;
  bool get isBusy => _busy;
  String? get errorCode => _errorCode;
  ProductPhotoPreview get preview => _preview;

  /// Last acknowledged photo, never an intermediate unsaved selection.
  ProductPhotoPreview get previousPhoto => _previousPhoto;

  bool selectReferencePhoto(String? key) {
    if (_disposed || _busy) return false;
    if (!ProductPhotoReference.isValidKey(key)) {
      _errorCode = 'invalid_photo';
      _notify();
      return false;
    }
    draft._photo = key == null || key.isEmpty ? null : key;
    _preview = ProductPhotoPreview._forKey(draft.photo);
    _errorCode = null;
    _notify();
    return true;
  }

  void removePhoto() => selectReferencePhoto(null);

  bool _hasAuthority(CatalogEditSession session) =>
      identical(viewModel.repository.document, _account) &&
      viewModel.repository.snapshot == _snapshot &&
      session.snapshot == _snapshot;

  CapabilityFailure<AccountDocument> _failure(String code) {
    if (!_disposed) _errorCode = code;
    return CapabilityFailure(code, 'Product save unavailable.');
  }

  Future<CapabilityResult<AccountDocument>> saveProduct({
    required CatalogEditSession session,
    InventoryMovement? opening,
  }) async {
    if (_disposed) return const CapabilityFailure('disposed', 'Form closed.');
    if (_busy) {
      return const CapabilityFailure('busy', 'Save already in progress.');
    }
    if (!_hasAuthority(session)) {
      final result = _failure('stale_revision');
      _notify();
      return result;
    }
    if (!_isNewProduct && opening != null) {
      final result = _failure('invalid_opening_stock');
      _notify();
      return result;
    }
    final submitted = draft.toImmutableSnapshot();
    _busy = true;
    _errorCode = null;
    try {
      _notify();
      if (_disposed) return _failure('disposed');
      if (!_hasAuthority(session)) return _failure('stale_revision');
      final result = _isNewProduct
          ? await viewModel.createProduct(
              submitted,
              session: session,
              opening: opening,
            )
          : await viewModel.editProduct(submitted, session: session);
      if (!_disposed) {
        if (result case CapabilitySuccess<AccountDocument>(:final value)) {
          _previousPhoto = ProductPhotoPreview._forKey(
            submitted['photo'] as String?,
          );
          _isNewProduct = false;
          // Never refresh the form onto unrelated authority after a late callback.
          if (identical(viewModel.repository.document, value)) {
            _account = value;
            _snapshot = viewModel.repository.snapshot!;
          }
          _errorCode = null;
        } else if (result case CapabilityFailure(:final code)) {
          _errorCode = code;
        }
      }
      return result;
    } on DomainValidationException catch (error) {
      return _failure(error.code);
    } on AccountCodecException catch (error) {
      return _failure(error.code);
    } on Object {
      // An exception is not proof that a write failed before commitment.
      // Retain all form input and rely on repository authority before retry.
      return _failure('unavailable');
    } finally {
      _busy = false;
      if (!_disposed) _notify();
    }
  }

  void _notify() {
    if (_disposed || _notificationDepth > 0) return;
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
