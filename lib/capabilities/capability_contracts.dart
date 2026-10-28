import 'dart:convert';
import 'dart:typed_data';

/// Cancellation is a user outcome, never a platform failure or success.
sealed class CapabilityResult<T> {
  const CapabilityResult();
}

final class CapabilitySuccess<T> extends CapabilityResult<T> {
  const CapabilitySuccess(this.value);
  final T value;
}

final class CapabilityCancelled<T> extends CapabilityResult<T> {
  const CapabilityCancelled();
}

final class CapabilityFailure<T> extends CapabilityResult<T> {
  const CapabilityFailure(this.code, this.message);
  final String code;
  final String message;
}

abstract interface class FileSelectionCapability {
  /// Accepted/returned payloads are validated to [SyntheticProbe.maxBytes].
  /// Native providers may materialize/cache the full selection before the Dart
  /// boundary; that work is not bounded or proven here. This phase 00 synthetic
  /// candidate does not certify production import. The selected source is not
  /// written by this operation.
  Future<CapabilityResult<Uint8List>> openSynthetic();

  /// Exports validated synthetic bytes through a native destination chooser.
  Future<CapabilityResult<void>> saveSynthetic(Uint8List bytes);
}

abstract interface class PdfCapability {
  Future<CapabilityResult<Uint8List>> generate(SyntheticProbe probe);

  /// Success proves a platform handoff, not delivery to a recipient.
  Future<CapabilityResult<void>> share(Uint8List bytes);

  /// Success proves a platform handoff, not physical printed output.
  Future<CapabilityResult<void>> print(Uint8List bytes);
}

/// Deliberately unrelated to restaurant records or later account schemas.
final class SyntheticProbe {
  const SyntheticProbe({required this.message, required this.sequence});

  static const format = 'dakhl_restaurant.phase00.synthetic.v1';
  static const maxBytes = 4096;
  static const specimen = SyntheticProbe(
    message: 'اختبار تقني معزول 123',
    sequence: 1,
  );

  final String message;
  final int sequence;

  bool get isValid =>
      message.runes.isNotEmpty &&
      message.runes.length <= 120 &&
      !message.runes.any((rune) => rune >= 0xd800 && rune <= 0xdfff) &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(message) &&
      sequence >= 0 &&
      sequence <= 999999;

  Uint8List encode() {
    if (!isValid) throw const FormatException('Invalid synthetic probe');
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': format,
          'message': message,
          'sequence': sequence,
        }),
      ),
    );
  }

  static CapabilityResult<SyntheticProbe> decode(Uint8List bytes) {
    const failure = CapabilityFailure<SyntheticProbe>(
      'invalid_synthetic_input',
      'The file must contain only a bounded phase 00 synthetic probe.',
    );
    if (bytes.isEmpty || bytes.length > maxBytes) return failure;
    try {
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic> ||
          value.length != 3 ||
          value['format'] != format ||
          value['message'] is! String ||
          value['sequence'] is! int) {
        return failure;
      }
      final probe = SyntheticProbe(
        message: value['message'] as String,
        sequence: value['sequence'] as int,
      );
      return probe.isValid ? CapabilitySuccess(probe) : failure;
    } on FormatException {
      return failure;
    }
  }
}
