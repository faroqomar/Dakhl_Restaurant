import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/shell/shell_preferences.dart';
import 'package:dakhl_restaurant/shell/shell_view_model.dart';

import '../support/preferences_store.dart';

void main() {
  test(
    'account shortcuts win while route stays device-local and cache preserved',
    () async {
      final cache = ShellPreferences(
        routeId: 'materials',
        shortcuts: List.filled(6, 'sales'),
      );
      final store = MemoryPreferencesStore(
        snapshot: PreferenceSnapshot(payload: cache.encode(), revision: 1),
      );
      final account = [
        'settings',
        '',
        'cash',
        'expenses',
        'sales',
        'materials',
      ];
      final model = ShellViewModel(
        store: store,
        accountShortcuts: () => account,
      );
      await model.initialize();
      expect(model.routeId, 'materials');
      expect(model.shortcuts, account);
      expect(store.writes, isEmpty);
    },
  );
  test('account save precedes cache; cache failure preserves acknowledged account settings', () async {
    final store = MemoryPreferencesStore()..writeFailure = 'unavailable';
    var account = List.filled(6, 'sales');
    var accountWrites = 0;
    final model = ShellViewModel(
      store: store,
      accountShortcuts: () => account,
      saveAccountShortcuts: (slots) async {
        expect(store.writes, isEmpty);
        account = List.of(slots);
        accountWrites++;
        return true;
      },
    );
    await model.initialize();
    model.beginShortcutEditing();
    model.setShortcut(0, 'settings');
    await model.saveShortcuts();
    expect(accountWrites, 1);
    expect(account.first, 'settings');
    expect(model.shortcuts.first, 'settings');
  });
  test(
    'failed account save retains editor and does not write device cache',
    () async {
      final store = MemoryPreferencesStore();
      final model = ShellViewModel(
        store: store,
        saveAccountShortcuts: (_) async => false,
      );
      await model.initialize();
      model.beginShortcutEditing();
      model.setShortcut(0, 'settings');
      await model.saveShortcuts();
      expect(model.shortcutDraft, isNotNull);
      expect(store.writes, isEmpty);
    },
  );
}
