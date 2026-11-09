import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/legacy_session_undo.dart';

import 'accounts_view_model_test.dart' show FixtureStore;

void main() {
  late FixtureStore store;
  late AccountsRepository repository;
  late LegacySessionUndoController undo;
  const codec = LegacyAccountCodec();
  setUp(() async {
    store = FixtureStore();
    repository = AccountsRepository(store: store);
    await repository.open();
    await repository.save(codec.empty());
    undo = LegacySessionUndoController(
      repository: repository,
      isWriteBlocked: () => false,
    )..observe();
  });
  tearDown(() => undo.dispose());
  Future<void> rename(String name) async {
    final json = repository.document!.toJson();
    final prefs = json['preferences']! as Map<String, Object?>;
    final saved = await repository.save(
      codec.decodeJson({
        ...json,
        'preferences': {
          ...prefs,
          'restaurant': {
            ...prefs['restaurant'] as Map<String, Object?>,
            'name': name,
          },
        },
      }),
    );
    expect(saved, isA<CapabilitySuccess>());
    expect(repository.document!.preferences.restaurant['name'], name);
  }

  test(
    'metadata undo restores captured fields and keeps unrelated workspace',
    () async {
      await rename('Changed');
      undo.observe();
      final workspace = repository.workspaceSnapshot;
      expect(await undo.undo(), isA<CapabilitySuccess<void>>());
      expect(repository.document!.preferences.restaurant['name'], '');
      expect(repository.workspaceSnapshot, same(workspace));
      expect(undo.length, 0);
    },
  );
  test(
    'lost acknowledgement retains exact compensation until readback',
    () async {
      await rename('Changed');
      undo.observe();
      store.throwAfterCommit = true;
      expect((await undo.undo() as CapabilityFailure).code, 'commit_unknown');
      expect(undo.needsReadback, true);
      final writes = store.writes;
      expect(await undo.undo(), isA<CapabilitySuccess<void>>());
      expect(store.writes, writes);
      expect(repository.document!.preferences.restaurant['name'], '');
      expect(undo.length, 0);
    },
  );
  test(
    'unobserved later edit refuses undo without changing current records',
    () async {
      await rename('First');
      undo.observe();
      await rename('Later');
      final writes = store.writes;
      expect(
        (await undo.undo() as CapabilityFailure).code,
        'stale_undo_snapshot',
      );
      expect(repository.document!.preferences.restaurant['name'], 'Later');
      expect(store.writes, writes);
      expect(undo.length, 1);
    },
  );
}
