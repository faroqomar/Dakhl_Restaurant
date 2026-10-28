import 'dart:convert';
import 'dart:typed_data';

import 'package:dakhl_restaurant/capabilities/capability_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('synthetic Arabic text and Latin sequence survive a round trip', () {
    const probe = SyntheticProbe(message: 'اختبار محلي 123', sequence: 7);
    final result = SyntheticProbe.decode(probe.encode());
    expect(result, isA<CapabilitySuccess<SyntheticProbe>>());
    final decoded = (result as CapabilitySuccess<SyntheticProbe>).value;
    expect(decoded.message, probe.message);
    expect(decoded.sequence, 7);
  });

  test('valid Unicode scalars round trip; lone surrogates are rejected', () {
    const valid = SyntheticProbe(message: 'اختبار 🌿 123', sequence: 999999);
    expect(
      SyntheticProbe.decode(valid.encode()),
      isA<CapabilitySuccess<SyntheticProbe>>(),
    );
    expect(
      const SyntheticProbe(message: '\ud800', sequence: 1).isValid,
      isFalse,
    );
    expect(
      const SyntheticProbe(message: '\udc00', sequence: 1).isValid,
      isFalse,
    );
  });

  test('rejects malformed, excessive and non-synthetic input', () {
    for (final bytes in <Uint8List>[
      Uint8List.fromList([0xff]),
      Uint8List.fromList(utf8.encode('{')),
      Uint8List.fromList(utf8.encode('{"accounts": []}')),
      Uint8List(SyntheticProbe.maxBytes + 1),
      Uint8List.fromList(utf8.encode('[]')),
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'format': SyntheticProbe.format,
            'message': 'safe',
            'sequence': 1,
            'accounts': [],
          }),
        ),
      ),
    ]) {
      expect(
        SyntheticProbe.decode(bytes),
        isA<CapabilityFailure<SyntheticProbe>>(),
      );
    }
  });

  test('rejects invalid sequence, message and field types', () {
    for (final values in <Map<String, Object?>>[
      {'message': 'safe', 'sequence': -1},
      {'message': 'safe', 'sequence': 1000000},
      {'message': 'safe', 'sequence': 1.5},
      {'message': '', 'sequence': 1},
      {'message': 'x' * 121, 'sequence': 1},
      {'message': 'unsafe\u0000', 'sequence': 1},
      {'message': 12, 'sequence': 1},
    ]) {
      final bytes = Uint8List.fromList(
        utf8.encode(jsonEncode({'format': SyntheticProbe.format, ...values})),
      );
      expect(
        SyntheticProbe.decode(bytes),
        isA<CapabilityFailure<SyntheticProbe>>(),
      );
    }
  });
}
