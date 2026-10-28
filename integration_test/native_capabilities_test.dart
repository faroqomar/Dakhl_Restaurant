import 'dart:io';
import 'dart:typed_data';

import 'package:dakhl_restaurant/capabilities/capability_contracts.dart';
import 'package:dakhl_restaurant/capabilities/isolated_probe_repository.dart';
import 'package:dakhl_restaurant/main.dart' as app;
import 'package:dakhl_restaurant/platform/native_probe_directory.dart';
import 'package:dakhl_restaurant/platform/offline_arabic_pdf.dart';
import 'package:dakhl_restaurant/platform/probe_run_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:printing/printing.dart';

/// Safe automatic native checks: no choosers, messaging, printing, or real data.
/// For a process restart proof run once with stage=write, terminate the app,
/// then run in a new process with stage=read. Both invocations require
/// --no-uninstall so the integration runner preserves the development data.
/// Neither a read stage nor a fresh repository instance alone proves restart.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const stage = String.fromEnvironment(
    'PHASE00_RESTART_STAGE',
    defaultValue: 'write',
  );

  const nonce = String.fromEnvironment('PHASE00_RUN_NONCE');

  testWidgets('native isolated storage and offline Arabic PDF [$stage]', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      expect(['write', 'read'], contains(stage));
      // Validate the REQUIRED identity before any native storage is accessed.
      final identity = ProbeRunIdentity(nonce);
      final resolved = await NativeProbeDirectory().resolve();
      expect(resolved, isA<CapabilitySuccess<Directory>>());
      final root = (resolved as CapabilitySuccess<Directory>).value;
      expect(
        root.path.split(Platform.pathSeparator).last,
        NativeProbeDirectory.leaf,
      );
      final repository = IsolatedProbeRepository(root);
      expect(await repository.initialise(), isA<CapabilitySuccess<void>>());
      if (stage == 'write') {
        expect(
          await repository.write(identity.probe),
          isA<CapabilitySuccess<void>>(),
        );
      }
      final result = await IsolatedProbeRepository(root).read();
      expect(
        result,
        isA<CapabilitySuccess<SyntheticProbe>>(),
        reason: result is CapabilityFailure<SyntheticProbe>
            ? 'Synthetic read failed: ${result.code}. ${result.message} '
                  'Both restart stages require --no-uninstall.'
            : 'Synthetic read must succeed before validating this run nonce.',
      );
      final reopened = (result as CapabilitySuccess<SyntheticProbe>).value;
      final validation = identity.validateRead(reopened);
      expect(
        validation,
        isA<CapabilitySuccess<void>>(),
        reason: validation is CapabilityFailure<void>
            ? '${validation.code}: ${validation.message}'
            : 'Saved synthetic data must contain this exact PHASE00_RUN_NONCE.',
      );
      expect(reopened.message, identity.probe.message);
      expect(reopened.sequence, identity.probe.sequence);

      final pdfResult = await OfflineArabicPdf().generate(reopened);
      expect(pdfResult, isA<CapabilitySuccess<Uint8List>>());
      final bytes = (pdfResult as CapabilitySuccess<Uint8List>).value;
      // Native PDF rasterization proves the generated document opens on this
      // target. Human inspection of the retained PNG is still needed for RTL.
      final rendered = await Printing.raster(bytes, pages: [0], dpi: 96).first;
      expect(rendered.width, greaterThan(0));
      expect(rendered.height, greaterThan(0));
      final evidence = await root.createTemp('pdf-evidence-');
      await File('${evidence.path}/synthetic.pdf')
          .writeAsBytes(bytes, flush: true);
      await File('${evidence.path}/synthetic-page-1.png')
          .writeAsBytes(await rendered.toPng(), flush: true);
      // Synthetic-only artifact path; no restaurant file names or contents.
      // ignore: avoid_print
      print(
        'PHASE00_SYNTHETIC_EVIDENCE=${evidence.path} stage=$stage nonce=$nonce',
      );
    });
  });
}
