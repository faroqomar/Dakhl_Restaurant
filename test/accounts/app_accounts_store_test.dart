import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/app/accounts_store.dart';

import 'accounts_view_model_test.dart' show FixtureStore;

void main() {
  test(
    'post-invocation exception preserves owner and reports uncertainty',
    () async {
      final engine = FixtureStore()..throwAfterCommit = true;
      var opens = 0;
      final store = AppAccountsStore(
        openStore: () async {
          opens++;
          return CapabilitySuccess(engine);
        },
      );
      final write = await store.writeDocument('{}', writeToken: 'fixture');
      expect((write as CapabilityFailure).code, 'commit_unknown');
      expect(
        await store.readDocument(),
        isA<CapabilitySuccess<DocumentSnapshot?>>(),
      );
      expect(opens, 1);
      await store.close();
    },
  );
}
