import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';

import '../accounts/account_document.dart';
import '../accounts/accounts_repository.dart';
import '../accounts/legacy_account_codec.dart';

/// Supported primary vs additional categorization.
enum CategoryType {
  primary('primary'),
  additional('additional');

  const CategoryType(this.wireValue);
  final String wireValue;

  static CategoryType fromWire(String? value, {required bool isBuiltIn}) {
    if (value == 'primary') return CategoryType.primary;
    if (value == 'additional') return CategoryType.additional;
    return isBuiltIn ? CategoryType.primary : CategoryType.additional;
  }
}

/// Validated, immutable category representation from current account authority.
@immutable
final class CategoryRecord {
  const CategoryRecord._({
    required this.id,
    required this.name,
    required this.type,
    required this.isArchived,
  });

  factory CategoryRecord.fromMap(Map<String, Object?> map) {
    final id = map['id']! as String;
    final isBuiltIn = CategoriesViewModel.isCoreBuiltIn(id);
    final rawType = map['type'] as String?;
    final type = CategoryType.fromWire(rawType, isBuiltIn: isBuiltIn);
    final isArchived = !isBuiltIn && map['archived'] == true;
    return CategoryRecord._(
      id: id,
      name: (map['name']! as String).trim(),
      type: type,
      isArchived: isArchived,
    );
  }

  final String id;
  final String name;
  final CategoryType type;
  final bool isArchived;

  bool get isBuiltIn => CategoriesViewModel.isCoreBuiltIn(id);
  bool get isActive => !isArchived;
  bool get isPrimary => type == CategoryType.primary;
  bool get isAdditional => type == CategoryType.additional;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'type': type.wireValue,
    if (isArchived && !isBuiltIn) 'archived': true,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          isArchived == other.isArchived;

  @override
  int get hashCode => Object.hash(id, name, type, isArchived);

  @override
  String toString() =>
      'CategoryRecord(id: $id, name: $name, type: ${type.wireValue}, isArchived: $isArchived, isBuiltIn: $isBuiltIn)';
}

/// Mutable draft for dialog-based category creation or editing.
final class CategoryDraft {
  CategoryDraft._(
    this._base,
    this._snapshot,
    this.id,
    this.isExisting,
    this.isBuiltIn, {
    required this._name,
    required this.type,
    required this._archived,
  });

  final AccountDocument _base;
  final DocumentSnapshot? _snapshot;
  final String id;
  final bool isExisting;
  final bool isBuiltIn;

  String _name;
  CategoryType type;
  bool _archived;

  String get name => _name;
  set name(String value) {
    if (isBuiltIn) {
      // Built-in categories cannot be renamed.
      return;
    }
    _name = value;
  }

  bool get isArchived => _archived;
  set isArchived(bool value) {
    if (isBuiltIn) {
      // Built-in categories cannot be archived.
      return;
    }
    _archived = value;
  }

  CategoryDraft copy() => CategoryDraft._(
    _base,
    _snapshot,
    id,
    isExisting,
    isBuiltIn,
    name: _name,
    type: type,
    archived: _archived,
  );
}

/// Nonvisual ViewModel and controller for account-scoped expense category metadata.
///
/// Implements C4-01 (grid/dialog commands, classification with automatic save),
/// C4-02 (built-in protections, custom archive/restore, duplicate name validation),
/// and C4-03 (active selectors, inline category creation, historical reference preservation).
final class CategoriesViewModel extends ChangeNotifier {
  CategoriesViewModel(this.repository);

  final AccountsRepository repository;

  static const Map<String, String> coreBuiltIns = {
    'samoon': 'الصمون',
    'bread': 'الخبز',
    'falafel': 'الفلافل',
    'market': 'الأسواق',
  };

  static bool isCoreBuiltIn(String id) => coreBuiltIns.containsKey(id);

  bool _busy = false;
  bool _disposed = false;
  int _notificationDepth = 0;
  String? lastErrorCode;
  String? lastErrorMessage;

  bool get busy => _busy;
  bool get isDisposed => _disposed;

  List<Map<String, Object?>> _rows(AccountDocument doc) =>
      (doc.toJson()['categories']! as List).cast<Map<String, Object?>>();

  AccountDocument _base() {
    if (_disposed) {
      throw StateError('ViewModel closed.');
    }
    if (repository.document == null) {
      throw StateError('Read accounts before editing categories.');
    }
    return repository.document!;
  }

  static String _generateId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  // --- Presentation contract (C4-01 / C4-03) ---

  List<CategoryRecord> get allCategories => List.unmodifiable([
    if (repository.document case final doc?)
      for (final row in _rows(doc)) CategoryRecord.fromMap(row),
  ]);

  List<CategoryRecord> get activeCategories =>
      List.unmodifiable(allCategories.where((c) => c.isActive));

  List<CategoryRecord> get primaryCategories =>
      List.unmodifiable(allCategories.where((c) => c.isActive && c.isPrimary));

  List<CategoryRecord> get additionalCategories => List.unmodifiable(
    allCategories.where((c) => c.isActive && c.isAdditional),
  );

  List<CategoryRecord> get archivedCategories =>
      List.unmodifiable(allCategories.where((c) => c.isArchived));

  CategoryRecord? findById(String id) {
    for (final category in allCategories) {
      if (category.id == id) return category;
    }
    return null;
  }

  String categoryName(String id, {String fallback = 'خانة'}) =>
      findById(id)?.name ?? fallback;

  /// Selector choices for expense forms and supplier payments.
  ///
  /// Returns active categories, plus [currentCategoryId] if it refers to a
  /// historical archived category so that saved references stay selectable.
  List<CategoryRecord> selectorChoices({String? currentCategoryId}) {
    return List.unmodifiable(
      allCategories.where(
        (category) => !category.isArchived || category.id == currentCategoryId,
      ),
    );
  }

  // --- Draft commands (C4-01) ---

  CategoryDraft newCategoryDraft({
    String? id,
    CategoryType type = CategoryType.additional,
  }) {
    final base = _base();
    final effectiveId = (id != null && id.trim().isNotEmpty)
        ? id.trim()
        : _generateId();
    final isBuiltIn = isCoreBuiltIn(effectiveId);
    return CategoryDraft._(
      base,
      repository.snapshot,
      effectiveId,
      false,
      isBuiltIn,
      name: isBuiltIn ? coreBuiltIns[effectiveId]! : '',
      type: type,
      archived: false,
    );
  }

  CategoryDraft? editCategoryDraft(String id) {
    final base = _base();
    for (final row in _rows(base)) {
      if (row['id'] != id) continue;
      final record = CategoryRecord.fromMap(row);
      return CategoryDraft._(
        base,
        repository.snapshot,
        record.id,
        true,
        record.isBuiltIn,
        name: record.name,
        type: record.type,
        archived: record.isArchived,
      );
    }
    return null;
  }

  // --- Save / classification commands (C4-01 / C4-02 / C4-03) ---

  Future<CapabilityResult<CategoryRecord>> saveCategory(
    CategoryDraft draft,
  ) async {
    if (_disposed) {
      return const CapabilityFailure('disposed', 'ViewModel closed.');
    }
    if (_busy) {
      return const CapabilityFailure('busy', 'Category write in progress.');
    }
    if (!identical(repository.document, draft._base) ||
        repository.snapshot != draft._snapshot) {
      return const CapabilityFailure(
        'conflict',
        'Read current accounts before editing categories.',
      );
    }
    if (repository.hasUnknownWrite || repository.hasUnknownWorkspaceWrite) {
      return const CapabilityFailure(
        'commit_unknown',
        'Reconcile accounts before editing.',
      );
    }

    final trimmedName = draft.name.trim();
    if (trimmedName.isEmpty) {
      lastErrorCode = 'invalid_name';
      lastErrorMessage = 'اسم الخانة فارغ.';
      _notify();
      return const CapabilityFailure(
        'invalid_name',
        'Category name cannot be empty.',
      );
    }
    if (trimmedName.length > 80) {
      lastErrorCode = 'invalid_name';
      lastErrorMessage = 'اسم الخانة يتجاوز 80 حرفاً.';
      _notify();
      return const CapabilityFailure(
        'invalid_name',
        'Category name exceeds 80 characters.',
      );
    }

    // Built-in restrictions
    if (isCoreBuiltIn(draft.id)) {
      if (trimmedName != coreBuiltIns[draft.id]) {
        lastErrorCode = 'forbidden';
        lastErrorMessage = 'الخانات الأصلية لا يمكن تغيير اسمها.';
        _notify();
        return const CapabilityFailure(
          'forbidden',
          'Built-in categories cannot be renamed.',
        );
      }
      if (draft.isArchived) {
        lastErrorCode = 'forbidden';
        lastErrorMessage = 'الخانات الأصلية لا يمكن أرشفتها.';
        _notify();
        return const CapabilityFailure(
          'forbidden',
          'Built-in categories cannot be archived.',
        );
      }
      if (!draft.isExisting) {
        lastErrorCode = 'forbidden';
        lastErrorMessage = 'معرف الخانة محجوز للخانات الأصلية.';
        _notify();
        return const CapabilityFailure(
          'forbidden',
          'Built-in categories cannot be created.',
        );
      }
    }

    // Duplicate name validation
    final rows = [..._rows(draft._base)];
    final duplicate = rows.any(
      (r) =>
          r['id'] != draft.id && (r['name']! as String).trim() == trimmedName,
    );
    if (duplicate) {
      lastErrorCode = 'duplicate_name';
      lastErrorMessage = 'اسم الخانة موجود مسبقاً. اختاره من القائمة.';
      _notify();
      return const CapabilityFailure(
        'duplicate_name',
        'اسم الخانة موجود مسبقاً.',
      );
    }

    // Maximum categories check (500 limit per codec)
    final existingIndex = rows.indexWhere((r) => r['id'] == draft.id);
    if ((existingIndex >= 0) != draft.isExisting) {
      return const CapabilityFailure('conflict', 'Category identity changed.');
    }
    if (existingIndex < 0 && rows.length >= 500) {
      lastErrorCode = 'limit_exceeded';
      lastErrorMessage = 'وصلت للحد الأقصى للخانات (500 خانة).';
      _notify();
      return const CapabilityFailure(
        'limit_exceeded',
        'Maximum of 500 categories reached.',
      );
    }

    final updatedMap = <String, Object?>{
      'id': draft.id,
      'name': trimmedName,
      'type': draft.type.wireValue,
      if (draft.isArchived && !draft.isBuiltIn) 'archived': true,
    };
    lastErrorCode = null;
    lastErrorMessage = null;
    _busy = true;
    _notify();

    try {
      if (existingIndex < 0) {
        rows.add(updatedMap);
      } else {
        rows[existingIndex] = updatedMap;
      }

      final document = repository.codec.decodeJson({
        ...draft._base.toJson(),
        'categories': rows,
      });

      if (_disposed ||
          !identical(repository.document, draft._base) ||
          repository.snapshot != draft._snapshot) {
        return const CapabilityFailure(
          'conflict',
          'Account authority changed.',
        );
      }

      final saveResult = await repository.save(document);
      switch (saveResult) {
        case CapabilitySuccess():
          lastErrorCode = null;
          lastErrorMessage = null;
        case CapabilityFailure(:final code, :final message):
          lastErrorCode = code;
          lastErrorMessage = message;
        case CapabilityCancelled():
          lastErrorCode = 'cancelled';
          lastErrorMessage = 'Write was cancelled.';
      }
      return switch (saveResult) {
        CapabilitySuccess() => CapabilitySuccess(
          CategoryRecord.fromMap(updatedMap),
        ),
        CapabilityFailure(:final code, :final message) => CapabilityFailure(
          code,
          message,
        ),
        CapabilityCancelled() => const CapabilityFailure(
          'cancelled',
          'Write was cancelled.',
        ),
      };
    } on AccountCodecException catch (error) {
      lastErrorCode = error.code;
      lastErrorMessage = 'Category validation failed.';
      _notify();
      return CapabilityFailure(error.code, 'Category validation failed.');
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Automatic save for category classification (primary vs additional).
  Future<CapabilityResult<CategoryRecord>> setCategoryType(
    String id,
    CategoryType newType,
  ) async {
    final existing = findById(id);
    if (existing == null) {
      return const CapabilityFailure('not_found', 'Category not found.');
    }
    if (existing.type == newType) {
      return CapabilitySuccess(existing);
    }

    final draft = editCategoryDraft(id);
    if (draft == null) {
      return const CapabilityFailure('not_found', 'Category not found.');
    }
    draft.type = newType;
    return saveCategory(draft);
  }

  /// Inline expense-category creation (C4-03).
  Future<CapabilityResult<CategoryRecord>> createInlineCategory({
    required String name,
    CategoryType type = CategoryType.additional,
    String? id,
  }) async {
    final draft = newCategoryDraft(id: id, type: type)..name = name;
    return saveCategory(draft);
  }

  /// Archive a custom category (C4-02).
  Future<CapabilityResult<CategoryRecord>> archiveCategory(String id) async {
    if (isCoreBuiltIn(id)) {
      return const CapabilityFailure(
        'forbidden',
        'Built-in categories cannot be archived.',
      );
    }
    final existing = findById(id);
    if (existing == null) {
      return const CapabilityFailure('not_found', 'Category not found.');
    }
    if (existing.isArchived) {
      return CapabilitySuccess(existing);
    }
    final draft = editCategoryDraft(id);
    if (draft == null) {
      return const CapabilityFailure('not_found', 'Category not found.');
    }
    draft.isArchived = true;
    return saveCategory(draft);
  }

  /// Restore an archived custom category (C4-02).
  Future<CapabilityResult<CategoryRecord>> restoreCategory(String id) async {
    final existing = findById(id);
    if (existing == null) {
      return const CapabilityFailure('not_found', 'Category not found.');
    }
    if (!existing.isArchived) {
      return CapabilitySuccess(existing);
    }
    final draft = editCategoryDraft(id);
    if (draft == null) {
      return const CapabilityFailure('not_found', 'Category not found.');
    }
    draft.isArchived = false;
    return saveCategory(draft);
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
