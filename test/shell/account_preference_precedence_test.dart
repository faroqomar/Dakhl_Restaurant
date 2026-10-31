import 'dart:async';

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
    final operations = <String>[];
    final store = _LoggedPreferencesStore(operations, failure: 'unavailable');
    var account = List.filled(6, 'sales');
    var accountWrites = 0;
    final model = ShellViewModel(
      store: store,
      accountShortcuts: () => account,
      saveAccountShortcuts: (slots) async {
        operations.add('account');
        account = List.of(slots);
        accountWrites++;
        return true;
      },
    );
    await model.initialize();
    model.beginShortcutEditing();
    model.setShortcut(0, 'settings');
    await model.saveShortcuts();
    expect(operations, ['account', 'cache']);
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
  test(
    'Retry repeats failed account callback before attempting device cache',
    () async {
      final operations = <String>[];
      final store = _LoggedPreferencesStore(operations);
      var account = List.filled(6, 'sales');
      var attempts = 0;
      final retry = Completer<bool>();
      final model = ShellViewModel(
        store: store,
        accountShortcuts: () => account,
        saveAccountShortcuts: (slots) async {
          operations.add('account');
          attempts++;
          if (attempts == 1) return false;
          final saved = await retry.future;
          if (saved) account = List.of(slots);
          return saved;
        },
      );
      addTearDown(model.dispose);
      await model.initialize();
      model.beginShortcutEditing();
      model.setShortcut(0, 'settings');
      await model.saveShortcuts();
      expect(model.saveState, ShellSaveState.failed);
      expect(model.shortcutDraft!.first, 'settings');
      expect(operations, ['account']);
      final firstRetry = model.retrySave();
      final duplicateRetry = model.retrySave();
      expect(attempts, 2);
      expect(operations, ['account', 'account']);
      retry.complete(true);
      await Future.wait([firstRetry, duplicateRetry]);
      expect(operations, ['account', 'account', 'cache']);
      expect(account.first, 'settings');
      expect(model.shortcutDraft, isNull);
      expect(model.saveState, ShellSaveState.saved);
    },
  );
}

final class _LoggedPreferencesStore implements LocalPreferencesStore {
  _LoggedPreferencesStore(this.operations, {String? failure})
    : inner = MemoryPreferencesStore(writeFailure: failure);
  final List<String> operations;
  final MemoryPreferencesStore inner;
  @override
  Future<CapabilityResult<PreferenceSnapshot?>> read(String namespace) =>
      inner.read(namespace);
  @override
  Future<CapabilityResult<PreferenceSnapshot>> replace(
    String namespace,
    String payload, {
    int? expectedRevision,
  }) {
    operations.add('cache');
    return inner.replace(
      namespace,
      payload,
      expectedRevision: expectedRevision,
    );
  }
}
