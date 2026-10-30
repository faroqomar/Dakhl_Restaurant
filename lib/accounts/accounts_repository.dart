import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:madar_application/madar_application.dart';

import 'account_document.dart';
import 'legacy_account_codec.dart';
import 'workspace_document.dart';

/// Validated app composition over the opaque Madar port. No SQL/file algorithms.
final class AccountsRepository {
  AccountsRepository({
    required this.store,
    this.codec = const LegacyAccountCodec(),
  });
  final LocalDocumentWorkspaceStore store;
  final LegacyAccountCodec codec;
  DocumentSnapshot? _snapshot;
  WorkspaceSnapshot? _workspace;
  AccountDocument? _document;
  bool _initialized = false;
  bool initialCreationBlocked = false;
  String? _pendingToken;
  String? _pendingPayload;
  StorageFence? _pendingWorkspaceFence;
  DocumentSnapshot? get snapshot => _snapshot;
  AccountDocument? get document => _document;
  bool get hasUnknownWrite => _pendingToken != null;
  bool get hasUnknownWorkspaceWrite => _pendingWorkspaceFence != null;

  String _token() {
    final random = Random.secure();
    return List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<CapabilityResult<AccountDocument?>> open() async {
    try {
      final read = await store.readDocument();
      if (read is! CapabilitySuccess<DocumentSnapshot?>) {
        _initialized = false;
        initialCreationBlocked =
            read is CapabilityFailure<DocumentSnapshot?> &&
            read.code == 'incomplete_state' &&
            _snapshot == null;
        return _failure(read);
      }
      final snapshot = read.value;
      final document = snapshot == null
          ? null
          : codec.decodeBytes(utf8.encode(snapshot.payload));
      _snapshot = snapshot;
      _document = document;
      _initialized = true;
      initialCreationBlocked = false;
      _workspace = null;
      return CapabilitySuccess(document);
    } on AccountCodecException catch (error) {
      _initialized = false;
      return CapabilityFailure(error.code, 'Account data is protected.');
    } on Object {
      _initialized = false;
      return const CapabilityFailure(
        'unavailable',
        'Account storage is unavailable.',
      );
    }
  }

  PendingAccountImport prepare(List<int> bytes) =>
      PendingAccountImport(codec.decodeBytes(bytes), Uint8List.fromList(bytes));

  Future<CapabilityResult<AccountDocument>> save(
    AccountDocument document, {
    PendingAccountImport? source,
    bool replace = false,
  }) async {
    if (!_initialized && !(initialCreationBlocked && source != null)) {
      return const CapabilityFailure('not_initialized', 'Read accounts first.');
    }
    if (hasUnknownWrite) {
      return const CapabilityFailure(
        'commit_unknown',
        'Read back before retrying.',
      );
    }
    String? attemptedToken;
    String? attemptedPayload;
    try {
      final payload = utf8.decode(codec.encode(document));
      if (source != null) {
        final archived = await store.preserveSource(source.originalBytes);
        if (archived is! CapabilitySuccess<String>) return _failure(archived);
      }
      final token = _token();
      attemptedToken = token;
      attemptedPayload = payload;
      var resume = false;
      if (_snapshot == null) {
        final current = await store.readDocument();
        if (current is CapabilityFailure<DocumentSnapshot?>) {
          if (current.code != 'incomplete_state') return _failure(current);
          resume = true;
          initialCreationBlocked = true;
        } else if (current is CapabilitySuccess<DocumentSnapshot?> &&
            current.value != null) {
          return const CapabilityFailure(
            'conflict',
            'Read current accounts before writing.',
          );
        }
      }
      final result = resume
          ? await store.resumeInitialCreation(payload, writeToken: token)
          : await store.writeDocument(
              payload,
              writeToken: token,
              expected: _snapshot,
              replaceGeneration: replace,
            );
      if (result is CapabilitySuccess<DocumentSnapshot>) {
        _accept(result.value, document);
        return CapabilitySuccess(document);
      }
      if (result is CapabilityFailure<DocumentSnapshot> &&
          (result.code == 'commit_unknown' ||
              result.code == 'recovery_publication_unknown')) {
        _pendingToken = token;
        _pendingPayload = payload;
      }
      return _failure(result);
    } on AccountCodecException catch (error) {
      return CapabilityFailure(error.code, 'Account validation failed.');
    } on Object {
      if (attemptedToken != null) {
        _pendingToken = attemptedToken;
        _pendingPayload = attemptedPayload;
        return const CapabilityFailure(
          'commit_unknown',
          'Read back before retrying.',
        );
      }
      return const CapabilityFailure(
        'unavailable',
        'Account operation is unavailable.',
      );
    }
  }

  AccountDocument withShortcuts(
    AccountDocument current,
    List<String> shortcuts,
  ) {
    final json = Map<String, Object?>.from(current.toJson());
    json['preferences'] = {
      ...Map<String, Object?>.from(json['preferences'] as Map),
      'shortcuts': List<String>.of(shortcuts),
    };
    return codec.decodeJson(json);
  }

  Future<CapabilityResult<AccountDocument>> saveShortcuts(
    List<String> shortcuts,
  ) async {
    final current = _document ?? codec.empty();
    final json = Map<String, Object?>.from(current.toJson());
    final preferences = Map<String, Object?>.from(json['preferences'] as Map);
    preferences['shortcuts'] = List<String>.of(shortcuts);
    json['preferences'] = preferences;
    try {
      return await save(codec.decodeJson(json));
    } on AccountCodecException catch (error) {
      return CapabilityFailure(error.code, 'Invalid account preferences.');
    }
  }

  Future<CapabilityResult<AccountDocument>> reconcile() async {
    final token = _pendingToken;
    if (token == null) {
      return const CapabilityFailure(
        'no_pending_write',
        'No pending account write.',
      );
    }
    final resolved = await store.resolvePendingWrite();
    if (resolved is! CapabilitySuccess<void>) return _failure(resolved);
    final workspaceFence = _pendingWorkspaceFence;
    if (workspaceFence != null) {
      final read = await store.readWorkspace(workspaceFence);
      if (read is! CapabilitySuccess<WorkspaceState>) return _failure(read);
      final actual = read.value.snapshot;
      if (_snapshot?.fence != workspaceFence ||
          actual == null ||
          actual.writeToken != token ||
          actual.payload != _pendingPayload) {
        _pendingToken = null;
        _pendingPayload = null;
        _pendingWorkspaceFence = null;
        return const CapabilityFailure(
          'stale_generation',
          'Read the current workspace before retry.',
        );
      }
      _workspace = actual;
      _pendingToken = null;
      _pendingPayload = null;
      _pendingWorkspaceFence = null;
      return CapabilitySuccess(_document!);
    }
    final read = await store.readDocument();
    if (read is! CapabilitySuccess<DocumentSnapshot?>) return _failure(read);
    final actual = read.value;
    if (actual == null ||
        actual.writeToken != token ||
        actual.payload != _pendingPayload) {
      _pendingToken = null;
      _pendingPayload = null;
      // No automatic overwrite after a known different authority.
      return const CapabilityFailure(
        'stale_revision',
        'Read current accounts before retry.',
      );
    }
    try {
      final document = codec.decodeBytes(utf8.encode(actual.payload));
      _accept(actual, document);
      return CapabilitySuccess(document);
    } on AccountCodecException catch (error) {
      return CapabilityFailure(error.code, 'Account data is protected.');
    }
  }

  Future<CapabilityResult<RecoverySelection?>> previous() async {
    final result = await store.readPrevious();
    if (result is! CapabilitySuccess<PreviousDocument?>) {
      return _failure(result);
    }
    final selected = result.value;
    if (selected == null) return const CapabilitySuccess(null);
    try {
      final document = codec.decodeBytes(utf8.encode(selected.payload));
      return CapabilitySuccess(RecoverySelection(selected, document));
    } on AccountCodecException catch (error) {
      return CapabilityFailure(
        error.code,
        'Previous account data is protected.',
      );
    }
  }

  Future<CapabilityResult<AccountDocument>> recover(
    RecoverySelection selected,
  ) async {
    if (hasUnknownWrite) {
      return const CapabilityFailure(
        'commit_unknown',
        'Read back before recovery.',
      );
    }
    final payload = utf8.decode(codec.encode(selected.document));
    final token = _token();
    final result = await store.recoverPrevious(
      selected.previous,
      payload: payload,
      writeToken: token,
    );
    if (result is CapabilitySuccess<DocumentSnapshot>) {
      _initialized = true;
      _accept(result.value, selected.document);
      return CapabilitySuccess(selected.document);
    }
    if (result is CapabilityFailure<DocumentSnapshot> &&
        (result.code == 'recovery_publication_unknown' ||
            result.code == 'commit_unknown')) {
      _pendingToken = token;
      _pendingPayload = payload;
    }
    return _failure(result);
  }

  Future<CapabilityResult<WorkspaceDocument>> readWorkspace() async {
    final fence = _snapshot?.fence;
    if (fence == null) {
      return const CapabilityFailure('no_document', 'Save an account first.');
    }
    final result = await store.readWorkspace(fence);
    if (result is! CapabilitySuccess<WorkspaceState>) return _failure(result);
    if (_snapshot?.fence != fence || result.value.fence != fence) {
      return const CapabilityFailure(
        'stale_generation',
        'Workspace belongs to another account.',
      );
    }
    try {
      final snapshot = result.value.snapshot;
      final workspace = snapshot == null
          ? WorkspaceDocument.empty()
          : WorkspaceDocument.decode(snapshot.payload);
      _workspace = snapshot;
      return CapabilitySuccess(workspace);
    } on FormatException {
      return const CapabilityFailure(
        'invalid_workspace',
        'Workspace data is protected.',
      );
    }
  }

  Future<CapabilityResult<void>> saveWorkspace(
    WorkspaceDocument workspace,
    StorageFence fence,
  ) async {
    if (hasUnknownWrite) {
      return const CapabilityFailure(
        'commit_unknown',
        'Read back before writing.',
      );
    }
    if (_snapshot?.fence != fence) {
      return const CapabilityFailure(
        'stale_generation',
        'Workspace belongs to another account.',
      );
    }
    final payload = workspace.encode();
    final token = _token();
    CapabilityResult<WorkspaceSnapshot> result;
    try {
      result = await store.writeWorkspace(
        payload,
        fence: fence,
        expectedRevision: _workspace?.revision,
        writeToken: token,
      );
    } on Object {
      result = const CapabilityFailure(
        'commit_unknown',
        'Workspace acknowledgement unavailable.',
      );
    }
    if (_snapshot?.fence != fence) {
      return const CapabilityFailure(
        'stale_generation',
        'Workspace belongs to another account.',
      );
    }
    if (result is CapabilitySuccess<WorkspaceSnapshot>) {
      _workspace = result.value;
      return const CapabilitySuccess(null);
    }
    if (result is CapabilityFailure<WorkspaceSnapshot> &&
        result.code == 'commit_unknown') {
      _pendingToken = token;
      _pendingPayload = payload;
      _pendingWorkspaceFence = fence;
    }
    return _failure(result);
  }

  void _accept(DocumentSnapshot snapshot, AccountDocument document) {
    _initialized = true;
    initialCreationBlocked = false;
    if (_snapshot?.fence != snapshot.fence) _workspace = null;
    _snapshot = snapshot;
    _document = document;
    _pendingToken = null;
    _pendingPayload = null;
    _pendingWorkspaceFence = null;
  }

  CapabilityFailure<T> _failure<T>(CapabilityResult<dynamic> result) =>
      result is CapabilityFailure<dynamic>
      ? CapabilityFailure(result.code, result.message)
      : const CapabilityFailure(
          'unavailable',
          'Account operation is unavailable.',
        );
}

final class PendingAccountImport {
  PendingAccountImport(this.document, Uint8List bytes)
    : _bytes = Uint8List.fromList(bytes);
  final AccountDocument document;
  final Uint8List _bytes;
  Uint8List get originalBytes => Uint8List.fromList(_bytes);
}

final class RecoverySelection {
  const RecoverySelection(this.previous, this.document);
  final PreviousDocument previous;
  final AccountDocument document;
}
