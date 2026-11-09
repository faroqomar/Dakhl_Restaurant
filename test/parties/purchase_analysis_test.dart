import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/parties/purchase_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unit summaries preserve saved units and date changes compare prior purchases', () {
    const codec = LegacyAccountCodec();
    final raw = Map<String, Object?>.of(codec.empty().toJson());
    final category = (raw['categories']! as List).first['id'];
    raw['suppliers'] = [
      for (final id in ['one', 'two'])
        <String, Object?>{
          'id': id,
          'name': id,
          'categoryId': category,
          'openingBalance': 0,
          'phone': '',
          'note': '',
          'materials': <Object?>[],
        },
    ];
    raw['materials'] = [
      <String, Object?>{
        'id': 'rice',
        'name': 'Rice',
        'unit': 'bag',
        'priceCarton': 999,
        'pricePiece': 999,
        'archived': false,
      },
    ];
    Map<String, Object?> invoice(
      String id,
      String date,
      String supplier,
      String unit,
      num cartons,
      num pieces,
      int cartonPrice,
      int piecePrice,
    ) => {
      'id': id,
      'number': id,
      'date': date,
      'supplierId': supplier,
      'createdAt': '${date}T00:00:00.000Z',
      'note': '',
      'lines': [
        <String, Object?>{
          'materialId': 'rice',
          'name': 'Rice',
          'unit': unit,
          'quantityCartons': cartons,
          'quantityPieces': pieces,
          'priceCarton': cartonPrice,
          'pricePiece': piecePrice,
        },
      ],
    };
    raw['invoices'] = [
      invoice('a', '2026-01-01', 'one', 'bag', 1, 0, 100, 10),
      invoice('b', '2026-02-01', 'one', 'bag', 1.5, 2, 120, 15),
      invoice('c', '2026-02-02', 'one', 'kg', 0, 0.5, 120, 15),
      invoice('d', '2026-02-03', 'two', 'bag', 9, 9, 500, 50),
    ];
    final account = codec.decodeJson(raw);
    final result = PurchaseAnalysis.build(
      account,
      supplierId: 'one',
      material: 'rice',
      from: '2026-02-01',
      to: '2026-02-28',
      compareText: (a, b) => a.compareTo(b),
    );
    expect(result.invoiceCount, 2);
    expect(result.units.map((u) => u.unit), ['bag', 'kg']);
    expect(result.units.first.cartons, BigInt.from(1500));
    expect(result.units.first.pieces, BigInt.from(2000));
    expect(result.units.last.pieces, BigInt.from(500));
    expect(result.amount, BigInt.from(218)); // 180+30, then 7.5 rounded to8.
    expect(result.changes, hasLength(1));
    expect(result.changes.single.cartonDelta, 20);
    expect(result.changes.single.pieceDelta, 5);
    expect(result.changes.single.date, '2026-02-01');
    expect((account.toJson()['materials']! as List).first['pricePiece'], 999);
  });

  test('missing collation refuses differently dated price history', () {
    const codec = LegacyAccountCodec();
    final raw = Map<String, Object?>.of(codec.empty().toJson());
    final category = (raw['categories']! as List).first['id'];
    raw['suppliers'] = [
      <String, Object?>{
        'id': 's',
        'name': 'S',
        'categoryId': category,
        'openingBalance': 0,
        'phone': '',
        'note': '',
        'materials': <Object?>[],
      },
    ];
    raw['materials'] = [
      <String, Object?>{
        'id': 'm',
        'name': 'M',
        'unit': 'piece',
        'priceCarton': 0,
        'pricePiece': 10,
        'archived': false,
      },
    ];
    raw['invoices'] = [
      for (final date in ['2026-01-01', '2026-02-01'])
        <String, Object?>{
          'id': date,
          'number': date,
          'date': date,
          'supplierId': 's',
          'createdAt': '${date}T00:00:00.000Z',
          'note': '',
          'lines': [
            <String, Object?>{
              'materialId': 'm',
              'name': 'M',
              'unit': 'piece',
              'quantity': 1,
              'price': 10,
            },
          ],
        },
    ];
    expect(
      () => PurchaseAnalysis.build(codec.decodeJson(raw), compareText: null),
      throwsFormatException,
    );
  });
}
