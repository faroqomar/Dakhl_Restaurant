import 'dart:convert';
import 'dart:io';

import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/accounts/account_document.dart';
import 'package:dakhl_restaurant/parties/supplier_ledger.dart';

void main() {
  final oracle = jsonDecode(
    File('test/parties/supplier_ledger_oracle.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final comparisons = oracle['comparisons'] as List;
  int compare(String a, String b) =>
      (comparisons.firstWhere((dynamic row) => row[0] == a && row[1] == b)
              as List)[2]
          as int;
  for (final raw in oracle['cases'] as List) {
    final c = raw as Map<String, dynamic>;
    test('frozen supplier queries: ${c['name']}', () {
      final model = SupplierLedgerQueries(
        c['validated'] == true
            ? const LegacyAccountCodec().decodeJson(c['state'])
            : AccountDocument.canonical(
                (c['state'] as Map).cast<String, Object?>(),
                sourceVersion: 11,
              ),
        compareText: compare,
      );
      final id = c['supplier'] as String? ?? 's';
      final result = {
        'balance': model.supplierBalance(id).toInt(),
        'debt': model.debtAvailable(id).toInt(),
        'datedDebt': model.debtAvailable(id, date: '2026-01-02').toInt(),
        'excludedDebt': model
            .debtAvailable(id, date: '2026-01-02', excludePaymentId: 'p')
            .toInt(),
        'paid': model.invoicePaid('i').toInt(),
        'due': model.invoiceDue('i').toInt(),
        'ledger': model
            .ledger(id)
            .map(
              (e) => {
                'id': e.id,
                'type': e.type,
                'amount': e.amount.toInt(),
                'before': e.before.toInt(),
                'balance': e.balance.toInt(),
              },
            )
            .toList(),
        'before': model
            .balanceBefore(
              id,
              date: '2026-01-02',
              createdAt: '2026-01-02T00:00:00Z',
            )
            .toInt(),
      };
      expect(result, c['expected']);
    });
  }
}
