import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/parties/purchase_proposal.dart';

void main() {
  test(
    'frozen invoice inline material and split immediate payment candidate',
    () {
      final j = jsonDecode(
        File('test/parties/purchase_proposal_oracle.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final base = const LegacyAccountCodec().decodeJson(j['baseline']);
      final proposal = PurchaseProposals(base);
      final result = proposal.invoice(
        id: 'invoice',
        supplierId: 's',
        number: '١',
        date: '2026-01-01',
        createdAt: '2026-01-01T12:00:00.000Z',
        note: ' x ',
        lines: [
          const PurchaseLine(
            materialIdForCreation: 'material',
            name: 'Rice',
            unit: 'kg',
            quantityCartons: 0,
            quantityPieces: 2,
            priceCarton: 0,
            pricePiece: 100,
          ),
        ],
        immediatePayment: const PurchasePayment(
          id: 'payment',
          amount: 250,
          source: 'shared',
          dailyAmount: 150,
          cashAmount: 100,
        ),
      );
      expect(result.toJson(), j['cases'][0]['expected']);
      expect(base.toJson()['invoices'], isEmpty);
    },
  );
  test('debt-only cash payment source candidate', () {
    final j = jsonDecode(
      File('test/parties/purchase_proposal_oracle.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final base = const LegacyAccountCodec().decodeJson(j['baseline']);
    final result = PurchaseProposals(base).payment(
      payment: const PurchasePayment(
        id: 'debt-payment',
        amount: 30,
        source: 'cash',
      ),
      supplierId: 's',
      invoiceId: null,
      categoryId: 'market',
      date: '2026-01-01',
      createdAt: '2026-01-01T12:00:00.000Z',
      note: ' paid ',
    );
    expect(result.toJson(), j['cases'][1]['expected']);
    expect(result.toJson()['transactions'], isEmpty);
    expect(base.toJson()['payments'], isEmpty);
  });
  test('failed proposals preserve baseline and paid invoice restrictions', () {
    final j = jsonDecode(
      File('test/parties/purchase_proposal_oracle.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final doc = const LegacyAccountCodec().decodeJson(
      j['cases'][0]['expected'],
    );
    final original = jsonEncode(doc.toJson());
    final p = PurchaseProposals(doc);
    void rejected(void Function() operation) {
      var failed = false;
      try {
        operation();
      } on Object {
        failed = true;
      }
      expect(failed, true);
      expect(jsonEncode(doc.toJson()), original);
    }

    rejected(() => p.removeInvoice('invoice'));
    rejected(
      () => p.invoice(
        id: 'duplicate',
        supplierId: 's',
        number: '1',
        date: '2026-01-02',
        createdAt: '2026-01-02T12:00:00Z',
        lines: [],
      ),
    );
    rejected(
      () => p.invoice(
        id: 'invoice',
        supplierId: 's',
        number: '1',
        date: '2026-01-01',
        createdAt: '2026-01-01T12:00:00Z',
        editing: true,
        lines: [
          const PurchaseLine(
            materialIdForCreation: 'unused',
            name: 'Rice',
            unit: 'kg',
            quantityCartons: 0,
            quantityPieces: 1,
            priceCarton: 0,
            pricePiece: 1,
          ),
        ],
      ),
    );
    rejected(
      () => p.payment(
        payment: const PurchasePayment(
          id: 'overpay',
          amount: 51,
          source: 'cash',
        ),
        supplierId: 's',
        invoiceId: null,
        categoryId: 'market',
        date: '2026-01-02',
        createdAt: '2026-01-02T12:00:00Z',
      ),
    );
    rejected(
      () => p.payment(
        payment: const PurchasePayment(id: 'early', amount: 1, source: 'cash'),
        supplierId: 's',
        invoiceId: 'invoice',
        categoryId: 'market',
        date: '2025-12-31',
        createdAt: '2026-01-02T12:00:00Z',
      ),
    );
    rejected(
      () => p.payment(
        payment: const PurchasePayment(
          id: 'bad-funding',
          amount: 10,
          source: 'shared',
          dailyAmount: 1,
          cashAmount: 1,
        ),
        supplierId: 's',
        invoiceId: null,
        categoryId: 'market',
        date: '2026-01-02',
        createdAt: '2026-01-02T12:00:00Z',
      ),
    );
  });
  final corpus = jsonDecode(
    File('test/parties/purchase_proposal_oracle.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final raw in (corpus['cases'] as List).skip(2)) {
    final c = raw as Map<String, dynamic>;
    test('expanded frozen submit: ${c['name']}', () {
      final base = const LegacyAccountCodec().decodeJson(c['baseline']);
      final before = jsonEncode(base.toJson());
      final p = PurchaseProposals(base),
          context = c['context'] as Map,
          values = c['values'] as Map;
      Map<String, Object?>? actual;
      var rejected = false;
      try {
        if (context['kind'] == 'invoice') {
          actual = p
              .invoice(
                id:
                    context['id'] as String? ??
                    (c['ids'] as List).first as String,
                supplierId: context['supplierId'] as String,
                number: values['invoice-number'] as String,
                date: values['date'] as String,
                createdAt: context['createdAt'] as String,
                note: values['note'] as String,
                editing: context['id'] != null,
                lines: [
                  for (final indexed in (c['lines'] as List).indexed)
                    PurchaseLine(
                      materialIdForCreation:
                          c['name'] ==
                                  'multiple lines reuse new and archived materials' &&
                              indexed.$1 == 1
                          ? 'new-material'
                          : 'unused',
                      name: indexed.$2['name'] as String,
                      unit: indexed.$2['unit'] as String,
                      quantityCartons: num.parse(
                        indexed.$2['cartons'] as String,
                      ),
                      quantityPieces: num.parse(indexed.$2['pieces'] as String),
                      priceCarton: int.parse(
                        indexed.$2['cartonPrice'] as String,
                      ),
                      pricePiece: int.parse(indexed.$2['piecePrice'] as String),
                    ),
                ],
              )
              .toJson();
        } else {
          actual = p
              .payment(
                payment: PurchasePayment(
                  id: context['id'] as String,
                  amount: int.parse(values['amount'] as String),
                  source: values['paymentSource'] as String,
                ),
                supplierId: values['supplierId'] as String,
                invoiceId: values['invoiceId'] == ''
                    ? null
                    : values['invoiceId'] as String,
                categoryId: values['categoryId'] as String,
                date: values['date'] as String,
                createdAt: '2030-01-01T00:00:00Z',
                note: values['note'] as String,
                editing: true,
              )
              .toJson();
        }
      } on Object {
        rejected = true;
      }
      expect(rejected, c['rejected'] == true);
      if (c['rejected'] != true) expect(actual, c['expected']);
      expect(jsonEncode(base.toJson()), before);
    });
  }
}
