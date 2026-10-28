import 'dart:typed_data';

import 'package:dakhl_restaurant/capabilities/capability_contracts.dart';
import 'package:dakhl_restaurant/platform/native_file_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'restaurant validates its schema before delegating export to Madar',
    () async {
      final transfer = _Transfer();
      final app = NativeFileSelection(transfer: transfer);
      final invalid = await app.saveSynthetic(Uint8List.fromList([1, 2, 3]));
      expect(
        (invalid as CapabilityFailure<void>).code,
        'invalid_synthetic_input',
      );
      expect(transfer.saved, isEmpty);
      final specimen = SyntheticProbe.specimen.encode();
      expect(await app.saveSynthetic(specimen), isA<CapabilitySuccess<void>>());
      expect(transfer.saved.single, specimen);
    },
  );

  test(
    'restaurant import bound remains enforced with a different engine adapter',
    () async {
      final transfer = _Transfer()
        ..incoming = Uint8List(SyntheticProbe.maxBytes);
      final app = NativeFileSelection(transfer: transfer);
      final accepted =
          await app.openSynthetic() as CapabilitySuccess<Uint8List>;
      expect(accepted.value.length, 4096);
      transfer.incoming = Uint8List(SyntheticProbe.maxBytes + 1);
      final rejected =
          await app.openSynthetic() as CapabilityFailure<Uint8List>;
      expect(rejected.code, 'input_too_large');
    },
  );
}

final class _Transfer implements FileTransferCapability {
  final saved = <Uint8List>[];
  Uint8List incoming = Uint8List(0);

  @override
  Future<CapabilityResult<Uint8List>> open() async =>
      CapabilitySuccess(incoming);

  @override
  Future<CapabilityResult<void>> save(Uint8List bytes) async {
    saved.add(Uint8List.fromList(bytes));
    return const CapabilitySuccess(null);
  }
}
