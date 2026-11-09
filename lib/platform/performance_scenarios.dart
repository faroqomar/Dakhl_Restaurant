import 'dart:io';

import 'package:madar_data/madar_data.dart';

import '../app/bootstrap.dart';
import '../shell/shell_view_model.dart';

const performanceCases = {
  'app.startup',
  'navigation.switch_route',
  'shortcuts.save',
};

final class PerformanceOptions {
  const PerformanceOptions(this.operationId, this.iterations, this.runId);
  final String operationId;
  final int iterations;
  final String runId;

  factory PerformanceOptions.parse(List<String> args) {
    final values = <String, String>{};
    for (var i = 0; i < args.length; i += 2) {
      if (i + 1 >= args.length ||
          !{'--case', '--iterations', '--run-id'}.contains(args[i]) ||
          values.containsKey(args[i])) {
        throw const FormatException('Invalid benchmark arguments.');
      }
      values[args[i]] = args[i + 1];
    }
    final operation = values['--case'] ?? 'app.startup';
    final iterations = int.tryParse(values['--iterations'] ?? '1') ?? 0;
    final identity = values['--run-id'] ?? 'local';
    if (!performanceCases.contains(operation) ||
        iterations < 1 ||
        iterations > 100 ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(identity)) {
      throw const FormatException(
        'Unsupported benchmark case, count or identity.',
      );
    }
    return PerformanceOptions(operation, iterations, identity);
  }
}

/// App-owned isolated composition over the reviewed Madar adapter. Only this
/// fresh directory is deleted; no normal application location is consulted.
final class PerformanceFixture {
  PerformanceFixture._(this.directory) {
    preferences = AppPreferencesStore(
      openStore: () =>
          PowerSyncLocalPreferencesStore.open(databasePath: databasePath),
      closeStore: (store) async {
        if (store is PowerSyncLocalPreferencesStore) await store.close();
      },
    );
  }
  final Directory directory;
  late final AppPreferencesStore preferences;
  String get databasePath => '${directory.path}/preferences.sqlite';

  static Future<PerformanceFixture> create(
    String runId, {
    Directory? parent,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(runId)) {
      throw const FormatException('Invalid benchmark run identity.');
    }
    final directory = await (parent ?? Directory.systemTemp).createTemp(
      'dakhl-bench-$runId-$pid-',
    );
    return PerformanceFixture._(directory);
  }

  Future<void> close() async {
    await preferences.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

List<String> performanceShortcuts(int iteration) => iteration.isEven
    ? ['inventory', 'settings', 'cash', 'expenses', 'materials', 'sales']
    : ['settings', 'cash', 'expenses', 'materials', 'sales', 'inventory'];

/// Measures real ViewModel commands, durable isolated storage and a subsequent
/// rendered frame. It does not claim pointer/keyboard input latency.
Future<void> runPerformanceIteration(
  ShellViewModel model,
  String operationId,
  int iteration, {
  required Future<void> Function() afterFrame,
}) async {
  if (model.bootstrapState != ShellBootstrapState.ready) {
    throw StateError('Bootstrap failed.');
  }
  switch (operationId) {
    case 'navigation.switch_route':
      final route = iteration.isEven ? 'inventory' : 'sales';
      final result = await model.navigate(route);
      if (result != ShellNavigationResult.changed ||
          model.routeId != route ||
          model.hasUnsavedPreferences) {
        throw StateError('Route change was not persisted.');
      }
    case 'shortcuts.save':
      if (!model.beginShortcutEditing()) {
        throw StateError('Shortcut editing unavailable.');
      }
      final slots = performanceShortcuts(iteration);
      for (var slot = 0; slot < 6; slot++) {
        model.setShortcut(slot, slots[slot]);
      }
      await model.saveShortcuts();
      if (model.shortcutDraft != null ||
          model.hasUnsavedPreferences ||
          model.shortcuts.join('|') != slots.join('|')) {
        throw StateError('Six-slot save was not acknowledged.');
      }
    default:
      throw ArgumentError.value(operationId, 'operationId');
  }
  await afterFrame();
}
