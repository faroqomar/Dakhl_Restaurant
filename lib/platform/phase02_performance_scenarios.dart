import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:madar_data/madar_data.dart';

import '../accounts/account_document.dart';
import '../accounts/accounts_repository.dart';
import '../accounts/accounts_view_model.dart';
import '../accounts/legacy_account_codec.dart';
import '../accounts/workspace_document.dart';
import '../app/accounts_store.dart';

const phase02PerformanceCases = {
  'accounts.open',
  'accounts.save',
  'accounts.migrate_legacy',
  'accounts.replace',
  'accounts.recover_previous',
  'workspace.save_restore',
};

final class Phase02PerformanceOptions {
  const Phase02PerformanceOptions(
    this.operationId,
    this.iterations,
    this.runId,
    this.fixtureName,
    this.manifestPath,
  );
  final String operationId, runId, fixtureName;
  final int iterations;
  final String? manifestPath;
  factory Phase02PerformanceOptions.parse(List<String> arguments) {
    final values = <String, String>{};
    for (var i = 0; i < arguments.length; i += 2) {
      if (i + 1 >= arguments.length ||
          !{
            '--case',
            '--iterations',
            '--run-id',
            '--fixture',
            '--fixture-manifest',
          }.contains(arguments[i]) ||
          values.containsKey(arguments[i])) {
        throw const FormatException('Invalid Phase02 benchmark arguments.');
      }
      values[arguments[i]] = arguments[i + 1];
    }
    final operation = values['--case'] ?? 'accounts.open',
        run = values['--run-id'] ?? 'local',
        fixture = values['--fixture'] ?? 'small';
    final iterations = int.tryParse(values['--iterations'] ?? '20') ?? 0;
    if (!phase02PerformanceCases.contains(operation) ||
        iterations < 1 ||
        iterations > 100 ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(run) ||
        !{'small', 'medium', 'largest'}.contains(fixture)) {
      throw const FormatException(
        'Unsupported Phase02 benchmark case, count, fixture or identity.',
      );
    }
    final manifest = values['--fixture-manifest'];
    if (manifest != null &&
        (!File(manifest).isAbsolute || !manifest.endsWith('.json'))) {
      throw const FormatException(
        'Manifest must be an absolute JSON output path.',
      );
    }
    return Phase02PerformanceOptions(
      operation,
      iterations,
      run,
      fixture,
      manifest,
    );
  }
}

/// Deterministic synthetic cash-transaction workload, not a production-volume
/// promise. Record counts, accepted bytes and source-schema are explicit.
final class Phase02Workload {
  Phase02Workload._(
    this.name,
    this.recordCount,
    this.noteLength,
    this.document,
    this.canonicalBytes,
    this.legacyBytes,
    this.replacementBytes,
    this.workspace,
  );
  final String name;
  final int recordCount, noteLength;
  final AccountDocument document;
  final Uint8List canonicalBytes, legacyBytes, replacementBytes;
  final WorkspaceDocument workspace;
  static const _codec = LegacyAccountCodec();
  static const savedSlots = [
    'settings',
    '',
    'sales',
    'cash',
    'sales',
    'materials',
  ];
  factory Phase02Workload.create(String name, String nonce) {
    if (!{'small', 'medium', 'largest'}.contains(name) ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(nonce)) {
      throw const FormatException('Invalid synthetic fixture profile.');
    }
    final count = switch (name) {
      'small' => 10,
      'medium' => 1000,
      _ => 10000,
    };
    final raw =
        jsonDecode(jsonEncode(_codec.empty().toJson())) as Map<String, dynamic>;
    (raw['preferences']['restaurant'] as Map)['name'] =
        'Synthetic Phase02 $nonce';
    final records = List.generate(
      count,
      (i) => <String, Object?>{
        'id': 'benchmark-$i',
        'date': '2024-02-29',
        'type': 'deposit',
        'amount': i % 100 + 1,
        'note': 'synthetic-$i',
        'createdAt': '2024-02-29T12:00:00.000Z',
      },
    );
    raw['transactions'] = records;
    var noteLength = 0;
    if (name == 'largest') {
      final base = _codec.encode(_codec.decodeJson(raw)).length;
      noteLength = min(
        2000,
        (LegacyAccountCodec.maxPayloadBytes - 65536 - base) ~/ count,
      );
      final note = List.filled(noteLength, 'x').join();
      for (final record in records) {
        record['note'] = note;
      }
    }
    final document = _codec.decodeJson(raw),
        canonical = _codec.encode(document);
    final legacy = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
    legacy['version'] = 1;
    final replacement =
        jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>;
    replacement['preferences']['restaurant']['name'] =
        'Replacement Phase02 $nonce';
    final workspace = WorkspaceDocument(
      active: {'note': 'active-$nonce', 'quantity': '1'},
      form: {'note': 'unsaved-$nonce'},
      held: List.generate(
        40,
        (i) => {'id': 'held-$i', 'note': 'held-$nonce-$i', 'quantity': '1'},
      ),
    );
    return Phase02Workload._(
      name,
      count,
      noteLength,
      document,
      canonical,
      Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(legacy)),
      ),
      _codec.encode(_codec.decodeJson(replacement)),
      workspace,
    );
  }
  Map<String, Object> get manifest => {
    'profile': name,
    'synthetic': true,
    'sourceSchema': 11,
    'legacySourceSchema': 1,
    'recordKind': 'cash transactions; no operating commands',
    'recordCount': recordCount,
    'canonicalBytes': canonicalBytes.length,
    'legacyInputBytes': legacyBytes.length,
    'replacementBytes': replacementBytes.length,
    if (noteLength > 0) 'noteCharactersPerRecord': noteLength,
    if (noteLength == 0) 'notePattern': 'synthetic-{index}',
    'accountLimitBytes': LegacyAccountCodec.maxPayloadBytes,
    'workspaceBytes': utf8.encode(workspace.encode()).length,
    'heldDrafts': 40,
    'activeDrafts': 1,
    'largestMarginPolicyBytes': 65536,
  };
}

void _saved(AccountsViewModel model) {
  if (model.state != AccountsState.saved ||
      model.busy ||
      model.document == null ||
      model.fence == null) {
    throw StateError(
      'Account operation did not acknowledge a valid saved document.',
    );
  }
}

Future<void> preparePhase02Operation(
  AccountsViewModel model,
  String operation,
  Phase02Workload fixture,
) async {
  if (!phase02PerformanceCases.contains(operation)) {
    throw ArgumentError.value(operation);
  }
  await model.initialize();
  if (model.state != AccountsState.absent) {
    throw StateError('Benchmark must start in a new isolated store.');
  }
  if (operation == 'accounts.migrate_legacy') return;
  model.prepareImport(fixture.canonicalBytes);
  await model.confirmImport();
  _saved(model);
  if ({'accounts.replace', 'accounts.recover_previous'}.contains(operation)) {
    await model.saveWorkspace(fixture.workspace, model.fence!);
    _saved(model);
  }
  if (operation == 'accounts.recover_previous') {
    if (!await model.saveShortcuts(Phase02Workload.savedSlots)) {
      throw StateError('Previous-copy setup failed.');
    }
  }
}

/// Consumer ViewModel/repository commands only; preparation/storage reset is
/// outside the elapsed timer. The entrypoint waits for actual raster completion.
Future<void> runPhase02Operation(
  AccountsViewModel model,
  String operation,
  Phase02Workload fixture,
) async {
  final oldFence = model.fence;
  switch (operation) {
    case 'accounts.open':
      await model.initialize();
    case 'accounts.save':
      if (!await model.saveShortcuts(Phase02Workload.savedSlots)) {
        throw StateError('Account save failed.');
      }
      if (model.accountShortcuts!.join('|') !=
          Phase02Workload.savedSlots.join('|')) {
        throw StateError('Saved preferences mismatch.');
      }
    case 'accounts.migrate_legacy':
      model.prepareImport(fixture.legacyBytes);
      await model.confirmImport();
      if (model.document?.sourceVersion != 1) {
        throw StateError('Legacy migration did not run.');
      }
    case 'accounts.replace':
      model.prepareImport(fixture.replacementBytes);
      await model.confirmImport();
      if (model.fence == oldFence ||
          model.workspace.held.isNotEmpty ||
          model.workspace.active.isNotEmpty) {
        throw StateError('Replacement did not fence old workspace.');
      }
    case 'accounts.recover_previous':
      await model.selectPrevious();
      await model.confirmRecovery();
      if (model.fence == oldFence ||
          model.workspace.held.isNotEmpty ||
          model.document?.preferences.shortcuts.join('|') !=
              fixture.document.preferences.shortcuts.join('|')) {
        throw StateError(
          'Recovery did not activate independent previous state with a fresh fence.',
        );
      }
    case 'workspace.save_restore':
      await model.saveWorkspace(fixture.workspace, model.fence!);
      await model.initialize();
      if (model.workspace.encode() != fixture.workspace.encode()) {
        throw StateError('Workspace restore mismatch.');
      }
    default:
      throw ArgumentError.value(operation);
  }
  _saved(model);
}

/// Owns one fresh temporary fixture directory and the app's real adapter
/// composition. No normal application location is resolved or deleted.
final class Phase02PerformanceFixture {
  Phase02PerformanceFixture._(this.directory) {
    _compose();
  }
  final Directory directory;
  late AppAccountsStore store;
  late AccountsViewModel model;
  void _compose() {
    store = AppAccountsStore(
      openStore: () => PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: directory.path,
      ),
    );
    model = AccountsViewModel(repository: AccountsRepository(store: store));
  }

  static Future<Phase02PerformanceFixture> create(
    String runId,
    String operation,
    Phase02Workload workload,
  ) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(runId)) {
      throw const FormatException('Invalid fixture identity.');
    }
    final directory = await Directory.systemTemp.createTemp(
      'dakhl-phase02-bench-$runId-$pid-',
    );
    final fixture = Phase02PerformanceFixture._(directory);
    try {
      await preparePhase02Operation(fixture.model, operation, workload);
      if (operation == 'accounts.open') {
        fixture.model.dispose();
        await fixture.store.close();
        fixture._compose();
      }
      return fixture;
    } on Object {
      await fixture.close();
      rethrow;
    }
  }

  Future<void> close() async {
    model.dispose();
    await store.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
