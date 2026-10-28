import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../capabilities/capability_contracts.dart';

typedef LoadArabicFont = Future<ByteData> Function();
typedef PdfNativeHandoff = Future<bool> Function(Uint8List bytes);

/// Synthetic PDF only. Always embeds the licensed bundled font, offline.
final class OfflineArabicPdf implements PdfCapability {
  OfflineArabicPdf({
    LoadArabicFont? loadFont,
    PdfNativeHandoff? share,
    PdfNativeHandoff? print,
  }) : _loadFont = loadFont ?? (() => rootBundle.load(fontAsset)),
       _share = share ?? _shareNative,
       _print = print ?? _printNative;

  static const fontAsset = 'assets/fonts/Amiri-Regular.ttf';
  static const filename = 'dakhl_restaurant_phase00_synthetic.pdf';
  final LoadArabicFont _loadFont;
  final PdfNativeHandoff _share;
  final PdfNativeHandoff _print;

  static Future<bool> _shareNative(Uint8List bytes) =>
      Printing.sharePdf(bytes: bytes, filename: filename);
  static Future<bool> _printNative(Uint8List bytes) => Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: filename,
    format: PdfPageFormat.a4,
    dynamicLayout: false,
  );

  @override
  Future<CapabilityResult<Uint8List>> generate(SyntheticProbe probe) async {
    if (!probe.isValid) {
      return const CapabilityFailure(
        'invalid_synthetic_input',
        'The synthetic probe is invalid.',
      );
    }
    try {
      final font = pw.Font.ttf(await _loadFont());
      final document = pw.Document(
        title: 'Dakhl_Restaurant phase00 synthetic probe',
        author: 'Dakhl_Restaurant development',
      );
      document.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            theme: pw.ThemeData.withFont(base: font),
            textDirection: pw.TextDirection.rtl,
            buildBackground: (_) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Container(color: PdfColors.white),
            ),
          ),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'اختبار تقني معزول — بيانات تجريبية فقط',
                style: pw.TextStyle(font: font, fontSize: 20),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                probe.message,
                style: pw.TextStyle(font: font, fontSize: 18),
              ),
              pw.Text(
                'التسلسل: ${probe.sequence}',
                style: pw.TextStyle(font: font, fontSize: 18),
              ),
              pw.SizedBox(height: 20),
              pw.Directionality(
                textDirection: pw.TextDirection.ltr,
                child: pw.Text(
                  'Dakhl_Restaurant / Phase 00 / 123',
                  style: pw.TextStyle(font: font),
                ),
              ),
            ],
          ),
        ),
      );
      return CapabilitySuccess(await document.save());
    } on Object {
      return const CapabilityFailure(
        'pdf_generation_failed',
        'Offline PDF generation failed.',
      );
    }
  }

  bool _hasPdfHeader(Uint8List bytes) =>
      bytes.length >= 5 &&
      bytes[0] == 37 &&
      bytes[1] == 80 &&
      bytes[2] == 68 &&
      bytes[3] == 70 &&
      bytes[4] == 45;

  @override
  Future<CapabilityResult<void>> share(Uint8List bytes) async {
    if (!_hasPdfHeader(bytes)) {
      return const CapabilityFailure(
        'invalid_pdf',
        'No generated PDF is available.',
      );
    }
    try {
      final accepted = await _share(Uint8List.fromList(bytes));
      // Native implementations do not consistently distinguish dismissal from
      // unsupported/failed sharing. False cannot truthfully certify cancellation.
      return accepted
          ? const CapabilitySuccess(null)
          : const CapabilityFailure(
              'share_unconfirmed',
              'The native share handoff was not confirmed.',
            );
    } on Object {
      return const CapabilityFailure(
        'native_share_failed',
        'The native share handoff failed.',
      );
    }
  }

  @override
  Future<CapabilityResult<void>> print(Uint8List bytes) async {
    if (!_hasPdfHeader(bytes)) {
      return const CapabilityFailure(
        'invalid_pdf',
        'No generated PDF is available.',
      );
    }
    try {
      final accepted = await _print(Uint8List.fromList(bytes));
      return accepted
          ? const CapabilitySuccess(null)
          : const CapabilityCancelled();
    } on Object {
      return const CapabilityFailure(
        'native_print_failed',
        'The native print handoff failed.',
      );
    }
  }
}
