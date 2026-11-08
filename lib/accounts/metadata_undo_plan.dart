import 'dart:convert';

import '../accounting/journal_command_host.dart' show canonicalIdentity;
import 'account_document.dart';
import 'legacy_account_codec.dart';
import 'portable_journal_state.dart';
import 'portable_metadata_validation.dart';

bool _sameValue(Object? a, Object? b) =>
    canonicalIdentity({'value': a}) == canonicalIdentity({'value': b});

final class _ValueChange {
  _ValueChange(
    this.path,
    this.before,
    this.after,
    this.hadBefore,
    this.hadAfter,
  );
  final List<String> path;
  final Object? before, after;
  final bool hadBefore, hadAfter;
  void restore(Map<String, Object?> target) {
    var parent = target;
    for (final key in path.take(path.length - 1)) {
      final nested = parent[key];
      if (nested is! Map<String, Object?>) {
        throw const FormatException('undo_metadata_conflict');
      }
      parent = nested;
    }
    final key = path.last;
    if (parent.containsKey(key) != hadAfter ||
        (hadAfter && !_sameValue(parent[key], after))) {
      throw const FormatException('undo_metadata_conflict');
    }
    if (hadBefore) {
      parent[key] = _copy(before);
    } else {
      parent.remove(key);
    }
  }
}

Object? _copy(Object? value) => jsonDecode(jsonEncode(value));
Map<String, Object?> _map(Object? value) =>
    (value! as Map).cast<String, Object?>();
List<_ValueChange> _changes(
  Map<String, Object?> before,
  Map<String, Object?> after, [
  List<String> prefix = const [],
]) {
  final result = <_ValueChange>[];
  for (final key in {...before.keys, ...after.keys}) {
    final old = before[key], next = after[key];
    if (before.containsKey(key) == after.containsKey(key) &&
        _sameValue(old, next)) {
      continue;
    }
    final path = [...prefix, key];
    if (old is Map && next is Map) {
      result.addAll(_changes(_map(old), _map(next), path));
    } else {
      result.add(
        _ValueChange(
          path,
          old,
          next,
          before.containsKey(key),
          after.containsKey(key),
        ),
      );
    }
  }
  return result;
}

/// Bounded source-only compensation. It restores only fields changed by the
/// captured operation; unrelated current records and financial history survive.
final class MetadataUndoPlan {
  MetadataUndoPlan._(this.candidate);
  final AccountDocument candidate;
  static const _codec = LegacyAccountCodec();
  static const _collections = [
    'products',
    'categories',
    'suppliers',
    'materials',
  ];
  static const _emptyDay = <String, Object?>{
    'expenses': <Object?>[],
    'chickenUsed': 0,
    'chickenLeft': 0,
    'balance': null,
    'totalOverride': null,
    'remaining': null,
  };

  factory MetadataUndoPlan.prepare({
    required PortableJournalState before,
    required PortableJournalState after,
    required PortableJournalState current,
  }) {
    if (before.accountLineage != after.accountLineage ||
        current.accountLineage != after.accountLineage) {
      throw const FormatException('account_lineage_mismatch');
    }
    if (!_sameValue(
      before.copyWith(account: after.account).toJson(),
      after.toJson(),
    )) {
      throw const FormatException('undo_metadata_financial_transition');
    }
    return MetadataUndoPlan.prepareAccounts(
      before: before.account,
      after: after.account,
      current: current.account,
    );
  }

  /// Schema11 source-only variant; portable callers add envelope guards above.
  factory MetadataUndoPlan.prepareAccounts({
    required AccountDocument before,
    required AccountDocument after,
    required AccountDocument current,
  }) {
    validatePortableMetadataChange(before, after);
    final a = before.toJson(), b = after.toJson();
    if (!_sameValue(a['stockEntries'], b['stockEntries'])) {
      throw const FormatException('undo_stock_requires_reversal');
    }
    if (_sameValue(a, b)) throw const FormatException('nothing_to_undo');
    final target = _map(_copy(current.toJson()));
    for (final key in _collections) {
      final oldRows = (a[key]! as List).map(_map).toList();
      final newRows = (b[key]! as List).map(_map).toList();
      final oldById = {for (final row in oldRows) row['id']! as String: row};
      final newById = {for (final row in newRows) row['id']! as String: row};
      final common = oldById.keys.toSet().intersection(newById.keys.toSet());
      if (!_sameValue(
        oldRows.map((r) => r['id']).where(common.contains).toList(),
        newRows.map((r) => r['id']).where(common.contains).toList(),
      )) {
        throw const FormatException('undo_metadata_reorder_unsupported');
      }
      final rows = (target[key]! as List).map(_map).toList();
      for (final id in {...oldById.keys, ...newById.keys}) {
        final old = oldById[id], next = newById[id];
        if (_sameValue(old, next)) continue;
        final index = rows.indexWhere((r) => r['id'] == id);
        if (old == null) {
          if (index < 0 || !_sameValue(rows[index], next)) {
            throw const FormatException('undo_metadata_conflict');
          }
          rows.removeAt(index);
        } else if (next == null) {
          if (index >= 0) throw const FormatException('undo_metadata_conflict');
          final later = oldRows
              .skip(oldRows.indexOf(old) + 1)
              .map((r) => r['id'])
              .toSet();
          final insert = rows.indexWhere((r) => later.contains(r['id']));
          rows.insert(insert < 0 ? rows.length : insert, _map(_copy(old)));
        } else {
          if (index < 0) throw const FormatException('undo_metadata_conflict');
          for (final change in _changes(old, next)) {
            change.restore(rows[index]);
          }
        }
      }
      target[key] = rows;
    }
    for (final change in _changes(
      _map(a['preferences']),
      _map(b['preferences']),
    )) {
      change.restore(_map(target['preferences']));
    }
    final days = _map(target['days']);
    for (final date in {...before.days.keys, ...after.days.keys}) {
      final old = _map(before.days[date] ?? _emptyDay);
      final next = _map(after.days[date] ?? _emptyDay);
      final changes = _changes(
        {
          for (final key in ['chickenUsed', 'chickenLeft']) key: old[key],
        },
        {
          for (final key in ['chickenUsed', 'chickenLeft']) key: next[key],
        },
      );
      if (changes.isEmpty) continue;
      final day = days[date];
      if (day is! Map) throw const FormatException('undo_metadata_conflict');
      for (final change in changes) {
        change.restore(_map(day));
      }
      if (!before.days.containsKey(date) && _sameValue(day, _emptyDay)) {
        days.remove(date);
      }
    }
    final candidate = _codec.decodeJson(target);
    validatePortableMetadataChange(current, candidate);
    return MetadataUndoPlan._(candidate);
  }
}
