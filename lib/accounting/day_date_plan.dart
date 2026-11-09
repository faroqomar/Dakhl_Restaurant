import 'dart:convert';

import '../accounts/account_document.dart';
import '../accounts/legacy_account_codec.dart';
import 'daily_cash_queries.dart';

/// Frozen restaurant source scope: days, payments, transactions and transfers.
/// Independently dated sales, returns, invoices, stock, debts and workers stay put.
final class DayDatePlan {
  DayDatePlan._(this.mapping);
  final Map<String, String> mapping;
  static DateTime _date(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const FormatException('invalid_day_date');
    }
    final parsed = DateTime.tryParse('${value}T00:00:00Z');
    if (parsed == null ||
        parsed.year < 1000 ||
        parsed.year > 9999 ||
        parsed.toIso8601String().substring(0, 10) != value) {
      throw const FormatException('invalid_day_date');
    }
    return parsed;
  }

  static List<String> recordedDays(AccountDocument account) {
    final json = account.toJson();
    final result = <String>{};
    for (final entry in (json['days']! as Map).entries) {
      final d = entry.value as Map;
      if ((d['expenses']! as List).isNotEmpty ||
          d['chickenUsed'] != 0 ||
          d['chickenLeft'] != 0 ||
          d['balance'] != null ||
          d['totalOverride'] != null ||
          d['remaining'] != null) {
        result.add(entry.key as String);
      }
    }
    for (final key in ['payments', 'transactions', 'transfers']) {
      for (final row in json[key]! as List) {
        result.add((row as Map)['date']! as String);
      }
    }
    return result.toList()..sort();
  }

  factory DayDatePlan.create(
    AccountDocument account, {
    required String from,
    required String to,
    String? end,
  }) {
    final start = _date(from), target = _date(to), last = _date(end ?? from);
    if (from == to || last.isBefore(start)) {
      throw const FormatException('invalid_day_range');
    }
    final recorded = recordedDays(account).toSet();
    if (!recorded.contains(from)) {
      throw const FormatException('missing_day_record');
    }
    final selected = recorded
        .where((d) => d.compareTo(from) >= 0 && d.compareTo(end ?? from) <= 0)
        .toSet();
    final offset = target.difference(start);
    final mapping = <String, String>{};
    for (final d in selected.toList()..sort()) {
      final destination = _date(d)
          .add(offset)
          .toIso8601String()
          .substring(0, 10);
      _date(destination);
      if (recorded.contains(destination) && !selected.contains(destination)) {
        throw const FormatException('day_date_collision');
      }
      mapping[d] = destination;
    }
    return DayDatePlan._(Map.unmodifiable(mapping));
  }
  factory DayDatePlan.exact(
    AccountDocument account,
    Map<String, String> values,
  ) {
    if (values.isEmpty || values.values.toSet().length != values.length) {
      throw const FormatException('invalid_exact_day_mapping');
    }
    final recorded = recordedDays(account).toSet();
    Duration? offset;
    for (final entry in values.entries) {
      final delta = _date(entry.value).difference(_date(entry.key));
      if (delta == Duration.zero ||
          (offset != null && delta != offset) ||
          !recorded.contains(entry.key)) {
        throw const FormatException('invalid_exact_day_mapping');
      }
      offset = delta;
      if (recorded.contains(entry.value) && !values.containsKey(entry.value)) {
        throw const FormatException('day_date_collision');
      }
    }
    final keys = values.keys.toList()..sort();
    return DayDatePlan._(
      Map.unmodifiable({for (final key in keys) key: values[key]!}),
    );
  }
  factory DayDatePlan.forIntent(
    AccountDocument account,
    Map<String, Object?> intent,
  ) => intent['exactMapping'] == null
      ? DayDatePlan.create(
          account,
          from: intent['from']! as String,
          to: intent['to']! as String,
          end: intent['end']! as String,
        )
      : DayDatePlan.exact(
          account,
          (intent['exactMapping']! as Map).cast<String, String>(),
        );
  AccountDocument apply(AccountDocument account) {
    final json = account.toJson();
    final destinations = mapping.values.toSet();
    final days = <String, Object?>{};
    for (final e in (json['days']! as Map).entries) {
      final date = e.key as String;
      if (mapping.containsKey(date) || !destinations.contains(date)) {
        days[mapping[date] ?? date] = e.value;
      }
    }
    final next = <String, Object?>{...json, 'days': days};
    for (final key in ['payments', 'transactions', 'transfers']) {
      next[key] = [
        for (final row in (json[key]! as List).cast<Map<String, Object?>>())
          {...row, 'date': mapping[row['date']] ?? row['date']},
      ];
    }
    final sales = DailyCashQueries(account);
    for (final e in mapping.entries) {
      final day = days[e.value] as Map<String, Object?>?;
      if (day?['remaining'] != null) {
        final remaining = day!['remaining']! as Map<String, Object?>;
        final baseline =
            BigInt.from(remaining['salesTotal'] as int) +
            sales.netSales(e.value) -
            sales.netSales(e.key);
        days[e.value] = {
          ...day,
          'remaining': {...remaining, 'salesTotal': baseline.toInt()},
        };
      }
    }
    return const LegacyAccountCodec().decodeJson(next);
  }
}

/// Read-only touched-source comparison for receipt-bound inverse eligibility.
/// Audit trails and empty scaffolding remain retained source evidence; unrelated
/// catalog/stock/party records are outside this operation's affected source set.
Map<String, Object?> dayDateTouchedSource(
  AccountDocument account,
  Iterable<String> dates,
) {
  final selected = dates.toSet(), json = account.toJson();
  final days = <String, Object?>{};
  for (final date in selected) {
    final raw = (json['days']! as Map)[date] as Map?;
    if (raw == null) continue;
    final day = Map<String, Object?>.from(raw)..remove('corrections');
    final expenses = (day['expenses']! as List).cast<Map<String, Object?>>();
    if (expenses.isEmpty &&
        day['chickenUsed'] == 0 &&
        day['chickenLeft'] == 0 &&
        day['balance'] == null &&
        day['totalOverride'] == null &&
        day['remaining'] == null) {
      continue;
    }
    day['expenses'] = {for (final row in expenses) row['id']! as String: row};
    days[date] = day;
  }
  return {
    'days': days,
    for (final key in ['payments', 'transactions', 'transfers'])
      key: {
        for (final row in (json[key]! as List).cast<Map<String, Object?>>())
          if (selected.contains(row['date'])) row['id']! as String: row,
      },
  };
}

AccountDocument applyDayDateIntent(
  AccountDocument account,
  Map<String, Object?> intent,
) {
  final shifted = DayDatePlan.forIntent(account, intent).apply(account);
  if (intent['inverseOf'] == null) return shifted;
  final json = shifted.toJson(), days = Map<String, Object?>.from(shifted.days);
  for (final entry in account.days.entries) {
    final current = entry.value! as Map,
        history = current['corrections'] as List? ?? const [];
    if (history.isEmpty) continue;
    final target = Map<String, Object?>.from(
      days[entry.key] as Map? ??
          const {
            'expenses': <Object?>[],
            'chickenUsed': 0,
            'chickenLeft': 0,
            'balance': null,
            'totalOverride': null,
            'remaining': null,
          },
    );
    final previous = target['corrections'] as List? ?? const [];
    final retained = <Object?>[...history];
    if (jsonEncode(previous) != jsonEncode(history)) {
      for (final field in [
        ('balance', 'balance'),
        ('total', 'totalOverride'),
      ]) {
        if (current[field.$2] != target[field.$2]) {
          retained.add({
            'field': field.$1,
            'date': entry.key,
            'before': current[field.$2],
            'after': target[field.$2],
            'reason': intent['reason'],
            'createdAt': intent['recordedAt'],
          });
        }
      }
    }
    target['corrections'] = retained;
    days[entry.key] = target;
  }
  return const LegacyAccountCodec().decodeJson({...json, 'days': days});
}
