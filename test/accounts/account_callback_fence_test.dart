import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/accounts_view_model.dart';
import 'package:dakhl_restaurant/app/app.dart';
import 'package:dakhl_restaurant/ui/route_surface.dart';

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
      final old = tester
          .widget<Phase01RouteSurface>(find.byType(Phase01RouteSurface))
          .onTicketChanged!;
      accounts.prepareImport(
        accounts.repository.codec.encode(accounts.repository.codec.empty()),
      );
      await accounts.confirmImport();
      await tester.pumpAndSettle();
      old({'nonce': 'retired'});
      await tester.pumpAndSettle();
      expect(accounts.workspace.active, isEmpty);
      expect(
        tester
            .widget<Phase01RouteSurface>(find.byType(Phase01RouteSurface))
            .ticketPresentation,
        isEmpty,
      );
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
      await tester.pumpWidget(
        DakhlRestaurantApp(
          preferencesStore: MemoryPreferencesStore(),
          accounts: model,
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<Phase01RouteSurface>(find.byType(Phase01RouteSurface))
          .onFormChanged!({'note': 'x' * (20 * 1024 * 1024)});
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(model.busy, isFalse);
      expect(model.state, AccountsState.failed);
      expect(store.workspaceWrites, 0);
      expect(model.workspace.form['note']!.length, 20 * 1024 * 1024);
    },
  );
}
