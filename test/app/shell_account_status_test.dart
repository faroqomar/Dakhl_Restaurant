import 'dart:async';
import 'dart:convert';

import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/accounts_view_model.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/app/app.dart';
import 'package:dakhl_restaurant/shell/shell_preferences.dart';
import 'package:dakhl_restaurant/shell/shell_view_model.dart';
import 'package:dakhl_restaurant/ui/dakhl_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;
import '../support/preferences_store.dart';

Future<AccountsViewModel> _savedAccount() async {
  const codec = LegacyAccountCodec();
  final engine = FixtureStore()
    ..document = DocumentSnapshot(
      payload: utf8.decode(codec.encode(codec.empty())),
      revision: 1,
      fence: const StorageFence(
        storeId: 'fixture-store',
        generation: 'fixture-generation',
      ),
      writeToken: 'fixture',
    );
  final account = AccountsViewModel(
    repository: AccountsRepository(store: engine),
  );
  await account.initialize();
  expect(account.state, AccountsState.saved);
  return account;
}

void main() {
  void desktop(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'saved account does not hide an in-flight shell preference save',
    (tester) async {
      desktop(tester);
      final account = await _savedAccount();
      addTearDown(account.dispose);
      final store = _DelayedPreferencesStore();
      ShellViewModel? model;
      await tester.pumpWidget(
        DakhlRestaurantApp(
          accounts: account,
          preferencesStore: store,
          onShellReady: (value) => model = value,
        ),
      );
      await tester.pumpAndSettle();
      store.holdWrites = true;
      final navigation = model!.navigate('cash');
      await tester.pump();
      final shell = tester.widget<DakhlShellView>(find.byType(DakhlShellView));
      expect(account.state, AccountsState.saved);
      expect(shell.statusKind, DakhlStatusKind.saving);
      expect(shell.statusMessage, 'جارٍ حفظ إعدادات العرض…');
      expect(find.text('محفوظ على جهازك'), findsNothing);
      store.release.complete();
      await navigation;
      await tester.pumpAndSettle();
      expect(
        tester.widget<DakhlShellView>(find.byType(DakhlShellView)).statusKind,
        DakhlStatusKind.saved,
      );
    },
  );

  testWidgets(
    'saved account does not hide unsaved session-only shell preferences',
    (tester) async {
      desktop(tester);
      final account = await _savedAccount();
      addTearDown(account.dispose);
      final store = MemoryPreferencesStore(
        readFailure: PreferenceErrorCodes.unavailable,
        snapshot: PreferenceSnapshot(
          payload: ShellPreferences.defaults()
              .copyWith(routeId: 'inventory')
              .encode(),
          revision: 4,
        ),
      );
      ShellViewModel? model;
      await tester.pumpWidget(
        DakhlRestaurantApp(
          accounts: account,
          preferencesStore: store,
          onShellReady: (value) => model = value,
        ),
      );
      await tester.pumpAndSettle();
      await model!.navigate('cash');
      store.readFailure = null;
      await model!.retryRead();
      await tester.pumpAndSettle();
      final shell = tester.widget<DakhlShellView>(find.byType(DakhlShellView));
      expect(account.state, AccountsState.saved);
      expect(shell.statusKind, DakhlStatusKind.info);
      expect(
        shell.statusMessage,
        'تغييرات العرض لهذه الجلسة فقط؛ لم تُحفظ على جهازك.',
      );
      expect(find.text('محفوظ على جهازك'), findsNothing);
      expect(store.writes, isEmpty);
    },
  );
}

final class _DelayedPreferencesStore implements LocalPreferencesStore {
  final inner = MemoryPreferencesStore();
  final release = Completer<void>();
  bool holdWrites = false;
  @override
  Future<CapabilityResult<PreferenceSnapshot?>> read(String namespace) =>
      inner.read(namespace);
  @override
  Future<CapabilityResult<PreferenceSnapshot>> replace(
    String namespace,
    String payload, {
    int? expectedRevision,
  }) async {
    if (holdWrites) await release.future;
    return inner.replace(
      namespace,
      payload,
      expectedRevision: expectedRevision,
    );
  }
}
