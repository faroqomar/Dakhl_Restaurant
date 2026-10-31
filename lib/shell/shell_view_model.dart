import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';

import 'shell_preferences.dart';
import 'shell_routes.dart';

enum ShellBootstrapState { initializing, ready, protectedReadFailure }

enum ShellSaveState { idle, saving, saved, failed, conflict, commitUnknown }

enum ShellNavigationResult { changed, cancelled, gated, superseded }

/// App presentation coordination over Madar's deliberately opaque store.
///
/// The ViewModel never sees SQL, file paths, posting logic or account records.
/// Session drafts and undo callbacks are never serialized with preferences.
final class ShellViewModel extends ChangeNotifier {
  ShellViewModel({
    required this._store,
    this.accountShortcuts,
    this.saveAccountShortcuts,
  });

  final List<String>? Function()? accountShortcuts;
  final Future<bool> Function(List<String>)? saveAccountShortcuts;

  final LocalPreferencesStore _store;
  ShellBootstrapState _bootstrapState = ShellBootstrapState.initializing;
  ShellSaveState _saveState = ShellSaveState.idle;
  ShellPreferences _preferences = ShellPreferences.defaults();
  ShellPreferences? _acknowledged;
  ShellPreferences? _pending;
  String? _uncertainPayload;
  int? _revision;
  String? _failureCode;
  List<String>? _shortcutDraft;
  Map<String, String> _formDraft = const {};
  Map<String, String> _ticketPresentation = const {};
  final List<VoidCallback> _undo = [];
  Future<void> _saveTail = Future<void>.value();
  var _saveCount = 0;
  var _readGeneration = 0;
  var _intentGeneration = 0;
  var _navigationGeneration = 0;
  var _firstReadComplete = false;
  var _readInProgress = false;
  var _saveRecoveryInProgress = false;
  var _dirtyForm = false;
  var _writeBlocked = false;
  var _disposed = false;

  ShellBootstrapState get bootstrapState => _bootstrapState;
  ShellSaveState get saveState => _saveState;
  String? get failureCode => _failureCode;
  String get routeId => _preferences.routeId;
  List<String> get shortcuts => _preferences.shortcuts;
  List<String>? get shortcutDraft => _shortcutDraft == null
      ? null
      : List<String>.unmodifiable(_shortcutDraft!);
  Map<String, String> get formDraft => _formDraft;
  Map<String, String> get ticketPresentation => _ticketPresentation;
  bool get dirtyForm => _dirtyForm;
  int? get preferenceRevision => _revision;
  bool get busy =>
      !_firstReadComplete ||
      _readInProgress ||
      _saveRecoveryInProgress ||
      _saveCount > 0;
  bool get readInProgress => _readInProgress;
  bool get canNavigate => !_disposed && _firstReadComplete;
  bool get canEditShortcuts =>
      !_disposed &&
      _bootstrapState == ShellBootstrapState.ready &&
      !_writeBlocked &&
      !_readInProgress &&
      !_saveRecoveryInProgress &&
      _saveCount == 0;
  bool get hasUnsavedPreferences =>
      _pending != null ||
      (_acknowledged != null && _preferences != _acknowledged) ||
      (_shortcutDraft != null &&
          _preferences.copyWith(shortcuts: _shortcutDraft) != _preferences);

  Future<void> initialize() =>
      _firstReadComplete ? Future<void>.value() : _readPreferences();

  /// A read never persists defaults or normalization as an implicit migration.
  Future<void> retryRead() async {
    if (_disposed || _saveCount > 0 || _saveRecoveryInProgress) return;
    await _readPreferences();
  }

  Future<void> _readPreferences() async {
    if (_disposed) return;
    final generation = ++_readGeneration;
    final intent = _intentGeneration;
    _readInProgress = true;
    _notify();
    final result = await _safeRead();
    if (_disposed || generation != _readGeneration) return;
    _readInProgress = false;
    _firstReadComplete = true;
    if (result case CapabilitySuccess<PreferenceSnapshot?>(:final value)) {
      final decoded = _decodeSnapshot(value);
      if (decoded == null) {
        _protectRead(_failureCode ?? 'invalid_preferences');
        return;
      }
      final keepSessionRoute =
          _intentGeneration != intent || _intentGeneration > 0;
      _revision = value?.revision;
      _acknowledged = decoded;
      _preferences = decoded.copyWith(
        routeId: keepSessionRoute ? routeId : decoded.routeId,
      );
      _bootstrapState = ShellBootstrapState.ready;
      _writeBlocked = false;
      _pending = null;
      _uncertainPayload = null;
      _saveState = ShellSaveState.idle;
      _failureCode = null;
      _notify();
      return;
    }
    _protectRead(_resultCode(result));
  }

  Future<CapabilityResult<PreferenceSnapshot?>> _safeRead() async {
    try {
      return await _store.read(ShellPreferences.namespace);
    } on Object {
      return const CapabilityFailure(
        PreferenceErrorCodes.unavailable,
        'Preference storage could not be read.',
      );
    }
  }

  ShellPreferences? _decodeSnapshot(PreferenceSnapshot? snapshot) {
    if (snapshot == null) {
      return ShellPreferences.defaults().copyWith(
        shortcuts: accountShortcuts?.call(),
      );
    }
    if (snapshot.revision <= 0) {
      _failureCode = PreferenceErrorCodes.invalidRevision;
      return null;
    }
    try {
      return ShellPreferences.decode(snapshot.payload)
          .copyWith(shortcuts: accountShortcuts?.call());
    } on ShellPreferencesFormatException catch (error) {
      _failureCode = error.code;
      return null;
    }
  }

  void _protectRead(String code) {
    _bootstrapState = ShellBootstrapState.protectedReadFailure;
    _failureCode = code;
    _writeBlocked = true;
    _saveState = ShellSaveState.failed;
    _notify();
  }

  Future<ShellNavigationResult> navigate(
    String id, {
    Future<bool> Function()? confirmDiscard,
  }) async {
    if (!canNavigate) return ShellNavigationResult.gated;
    final destination = ShellRoutes.normalizeRoute(id);
    if (destination == routeId) {
      if (_bootstrapState == ShellBootstrapState.ready &&
          !_readInProgress &&
          _preferences != _acknowledged) {
        await _enqueueSave(_preferences);
      }
      return ShellNavigationResult.changed;
    }
    final generation = ++_navigationGeneration;
    if (_dirtyForm || _shortcutDraft != null) {
      var discard = false;
      if (confirmDiscard != null) {
        try {
          discard = await confirmDiscard();
        } on Object {
          // A disposed/failed prompt cannot authorize discarding session edits.
          discard = false;
        }
      }
      if (_disposed) return ShellNavigationResult.gated;
      if (generation != _navigationGeneration) {
        return ShellNavigationResult.superseded;
      }
      if (!discard) return ShellNavigationResult.cancelled;
      _formDraft = const {};
      _dirtyForm = false;
      _shortcutDraft = null;
    }
    _intentGeneration++;
    _preferences = _preferences.copyWith(routeId: destination);
    _notify();
    if (_bootstrapState == ShellBootstrapState.ready) {
      await _enqueueSave(_preferences);
    }
    return ShellNavigationResult.changed;
  }

  bool beginShortcutEditing() {
    if (!canEditShortcuts) return false;
    _shortcutDraft = List<String>.of(shortcuts);
    _notify();
    return true;
  }

  void setShortcut(int slot, String destination) {
    if (!canEditShortcuts || _shortcutDraft == null || slot < 0 || slot >= 6) {
      return;
    }
    _shortcutDraft![slot] = ShellRoutes.normalizeShortcut(destination);
    _notify();
  }

  Future<void> saveShortcuts() async {
    if (!canEditShortcuts || _shortcutDraft == null) return;
    final draft = List<String>.of(_shortcutDraft!);
    final persistAccount = saveAccountShortcuts;
    if (persistAccount != null) {
      _saveCount++;
      _notify();
      var saved = false;
      try {
        saved = await persistAccount(draft);
      } finally {
        _saveCount--;
      }
      if (_disposed) return;
      if (!saved) {
        _saveState = ShellSaveState.failed;
        _failureCode = 'account_preferences_failed';
        _notify();
        return;
      }
      // The account is authoritative even when this subsequent device cache
      // write fails. Device last-route durability remains a separate outcome.
      _preferences = _preferences.copyWith(shortcuts: draft);
    }
    await _enqueueSave(_preferences.copyWith(shortcuts: draft));
  }

  void cancelShortcutEditing() {
    if (_disposed || _saveCount > 0 || _saveRecoveryInProgress) return;
    _shortcutDraft = null;
    if (_pending != null) {
      _pending = _preferences;
      if (_pending == _acknowledged &&
          _uncertainPayload == null &&
          _saveState != ShellSaveState.conflict) {
        _pending = null;
        _writeBlocked = false;
        _saveState = ShellSaveState.idle;
        _failureCode = null;
      }
    }
    _notify();
  }

  Future<void> _enqueueSave(ShellPreferences desired) {
    if (_disposed || _bootstrapState != ShellBootstrapState.ready) {
      return Future<void>.value();
    }
    _pending = desired;
    if (_readInProgress) {
      // Session intent may change during a retry, but a read result must first
      // establish a safe revision. Completion itself never flushes this intent.
      _notify();
      return Future<void>.value();
    }
    _saveCount++;
    if (!_writeBlocked) {
      _saveState = ShellSaveState.saving;
      _failureCode = null;
    }
    _notify();
    final operation = _saveTail.then((_) async {
      if (_disposed || _writeBlocked) return;
      await _write(desired);
    });
    _saveTail = operation.whenComplete(() {
      _saveCount--;
      if (!_disposed) {
        if (_saveCount > 0 && !_writeBlocked) {
          _saveState = ShellSaveState.saving;
        }
        _notify();
      }
    });
    return _saveTail;
  }

  Future<void> _write(ShellPreferences desired) async {
    CapabilityResult<PreferenceSnapshot> result;
    final payload = desired.encode();
    try {
      result = await _store.replace(
        ShellPreferences.namespace,
        payload,
        expectedRevision: _revision,
      );
    } on Object {
      // An unexpected exception after invoking a store may follow commit.
      result = const CapabilityFailure(
        PreferenceErrorCodes.commitUnknown,
        'Preference commit acknowledgement is unavailable.',
      );
    }
    if (_disposed) return;
    if (result case CapabilitySuccess<PreferenceSnapshot>(:final value)) {
      if (value.payload != payload || value.revision <= (_revision ?? 0)) {
        _uncertainPayload = payload;
        _blockSave(PreferenceErrorCodes.commitUnknown);
        return;
      }
      _acknowledge(desired, value.revision);
      return;
    }
    final code = _resultCode(result);
    if (code == PreferenceErrorCodes.commitUnknown) {
      _uncertainPayload = payload;
    }
    _blockSave(code);
    if (code == PreferenceErrorCodes.conflict) {
      await _rereadConflict();
    }
  }

  void _acknowledge(ShellPreferences saved, int revision) {
    _revision = revision;
    _acknowledged = saved;
    _preferences = _preferences.copyWith(
      shortcuts: accountShortcuts?.call() ?? saved.shortcuts,
    );
    if (_shortcutDraft != null &&
        saved.copyWith(routeId: routeId) ==
            _preferences.copyWith(shortcuts: _shortcutDraft)) {
      _shortcutDraft = null;
    }
    if (_pending == saved) _pending = null;
    _uncertainPayload = null;
    _failureCode = null;
    _saveState = _pending == null
        ? ShellSaveState.saved
        : ShellSaveState.saving;
  }

  void _blockSave(String code) {
    _failureCode = code;
    _writeBlocked = true;
    _saveState = switch (code) {
      PreferenceErrorCodes.conflict => ShellSaveState.conflict,
      PreferenceErrorCodes.commitUnknown => ShellSaveState.commitUnknown,
      _ => ShellSaveState.failed,
    };
  }

  Future<void> _rereadConflict() async {
    final result = await _safeRead();
    if (_disposed) return;
    if (result case CapabilitySuccess<PreferenceSnapshot?>(:final value)) {
      final decoded = _decodeSnapshot(value);
      if (decoded == null) {
        _protectRead(_failureCode ?? 'invalid_preferences');
      } else {
        _acknowledged = decoded;
        _revision = value?.revision;
      }
    } else {
      _protectRead(_resultCode(result));
    }
  }

  Future<void> retrySave() async {
    final retryAccountShortcuts =
        _failureCode == 'account_preferences_failed' && _shortcutDraft != null;
    if (_disposed ||
        _saveRecoveryInProgress ||
        _readInProgress ||
        _saveCount > 0 ||
        _bootstrapState != ShellBootstrapState.ready ||
        (_pending == null && !retryAccountShortcuts)) {
      return;
    }
    if (retryAccountShortcuts) {
      await saveShortcuts();
      return;
    }
    // Set the guard before notifying or awaiting: repeated UI commands and
    // reentrant listeners must not start a second read against mutable intent.
    _saveRecoveryInProgress = true;
    int? recoveryReadGeneration;
    try {
      if (_saveState == ShellSaveState.conflict) {
        _readInProgress = true;
        recoveryReadGeneration = ++_readGeneration;
        _notify();
        // A conflict is presented/reloaded, never automatically overwritten.
        await _rereadConflict();
        return;
      }
      final uncertainPayload = _uncertainPayload;
      if (uncertainPayload != null) {
        _readInProgress = true;
        recoveryReadGeneration = ++_readGeneration;
        _notify();
        final result = await _safeRead();
        if (_disposed || recoveryReadGeneration != _readGeneration) return;
        _readInProgress = false;
        if (result is! CapabilitySuccess<PreferenceSnapshot?>) {
          _protectRead(_resultCode(result));
          return;
        }
        final snapshot = result.value;
        final decoded = _decodeSnapshot(snapshot);
        if (decoded == null) {
          _protectRead(_failureCode ?? 'invalid_preferences');
          return;
        }
        if (snapshot?.payload == uncertainPayload) {
          // Read the latest desired intent after recovery, not the intent at
          // its start. Session navigation can legitimately change meanwhile.
          final desired = _pending;
          _writeBlocked = false;
          _acknowledge(decoded, snapshot!.revision);
          if (desired != null && desired != decoded) {
            await _enqueueSave(desired);
          } else {
            _pending = null;
            _saveState = hasUnsavedPreferences
                ? ShellSaveState.idle
                : ShellSaveState.saved;
          }
          return;
        }
        if (decoded != _acknowledged || snapshot?.revision != _revision) {
          _acknowledged = decoded;
          _revision = snapshot?.revision;
          _uncertainPayload = null;
          _blockSave(PreferenceErrorCodes.conflict);
          return;
        }
        _uncertainPayload = null;
      }
      final desired = _pending;
      if (desired != null) {
        _writeBlocked = false;
        await _enqueueSave(desired);
      }
    } finally {
      _saveRecoveryInProgress = false;
      if (recoveryReadGeneration == _readGeneration) {
        _readInProgress = false;
      }
      _notify();
    }
  }

  Future<void> refreshAccountSettings({bool cache = true}) async {
    if (_disposed) return;
    final slots = accountShortcuts?.call();
    if (slots == null) return;
    _preferences = _preferences.copyWith(shortcuts: slots);
    _acknowledged = _acknowledged?.copyWith(shortcuts: slots);
    _shortcutDraft = null;
    _notify();
    if (cache &&
        _bootstrapState == ShellBootstrapState.ready &&
        !_writeBlocked) {
      await _enqueueSave(_preferences);
    }
  }

  void restoreAccountWorkspace({
    required Map<String, String> form,
    required Map<String, String> ticket,
  }) {
    if (_disposed) return;
    _formDraft = Map.unmodifiable(form);
    _ticketPresentation = Map.unmodifiable(ticket);
    _dirtyForm = form.isNotEmpty;
    _undo.clear();
    _notify();
  }

  void setFormDraft(Map<String, String> values) {
    if (_disposed || !canNavigate) return;
    _formDraft = Map<String, String>.unmodifiable(values);
    _dirtyForm = true;
    _notify();
  }

  void markFormDirty(bool dirty) {
    if (_disposed || !canNavigate) return;
    _dirtyForm = dirty;
    _notify();
  }

  void discardForm() {
    if (_disposed) return;
    _formDraft = const {};
    _dirtyForm = false;
    _notify();
  }

  void setTicketPresentation(Map<String, String> values) {
    if (_disposed || !canNavigate) return;
    _ticketPresentation = Map<String, String>.unmodifiable(values);
    _notify();
  }

  void registerSessionUndo(VoidCallback undo) {
    if (_disposed || !canNavigate) return;
    _undo.add(undo);
    _notify();
  }

  bool dispatchUndo({bool textEditing = false}) {
    if (_disposed || !canNavigate || textEditing || _undo.isEmpty) return false;
    _undo.removeLast()();
    _notify();
    return true;
  }

  static String _resultCode<T>(CapabilityResult<T> result) => switch (result) {
    CapabilityFailure<T>(:final code) => code,
    _ => PreferenceErrorCodes.unavailable,
  };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _readGeneration++;
    _navigationGeneration++;
    _undo.clear();
    super.dispose();
  }
}
