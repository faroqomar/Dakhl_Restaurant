import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../capabilities/capability_contracts.dart';

typedef PickProbeBytes = Future<Uint8List?> Function();
typedef SaveProbeBytes = Future<Uri?> Function(Uint8List bytes);

/// Provisional native plugin adapter. No account paths or product schema access.
final class NativeFileSelection implements FileSelectionCapability {
  NativeFileSelection({PickProbeBytes? pick, SaveProbeBytes? save})
    : _pick = pick ?? _pickNative,
      _save = save ?? _saveNative;

  final PickProbeBytes _pick;
  final SaveProbeBytes _save;

  static Future<Uint8List?> _pickNative() async {
    final selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (selected == null) return null;
    final length = await selected.length();
    if (length != null && length > SyntheticProbe.maxBytes) {
      throw const FormatException('Synthetic input too large');
    }
    // Providers can omit or misreport length, so bound the Dart stream as well.
    // This cannot bound native materialization: Android/iOS providers can copy
    // the entire document into cache before this Dart code receives it.
    final bytes = BytesBuilder(copy: true);
    await for (final chunk in selected.readAsByteStream()) {
      if (bytes.length + chunk.length > SyntheticProbe.maxBytes) {
        throw const FormatException('Synthetic input too large');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  static Future<Uri?> _saveNative(Uint8List bytes) => FilePicker.saveFile(
    fileName: 'dakhl_restaurant_phase00_synthetic.json',
    mimeType: 'application/json',
    bytes: bytes,
  );

  @override
  Future<CapabilityResult<Uint8List>> openSynthetic() async {
    try {
      final bytes = await _pick();
      if (bytes == null) return const CapabilityCancelled();
      if (bytes.length > SyntheticProbe.maxBytes) {
        return const CapabilityFailure(
          'input_too_large',
          'Synthetic input exceeds its size limit.',
        );
      }
      return CapabilitySuccess(Uint8List.fromList(bytes));
    } on FormatException {
      return const CapabilityFailure(
        'input_too_large',
        'Synthetic input exceeds its size limit.',
      );
    } on Object {
      return const CapabilityFailure(
        'native_open_failed',
        'Native selection or read failed.',
      );
    }
  }

  @override
  Future<CapabilityResult<void>> saveSynthetic(Uint8List bytes) async {
    if (SyntheticProbe.decode(bytes) is! CapabilitySuccess<SyntheticProbe>) {
      return const CapabilityFailure(
        'invalid_synthetic_input',
        'Only a validated synthetic probe can be exported.',
      );
    }
    try {
      final saved = await _save(Uint8List.fromList(bytes));
      return saved == null
          ? const CapabilityCancelled()
          : const CapabilitySuccess(null);
    } on Object {
      return const CapabilityFailure(
        'native_export_failed',
        'Native export failed; source bytes remain unchanged.',
      );
    }
  }
}
