import 'package:flutter/material.dart';

import '../capabilities/capability_contracts.dart';
import '../capabilities/capability_probe_view_model.dart';
import '../capabilities/isolated_probe_repository.dart';
import 'native_file_selection.dart';
import 'native_probe_directory.dart';
import 'offline_arabic_pdf.dart';
import 'probe_app.dart';

/// Opt-in technical harness: flutter run -t lib/platform/probe_main.dart.
/// The default lib/main.dart stays blank and never instantiates these adapters.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final result = await NativeProbeDirectory().resolve();
  if (result case CapabilitySuccess(:final value)) {
    final repository = IsolatedProbeRepository(value);
    if (await repository.initialise() is CapabilitySuccess<void>) {
      runApp(
        ProbeApp(
          viewModel: CapabilityProbeViewModel(
            files: NativeFileSelection(),
            pdf: OfflineArabicPdf(),
            repository: repository,
          ),
        ),
      );
      return;
    }
  }
  runApp(
    const Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        color: Color(0xfffaf8f1),
        child: Center(
          child: Text(
            'تعذّر فتح بيئة الاختبار المعزولة',
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 20,
              color: Color(0xff1b3127),
            ),
          ),
        ),
      ),
    ),
  );
}
