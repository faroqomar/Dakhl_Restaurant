import '../accounting/journal_command_host.dart' show canonicalIdentity;

import 'account_document.dart';

/// Pure source whitelist shared by metadata writes and financial compensation.
void validatePortableMetadataChange(
  AccountDocument before,
  AccountDocument after,
) {
  final a = Map<String, Object?>.of(before.toJson()),
      b = Map<String, Object?>.of(after.toJson());
  for (final key in [
    'categories',
    'products',
    'stockEntries',
    'suppliers',
    'materials',
    'preferences',
    'days',
  ]) {
    a.remove(key);
    b.remove(key);
  }
  if (canonicalIdentity(a) != canonicalIdentity(b)) {
    throw const FormatException('metadata_financial_mutation_refused');
  }
  Map<String, int> openings(AccountDocument document) => {
    for (final s
        in (document.toJson()['suppliers']! as List)
            .cast<Map<String, Object?>>())
      s['id']! as String: s['openingBalance']! as int,
  };
  final oldOpenings = openings(before), newOpenings = openings(after);
  for (final id in {...oldOpenings.keys, ...newOpenings.keys}) {
    if ((oldOpenings[id] ?? 0) != (newOpenings[id] ?? 0)) {
      throw const FormatException('metadata_opening_debt_refused');
    }
  }
  final oldDays = before.days, newDays = after.days;
  Map<String, Object?> financialDay(Object? value) {
    if (value == null) {
      return {
        'expenses': <Object?>[],
        'balance': null,
        'totalOverride': null,
        'remaining': null,
      };
    }
    return Map<String, Object?>.of((value as Map).cast<String, Object?>())
      ..remove('chickenUsed')
      ..remove('chickenLeft');
  }

  for (final date in {...oldDays.keys, ...newDays.keys}) {
    if (canonicalIdentity(financialDay(oldDays[date])) !=
        canonicalIdentity(financialDay(newDays[date]))) {
      throw const FormatException('metadata_financial_day_refused');
    }
  }
}
