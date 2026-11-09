import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:madar_flutter_adapters/madar_flutter_adapters.dart';

import 'package:dakhl_restaurant/app/accounts_store.dart';
import 'package:dakhl_restaurant/app/bootstrap.dart';
import 'package:dakhl_restaurant/app/portable_restaurant_host.dart';
import 'package:dakhl_restaurant/app/source_collation_runtime.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_accounts_surface.dart';
import 'package:dakhl_restaurant/reports/restaurant_report_pdf.dart';
import 'package:dakhl_restaurant/shell/shell_view_model.dart';
import 'package:dakhl_restaurant/shell/shell_routes.dart';

import '../test/sales/sales_workflow_session_test.dart' show fixture, fresh;
import 'support/native_app_readiness.dart';

/// Retained acceptance: synthetic fixture bytes enter a fresh native store.
/// Never invokes normal main or resolves the restaurant's storage directory.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native complete-envelope sale, all routes, PDF and recovery', (
    tester,
  ) async {
    final root = await Directory.systemTemp.createTemp('dakhl-review-native-');
    final store = AppAccountsStore(
      openStore: () async {
        final directory = await Directory('${root.path}/accounts').create();
        return PowerSyncLocalDocumentWorkspaceStore.open(
          directoryPath: directory.path,
        );
      },
    );
    final preferences = AppPreferencesStore(
      openStore: () => PowerSyncLocalPreferencesStore.open(
        databasePath: '${root.path}/shell.sqlite',
      ),
      closeStore: (owner) async {
        if (owner is PowerSyncLocalPreferencesStore) await owner.close();
      },
    );
    SourceCollationRuntime? runtime;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      runtime?.close();
      try {
        await preferences.close();
      } finally {
        try {
          await store.close();
        } finally {
          await root.delete(recursive: true);
        }
      }
    });
    final (_, source) = await fixture();
    final created = await store.writeDocument(
      source.payload,
      writeToken: 'native-fixture',
    );
    expect(
      created,
      isA<CapabilitySuccess<DocumentSnapshot>>(),
      reason: created is CapabilityFailure<DocumentSnapshot>
          ? created.code
          : 'Fixture creation was not acknowledged.',
    );
    final initial = (created as CapabilitySuccess<DocumentSnapshot>).value;
    runtime = SourceCollationRuntime.loadBundled();
    expect(
      runtime,
      isNotNull,
      reason: 'The qualified ARM64 target must load its bundled ICU runtime.',
    );
    expect(runtime!.events.compare('é', 'e\u0301'), 0);
    expect(runtime.materialNames.compare('رز', 'رز'), 0);
    final host = GlobalKey<PortableRestaurantHostState>();
    ShellViewModel? shell;
    var ticket = 0;

    await waitForNativeAppReadiness(
      frames: LiveNativeAppReadinessFrames(binding),
      mount: () => mountNativeAppRoot(
        PortableRestaurantHost(
          key: host,
          store: store,
          initialSnapshot: initial,
          compareText: runtime?.events.compare ?? (a, b) => a.compareTo(b),
          compareMaterialNames: runtime?.materialNames.compare,
          freshTicket: () => fresh('native-${ticket++}'),
          preferencesStore: preferences,
          onShellReady: (value) => shell = value,
        ),
      ),
      ready: () => shell != null && host.currentState?.session != null,
    );
    expect(shell, isNotNull);
    final session = host.currentState!.session!;
    expect(await session.sales.addProduct('p'), isA<CapabilitySuccess<void>>());
    final saleId = session.sales.active!.id;
    expect(
      await session.sales.checkout(
        fresh: fresh('native-after-sale'),
        operationId: 'native-sale',
        journalId: 'native-sale-journal',
        recordedAt: '2026-11-07T12:00:00Z',
      ),
      isA<CapabilitySuccess>(),
    );
    await session.synchronize();
    for (final route in ShellRoutes.destinations.map((d) => d.id)) {
      await shell!.navigate(route);
      await tester.pumpAndSettle();
      expect(shell!.routeId, route);
      expect(tester.takeException(), isNull, reason: route);
    }
    final report = session.reports.composer.sale(saleId);
    final generated = await RestaurantReportPdf().generate(report);
    expect(generated, isA<CapabilitySuccess>());
    final bytes = (generated as CapabilitySuccess).value;
    final raster = await NativePdfRaster().rasterizePage(
      bytes,
      page: 0,
      dpi: 72,
    );
    expect(raster, isA<CapabilitySuccess>());
    final png = (raster as CapabilitySuccess).value as List<int>;
    expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(png.length, greaterThan(100));
    await shell!.navigate('settings');
    await tester.pumpAndSettle();
    await tester.tap(find.text('النسخ والبيانات'));
    await tester.pumpAndSettle();
    final transfer = host.currentState!.transferController!;
    final exported = transfer.exportBytes();
    final decoded = const PortableJournalCodec().decodeBytes(exported);
    expect(decoded.account.toJson()['sales'], hasLength(1));
    expect(
      decoded.receipts.any((r) => r.identity.operationId == 'native-sale'),
      true,
    );
    expect(transfer.prepareImport(exported), isA<CapabilitySuccess>());
    final beforeFence = transfer.snapshot.fence;
    final beforeGeneration = host.currentState!.generation;
    expect(await transfer.confirmImport(), isA<CapabilitySuccess<void>>());
    expect(transfer.snapshot.fence, isNot(beforeFence));
    tester
        .widget<PortableAccountsSurface>(find.byType(PortableAccountsSurface))
        .onImportApplied
        ?.call(transfer.snapshot);
    await waitForNativeAppReadiness(
      frames: LiveNativeAppReadinessFrames(binding),
      mount: binding.scheduleFrame,
      ready: () =>
          host.currentState?.session != null && !host.currentState!.isOpening,
    );
    expect(host.currentState!.generation, beforeGeneration + 1);
    expect(host.currentState!.session!.snapshot.fence, transfer.snapshot.fence);
    final reread = await store.readDocument();
    expect(
      (reread as CapabilitySuccess<DocumentSnapshot?>).value!.payload,
      const PortableJournalCodec().encodeState(decoded),
    );
    binding.reportData = {
      ...?binding.reportData,
      'native_review': 'passed',
      'routes': 12,
      'pdfRaster': true,
      'completeEnvelope': true,
      'icuBundled': true,
    };
    debugPrint(
      '{"native_review":"passed","routes":12,"pdfRaster":true,"completeEnvelope":true,"icuBundled":true}',
    );
  });
}
