import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_flutter_adapters/madar_flutter_adapters.dart';

/// Opens the immutable saved document through app-owned presentation.
Future<CapabilityResult<void>> openSavedReportPdf(
  BuildContext context, {
  required String title,
  required Uint8List bytes,
  PdfRasterCapability? raster,
}) async {
  if (!context.mounted) {
    return const CapabilityFailure('disposed', 'Report view closed.');
  }
  await showDialog<void>(
    context: context,
    builder: (_) =>
        SavedReportPdfViewer(title: title, bytes: bytes, raster: raster),
  );
  return const CapabilitySuccess(null);
}

/// App presentation over the shared native byte raster capability. No file,
/// account, posting or report regeneration occurs when a page is opened.
class SavedReportPdfViewer extends StatefulWidget {
  SavedReportPdfViewer({
    super.key,
    required this.title,
    required Uint8List bytes,
    PdfRasterCapability? raster,
  }) : bytes = Uint8List.fromList(bytes),
       raster = raster ?? NativePdfRaster();
  final String title;
  final Uint8List bytes;
  final PdfRasterCapability raster;
  @override
  State<SavedReportPdfViewer> createState() => _SavedReportPdfViewerState();
}

class _SavedReportPdfViewerState extends State<SavedReportPdfViewer> {
  var _page = 0;
  bool _loading = true;
  late Future<CapabilityResult<Uint8List>> _render;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _loading = true;
    _render = widget.raster
        .rasterizePage(Uint8List.fromList(widget.bytes), page: _page)
        .whenComplete(() {
          if (mounted) setState(() => _loading = false);
        });
  }

  void _move(int delta) {
    if (_loading) return;
    setState(() {
      _page += delta;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<CapabilityResult<Uint8List>>(
              future: _render,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final result = snapshot.data;
                if (result is CapabilitySuccess<Uint8List>) {
                  return InteractiveViewer(
                    maxScale: 5,
                    child: Center(
                      child: Image.memory(
                        result.value,
                        fit: BoxFit.contain,
                        gaplessPlayback: false,
                      ),
                    ),
                  );
                }
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        result is CapabilityFailure<Uint8List> &&
                                result.code == 'page_unavailable'
                            ? 'لا توجد صفحة بهذا الرقم.'
                            : 'تعذّر فتح صفحة التقرير. أعد المحاولة.',
                      ),
                      TextButton(
                        onPressed: () => setState(_load),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _loading || _page == 0 ? null : () => _move(-1),
                  child: const Text('الصفحة السابقة'),
                ),
                Text('صفحة ${_page + 1}'),
                TextButton(
                  onPressed: _loading || _page == 999 ? null : () => _move(1),
                  child: const Text('الصفحة التالية'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
