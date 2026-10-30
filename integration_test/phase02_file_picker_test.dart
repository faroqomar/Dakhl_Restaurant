import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/accounts_surface.dart';
import 'package:dakhl_restaurant/accounts/accounts_view_model.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/workspace_document.dart';
import 'package:dakhl_restaurant/app/accounts_store.dart';
import 'package:dakhl_restaurant/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:madar_flutter_adapters/madar_flutter_adapters.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Human/computer-use native dialog handoff over synthetic marked fixtures only.
/// PHASE02_PICKER_STAGE: cancel-open, cancel-save, import-file. Every native
/// picker/confirmation wait is bounded120s. The host operates only printed paths.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const stage = String.fromEnvironment('PHASE02_PICKER_STAGE');
  const nonce = String.fromEnvironment('PHASE02_RUN_NONCE');
  const codec = LegacyAccountCodec();
  testWidgets('Phase02 real native picker $stage; isolated synthetic fixture', (
    tester,
  ) async {
    expect(['cancel-open', 'cancel-save', 'import-file'], contains(stage));
    expect(
      RegExp(
        r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
      ).hasMatch(nonce),
      isTrue,
    );
    final support = await getApplicationSupportDirectory();
    await support.create(recursive: true);
    final parent = await support.resolveSymbolicLinks();
    final fixtureRoot = Directory(
      p.join(parent, 'dakhl_restaurant_phase02_picker_conformance'),
    );
    final type = await FileSystemEntity.type(
      fixtureRoot.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.directory) {
      throw StateError('Unsafe picker fixture root.');
    }
    await fixtureRoot.create();
    if (await fixtureRoot.resolveSymbolicLinks() != fixtureRoot.path) {
      throw StateError('Unsafe picker fixture root.');
    }
    final marker = File(p.join(fixtureRoot.path, '.phase02-fixture-owner'));
    const owner = 'dakhl_restaurant_phase02_picker_conformance_v1\n';
    if (await marker.exists()) {
      if (await marker.readAsString() != owner) {
        throw StateError('Unknown picker fixture ownership.');
      }
    } else {
      if (!await fixtureRoot.list().isEmpty) {
        throw StateError('Unmarked nonempty picker fixture root.');
      }
      await marker.create(exclusive: true);
      await marker.writeAsString(owner, flush: true);
    }
    // Each invocation owns a fresh child. Preserve source and all evidence;
    // never delete/overwrite any previous fixture or normal app location.
    final run = await fixtureRoot.createTemp('$nonce-$stage-');
    final accountRoot = Directory(p.join(run.path, 'accounts'));
    await accountRoot.create();
    final store = AppAccountsStore(
      openStore: () => PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: accountRoot.path,
      ),
    );
    addTearDown(store.close);
    final repository = AccountsRepository(store: store);
    final model = AccountsViewModel(repository: repository);
    addTearDown(model.dispose);
    await model.initialize();
    expect(model.state, AccountsState.absent);
    Map<String, dynamic> named(String name) =>
        jsonDecode(jsonEncode(codec.empty().toJson())) as Map<String, dynamic>
          ..['preferences']['restaurant']['name'] = name;
    final beforeName = 'before-picker-$nonce',
        importedName = 'selected-fixture-$nonce';
    final before = codec.decodeJson(named(beforeName));
    model.prepareImport(codec.encode(before));
    await model.confirmImport();
    expect(model.state, AccountsState.saved);
    await model.saveWorkspace(
      WorkspaceDocument(
        active: {'note': 'retained-input-$nonce'},
        form: {'fixture': nonce},
        held: const [],
      ),
      model.fence!,
    );
    expect(model.state, AccountsState.saved);
    final baseline = repository.snapshot!,
        baselineWorkspace = model.workspace.encode();
    final raw = named(importedName);
    raw['version'] = 1;
    final originalBytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(raw)),
    );
    final source = File(p.join(run.path, 'accounts.json'));
    await source.create(exclusive: true);
    await source.writeAsBytes(originalBytes, flush: true);
    final transfer = _ObservedTransfer(
      NativeFileTransfer(
        maxBytes: LegacyAccountCodec.maxPayloadBytes,
        fileName: 'phase02-$nonce-synthetic-export.json',
        mimeType: 'application/json',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: DakhlTheme.light,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: AccountsSurface(model: model, transfer: transfer),
        ),
      ),
    );
    await tester.pumpAndSettle();
    debugPrint('PHASE02_PICKER_FIXTURE ${source.path}');
    debugPrint('PHASE02_PICKER_STAGE $stage $nonce');
    if (stage == 'cancel-save') {
      await tester.tap(find.text('تصدير الحسابات'));
      await tester.pump();
      await _wait(
        tester,
        () => transfer.saved != null,
        'native export cancellation',
      );
      expect(transfer.saved, isA<CapabilityCancelled<void>>());
    } else {
      await tester.tap(find.text('استيراد الحسابات'));
      await tester.pump();
      await _wait(
        tester,
        () => transfer.opened != null,
        'native file selection',
      );
      if (stage == 'cancel-open') {
        expect(transfer.opened, isA<CapabilityCancelled<Uint8List>>());
      } else {
        expect(transfer.opened, isA<CapabilitySuccess<Uint8List>>());
        expect(
          (transfer.opened as CapabilitySuccess<Uint8List>).value,
          originalBytes,
        );
        debugPrint('PHASE02_PICKER_AWAIT_REPLACE_CONFIRM $nonce');
        await _wait(
          tester,
          () =>
              model.state == AccountsState.saved &&
              model.document?.preferences.restaurant['name'] == importedName,
          'explicit replacement confirmation',
        );
        expect(model.fence, isNot(baseline.fence));
        expect(model.workspace.active, isEmpty);
        expect(model.workspace.held, isEmpty);
        final importedFence = model.fence!;
        final previous = await repository.previous();
        expect(previous, isA<CapabilitySuccess<RecoverySelection?>>());
        expect(
          (previous as CapabilitySuccess<RecoverySelection?>)
              .value!
              .document
              .preferences
              .restaurant['name'],
          beforeName,
        );
        await tester.tap(find.text('استعادة النسخة السابقة').first);
        await tester.pump();
        debugPrint('PHASE02_PICKER_AWAIT_RECOVERY_CONFIRM $nonce');
        await _wait(
          tester,
          () =>
              model.state == AccountsState.saved &&
              model.document?.preferences.restaurant['name'] == beforeName,
          'explicit previous-copy recovery confirmation',
        );
        expect(model.fence!.storeId, isNot(importedFence.storeId));
        expect(model.fence!.generation, isNot(importedFence.generation));
        expect(model.workspace.active, isEmpty);
        expect(model.workspace.held, isEmpty);
      }
    }
    await _wait(tester, () => !model.busy, 'settled consumer state');
    expect(model.state, AccountsState.saved);
    expect(model.pendingImport, isNull);
    expect(
      await source.readAsBytes(),
      originalBytes,
      reason: 'Selected original must remain byte-for-byte unchanged.',
    );
    if (stage != 'import-file') {
      expect(repository.snapshot!.fence, baseline.fence);
      expect(repository.snapshot!.revision, baseline.revision);
      expect(repository.snapshot!.writeToken, baseline.writeToken);
      expect(model.document!.preferences.restaurant['name'], beforeName);
      expect(model.workspace.encode(), baselineWorkspace);
    }
    binding.reportData = {
      'stage': stage,
      'runNonce': nonce,
      'pid': pid,
      'nativeOpenOutcome': transfer.opened.runtimeType.toString(),
      'nativeSaveOutcome': transfer.saved.runtimeType.toString(),
      'sourceUnchanged': true,
      'replacementAndRecovery': stage == 'import-file',
      'dataScope': 'marked fresh picker-conformance child only',
      'runtime': 'real NativeFileTransfer + AccountsSurface + consumer ViewModel/repository + Madar',
    };
    debugPrint('PHASE02_PICKER_COMPLETE $stage $nonce');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }, timeout: const Timeout(Duration(minutes: 7)));
}

Future<void> _wait(
  WidgetTester tester,
  bool Function() settled,
  String label,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 120));
  while (!settled()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Timed out waiting for $label.');
    }
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  await tester.pump();
}

/// Observe actual outcomes without replacing the native picker implementation.
final class _ObservedTransfer implements FileTransferCapability {
  _ObservedTransfer(this.delegate);
  final FileTransferCapability delegate;
  CapabilityResult<Uint8List>? opened;
  CapabilityResult<void>? saved;
  @override
  Future<CapabilityResult<Uint8List>> open() async =>
      opened = await delegate.open();
  @override
  Future<CapabilityResult<void>> save(Uint8List bytes) async =>
      saved = await delegate.save(bytes);
}
