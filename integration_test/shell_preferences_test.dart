import 'dart:convert';
import 'dart:io';

import 'package:dakhl_restaurant/app/app.dart';
import 'package:dakhl_restaurant/app/bootstrap.dart';
import 'package:dakhl_restaurant/shell/shell_preferences.dart';
import 'package:dakhl_restaurant/shell/shell_view_model.dart';
import 'package:dakhl_restaurant/ui/dakhl_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:madar_application/madar_application.dart';

/// Explicit synthetic development data; host must stop/relaunch between stages.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const stage = String.fromEnvironment('PHASE01_RESTART_STAGE');
  const nonce = String.fromEnvironment('PHASE01_RUN_NONCE');
  const markerNamespace = 'dakhl_restaurant.phase01.conformance';
  const slots = ['settings', '', 'sales', 'cash', 'sales', 'materials'];

  testWidgets('real engine shell preferences $stage in fresh native process', (
    tester,
  ) async {
    expect(
      ['write', 'read'],
      contains(stage),
      reason: 'Use the documented bounded host write/stop/read flow.',
    );
    expect(
      RegExp(r'^[a-f0-9-]{36}$').hasMatch(nonce),
      isTrue,
      reason: 'A fresh host UUID prevents stale acceptance.',
    );
    final store = AppPreferencesStore.native();
    addTearDown(store.close);
    final model = ShellViewModel(store: store);
    addTearDown(model.dispose);
    await model.initialize();
    expect(model.bootstrapState, ShellBootstrapState.ready);

    if (stage == 'write') {
      await model.navigate('inventory');
      expect(model.beginShortcutEditing(), isTrue);
      for (var i = 0; i < slots.length; i++) {
        model.setShortcut(i, slots[i]);
      }
      await model.saveShortcuts();
      expect(model.saveState, ShellSaveState.saved);
      final old = await store.read(markerNamespace);
      expect(old, isA<CapabilitySuccess<PreferenceSnapshot?>>());
      final revision =
          (old as CapabilitySuccess<PreferenceSnapshot?>).value?.revision;
      final result = await store.replace(
        markerNamespace,
        jsonEncode({
          'runNonce': nonce,
          'writerPid': pid,
          'shellRevision': model.preferenceRevision,
        }),
        expectedRevision: revision,
      );
      expect(result, isA<CapabilitySuccess<PreferenceSnapshot>>());
    } else {
      final result = await store.read(markerNamespace);
      expect(result, isA<CapabilitySuccess<PreferenceSnapshot?>>());
      final snapshot = (result as CapabilitySuccess<PreferenceSnapshot?>).value;
      expect(snapshot, isNotNull);
      final receipt = jsonDecode(snapshot!.payload) as Map<String, dynamic>;
      expect(
        receipt['runNonce'],
        nonce,
        reason: 'Reject stale write evidence.',
      );
      expect(
        receipt['writerPid'],
        isNot(pid),
        reason: 'Read must execute in a new process.',
      );
      expect(model.preferenceRevision, receipt['shellRevision']);
    }
    expect(model.routeId, 'inventory');
    expect(model.shortcuts, slots);
    final payload = await store.read(
      ShellPreferences.namespace,
    ) as CapabilitySuccess<PreferenceSnapshot?>;
    expect(
      jsonDecode(payload.value!.payload).keys,
      unorderedEquals(['schemaVersion', 'lastRouteId', 'shortcuts']),
    );
    await tester.pumpWidget(DakhlRestaurantApp(preferencesStore: store));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Phase01RouteSurface>(find.byType(Phase01RouteSurface))
          .routeId,
      'inventory',
    );
    expect(
      tester.widget<DakhlShellView>(find.byType(DakhlShellView)).shortcuts,
      slots,
    );
    binding.reportData = {
      'stage': stage,
      'runNonce': nonce,
      'pid': pid,
      'shellRevision': model.preferenceRevision,
      'route': 'inventory',
      'slots': slots,
      'runtime': 'real native engine adapter; development UI preferences only',
    };
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
