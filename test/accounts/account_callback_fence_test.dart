import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/accounts_view_model.dart';
import 'package:dakhl_restaurant/app/app.dart';
import 'package:dakhl_restaurant/sales/sales_surface.dart';
import 'package:dakhl_restaurant/shell/shell_view_model.dart';
import 'package:madar_application/madar_application.dart';
import 'package:flutter/material.dart';

import '../support/preferences_store.dart';
import 'accounts_view_model_test.dart' show FixtureStore;

void main() {
  testWidgets(
    'retired screen callback cannot revive workspace after replacement',
    (tester) async {
      final store = FixtureStore();
      final accounts = AccountsViewModel(
        repository: AccountsRepository(store: store),
      );
      await accounts.initialize();
      await accounts.save();
      await tester.pumpWidget(
        DakhlRestaurantApp(
          preferencesStore: MemoryPreferencesStore(),
          accounts: accounts,
        ),
      );
      await tester.pumpAndSettle();
      final old = tester.widget<SalesSurface>(find.byType(SalesSurface)).model!;
      final oldSave = old.saveFormDraft;
      accounts.prepareImport(
        accounts.repository.codec.encode(accounts.repository.codec.empty()),
      );
      await accounts.confirmImport();
      await tester.pumpAndSettle();
      final before = accounts.workspace.encode();
      final writes = store.workspaceWrites;
      final refused = await oldSave({'nonce': 'retired'});
      await tester.pumpAndSettle();
      expect(refused, isA<CapabilityFailure<void>>());
      expect((refused as CapabilityFailure<void>).code, 'disposed');
      expect(accounts.workspace.encode(), before);
      expect(store.workspaceWrites, writes);
      expect(
        tester.widget<SalesSurface>(find.byType(SalesSurface)).model,
        isNot(same(old)),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      accounts.dispose();
    },
  );
  testWidgets(
    'shell listener retains oversized draft without exception or storewrite',
    (tester) async {
      final store = FixtureStore();
      final model = AccountsViewModel(
        repository: AccountsRepository(store: store),
      );
      await model.initialize();
      await model.save();
      ShellViewModel? shell;
      await tester.pumpWidget(
        DakhlRestaurantApp(
          preferencesStore: MemoryPreferencesStore(),
          accounts: model,
          onShellReady: (value) => shell = value,
        ),
      );
      await tester.pumpAndSettle();
      final writes = store.workspaceWrites;
      shell!.setFormDraft({'note': 'x' * (20 * 1024 * 1024)});
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(model.busy, isFalse);
      expect(model.state, AccountsState.failed);
      expect(store.workspaceWrites, writes);
      expect(model.workspace.form['note']!.length, 20 * 1024 * 1024);
      expect(shell!.formDraft['note']!.length, 20 * 1024 * 1024);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    },
  );
}
