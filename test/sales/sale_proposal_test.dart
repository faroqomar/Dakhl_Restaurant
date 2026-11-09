import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/sales/sale_proposal.dart';

void main() {
  final oracle = jsonDecode(
    File('test/sales/sale_proposal_oracle.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final raw in oracle['cases'] as List) {
    final c = raw as Map<String, dynamic>;
    test('frozen checkout proposal: ${c['name']}', () {
      final base = const LegacyAccountCodec().decodeJson(
        c['state'] as Map<String, dynamic>,
      );
      final before = jsonEncode(base.toJson());
      SaleProposal build() => SaleProposal.build(
        base,
        draft: c['draft'] as Map<String, dynamic>,
        saleId: c['saleId'] as String,
        createdAt: c['createdAt'] as String,
      );
      if (c['ok'] == true) {
        final proposal = build();
        expect(proposal.candidate.toJson(), c['expected']);
        expect(() => proposal.sale['note'] = 'changed', throwsUnsupportedError);
      } else {
        expect(build, throwsA(anything));
      }
      expect(jsonEncode(base.toJson()), before);
    });
  }
}
