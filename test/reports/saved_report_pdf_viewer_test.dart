import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/reports/saved_report_pdf_viewer.dart';

class Raster implements PdfRasterCapability {
  final calls = <int>[];
  final pending = <Completer<CapabilityResult<Uint8List>>>[];
  @override
  Future<CapabilityResult<Uint8List>> rasterizePage(
    Uint8List bytes, {
    required int page,
    double dpi = 96,
  }) {
    calls.add(page);
    expect(bytes, Uint8List.fromList([37, 80, 68, 70, 45]));
    bytes[0] = 0;
    final result = Completer<CapabilityResult<Uint8List>>();
    pending.add(result);
    return result.future;
  }
}

void main() {
  testWidgets(
    'pending page rendering excludes repeated paging and preserves source bytes',
    (tester) async {
      final raster = Raster();
      final bytes = Uint8List.fromList([37, 80, 68, 70, 45]);
      await tester.pumpWidget(
        MaterialApp(
          home: SavedReportPdfViewer(
            title: 'Saved report',
            bytes: bytes,
            raster: raster,
          ),
        ),
      );
      expect(raster.calls, [0]);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('الصفحة التالية'));
        await tester.pump();
      }
      expect(raster.calls, [0]);
      expect(bytes[0], 37);
      raster.pending[0].complete(
        const CapabilityFailure('page_unavailable', 'Unavailable'),
      );
      await tester.pumpAndSettle();
      expect(find.text('لا توجد صفحة بهذا الرقم.'), findsOneWidget);
      await tester.tap(find.text('الصفحة التالية'));
      await tester.pump();
      expect(raster.calls, [0, 1]);
      await tester.pumpWidget(const SizedBox.shrink());
      raster.pending[1].complete(
        const CapabilityFailure('page_unavailable', 'Unavailable'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
