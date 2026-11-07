import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounts/account_document.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/reports/sales_report.dart';

// Actual frozen model creates/validates synthetic history. The actual history
// function's computation prefix is executed before its rendering expression.
Map<String, dynamic> oracle() {
  final result = Process.runSync('node', [
    '-e',
    r'''
const fs=require('fs'); const M=require('./electron-reference/app/ui/model.js');
let state=M.empty();
state.products=[{id:'p',name:'Historic Rice',code:'',group:'',unit:'plate',price:101,minStock:0,trackStock:false,archived:false}];
for(const [id,date,qty,discount,note,type] of [['a','2026-01-01',2,1,'Family','صالة'],['b','2026-01-02',1,0,'Quick','سفري'],['c','2026-01-02',1,0,'Void','صالة']]) {
state=M.completeSale(state,{date,lines:[{productId:'p',quantity:qty}],discount,note,orderType:type},id,date+'T12:00:00.000Z');
}
state=M.voidSale(state,'c','mistake','2026-01-03T12:00:00.000Z');
state=M.returnSale(state,'a',{date:'2026-01-03',reason:'return',lines:[{productId:'p',quantity:1,restock:false}]},'r','2026-01-03T12:00:00.000Z');
state.products[0].name='Current renamed item';state.products[0].price=999;state=M.validate(state);
const filters=[{},{from:'2026-01-03',to:'2026-01-03'},{from:'2026-01-02',to:'2026-01-03',query:'FAMILY'}, {status:'void'}, {orderType:'سفري'}, {query:'Historic Rice'}, {query:'Current renamed item'}, {from:'2026-01-04',to:'2026-01-01'}, {query:' S-000001'}, {query:'S-000001'}];
const source=fs.readFileSync('./electron-reference/app/ui/commerce.js','utf8');
const start=source.indexOf('function salesHistoryPage() {')+'function salesHistoryPage() {'.length;
const body=source.slice(start,source.indexOf("  return header(",start));
const run=new Function('state','saleFilter','M',body+';return {ids:sales.map(s=>s.id),returns:refunds.map(r=>r.id),refunded,total,completed:active.length,voided:sales.length-active.length};');
const ux=fs.readFileSync('./electron-reference/app/ui/ux.js','utf8');
const validRange=new Function('M','toast',ux.split('\n').find(l=>l.startsWith('function validRange(f)'))+';return validRange;')(M,()=>{});
console.log(JSON.stringify({state,filters,valid:filters.map(f=>validRange(f)),results:filters.map(f=>run(state,{from:'',to:'',query:'',status:'',orderType:'',...f},M))}));
''',
  ]);
  if (result.exitCode != 0) {
    throw StateError('Frozen source oracle failed: ${result.stderr}');
  }
  return jsonDecode(result.stdout as String) as Map<String, dynamic>;
}

void main() {
  test('report rejects invalid source date bounds and reversed period', () {
    final empty = const LegacyAccountCodec().empty();
    expect(
      () => SalesReport.build(
        empty,
        filter: const SalesHistoryFilter(from: '2026-02-01', to: '2026-01-01'),
      ),
      throwsFormatException,
    );
    expect(
      () => SalesReport.build(
        empty,
        filter: const SalesHistoryFilter(from: '0999-12-31'),
      ),
      throwsA(isA<DomainValidationException>()),
    );
    expect(
      SalesReport.build(
        empty,
        filter: const SalesHistoryFilter(from: '1000-01-01', to: '1000-01-01'),
      ).netMovement,
      BigInt.zero,
    );
  });
  late Map<String, dynamic> source;
  late AccountDocument document;
  setUpAll(() {
    source = oracle();
    document = const LegacyAccountCodec().decodeJson(
      (source['state'] as Map).cast<String, Object?>(),
    );
  });
  test(
    'actual frozen JS history filtering and period totals agree for ten cases',
    () {
      final filters = source['filters'] as List;
      final expected = source['results'] as List;
      for (var i = 0; i < filters.length; i++) {
        final f = filters[i] as Map;
        if ((source['valid'] as List)[i] != true) {
          expect(
            () => SalesReport.build(
              document,
              filter: SalesHistoryFilter(
                from: f['from'] as String? ?? '',
                to: f['to'] as String? ?? '',
              ),
            ),
            throwsFormatException,
          );
          continue;
        }
        final report = SalesReport.build(
          document,
          filter: SalesHistoryFilter(
            from: f['from'] as String? ?? '',
            to: f['to'] as String? ?? '',
            query: f['query'] as String? ?? '',
            status: f['status'] as String? ?? '',
            orderType: f['orderType'] as String? ?? '',
          ),
        );
        expect(
          report.sales.map((s) => s.snapshot['id']).toList(),
          expected[i]['ids'],
        );
        expect(
          report.returns.map((r) => r['id']).toList(),
          expected[i]['returns'],
        );
        expect(report.refunded.toString(), '${expected[i]['refunded']}');
        expect(report.netMovement.toString(), '${expected[i]['total']}');
        expect(report.completedCount, expected[i]['completed']);
        expect(report.voidCount, expected[i]['voided']);
      }
    },
  );
  test('return-only period is negative; snapshots are immutable and catalog-independent', () {
    final report = SalesReport.build(
      document,
      filter: const SalesHistoryFilter(from: '2026-01-03', to: '2026-01-03'),
    );
    expect(report.sales, isEmpty);
    expect(report.netMovement, BigInt.from(-100));
    final all = SalesReport.build(document);
    final sale = all.sales.singleWhere((s) => s.snapshot['id'] == 'a');
    expect(sale.total, BigInt.from(201));
    expect(sale.lifetimeRefunded, BigInt.from(100));
    expect((sale.snapshot['lines'] as List).first['name'], 'Historic Rice');
    expect(() => sale.snapshot['note'] = 'mutate', throwsUnsupportedError);
    expect(() => all.returns.clear(), throwsUnsupportedError);
    expect(
      () => ((sale.snapshot['lines'] as List).first as Map)['price'] = 1,
      throwsUnsupportedError,
    );
  });
  test('invalid date/status filters fail with sanitized errors', () {
    expect(
      () => SalesReport.build(
        document,
        filter: const SalesHistoryFilter(from: '2026-02-30'),
      ),
      throwsA(isA<DomainValidationException>()),
    );
    expect(
      () => SalesReport.build(
        document,
        filter: const SalesHistoryFilter(status: 'paid'),
      ),
      throwsFormatException,
    );
  });
  test('valid multi-day history preserves frozen binary64 aggregate', () {
    final raw = {...document.toJson()};
    final template = (raw['sales'] as List).first as Map<String, Object?>;
    final line = (template['lines'] as List).first as Map<String, Object?>;
    raw['saleReturns'] = <Object?>[];
    raw['sales'] = [
      for (var i = 0; i < 9008; i++)
        {
          ...template,
          'id': 'large-$i',
          'number': 'L-$i',
          'date': DateTime.utc(
            2000,
            1,
            1,
          ).add(Duration(days: i)).toIso8601String().substring(0, 10),
          'discount': i.isOdd ? 1 : 0,
          'paid': 1000000000000,
          'lines': [
            {...line, 'quantity': 1000, 'price': 1000000000},
          ],
        },
    ];
    final large = const LegacyAccountCodec().decodeJson(raw);
    final result = Process.runSync('node', [
      '-e',
      r"const fs=require('fs');const M=require('./electron-reference/app/ui/model.js');const src=fs.readFileSync('./electron-reference/app/ui/commerce.js','utf8');const start=src.indexOf('function salesHistoryPage() {')+'function salesHistoryPage() {'.length;const body=src.slice(start,src.indexOf('  return header(',start));const state={sales:Array.from({length:9008},(_,i)=>({id:String(i),date:new Date(Date.UTC(2000,0,1+i)).toISOString().slice(0,10),createdAt:'2026-01-01T00:00:00Z',status:'completed',number:String(i),note:'',lines:[{name:'Rice',quantity:1000,price:1000000000}],discount:i%2})),saleReturns:[]};const run=new Function('state','saleFilter','M',body+';return BigInt(total).toString();');console.log(run(state,{from:'',to:'',query:'',status:'',orderType:''},M));",
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final report = SalesReport.build(large);
    expect(report.completedTotal.toString(), (result.stdout as String).trim());
    expect(report.netMovement, report.completedTotal);
    expect(
      report.completedTotal,
      greaterThan(BigInt.parse('9007199254740991')),
    );
  });
  test(
    'legacy timestamp collation gap is explicit, not claimed as JS parity',
    () {
      final raw = {...document.toJson()};
      raw['sales'] = [
        for (final value in raw['sales'] as List)
          {
            ...value as Map<String, Object?>,
            if (value['id'] == 'b') 'createdAt': 'Jan 2, 2026 12:00:00',
            if (value['id'] == 'c') 'createdAt': 'jan 2, 2026 12:00:00',
          },
      ];
      final legacy = const LegacyAccountCodec().decodeJson(raw);
      final report = SalesReport.build(
        legacy,
        filter: const SalesHistoryFilter(from: '2026-01-02', to: '2026-01-02'),
      );
      expect(report.sales.map((row) => row.snapshot['id']), ['c', 'b']);
      final sourceOrder = Process.runSync('node', [
        '-e',
        "console.log(JSON.stringify([['b','Jan 2, 2026 12:00:00'],['c','jan 2, 2026 12:00:00']].sort((a,b)=>b[1].localeCompare(a[1])).map(x=>x[0])))",
      ]);
      expect(sourceOrder.exitCode, 0);
      expect(jsonDecode(sourceOrder.stdout as String), ['b', 'c']);
    },
  );
}
