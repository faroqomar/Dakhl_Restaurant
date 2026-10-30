import 'dart:convert';
import 'dart:io';

import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/accounts_view_model.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/workspace_document.dart';
import 'package:dakhl_restaurant/app/accounts_store.dart';
import 'package:dakhl_restaurant/app/app.dart';
import 'package:dakhl_restaurant/app/bootstrap.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Fixture-only multi-launch harness. Keep --no-uninstall on every invocation.
/// Write/read/recover/read-recovered each require a fresh native process; a read
/// with a wrong nonce must fail, then the original nonce must still pass.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const stage = String.fromEnvironment('PHASE02_RESTART_STAGE');
  const nonce = String.fromEnvironment('PHASE02_RUN_NONCE');
  const slots = ['settings', '', 'sales', 'cash', 'sales', 'materials'];
  const codec = LegacyAccountCodec();
  testWidgets('Phase02 native account/workspace $stage; synthetic only', (
    tester,
  ) async {
    expect(['write', 'read', 'recover', 'read-recovered'], contains(stage));
    expect(
      RegExp(
        r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
      ).hasMatch(nonce),
      isTrue,
      reason: 'Fresh host UUID required before any storage access.',
    );
    final root = await _conformanceRoot();
    final accountsRoot = Directory(p.join(root.path, 'accounts'));
    await accountsRoot.create();
    final store = AppAccountsStore(
      openStore: () => PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: accountsRoot.path,
      ),
    );
    final preferences = AppPreferencesStore(
      openStore: () => PowerSyncLocalPreferencesStore.open(
        databasePath: p.join(root.path, 'shell.sqlite'),
      ),
      closeStore: (owner) async {
        if (owner is PowerSyncLocalPreferencesStore) await owner.close();
      },
    );
    addTearDown(preferences.close);
    addTearDown(store.close);
    final repository = AccountsRepository(store: store);
    final model = AccountsViewModel(repository: repository);
    addTearDown(model.dispose);
    await model.initialize();
    if (stage == 'write') {
      expect([
        AccountsState.absent,
        AccountsState.saved,
      ], contains(model.state));
      final raw = jsonDecode(
        jsonEncode(codec.empty().toJson()),
      ) as Map<String, dynamic>;
      raw['preferences']['restaurant'] = {
        'name': 'phase02-$nonce',
        'contact': 'writer-pid:$pid',
        'footer': 'isolated synthetic conformance fixture',
      };
      model.prepareImport(codec.encode(codec.decodeJson(raw)));
      await model.confirmImport();
      expect(model.state, AccountsState.saved);
      expect(await model.saveShortcuts(slots), isTrue);
      final workspace = WorkspaceDocument(
        active: {'note': 'active-$nonce'},
        form: {'runNonce': nonce, 'writerPid': '$pid', 'recovered': 'false'},
        held: List.generate(40, (i) => {'id': 'held-$i', 'note': '$nonce-$i'}),
      );
      await model.saveWorkspace(workspace, model.fence!);
      expect(model.state, AccountsState.saved);
    } else {
      expect(model.state, AccountsState.saved);
      expect(
        model.document!.preferences.restaurant['name'],
        'phase02-$nonce',
        reason: 'run_nonce_mismatch: never accept stale evidence.',
      );
      final writerPid = int.parse(
        model.document!.preferences.restaurant['contact']!.substring(
          'writer-pid:'.length,
        ),
      );
      expect(
        writerPid,
        isNot(pid),
        reason: 'Read/recovery must execute in a fresh process.',
      );
      expect(model.workspace.form['runNonce'], nonce);
      expect(model.workspace.form['writerPid'], isNot('$pid'));
      if (stage == 'read-recovered') {
        expect(model.workspace.form['recovered'], 'true');
        expect(model.workspace.active, isEmpty);
        expect(model.workspace.held, isEmpty);
      } else {
        expect(model.workspace.form['recovered'], 'false');
        expect(model.workspace.held.length, 40);
        expect(model.accountShortcuts, slots);
      }
      if (stage == 'recover') {
        final retired = model.fence!;
        final previous = await store.readPrevious();
        expect(previous, isA<CapabilitySuccess<PreviousDocument?>>());
        final selection =
            (previous as CapabilitySuccess<PreviousDocument?>).value!;
        expect(
          codec
              .decodeBytes(utf8.encode(selection.payload))
              .preferences
              .restaurant['name'],
          'phase02-$nonce',
        );
        await model.selectPrevious();
        expect(model.state, AccountsState.recoveryReady);
        await model.confirmRecovery();
        expect(model.state, AccountsState.saved);
        expect(model.fence!.storeId, isNot(retired.storeId));
        expect(model.fence!.generation, isNot(retired.generation));
        expect(model.workspace.active, isEmpty);
        expect(model.workspace.held, isEmpty);
        final late = await repository.saveWorkspace(
          WorkspaceDocument(
            active: {'note': 'late old callback'},
            form: const {},
            held: const [],
          ),
          retired,
        );
        expect(late, isA<CapabilityFailure<void>>());
        expect((late as CapabilityFailure<void>).code, 'stale_generation');
        await model.saveWorkspace(
          WorkspaceDocument(
            active: const {},
            form: {'runNonce': nonce, 'writerPid': '$pid', 'recovered': 'true'},
            held: const [],
          ),
          model.fence!,
        );
        expect(model.state, AccountsState.saved);
      }
    }
    final independent = await store.readPrevious();
    expect(independent, isA<CapabilitySuccess<PreviousDocument?>>());
    expect(
      (independent as CapabilitySuccess<PreviousDocument?>).value,
      isNotNull,
    );
    expect(model.document!.preferences.restaurant['name'], 'phase02-$nonce');
    await tester.pumpWidget(
      DakhlRestaurantApp(preferencesStore: preferences, accounts: model),
    );
    await tester.pumpAndSettle();
    expect(model.state, AccountsState.saved);
    binding.reportData = {
      'stage': stage,
      'runNonce': nonce,
      'pid': pid,
      'storeId': model.fence!.storeId,
      'generation': model.fence!.generation,
      'documentRevision': repository.snapshot!.revision,
      'held': model.workspace.held.length,
      'runtime': 'real native Madar adapter + consumer codec/repository/ViewModel + rendered app',
      'dataScope': 'fixed marked Phase02 conformance child only; --no-uninstall required',
    };
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Future<Directory> _conformanceRoot() async {
  final support = await getApplicationSupportDirectory();
  await support.create(recursive: true);
  final canonical = await support.resolveSymbolicLinks();
  final root = Directory(
    p.join(canonical, 'dakhl_restaurant_phase02_conformance'),
  );
  final type = await FileSystemEntity.type(root.path, followLinks: false);
  if (type != FileSystemEntityType.notFound &&
      type != FileSystemEntityType.directory) {
    throw StateError('Unsafe conformance root.');
  }
  await root.create();
  if (await root.resolveSymbolicLinks() != root.path) {
    throw StateError('Unsafe conformance root.');
  }
  final marker = File(p.join(root.path, '.phase02-fixture-owner'));
  const expected = 'dakhl_restaurant_phase02_conformance_v1\n';
  if (await marker.exists()) {
    if (await marker.readAsString() != expected) {
      throw StateError('Unknown conformance ownership.');
    }
  } else {
    if (await root.list().isEmpty == false) {
      throw StateError('Unmarked nonempty conformance root.');
    }
    await marker.create(exclusive: true);
    await marker.writeAsString(expected, flush: true);
  }
  return root;
}
