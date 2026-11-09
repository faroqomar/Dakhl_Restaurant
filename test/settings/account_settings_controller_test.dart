import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/settings/account_settings_controller.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;

void main() {
  late FixtureStore store;
  late AccountsRepository repository;
  setUp(() async {
    store = FixtureStore();
    repository = AccountsRepository(store: store);
    await repository.open();
    await repository.save(const LegacyAccountCodec().empty());
  });
  test(
    'durable save trims values and stale editor cannot overwrite it',
    () async {
      final first = AccountSettingsController(repository);
      final stale = AccountSettingsController(repository);
      first.replace(first.values.copyWith(name: ' Restaurant '));
      expect(await first.save(), isA<CapabilitySuccess<void>>());
      expect(first.values.name, 'Restaurant');
      expect(first.isDirty, isFalse);
      stale.replace(stale.values.copyWith(name: 'Old editor'));
      expect((await stale.save() as CapabilityFailure).code, 'stale_revision');
      expect(repository.document!.preferences.restaurant['name'], 'Restaurant');
    },
  );
  test(
    'edits during save survive acknowledgement and busy save is rejected',
    () async {
      final editor = AccountSettingsController(repository);
      editor.replace(editor.values.copyWith(name: 'First'));
      final pending = editor.save();
      editor.replace(editor.values.copyWith(name: 'Second'));
      expect((await editor.save() as CapabilityFailure).code, 'busy');
      expect(await pending, isA<CapabilitySuccess<void>>());
      expect(editor.values.name, 'Second');
      expect(editor.isDirty, isTrue);
      expect(repository.document!.preferences.restaurant['name'], 'First');
      expect(await editor.save(), isA<CapabilitySuccess<void>>());
      expect(repository.document!.preferences.restaurant['name'], 'Second');
    },
  );
  test(
    'definite failure retains edits; unknown outcome blocks retries',
    () async {
      final editor = AccountSettingsController(repository);
      editor.replace(editor.values.copyWith(name: 'Edited'));
      store.writeFailure = 'disk_full';
      expect((await editor.save() as CapabilityFailure).code, 'disk_full');
      expect(editor.isDirty, isTrue);
      store.writeFailure = null;
      store.throwAfterCommit = true;
      expect((await editor.save() as CapabilityFailure).code, 'commit_unknown');
      final count = store.writes;
      expect((await editor.save() as CapabilityFailure).code, 'commit_unknown');
      expect(store.writes, count);
      expect(editor.values.name, 'Edited');
    },
  );
  test(
    'invalid settings do not write and replaced account invalidates editor',
    () async {
      final editor = AccountSettingsController(repository);
      editor.replace(editor.values.copyWith(activeOrderTypes: []));
      final count = store.writes;
      expect(await editor.save(), isA<CapabilityFailure<void>>());
      expect(store.writes, count);
      await repository.save(const LegacyAccountCodec().empty(), replace: true);
      expect((await editor.save() as CapabilityFailure).code, 'stale_revision');
    },
  );
}
