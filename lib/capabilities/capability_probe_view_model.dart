import 'package:flutter/foundation.dart';

import 'capability_contracts.dart';
import 'isolated_probe_repository.dart';

enum ProbeState { idle, running, success, cancelled, failure }

/// Coordinates the optional development harness; contains no product UI logic.
final class CapabilityProbeViewModel extends ChangeNotifier {
  CapabilityProbeViewModel({
    required this._files,
    required this._pdf,
    required this._repository,
  });

  static const maxPdfBytes = 4 * 1024 * 1024;
  final FileSelectionCapability _files;
  final PdfCapability _pdf;
  final IsolatedProbeRepository _repository;
  ProbeState _state = ProbeState.idle;
  String? _operation;
  CapabilityFailure<void>? _failure;
  SyntheticProbe _probe = SyntheticProbe.specimen;
  Uint8List? _pdfBytes;
  bool _disposed = false;

  ProbeState get state => _state;
  String? get operation => _operation;
  CapabilityFailure<void>? get failure => _failure;
  SyntheticProbe get probe => _probe;
  Uint8List? get pdfBytes =>
      _pdfBytes == null ? null : Uint8List.fromList(_pdfBytes!);

  Future<void> importSynthetic() => _run('import', () async {
    final selected = await _files.openSynthetic();
    if (selected case CapabilitySuccess<Uint8List>(:final value)) {
      final decoded = SyntheticProbe.decode(value);
      if (decoded case CapabilitySuccess<SyntheticProbe>(:final value)) {
        final saved = await _repository.write(value);
        if (saved is CapabilitySuccess<void>) _replaceProbe(value);
        return saved;
      }
      return _withoutValue(decoded);
    }
    return _withoutValue(selected);
  });

  Future<void> exportSynthetic() =>
      _run('export', () => _files.saveSynthetic(_probe.encode()));

  Future<void> writeAndReopen() => _run('write_reopen', () async {
    final saved = await _repository.write(_probe);
    if (saved is! CapabilitySuccess<void>) return saved;
    return _load();
  });

  Future<void> reopen() => _run('reopen', _load);

  Future<CapabilityResult<void>> _load() async {
    final result = await _repository.read();
    if (result case CapabilitySuccess<SyntheticProbe>(:final value)) {
      _replaceProbe(value);
    }
    return _withoutValue(result);
  }

  void _replaceProbe(SyntheticProbe value) {
    if (value.message != _probe.message || value.sequence != _probe.sequence) {
      _pdfBytes = null;
    }
    _probe = value;
  }

  Future<void> generatePdf() => _run('pdf_generate', () async {
    final result = await _pdf.generate(_probe);
    if (result case CapabilitySuccess<Uint8List>(:final value)) {
      if (value.length < 5 ||
          value.length > maxPdfBytes ||
          String.fromCharCodes(value.take(5)) != '%PDF-') {
        return const CapabilityFailure('invalid_pdf', 'PDF output is invalid.');
      }
      _pdfBytes = Uint8List.fromList(value);
    }
    return _withoutValue(result);
  });

  Future<void> sharePdf() => _run('pdf_share', () async {
    if (_pdfBytes == null) return _missingPdf;
    return _pdf.share(Uint8List.fromList(_pdfBytes!));
  });

  Future<void> printPdf() => _run('pdf_print', () async {
    if (_pdfBytes == null) return _missingPdf;
    return _pdf.print(Uint8List.fromList(_pdfBytes!));
  });

  static const _missingPdf = CapabilityFailure<void>(
    'pdf_missing',
    'Generate a synthetic PDF first.',
  );

  Future<void> _run(
    String operation,
    Future<CapabilityResult<void>> Function() action,
  ) async {
    if (_disposed || _state == ProbeState.running) return;
    _operation = operation;
    _failure = null;
    _state = ProbeState.running;
    notifyListeners();
    CapabilityResult<void> result;
    try {
      result = await action();
    } on Exception {
      result = const CapabilityFailure(
        'unexpected_failure',
        'The capability could not complete. It can be retried.',
      );
    }
    if (_disposed) return;
    switch (result) {
      case CapabilitySuccess<void>():
        _state = ProbeState.success;
      case CapabilityCancelled<void>():
        _state = ProbeState.cancelled;
      case CapabilityFailure<void>():
        _failure = result;
        _state = ProbeState.failure;
    }
    notifyListeners();
  }

  static CapabilityResult<void> _withoutValue<T>(CapabilityResult<T> result) =>
      switch (result) {
        CapabilitySuccess<T>() => const CapabilitySuccess(null),
        CapabilityCancelled<T>() => const CapabilityCancelled(),
        CapabilityFailure<T>(:final code, :final message) => CapabilityFailure(
          code,
          message,
        ),
      };

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
