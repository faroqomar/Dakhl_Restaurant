import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';

import '../platform/shell_preferences_directory.dart';

/// App composition only: isolated location + reviewed engine adapter lifecycle.
/// No payload validation, persistence algorithm or SQL lives in this layer.
final class AppPreferencesStore implements LocalPreferencesStore {
  AppPreferencesStore({required this.openStore, this.closeStore});

  factory AppPreferencesStore.native() => AppPreferencesStore(
    openStore: () async {
      final location = await ShellPreferencesDirectory().databasePath();
      if (location case CapabilityFailure<String>(
        :final code,
        :final message,
      )) {
        return CapabilityFailure(code, message);
      }
      if (location case CapabilitySuccess<String>(:final value)) {
        return PowerSyncLocalPreferencesStore.open(
          databasePath: value,
          eventSink: (event) {
            if (kDebugMode) debugPrint(jsonEncode(event.toJson()));
          },
        );
      }
      return const CapabilityFailure(
        PreferenceErrorCodes.unavailable,
        'Isolated preferences are unavailable.',
      );
    },
    closeStore: (store) async {
      if (store is PowerSyncLocalPreferencesStore) await store.close();
    },
  );

  final Future<CapabilityResult<LocalPreferencesStore>> Function() openStore;
  final Future<void> Function(LocalPreferencesStore)? closeStore;
  Future<CapabilityResult<LocalPreferencesStore>>? _opening;
  Future<void>? _closing;
  bool _closed = false;

  Future<CapabilityResult<LocalPreferencesStore>> _acquire() async {
    if (_closed) return _closedResult();
    final opening = _opening ??= _openSafely();
    final result = await opening;
    if (result is! CapabilitySuccess<LocalPreferencesStore> &&
        identical(_opening, opening)) {
      _opening = null;
    }
    return _closed ? _closedResult() : result;
  }

  Future<CapabilityResult<LocalPreferencesStore>> _openSafely() async {
    try {
      return await openStore();
    } on Object {
      return const CapabilityFailure(
        PreferenceErrorCodes.unavailable,
        'Preferences could not be initialized.',
      );
    }
  }

  CapabilityFailure<T> _closedResult<T>() => const CapabilityFailure(
    PreferenceErrorCodes.closed,
    'Preferences have closed.',
  );

  CapabilityFailure<T> _failure<T>(
    CapabilityResult<LocalPreferencesStore> result,
  ) => result is CapabilityFailure<LocalPreferencesStore>
      ? CapabilityFailure(result.code, result.message)
      : const CapabilityFailure(
          PreferenceErrorCodes.unavailable,
          'Preferences are unavailable.',
        );

  @override
  Future<CapabilityResult<PreferenceSnapshot?>> read(String namespace) async {
    final result = await _acquire();
    return result is CapabilitySuccess<LocalPreferencesStore>
        ? result.value.read(namespace)
        : _failure(result);
  }

  @override
  Future<CapabilityResult<PreferenceSnapshot>> replace(
    String namespace,
    String payload, {
    int? expectedRevision,
  }) async {
    final result = await _acquire();
    return result is CapabilitySuccess<LocalPreferencesStore>
        ? result.value.replace(
            namespace,
            payload,
            expectedRevision: expectedRevision,
          )
        : _failure(result);
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    final opening = _opening;
    if (opening == null) return;
    final result = await opening;
    if (result is CapabilitySuccess<LocalPreferencesStore>) {
      await closeStore?.call(result.value);
    }
  }
}
