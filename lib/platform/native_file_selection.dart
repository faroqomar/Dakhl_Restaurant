import 'dart:typed_data';

import 'package:madar_flutter_adapters/madar_flutter_adapters.dart';

import '../capabilities/capability_contracts.dart';

typedef PickProbeBytes = Future<Uint8List?> Function();
typedef SaveProbeBytes = Future<Uri?> Function(Uint8List bytes);

/// Restaurant development policy around Madar's reusable byte-transfer adapter.
final class NativeFileSelection implements FileSelectionCapability {
  NativeFileSelection({
    PickProbeBytes? pick,
    SaveProbeBytes? save,
    FileTransferCapability? transfer,
  }) : _transfer =
           transfer ??
           NativeFileTransfer(
             maxBytes: SyntheticProbe.maxBytes,
             fileName: 'dakhl_restaurant_phase00_synthetic.json',
             mimeType: 'application/json',
             pick: pick,
             save: save,
           );

  final FileTransferCapability _transfer;

  @override
  Future<CapabilityResult<Uint8List>> openSynthetic() async {
    final result = await _transfer.open();
    if (result case CapabilitySuccess<Uint8List>(:final value)) {
      // Keep the app limit even when composed with a different adapter.
      if (value.length > SyntheticProbe.maxBytes) {
        return const CapabilityFailure(
          'input_too_large',
          'Synthetic input exceeds its size limit.',
        );
      }
      return CapabilitySuccess(Uint8List.fromList(value));
    }
    return result;
  }

  @override
  Future<CapabilityResult<void>> saveSynthetic(Uint8List bytes) async {
    if (SyntheticProbe.decode(bytes) is! CapabilitySuccess<SyntheticProbe>) {
      return const CapabilityFailure(
        'invalid_synthetic_input',
        'Only a validated synthetic probe can be exported.',
      );
    }
    return _transfer.save(Uint8List.fromList(bytes));
  }
}
