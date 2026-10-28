import 'dart:io';
import 'dart:typed_data';

import 'package:dakhl_restaurant/capabilities/capability_probe_view_model.dart';
import 'package:dakhl_restaurant/capabilities/isolated_probe_repository.dart';
import 'package:dakhl_restaurant/platform/native_file_selection.dart';
import 'package:dakhl_restaurant/platform/offline_arabic_pdf.dart';
import 'package:dakhl_restaurant/platform/probe_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'development controls are Arabic RTL, labelled, scrollable at large text; cancel announced',
    (tester) async {
      final temp = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('probe-widget-'),
      ))!;
      addTearDown(() => temp.delete(recursive: true));
      final vm = CapabilityProbeViewModel(
        files: NativeFileSelection(pick: () async => null),
        pdf: OfflineArabicPdf(),
        repository: IsolatedProbeRepository(
          Directory('${temp.path}/dakhl_restaurant_phase00_devprobe'),
        ),
      );
      addTearDown(vm.dispose);
      await tester.binding.setSurfaceSize(const Size(360, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProbeApp(viewModel: vm, textScaler: const TextScaler.linear(2)),
      );
      expect(find.text('اختبار تقني — بيانات تجريبية فقط'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.rtl,
      );
      await tester.scrollUntilVisible(find.text('فتح ملف تجريبي'), 200);
      await tester.tap(find.text('فتح ملف تجريبي'));
      await tester.pumpAndSettle();
      expect(find.text('أُلغي الاختيار'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('فتح نافذة الطباعة'), 200);
      expect(find.text('فتح نافذة الطباعة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('native handoffs are disabled until a PDF is generated', (
    tester,
  ) async {
    final temp = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('probe-widget-'),
    ))!;
    addTearDown(() => temp.delete(recursive: true));
    final vm = CapabilityProbeViewModel(
      files: NativeFileSelection(pick: () async => Uint8List(0)),
      pdf: OfflineArabicPdf(),
      repository: IsolatedProbeRepository(
        Directory('${temp.path}/dakhl_restaurant_phase00_devprobe'),
      ),
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(ProbeApp(viewModel: vm));
    for (final key in ['share-pdf', 'print-pdf']) {
      expect(
        tester.widget<FilledButton>(find.byKey(ValueKey(key))).onPressed,
        isNull,
      );
    }
  });
}
