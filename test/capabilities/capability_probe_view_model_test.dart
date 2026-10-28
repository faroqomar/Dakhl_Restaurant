import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dakhl_restaurant/capabilities/capability_contracts.dart';
import 'package:dakhl_restaurant/capabilities/capability_probe_view_model.dart';
import 'package:dakhl_restaurant/capabilities/isolated_probe_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporary;
  late IsolatedProbeRepository repository;
  late _Files files;
  late _Pdf pdf;
  late CapabilityProbeViewModel model;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('phase00-view-model-');
    repository = IsolatedProbeRepository(
      Directory('${temporary.path}/${IsolatedProbeRepository.rootName}'),
    );
    files = _Files();
    pdf = _Pdf();
    model = CapabilityProbeViewModel(
      files: files,
      pdf: pdf,
      repository: repository,
    );
  });
  tearDown(() async {
    model.dispose();
    await temporary.delete(recursive: true);
  });

  test(
    'canceled selection is distinct from failed selection and writes nothing',
    () async {
      files.openResult = const CapabilityCancelled();
      await model.importSynthetic();
      expect(model.state, ProbeState.cancelled);
      expect(model.failure, isNull);
      expect(await repository.root.exists(), isFalse);
      files.openResult = const CapabilityFailure('denied', 'Access denied');
      await model.importSynthetic();
      expect(model.state, ProbeState.failure);
      expect(model.failure?.code, 'denied');
      expect(await repository.root.exists(), isFalse);
    },
  );

  test('invalid imported bytes preserve existing source and output; valid retry persists', () async {
    await model.writeAndReopen();
    final original = model.probe;
    files.openResult = CapabilitySuccess(Uint8List.fromList([0xff]));
    await model.importSynthetic();
    expect(model.state, ProbeState.failure);
    expect(model.probe, same(original));
    expect(
      (await repository.read() as CapabilitySuccess<SyntheticProbe>)
          .value
          .message,
      original.message,
    );
    const imported = SyntheticProbe(
      message: 'استيراد تجريبي 456',
      sequence: 456,
    );
    files.openResult = CapabilitySuccess(imported.encode());
    await model.importSynthetic();
    expect(model.state, ProbeState.success);
    expect(model.probe.sequence, 456);
    expect(
      (await repository.read() as CapabilitySuccess<SyntheticProbe>)
          .value
          .sequence,
      456,
    );
  });

  test(
    'pending export blocks concurrent duplicate writes and permits retry',
    () async {
      final pending = Completer<CapabilityResult<void>>();
      files.pendingSave = pending.future;
      final states = <ProbeState>[];
      model.addListener(() => states.add(model.state));
      final saving = model.exportSynthetic();
      expect(model.state, ProbeState.running);
      await model.exportSynthetic();
      expect(files.saveCalls, 1);
      pending.complete(const CapabilityFailure('denied', 'Denied'));
      await saving;
      expect(states, [ProbeState.running, ProbeState.failure]);
      expect(model.failure?.code, 'denied');
      files.pendingSave = null;
      await model.exportSynthetic();
      expect(model.state, ProbeState.success);
      expect(files.saveCalls, 2);
      expect(
        SyntheticProbe.decode(files.lastSaved!),
        isA<CapabilitySuccess<SyntheticProbe>>(),
      );
    },
  );

  test(
    'PDF generation, share and print preserve cancellation semantics',
    () async {
      await model.sharePdf();
      expect(model.failure?.code, 'pdf_missing');
      expect(pdf.shareCalls, 0);
      await model.generatePdf();
      expect(model.state, ProbeState.success);
      final original = model.pdfBytes!;
      original[0] = 0;
      expect(model.pdfBytes![0], 37);
      pdf.handoffResult = const CapabilityCancelled();
      await model.sharePdf();
      expect(model.state, ProbeState.cancelled);
      expect(model.failure, isNull);
      await model.printPdf();
      expect(model.state, ProbeState.cancelled);
      expect(pdf.shareCalls, 1);
      expect(pdf.printCalls, 1);
      pdf.handoffResult = const CapabilitySuccess(null);
      await model.printPdf();
      expect(model.state, ProbeState.success);
    },
  );

  test(
    'changing imported probe invalidates PDF to prevent stale handoffs',
    () async {
      await model.generatePdf();
      files.openResult = CapabilitySuccess(
        const SyntheticProbe(message: 'جديد', sequence: 2).encode(),
      );
      await model.importSynthetic();
      expect(model.pdfBytes, isNull);
      await model.printPdf();
      expect(model.failure?.code, 'pdf_missing');
      expect(pdf.printCalls, 0);
    },
  );

  test(
    'failed or oversized PDF generation preserves previous valid output',
    () async {
      await model.generatePdf();
      final previous = model.pdfBytes;
      pdf.generatedResult = const CapabilityFailure(
        'font_unavailable',
        'Font unavailable',
      );
      await model.generatePdf();
      expect(model.state, ProbeState.failure);
      expect(model.failure?.code, 'font_unavailable');
      expect(model.pdfBytes, previous);
      pdf.generatedResult = CapabilitySuccess(
        Uint8List(CapabilityProbeViewModel.maxPdfBytes + 1),
      );
      await model.generatePdf();
      expect(model.failure?.code, 'invalid_pdf');
      expect(model.pdfBytes, previous);
    },
  );

  test(
    'reopen reads previous process output without writing default specimen',
    () async {
      await repository.write(
        const SyntheticProbe(message: 'محفوظ سابقاً', sequence: 99),
      );
      await model.reopen();
      expect(model.state, ProbeState.success);
      expect(model.probe.sequence, 99);
      final revisions = (await repository.root.list().toList())
          .whereType<Directory>();
      expect(revisions.length, 1);
    },
  );

  test(
    'unexpected platform exception becomes a recoverable safe failure',
    () async {
      files.throwOnOpen = true;
      await model.importSynthetic();
      expect(model.state, ProbeState.failure);
      expect(model.failure?.code, 'unexpected_failure');
      expect(model.failure?.message.contains('private/path'), isFalse);
      files.throwOnOpen = false;
      files.openResult = const CapabilityCancelled();
      await model.importSynthetic();
      expect(model.state, ProbeState.cancelled);
    },
  );
}

final class _Files implements FileSelectionCapability {
  CapabilityResult<Uint8List> openResult = const CapabilityCancelled();
  Future<CapabilityResult<void>>? pendingSave;
  bool throwOnOpen = false;
  int saveCalls = 0;
  Uint8List? lastSaved;

  @override
  Future<CapabilityResult<Uint8List>> openSynthetic() async {
    if (throwOnOpen) throw const FileSystemException('/private/path');
    return openResult;
  }

  @override
  Future<CapabilityResult<void>> saveSynthetic(Uint8List bytes) async {
    saveCalls++;
    lastSaved = Uint8List.fromList(bytes);
    return pendingSave ?? const CapabilitySuccess(null);
  }
}

final class _Pdf implements PdfCapability {
  CapabilityResult<void> handoffResult = const CapabilitySuccess(null);
  CapabilityResult<Uint8List> generatedResult = CapabilitySuccess(
    Uint8List.fromList('%PDF-synthetic'.codeUnits),
  );
  int shareCalls = 0;
  int printCalls = 0;

  @override
  Future<CapabilityResult<Uint8List>> generate(SyntheticProbe probe) async =>
      generatedResult;
  @override
  Future<CapabilityResult<void>> share(Uint8List bytes) async {
    shareCalls++;
    return handoffResult;
  }

  @override
  Future<CapabilityResult<void>> print(Uint8List bytes) async {
    printCalls++;
    return handoffResult;
  }
}
