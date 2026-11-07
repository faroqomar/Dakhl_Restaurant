import 'dart:convert';
import 'dart:io';

import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/sales/return_proposal.dart';

int verifyReturnProposal() {
  final process = Process.runSync('node', [
    'return_proposal_oracle.cjs',
  ], workingDirectory: 'test/sales');
  if (process.exitCode != 0) throw StateError('${process.stderr}');
  final oracle = jsonDecode(process.stdout as String) as Map<String, dynamic>;
  var checks = 0;
  void check(bool value, String label) {
    if (!value) throw StateError(label);
    checks++;
  }

  for (final raw in oracle['cases'] as List) {
    final base = const LegacyAccountCodec().decodeJson(
      raw['base'] as Map<String, dynamic>,
    );
    final request = raw['request'] as Map<String, dynamic>;
    final inputs = (request['lines'] as List)
        .map(
          (r) => ReturnLineRequest(
            productId: r['productId'] as String,
            quantityUnits: BigInt.from((r['quantity'] as num) * 1000),
            restock: r['restock'] as bool,
          ),
        )
        .toList();
    final before = jsonEncode(base.toJson());
    final proposal = ReturnProposal.build(
      base,
      saleId: 'sale',
      returnId: raw['id'] as String,
      date: request['date'] as String,
      reason: request['reason'] as String,
      createdAt: raw['createdAt'] as String,
      today: '2026-01-02',
      lines: inputs,
    );
    final expected = const LegacyAccountCodec().decodeJson(
      raw['candidate'] as Map<String, dynamic>,
    );
    check(
      jsonEncode(proposal.candidate.toJson()) == jsonEncode(expected.toJson()),
      'source candidate parity',
    );
    check(jsonEncode(base.toJson()) == before, 'base unchanged');
    bool rejects(void Function() operation) {
      try {
        operation();
        return false;
      } on Object {
        return true;
      }
    }

    ReturnProposal build({
      String date = '2026-01-02',
      String reason = 'valid',
      String id = 'new',
      List<ReturnLineRequest>? lines,
    }) => ReturnProposal.build(
      base,
      saleId: 'sale',
      returnId: id,
      date: date,
      reason: reason,
      createdAt: '2026-01-02T12:00:00Z',
      today: '2026-01-02',
      lines: lines ?? inputs,
    );
    check(rejects(() => build(date: '2025-12-31')), 'before sale');
    check(rejects(() => build(date: '2026-01-03')), 'future date');
    check(rejects(() => build(reason: ' \uFEFF ')), 'empty reason');
    check(
      rejects(() => build(lines: [inputs.first, inputs.first])),
      'duplicate line',
    );
    check(rejects(() => build(lines: [])), 'empty lines');
    check(
      rejects(
        () => (proposal.candidate.toJson()['saleReturns'] as List).clear(),
      ),
      'immutable candidate',
    );
    if (raw['id'] == 'r2') {
      check(rejects(() => build(id: 'r1')), 'duplicate return identity');
    }
    check(
      rejects(
        () => build(
          lines: [
            ReturnLineRequest(
              productId: 'missing',
              quantityUnits: BigInt.from(1000),
              restock: false,
            ),
          ],
        ),
      ),
      'unknown line',
    );

    check(
      rejects(
        () => build(
          lines: [
            ReturnLineRequest(
              productId: 'a',
              quantityUnits: BigInt.from(100000),
              restock: false,
            ),
          ],
        ),
      ),
      'excess quantity',
    );
    check(
      rejects(
        () => build(
          lines: [
            ReturnLineRequest(
              productId: 'a',
              quantityUnits: BigInt.from(1000),
              restock: true,
            ),
          ],
        ),
      ),
      'untracked restock',
    );
  }
  check(oracle['net'] == oracle['refunded'], 'cumulative net exhaustion');
  return checks;
}
