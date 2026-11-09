import 'package:flutter/foundation.dart';

import 'package:madar_icu_collation/madar_icu_collation.dart';

/// Local development runtime composition. The caller owns both explicit source
/// profiles; unsupported/missing native runtimes expose no comparator.
final class SourceCollationRuntime {
  SourceCollationRuntime._(this._adapter, this.events, this.materialNames);
  final IcuCollationAdapter _adapter;
  final CollationSession events, materialNames;
  bool _closed = false;

  /// Resolves Madar's verified native asset on its qualified ARM64 targets.
  /// A missing or unsupported asset exposes no comparator or host fallback.
  static SourceCollationRuntime? loadBundled() =>
      loadWithAdapter(IcuCollationAdapter.loadBundled);

  /// Explicit path is also usable by an isolated bundle smoke. No accounts,
  /// preferences, source fixtures or host-locale fallback enter this loader.
  static SourceCollationRuntime? loadLibrary(String library) =>
      loadWithAdapter(() => IcuCollationAdapter.load(library));

  @visibleForTesting
  static SourceCollationRuntime? loadWithAdapter(
    IcuCollationAdapter Function() load, {
    CollationSession Function(IcuCollationAdapter, CollationProfile)?
    openSession,
  }) {
    IcuCollationAdapter? adapter;
    try {
      adapter = load();
      final open =
          openSession ?? (adapter, profile) => adapter.openSession(profile);
      final events = open(adapter, CollationProfile.enUs);
      final materials = open(adapter, CollationProfile.ar);
      return SourceCollationRuntime._(adapter, events, materials);
    } on CollationException {
      adapter?.dispose();
      return null;
    } on StateError {
      // The native binding reports a refused profile open as StateError.
      // Dispose any previously opened profile before exposing no comparator.
      adapter?.dispose();
      return null;
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _adapter.dispose();
  }
}
