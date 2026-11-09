import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
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
      final readback = await store.readDocument();
      expect(readback, isA<CapabilitySuccess<DocumentSnapshot?>>());
      final document = (readback as CapabilitySuccess<DocumentSnapshot?>).value;
      expect(document, isNotNull);
      expect(document!.payload, '{}');
      expect(document.writeToken, 'fixture');
      expect(document.revision, 1);
      expect(opens, 1);
      await store.close();
    },
  );
  test(
    'app wrapper forwards fenced writes to Madar and releases its real owner',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dakhl-app-owner-conformance-',
      );
      addTearDown(() => root.delete(recursive: true));
      var opens = 0;
      final store = AppAccountsStore(
        openStore: () {
          opens++;
          return PowerSyncLocalDocumentWorkspaceStore.open(
            directoryPath: root.path,
          );
        },
      );
      addTearDown(store.close);
      final firstResult = await store.writeDocument(
        'first fixture',
        writeToken: 'first',
      );
      expect(firstResult, isA<CapabilitySuccess<DocumentSnapshot>>());
      final first = (firstResult as CapabilitySuccess<DocumentSnapshot>).value;
      final nextResult = await store.writeDocument(
        'replacement fixture',
        expected: first,
        writeToken: 'replacement',
        replaceGeneration: true,
      );
      expect(nextResult, isA<CapabilitySuccess<DocumentSnapshot>>());
      final next = (nextResult as CapabilitySuccess<DocumentSnapshot>).value;
      expect(next.revision, 2);
      expect(next.fence.storeId, first.fence.storeId);
      expect(next.fence.generation, isNot(first.fence.generation));
      expect(next.writeToken, 'replacement');
      final current =
          (await store.readDocument() as CapabilitySuccess<DocumentSnapshot?>)
              .value!;
      expect(current.payload, 'replacement fixture');
      expect(current.fence, next.fence);
      expect(opens, 1);
      await Future.wait([store.close(), store.close()]);
      final closed = await store.readDocument();
      expect((closed as CapabilityFailure<DocumentSnapshot?>).code, 'closed');
      final reopenedResult = await PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: root.path,
      );
      expect(
        reopenedResult,
        isA<CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>>(),
      );
      final reopened =
          (reopenedResult
                  as CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>)
              .value;
      addTearDown(reopened.close);
      final persisted =
          (await reopened.readDocument()
                  as CapabilitySuccess<DocumentSnapshot?>)
              .value!;
      expect(persisted.payload, 'replacement fixture');
      expect(persisted.fence, next.fence);
      expect(persisted.writeToken, 'replacement');
    },
  );
}
