import 'dart:convert';
import 'dart:typed_data';

import 'package:madar_application/madar_application.dart';

import 'account_document.dart';
import 'legacy_account_codec.dart';
import 'portable_journal_state.dart';

/// Isolated version 12 complete-state codec. Existing schema 11 runtime readers
/// remain unchanged. Capacity overrides may tighten, never raise, store limits.
final class PortableJournalCodec
    implements DurableCommandStateCodec<PortableJournalState> {
  const PortableJournalCodec({
    this.maxPayloadBytes = DocumentLimits.accountBytes,
  });
  final int maxPayloadBytes;
  static const _legacyCodec = LegacyAccountCodec();

  void _checkCapacity(int bytes) {
    if (maxPayloadBytes <= 0 || maxPayloadBytes > DocumentLimits.accountBytes) {
      throw const PortableJournalException(
        'invalid_configuration',
        'Invalid payload capacity.',
      );
    }
    if (bytes > maxPayloadBytes) {
      throw const PortableJournalException(
        'payload_too_large',
        'Portable state exceeds payload capacity.',
      );
    }
  }

  PortableJournalState _decodeText(String text) {
    try {
      final raw = jsonDecode(text);
      if (raw is! Map<String, Object?>) {
        throw const PortableJournalException(
          'invalid_payload',
          'Expected a portable state object.',
        );
      }
      return decodeJson(raw);
    } on PortableJournalException {
      rethrow;
    } catch (_) {
      throw const PortableJournalException(
        'corrupt_state',
        'Malformed portable state.',
      );
    }
  }

  @override
  PortableJournalState decodeState(String payload) {
    final bytes = utf8.encode(payload);
    _checkCapacity(bytes.length);
    if (utf8.decode(bytes) != payload) {
      throw const PortableJournalException(
        'corrupt_state',
        'Malformed Unicode in payload.',
      );
    }
    return _decodeText(payload);
  }

  @override
  String encodeState(PortableJournalState state) {
    _checkCapacity(0);
    state.validate();
    try {
      final text = const JsonEncoder.withIndent('  ').convert(state.toJson());
      _checkCapacity(utf8.encode(text).length);
      return text;
    } on PortableJournalException {
      rethrow;
    } catch (_) {
      throw const PortableJournalException(
        'invalid_payload',
        'State cannot be encoded.',
      );
    }
  }

  @override
  Iterable<DurableCommandReceipt> extractReceipts(PortableJournalState state) =>
      state.receipts;
  @override
  PortableJournalState attachReceipt(
    PortableJournalState state,
    DurableCommandReceipt receipt,
  ) => state.attachReceipt(receipt);

  PortableJournalState decodeBytes(List<int> bytes) {
    _checkCapacity(bytes.length);
    try {
      return _decodeText(utf8.decode(bytes, allowMalformed: false));
    } on PortableJournalException {
      rethrow;
    } catch (_) {
      throw const PortableJournalException(
        'corrupt_state',
        'Malformed UTF-8 payload.',
      );
    }
  }

  Uint8List encodeBytes(PortableJournalState state) =>
      Uint8List.fromList(utf8.encode(encodeState(state)));

  PortableJournalState decodeJson(Map<String, Object?> json) {
    _checkCapacity(0);
    final state = PortableJournalState.fromJson(json);
    // Direct-map entry points obey the same normalized-output byte bound.
    encodeState(state);
    return state;
  }

  /// Enrolls an existing validated schema 1..11 canonical [AccountDocument]
  /// into a version 12 portable envelope.
  ///
  /// Under ADR 0021, cutover state remains gated and no historical or opening
  /// journals are synthesized.
  PortableJournalState enrollLegacyDocument(
    AccountDocument source, {
    required String accountLineage,
    DateTime? enrolledAt,
  }) {
    final now = (enrolledAt ?? DateTime.now().toUtc()).toIso8601String();
    return PortableJournalState(
      accountLineage: accountLineage,
      account: source,
      sourceProvenance: PortableJournalSourceProvenance(
        sourceVersion: source.sourceVersion,
        enrolledAt: now,
        migrated: source.sourceVersion != 11,
      ),
      cutoverState: PortableJournalCutoverState.gated(),
      journals: const [],
      receipts: const [],
    );
  }

  /// Enrolls a legacy schema 1..11 JSON map into a version 12 portable envelope.
  PortableJournalState enrollLegacySourceJson(
    Map<String, Object?> json, {
    required String accountLineage,
    DateTime? enrolledAt,
  }) {
    final doc = _legacyCodec.decodeJson(json);
    return enrollLegacyDocument(
      doc,
      accountLineage: accountLineage,
      enrolledAt: enrolledAt,
    );
  }

  /// Enrolls legacy schema 1..11 bytes into a version 12 portable envelope.
  PortableJournalState enrollLegacySourceBytes(
    List<int> bytes, {
    required String accountLineage,
    DateTime? enrolledAt,
  }) {
    final doc = _legacyCodec.decodeBytes(bytes);
    return enrollLegacyDocument(
      doc,
      accountLineage: accountLineage,
      enrolledAt: enrolledAt,
    );
  }
}
