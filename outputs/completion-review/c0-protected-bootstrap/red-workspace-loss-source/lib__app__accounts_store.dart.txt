import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:path/path.dart' as p;

import '../platform/shell_preferences_directory.dart';

/// App-owned location/lifecycle composition; all durable algorithms are Madar.
final class AppAccountsStore implements LocalDocumentWorkspaceStore {
  AppAccountsStore({required this.openStore});
  factory AppAccountsStore.native() => AppAccountsStore(
    openStore: () async {
      final location = await ShellPreferencesDirectory().databasePath();
      if (location is! CapabilitySuccess<String>) {
        return const CapabilityFailure(
          'unavailable',
          'Account location is unavailable.',
        );
      }
      final root = Directory(
        p.join(p.dirname(location.value), 'accounts-phase02'),
      );
      final type = await FileSystemEntity.type(root.path, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.directory) {
        return const CapabilityFailure(
          'unsafe_storage_root',
          'Account location is protected.',
        );
      }
      await root.create();
      if (await root.resolveSymbolicLinks() != root.path) {
        return const CapabilityFailure(
          'unsafe_storage_root',
          'Account location is protected.',
        );
      }
      return PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: root.path,
        eventSink: (event) {
          if (kDebugMode) debugPrint(jsonEncode(event.toJson()));
        },
      );
    },
  );
  final Future<CapabilityResult<LocalDocumentWorkspaceStore>> Function()
  openStore;
  Future<CapabilityResult<LocalDocumentWorkspaceStore>>? _opening;
  bool _closed = false;
  Future<void>? _closing;
  Future<CapabilityResult<T>> _call<T>(
    Future<CapabilityResult<T>> Function(LocalDocumentWorkspaceStore)
    operation, {
    bool mutating = false,
  }) async {
    if (_closed) {
      return const CapabilityFailure('closed', 'Account owner has closed.');
    }
    final CapabilityResult<LocalDocumentWorkspaceStore> acquired;
    try {
      acquired = await (_opening ??= openStore());
    } on Object {
      _opening = null;
      return const CapabilityFailure(
        'unavailable',
        'Account storage is unavailable.',
      );
    }
    if (_closed) {
      return const CapabilityFailure('closed', 'Account owner has closed.');
    }
    if (acquired is! CapabilitySuccess<LocalDocumentWorkspaceStore>) {
      _opening = null;
      return acquired is CapabilityFailure<LocalDocumentWorkspaceStore>
          ? CapabilityFailure(acquired.code, acquired.message)
          : const CapabilityFailure(
              'unavailable',
              'Account storage is unavailable.',
            );
    }
    try {
      return await operation(acquired.value);
    } on Object {
      // Preserve the owner for authoritative readback. A post-invocation error
      // cannot release ownership or establish transaction rollback.
      return CapabilityFailure(
        mutating ? 'commit_unknown' : 'unavailable',
        'Account operation could not be confirmed.',
      );
    }
  }

  @override
  Future<CapabilityResult<DocumentSnapshot?>> readDocument() =>
      _call((s) => s.readDocument());
  @override
  Future<CapabilityResult<DocumentSnapshot>> writeDocument(
    String payload, {
    required String writeToken,
    DocumentSnapshot? expected,
    bool replaceGeneration = false,
  }) => _call(
    (s) => s.writeDocument(
      payload,
      writeToken: writeToken,
      expected: expected,
      replaceGeneration: replaceGeneration,
    ),
    mutating: true,
  );
  @override
  Future<CapabilityResult<DocumentSnapshot>> resumeInitialCreation(
    String payload, {
    required String writeToken,
  }) => _call(
    (s) => s.resumeInitialCreation(payload, writeToken: writeToken),
    mutating: true,
  );
  @override
  Future<CapabilityResult<WorkspaceState>> readWorkspace(StorageFence fence) =>
      _call((s) => s.readWorkspace(fence));
  @override
  Future<CapabilityResult<WorkspaceSnapshot>> writeWorkspace(
    String payload, {
    required StorageFence fence,
    required int? expectedRevision,
    required String writeToken,
  }) => _call(
    (s) => s.writeWorkspace(
      payload,
      fence: fence,
      expectedRevision: expectedRevision,
      writeToken: writeToken,
    ),
    mutating: true,
  );
  @override
  Future<CapabilityResult<PreviousDocument?>> readPrevious() =>
      _call((s) => s.readPrevious());
  @override
  Future<CapabilityResult<String>> preserveSource(List<int> bytes) =>
      _call((s) => s.preserveSource(bytes));
  @override
  Future<CapabilityResult<DocumentSnapshot>> recoverPrevious(
    PreviousDocument previous, {
    required String payload,
    required String writeToken,
  }) => _call(
    (s) =>
        s.recoverPrevious(previous, payload: payload, writeToken: writeToken),
    mutating: true,
  );
  @override
  Future<CapabilityResult<void>> resolvePendingWrite() =>
      _call((s) => s.resolvePendingWrite());
  @override
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    final opening = _opening;
    if (opening == null) return;
    final result = await opening;
    if (result is CapabilitySuccess<LocalDocumentWorkspaceStore>) {
      await result.value.close();
    }
  }
}
