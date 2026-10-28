import '../capabilities/capability_contracts.dart';

/// Caller-supplied identity for one write/restart/read evidence pair.
/// A fresh token must be generated for every pair; never use a secret here.
final class ProbeRunIdentity {
  ProbeRunIdentity(this.nonce) {
    if (nonce.length < 16 ||
        nonce.length > 64 ||
        RegExp(r'[^A-Za-z0-9_-]').hasMatch(nonce)) {
      throw const FormatException(
        'PHASE00_RUN_NONCE is required: supply a fresh 16-64 character ASCII token (letters, digits, underscore or hyphen).',
      );
    }
  }

  final String nonce;

  SyntheticProbe get probe => SyntheticProbe(
    message: 'اختبار تقني معزول $nonce',
    sequence: nonce.codeUnits.fold<int>(
      0,
      (hash, byte) => (hash * 31 + byte) % 1000000,
    ),
  );

  CapabilityResult<void> validateRead(SyntheticProbe actual) =>
      actual.message == probe.message && actual.sequence == probe.sequence
      ? const CapabilitySuccess(null)
      : const CapabilityFailure(
          'run_nonce_mismatch',
          'The saved synthetic payload does not match this run nonce. Existing data was preserved.',
        );
}
