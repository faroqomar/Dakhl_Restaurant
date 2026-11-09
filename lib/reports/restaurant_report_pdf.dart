import 'package:flutter/services.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_flutter_adapters/madar_flutter_adapters.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'restaurant_report.dart';

typedef ReportFontLoader = Future<ByteData> Function();

/// Offline consumer composition with the bundled licensed Arabic font. Native
/// transfer/printing stays in Madar and has no account/posting dependency.
final class RestaurantReportPdf {
  RestaurantReportPdf({ReportFontLoader? loadFont})
    : _loadFont =
          loadFont ?? (() => rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
  final ReportFontLoader _loadFont;

  Future<CapabilityResult<Uint8List>> generate(RestaurantReport report) async {
    try {
      final font = pw.Font.ttf(await _loadFont());
      final pdf = pw.Document(
        title: report.title,
        author: report.identity['name'],
      );
      pdf.addPage(
        pw.MultiPage(
          maxPages: 1000,
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(30),
            theme: pw.ThemeData.withFont(base: font, bold: font),
            textDirection: pw.TextDirection.rtl,
          ),
          header: (_) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  report.identity['name']!.isEmpty
                      ? 'دفتر'
                      : report.identity['name']!,
                  style: pw.TextStyle(fontSize: 20),
                ),
                if (report.identity['contact']!.isNotEmpty)
                  pw.Text(report.identity['contact']!),
                pw.Text(report.title, style: pw.TextStyle(fontSize: 17)),
                pw.Text('${report.period} · ${report.reference}'),
              ],
            ),
          ),
          footer: (context) => pw.Column(
            children: [
              if (report.identity['footer']!.isNotEmpty)
                pw.Text(report.identity['footer']!),
              pw.Directionality(
                textDirection: pw.TextDirection.ltr,
                child: pw.Text(
                  '${context.pageNumber} / ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ],
          ),
          build: (_) => [
            for (final section in report.sections) ...[
              if (section.title.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
                  child: pw.Text(
                    section.title,
                    style: pw.TextStyle(fontSize: 15),
                  ),
                ),
              if (section.rows.isEmpty) pw.Text('لا توجد سجلات ضمن هذا العرض.'),
              if (section.rows.isNotEmpty)
                pw.TableHelper.fromTextArray(
                  headers: section.headers.reversed.toList(),
                  data: section.rows.map((r) => r.reversed.toList()).toList(),
                  headerCount: 1,
                  cellAlignment: pw.Alignment.centerRight,
                  headerAlignment: pw.Alignment.centerRight,
                  cellStyle: pw.TextStyle(font: font, fontSize: 10),
                  headerStyle: pw.TextStyle(font: font, fontSize: 10),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                  cellPadding: const pw.EdgeInsets.all(5),
                ),
              pw.SizedBox(height: 10),
            ],
          ],
        ),
      );
      return CapabilitySuccess(await pdf.save());
    } on Object {
      return const CapabilityFailure(
        'pdf_generation_failed',
        'Offline report generation failed.',
      );
    }
  }

  /// Save uses the same immutable bytes that share/print receives. A cancelled
  /// handoff cannot create or repeat a transaction.
  Future<CapabilityResult<void>> save(
    RestaurantReport report,
    Uint8List bytes, {
    FileTransferCapability? transfer,
  }) =>
      (transfer ??
              NativeFileTransfer(
                maxBytes: 20 * 1024 * 1024,
                fileName: report.filename,
                mimeType: 'application/pdf',
                allowedExtensions: const ['pdf'],
              ))
          .save(Uint8List.fromList(bytes));

  Future<CapabilityResult<void>> share(
    RestaurantReport report,
    Uint8List bytes, {
    PdfHandoffCapability? handoff,
  }) => (handoff ?? NativePdfHandoff(filename: report.filename)).share(
    Uint8List.fromList(bytes),
  );

  Future<CapabilityResult<void>> print(
    RestaurantReport report,
    Uint8List bytes, {
    PdfHandoffCapability? handoff,
  }) => (handoff ?? NativePdfHandoff(filename: report.filename)).print(
    Uint8List.fromList(bytes),
  );
}
