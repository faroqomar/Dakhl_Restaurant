import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';

import '../accounts/account_document.dart';
import '../accounts/accounts_repository.dart';
import '../accounts/legacy_account_codec.dart';

/// Supplier metadata only. Opening debt is visible but cannot be edited here.
final class SupplierRecord {
  SupplierRecord._(Map<String, Object?> row)
    : id = row['id']! as String,
      name = row['name']! as String,
      phone = row['phone']! as String,
      note = row['note']! as String,
      categoryId = row['categoryId']! as String,
      openingBalance = row['openingBalance']! as int,
      archived = row['archived'] == true;
  final String id, name, phone, note, categoryId;
  final int openingBalance;
  final bool archived;
}

/// Independent default prices; neither field implies a carton conversion.
final class MaterialRecord {
  MaterialRecord._(Map<String, Object?> row)
    : id = row['id']! as String,
      name = row['name']! as String,
      unit = row['unit']! as String,
      priceCarton = row['priceCarton']! as int,
      pricePiece = row['pricePiece']! as int,
      archived = row['archived']! as bool;
  final String id, name, unit;
  final int priceCarton, pricePiece;
  final bool archived;
}

sealed class PartyDraft {
  PartyDraft._(this._base, this._snapshot, this.id, this._existing);
  final AccountDocument _base;
  final DocumentSnapshot? _snapshot;
  final String id;
  final bool _existing;
}

final class SupplierDraft extends PartyDraft {
  SupplierDraft._(
    super.base,
    super.snapshot,
    super.id,
    super.existing, {
    required this.name,
    required this.phone,
    required this.note,
    required this.categoryId,
    required this.archived,
  }) : super._();
  String name, phone, note, categoryId;
  bool archived;
}

final class MaterialDraft extends PartyDraft {
  MaterialDraft._(
    super.base,
    super.snapshot,
    super.id,
    super.existing, {
    required this.name,
    required this.unit,
    required this.priceCarton,
    required this.pricePiece,
    required this.archived,
  }) : super._();
  String name, unit;
  int priceCarton, pricePiece;
  bool archived;
}

/// Nonvisual catalog commands over the current immutable account authority.
/// IDs are supplied by the caller; no financial posting or history rewrite.
final class PartiesViewModel extends ChangeNotifier {
  PartiesViewModel(this.repository);
  final AccountsRepository repository;
  bool _busy = false, _disposed = false;
  bool get busy => _busy;
  List<Map<String, Object?>> _rows(AccountDocument doc, String key) =>
      (doc.toJson()[key]! as List).cast<Map<String, Object?>>();
  List<SupplierRecord> get suppliers => List.unmodifiable([
    if (repository.document case final doc?)
      for (final row in _rows(doc, 'suppliers')) SupplierRecord._(row),
  ]);
  List<MaterialRecord> get materials => List.unmodifiable([
    if (repository.document case final doc?)
      for (final row in _rows(doc, 'materials')) MaterialRecord._(row),
  ]);
  AccountDocument _base() {
    if (_disposed || repository.document == null) {
      throw StateError('Read accounts before editing catalogs.');
    }
    return repository.document!;
  }

  SupplierDraft newSupplier({required String id, required String categoryId}) =>
      SupplierDraft._(
        _base(),
        repository.snapshot,
        id,
        false,
        name: '',
        phone: '',
        note: '',
        categoryId: categoryId,
        archived: false,
      );
  MaterialDraft newMaterial({required String id}) => MaterialDraft._(
    _base(),
    repository.snapshot,
    id,
    false,
    name: '',
    unit: '',
    priceCarton: 0,
    pricePiece: 0,
    archived: false,
  );
  SupplierDraft? editSupplier(String id) {
    final base = _base();
    for (final row in _rows(base, 'suppliers')) {
      if (row['id'] != id) continue;
      final value = SupplierRecord._(row);
      return SupplierDraft._(
        base,
        repository.snapshot,
        id,
        true,
        name: value.name,
        phone: value.phone,
        note: value.note,
        categoryId: value.categoryId,
        archived: value.archived,
      );
    }
    return null;
  }

  MaterialDraft? editMaterial(String id) {
    final base = _base();
    for (final row in _rows(base, 'materials')) {
      if (row['id'] != id) continue;
      final value = MaterialRecord._(row);
      return MaterialDraft._(
        base,
        repository.snapshot,
        id,
        true,
        name: value.name,
        unit: value.unit,
        priceCarton: value.priceCarton,
        pricePiece: value.pricePiece,
        archived: value.archived,
      );
    }
    return null;
  }

  Future<CapabilityResult<AccountDocument>> saveSupplier(SupplierDraft draft) =>
      _save(draft, 'suppliers', {
        'name': draft.name,
        'phone': draft.phone,
        'note': draft.note,
        'categoryId': draft.categoryId,
        'archived': draft.archived,
        if (!draft._existing) 'openingBalance': 0,
        if (!draft._existing) 'materials': <Object?>[],
      });
  Future<CapabilityResult<AccountDocument>> saveMaterial(MaterialDraft draft) =>
      _save(draft, 'materials', {
        'name': draft.name,
        'unit': draft.unit,
        'priceCarton': draft.priceCarton,
        'pricePiece': draft.pricePiece,
        'archived': draft.archived,
      });
  Future<CapabilityResult<AccountDocument>> _save(
    PartyDraft draft,
    String key,
    Map<String, Object?> changes,
  ) async {
    if (_disposed) {
      return const CapabilityFailure('disposed', 'Controller closed.');
    }
    if (_busy) {
      return const CapabilityFailure('busy', 'Catalog write in progress.');
    }
    if (!identical(repository.document, draft._base) ||
        repository.snapshot != draft._snapshot) {
      return const CapabilityFailure(
        'conflict',
        'Read current accounts before editing.',
      );
    }
    if (repository.hasUnknownWrite || repository.hasUnknownWorkspaceWrite) {
      return const CapabilityFailure(
        'commit_unknown',
        'Reconcile accounts before editing.',
      );
    }
    _busy = true;
    try {
      // Build and validate before notifying listeners: notifications may change
      // repository authority. Check it again immediately before persistence.
      final rows = [..._rows(draft._base, key)];
      final index = rows.indexWhere((row) => row['id'] == draft.id);
      if ((index >= 0) != draft._existing) {
        return const CapabilityFailure('conflict', 'Catalog identity changed.');
      }
      final updated = <String, Object?>{
        if (index >= 0) ...rows[index],
        'id': draft.id,
        ...changes,
      };
      if (index < 0) {
        rows.add(updated);
      } else {
        rows[index] = updated;
      }
      final document = repository.codec.decodeJson({
        ...draft._base.toJson(),
        key: rows,
      });
      notifyListeners();
      if (_disposed ||
          !identical(repository.document, draft._base) ||
          repository.snapshot != draft._snapshot) {
        return const CapabilityFailure(
          'conflict',
          'Account authority changed.',
        );
      }
      return await repository.save(document);
    } on AccountCodecException catch (error) {
      return CapabilityFailure(error.code, 'Catalog validation failed.');
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
