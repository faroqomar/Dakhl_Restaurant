import 'dart:io';
import 'dart:convert';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/catalog/catalog_read_model.dart';
void main() {
  final oracle=jsonDecode(File('test/catalog/oracle.json').readAsStringSync()) as Map;
  const codec=LegacyAccountCodec();
  final model=CatalogReadModel.fromAccount(codec.decodeJson({...codec.empty().toJson(),'products':oracle['products']}), balanceUnitsByProduct:{'p0':BigInt.from(1500),'p1':BigInt.from(2000)});
  for(final c in oracle['cases']) {
    final result=c['kind']=='sales'? model.sales(query:c['query'],group:c['group'],page:c['page']):model.inventory(query:c['query'],group:c['group'],page:c['page'],status:InventoryStatus.values.byName(c['status']));
    if(jsonEncode(result.items.map((p)=>p.id).toList())!=jsonEncode(c['expected']['ids']) || result.total!=c['expected']['total'] || result.page!=c['expected']['page']) throw StateError('Source catalog mismatch');
  }
  stdout.writeln('Catalog source corpus: ${oracle['cases'].length} cases passed');
}
