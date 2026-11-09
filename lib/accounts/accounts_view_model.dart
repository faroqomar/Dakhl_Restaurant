import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';

import 'account_document.dart';
import 'accounts_repository.dart';
import 'legacy_account_codec.dart';
import 'workspace_document.dart';

enum AccountsState {
  loading,
  absent,
  saved,
  saving,
  failed,
  protected,
  importReady,
  recoveryReady,
  commitUnknown,
  conflict,
}

enum ImportPickOutcome { selected, cancelled, failed, superseded }

/// Account presentation decisions only. The repository owns validated app data;
/// Madar owns storage, CAS, recovery and durable generation semantics.
final class AccountsViewModel extends ChangeNotifier {
  AccountsViewModel({required this.repository});
  final AccountsRepository repository;
  Future<bool> Function()? confirmAuthorityReload;
  AccountsState _state = AccountsState.loading;
  AccountsState _settled = AccountsState.loading;
  String? _failureCode;
  PendingAccountImport? _pendingImport;
  RecoverySelection? _recovery;
  WorkspaceDocument _workspace = WorkspaceDocument.empty();
  bool _busy = false, _disposed = false;
  StorageFence? _failedWorkspaceFence;
  List<String>? _deviceFallback;
  String? _authorityConflictCode;
  bool _reloadConfirming = false;
  Future<void> Function()? _retryReadOnly;
  int _operation = 0;
  AccountsState get state => _state;
  bool get busy => _busy || _reloadConfirming;
  bool get needsAuthorityReload => _authorityConflictCode != null;
  bool get needsWriteReadback => repository.hasUnknownWrite;
  bool get hasReadOnlyRetry => _retryReadOnly != null;
  String? get failureCode => _failureCode;
  AccountDocument? get document => repository.document;
  StorageFence? get fence => repository.snapshot?.fence;
  PendingAccountImport? get pendingImport => _pendingImport;
  RecoverySelection? get recoverySelection => _recovery;
  WorkspaceDocument get workspace => _workspace;
  List<String>? get accountShortcuts => document?.preferences.shortcuts;
  bool get canMutate =>
      !_disposed &&
      !_busy &&
      !_reloadConfirming &&
      _authorityConflictCode == null &&
      !repository.hasUnknownWrite &&
      _state != AccountsState.commitUnknown &&
      _state != AccountsState.conflict &&
      _settled != AccountsState.loading &&
      _settled != AccountsState.protected;
  bool get canImport =>
      canMutate ||
      (!_disposed &&
          !_busy &&
          !repository.hasUnknownWrite &&
          repository.initialCreationBlocked);
  bool get canSelectRecovery =>
      !_disposed && !_busy && !repository.hasUnknownWrite;

  Future<void> initialize() async {
    if (_disposed || _busy) return;
    _retryReadOnly = null;
    final retainedWorkspace = _failedWorkspaceFence == fence
        ? _workspace
        : null;
    final retainedFence = fence;
    final operation = ++_operation;
    _busy = true;
    _state = AccountsState.loading;
    _notify();
    final result = await repository.open();
    if (!_current(operation)) return;
    if (repository.hasUnknownWrite) {
      _state = AccountsState.commitUnknown;
      _failureCode = result is CapabilityFailure<AccountDocument?>
          ? result.code
          : 'commit_unknown';
      _busy = false;
      _notify();
      return;
    }
    if (result is CapabilitySuccess<AccountDocument?>) {
      if (result.value != null) {
        final workspace = await repository.readWorkspace();
        if (!_current(operation)) return;
        if (workspace is! CapabilitySuccess<WorkspaceDocument>) {
          _finishFailure(workspace, protected: true);
          return;
        }
        if (retainedWorkspace != null && fence == retainedFence) {
          _workspace = retainedWorkspace;
        } else {
          _workspace = workspace.value;
          _failedWorkspaceFence = null;
        }
      }
      _state = result.value == null
          ? AccountsState.absent
          : AccountsState.saved;
      _settled = _state;
      _authorityConflictCode = null;
      if (_failedWorkspaceFence != null) {
        _state = AccountsState.failed;
        _failureCode = 'workspace_unsaved';
      } else {
        _failureCode = null;
        if (_pendingImport != null) _state = AccountsState.importReady;
      }
    } else {
      _state = AccountsState.protected;
      _settled = _state;
      _failureCode = _code(result);
    }
    _busy = false;
    _notify();
  }

  void prepareImport(List<int> bytes) {
    if (!canImport) return;
    _retryReadOnly = null;
    try {
      final pending = repository.prepare(bytes);
      _pendingImport = pending;
      _recovery = null;
      _failureCode = null;
      _state = AccountsState.importReady;
    } on AccountCodecException catch (error) {
      // Invalid selected bytes require another selection, never an account save.
      _retryReadOnly = () async {};
      _failureCode = error.code;
      _state = AccountsState.failed;
    }
    _notify();
  }

  void reportFileFailure(String code, {Future<void> Function()? retry}) {
    if (_disposed || _busy) return;
    _failureCode = code;
    _retryReadOnly = retry ?? () async {};
    _state = AccountsState.failed;
    _notify();
  }

  void cancelImport() {
    if (_disposed || _busy || repository.hasUnknownWrite) return;
    _pendingImport = null;
    _recovery = null;
    _retryReadOnly = null;
    if (_authorityConflictCode != null) {
      _state = AccountsState.conflict;
      _failureCode = _authorityConflictCode;
    } else if (_failedWorkspaceFence != null &&
        _failedWorkspaceFence == fence) {
      _state = AccountsState.failed;
      _failureCode = 'workspace_unsaved';
    } else {
      _state = _settled;
      if (_settled != AccountsState.protected) _failureCode = null;
    }
    _notify();
  }

  void seedDeviceFallback(List<String> slots) {
    if (_disposed || document != null || _settled != AccountsState.absent) {
      return;
    }
    _deviceFallback = List.unmodifiable(slots);
  }

  Future<void> save() async {
    if (!canMutate || _pendingImport != null || _recovery != null) return;
    var value = document ?? repository.codec.empty();
    if (document == null && _deviceFallback != null) {
      value = repository.withShortcuts(value, _deviceFallback!);
    }
    await _write(() => repository.save(value));
  }

  Future<void> confirmImport() async {
    final selected = _pendingImport;
    if (!canImport || selected == null) return;
    await _write(
      () => repository.save(selected.document, source: selected, replace: true),
    );
  }

  Future<bool> saveShortcuts(List<String> shortcuts) async {
    if (!canMutate || _pendingImport != null || _recovery != null) return false;
    return _write(() => repository.saveShortcuts(shortcuts));
  }

  Future<void> selectPrevious() async {
    if (!canSelectRecovery) return;
    _retryReadOnly = null;
    final operation = ++_operation;
    _busy = true;
    _notify();
    final result = await repository.previous();
    if (!_current(operation)) return;
    _busy = false;
    if (result is CapabilitySuccess<RecoverySelection?> &&
        result.value != null) {
      _recovery = result.value;
      _pendingImport = null;
      _failureCode = null;
      _state = AccountsState.recoveryReady;
    } else {
      _retryReadOnly = selectPrevious;
      _state = AccountsState.failed;
      _failureCode = result is CapabilitySuccess<RecoverySelection?>
          ? 'no_previous_copy'
          : _code(result);
    }
    _notify();
  }

  Future<void> confirmRecovery() async {
    final selection = _recovery;
    if (!canSelectRecovery || selection == null) return;
    await _write(() => repository.recover(selection));
  }

  Future<void> reconcile() async {
    if (_disposed || _busy || !repository.hasUnknownWrite) return;
    await _write(
      repository.reconcile,
      acknowledgesWorkspace: repository.hasUnknownWorkspaceWrite,
    );
  }

  Future<bool> _write(
    Future<CapabilityResult<AccountDocument>> Function() action, {
    bool acknowledgesWorkspace = false,
  }) async {
    _retryReadOnly = null;
    final operation = ++_operation;
    final oldFence = fence;
    final retainedFailure = _failureCode;
    _busy = true;
    _state = AccountsState.saving;
    _notify();
    CapabilityResult<AccountDocument> result;
    try {
      result = await action();
    } on Object {
      if (_current(operation)) {
        _finishFailure(
          const CapabilityFailure(
            'unavailable',
            'Account operation failed safely.',
          ),
          protected: true,
        );
      }
      return false;
    }
    if (!_current(operation)) return false;
    if (result is CapabilitySuccess<AccountDocument>) {
      if (fence != oldFence) {
        _workspace = WorkspaceDocument.empty();
        _failedWorkspaceFence = null;
      }
      if (acknowledgesWorkspace) _failedWorkspaceFence = null;
      _settled = AccountsState.saved;
      _authorityConflictCode = null;
      _state = _failedWorkspaceFence == fence && _failedWorkspaceFence != null
          ? AccountsState.failed
          : AccountsState.saved;
      _failureCode = _state == AccountsState.failed
          ? retainedFailure ?? 'workspace_unsaved'
          : null;
      _pendingImport = null;
      _recovery = null;
      _busy = false;
      _notify();
      return true;
    }
    _finishFailure(result);
    return false;
  }

  /// Caller captures the current authority when the edit originates. A callback
  /// from a retired/recovered account cannot be rebound to the new generation.
  Future<void> saveWorkspace(
    WorkspaceDocument workspace,
    StorageFence origin,
  ) async {
    if (!canMutate || fence != origin) return;
    _retryReadOnly = null;
    final operation = ++_operation;
    _workspace = workspace;
    _failedWorkspaceFence = origin;
    try {
      workspace.encode();
    } on FormatException {
      _busy = false;
      _state = AccountsState.failed;
      _failureCode = 'payload_too_large';
      _notify();
      return;
    }
    _busy = true;
    _state = AccountsState.saving;
    _notify();
    CapabilityResult<void> result;
    try {
      result = await repository.saveWorkspace(workspace, origin);
    } on Object {
      result = const CapabilityFailure(
        'unavailable',
        'Workspace operation is unavailable.',
      );
    }
    if (!_current(operation) || fence != origin) return;
    if (result is CapabilitySuccess<void>) {
      _failedWorkspaceFence = null;
      _busy = false;
      _state = AccountsState.saved;
      _failureCode = null;
      _notify();
    } else {
      _finishFailure(result);
    }
  }

  Future<void> retry() async {
    if (_disposed || _busy || _reloadConfirming) return;
    if (needsWriteReadback || _state == AccountsState.commitUnknown) {
      await reconcile();
      return;
    }
    if (_authorityConflictCode != null) {
      _reloadConfirming = true;
      _notify();
      try {
        final allowed = await confirmAuthorityReload?.call() ?? true;
        if (allowed && !_disposed) await initialize();
      } finally {
        _reloadConfirming = false;
        _notify();
      }
      return;
    }
    final readOnlyRetry = _retryReadOnly;
    if (readOnlyRetry != null) {
      await readOnlyRetry();
      return;
    }
    if (_failedWorkspaceFence != null && _failedWorkspaceFence == fence) {
      await saveWorkspace(_workspace, _failedWorkspaceFence!);
      return;
    }
    if (_settled == AccountsState.protected) {
      await initialize();
      return;
    }
    await save();
  }

  Future<ImportPickOutcome> pickImport(FileTransferCapability transfer) async {
    if (!canImport) return ImportPickOutcome.superseded;
    final operation = ++_operation;
    final origin = fence;
    final previous = _pendingImport;
    _busy = true;
    _notify();
    final CapabilityResult<Uint8List> result;
    try {
      result = await transfer.open();
    } on Object {
      if (_current(operation)) {
        _busy = false;
        reportFileFailure(
          'file_unreadable',
          retry: () async {
            await pickImport(transfer);
          },
        );
      }
      return ImportPickOutcome.failed;
    }
    if (!_current(operation) || fence != origin) {
      return ImportPickOutcome.superseded;
    }
    _busy = false;
    if (result is CapabilitySuccess<Uint8List>) {
      prepareImport(result.value);
      if (_state == AccountsState.failed) {
        _retryReadOnly = () async {
          await pickImport(transfer);
        };
      }
      return _state == AccountsState.importReady &&
              !identical(previous, _pendingImport)
          ? ImportPickOutcome.selected
          : ImportPickOutcome.failed;
    }
    if (result is CapabilityFailure<Uint8List>) {
      reportFileFailure(
        result.code,
        retry: () async {
          await pickImport(transfer);
        },
      );
      return ImportPickOutcome.failed;
    }
    _notify();
    return ImportPickOutcome.cancelled;
  }

  Future<void> exportTo(FileTransferCapability transfer) async {
    final bytes = exportBytes();
    if (_disposed || _busy || bytes == null) return;
    _retryReadOnly = null;
    final operation = ++_operation;
    _busy = true;
    _notify();
    final CapabilityResult<void> result;
    try {
      result = await transfer.save(bytes);
    } on Object {
      if (_current(operation)) {
        _busy = false;
        reportFileFailure('file_unavailable', retry: () => exportTo(transfer));
      }
      return;
    }
    if (!_current(operation)) return;
    _busy = false;
    if (result is CapabilityFailure<void>) {
      reportFileFailure(result.code, retry: () => exportTo(transfer));
    } else {
      if (_authorityConflictCode != null) {
        _state = AccountsState.conflict;
        _failureCode = _authorityConflictCode;
      } else if (_failedWorkspaceFence != null &&
          _failedWorkspaceFence == fence) {
        _state = AccountsState.failed;
        _failureCode = 'workspace_unsaved';
      } else if (_pendingImport != null) {
        _state = AccountsState.importReady;
        _failureCode = null;
      } else if (_recovery != null) {
        _state = AccountsState.recoveryReady;
        _failureCode = null;
      } else {
        _state = _settled;
        if (_settled != AccountsState.protected) _failureCode = null;
      }
      _notify();
    }
  }

  Uint8List? exportBytes() =>
      document == null ? null : repository.codec.encode(document!);

  void _finishFailure(
    CapabilityResult<dynamic> result, {
    bool protected = false,
  }) {
    _failureCode = _code(result);
    _state =
        repository.hasUnknownWrite ||
            _failureCode == 'commit_unknown' ||
            _failureCode == 'recovery_publication_unknown'
        ? AccountsState.commitUnknown
        : protected
        ? AccountsState.protected
        : AccountsState.failed;
    if ({
      'conflict',
      'stale_revision',
      'stale_generation',
    }.contains(_failureCode)) {
      _authorityConflictCode = _failureCode;
      _state = AccountsState.conflict;
    }
    if (protected) _settled = AccountsState.protected;
    _busy = false;
    _notify();
  }

  String _code(CapabilityResult<dynamic> result) =>
      result is CapabilityFailure<dynamic> ? result.code : 'unavailable';
  bool _current(int operation) => !_disposed && operation == _operation;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _operation++;
    super.dispose();
  }
}
