import 'dart:convert';

import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import 'account_document.dart';
import 'legacy_account_codec.dart';
import '../accounting/restaurant_journal_mapper.dart';

/// Exception thrown on invariant failure, unsupported format, or corrupt data
/// within the portable journal envelope.
final class PortableJournalException implements Exception {
  const PortableJournalException(this.code, this.message, [this.details]);

  final String code;
  final String message;
  final Map<String, Object?>? details;

  @override
  String toString() => 'PortableJournalException($code: $message)';
}

/// Provenance metadata tracking the origin and legacy migration of the document.
final class PortableJournalSourceProvenance {
  const PortableJournalSourceProvenance({
    required this.sourceVersion,
    required this.enrolledAt,
    required this.migrated,
  });

  final int sourceVersion;
  final String enrolledAt;
  final bool migrated;

  Map<String, Object?> toJson() => {
    'sourceVersion': sourceVersion,
    'enrolledAt': enrolledAt,
    'migrated': migrated,
  };

  void validate() {
    _require(
      sourceVersion >= 1 && sourceVersion <= 12,
      'invalid_source_provenance',
    );
    _timestamp(enrolledAt);
    _require(migrated == (sourceVersion < 11), 'invalid_source_provenance');
  }

  factory PortableJournalSourceProvenance.fromJson(Map<String, Object?> json) {
    return _guard('invalid_payload', () {
      _keys(json, const {'sourceVersion', 'enrolledAt', 'migrated'});
      final result = PortableJournalSourceProvenance(
        sourceVersion: _integer(json['sourceVersion']),
        enrolledAt: _text(json['enrolledAt']),
        migrated: _boolean(json['migrated']),
      );
      result.validate();
      return result;
    });
  }
}

/// Explicit cutover state governing financial activation.
///
/// Under ADR 0021 / F-02, enrolling a source envelope leaves cutover gated;
/// preparing an envelope must never imply accepted financial posting.
final class PortableJournalCutoverState {
  PortableJournalCutoverState.gated({
    this.status = 'gated',
    Map<String, Object?>? verifiedOpeningValues,
  }) : isGated = true,
       hasActivePosting = false,
       cutoverDate = null,
       openingJournalId = null,
       verifiedOpeningValues = _optionalSnapshot(verifiedOpeningValues) {
    validate();
  }

  PortableJournalCutoverState.established({
    required this.cutoverDate,
    required this.openingJournalId,
    this.status = 'established',
    this.hasActivePosting = true,
    Map<String, Object?>? verifiedOpeningValues,
  }) : isGated = false,
       verifiedOpeningValues = _optionalSnapshot(verifiedOpeningValues) {
    validate();
  }

  final bool isGated;
  final String status;
  final DateOnly? cutoverDate;
  final String? openingJournalId;
  final bool hasActivePosting;
  final Map<String, Object?>? verifiedOpeningValues;

  Map<String, Object?> toJson() => {
    'isGated': isGated,
    'status': status,
    if (cutoverDate != null) 'cutoverDate': cutoverDate!.toString(),
    if (openingJournalId != null) 'openingJournalId': openingJournalId,
    'hasActivePosting': hasActivePosting,
    if (verifiedOpeningValues != null)
      'verifiedOpeningValues': verifiedOpeningValues,
  };

  void validate() {
    _require(
      isGated
          ? status == 'gated' &&
                !hasActivePosting &&
                cutoverDate == null &&
                openingJournalId == null
          : status == 'established' &&
                hasActivePosting &&
                cutoverDate != null &&
                openingJournalId != null,
      'invalid_cutover_state',
    );
    if (openingJournalId != null) _text(openingJournalId);
  }

  factory PortableJournalCutoverState.fromJson(Map<String, Object?> json) =>
      _guard('invalid_cutover_state', () {
        _keys(json, const {
          'isGated',
          'status',
          'hasActivePosting',
          'cutoverDate',
          'openingJournalId',
          'verifiedOpeningValues',
        });
        final gated = _boolean(json['isGated']);
        final status = _text(json['status']);
        final active = _boolean(json['hasActivePosting']);
        final date = json['cutoverDate'];
        final openingId = json['openingJournalId'];
        final values = json['verifiedOpeningValues'];
        if (gated) {
          _require(
            !active && date == null && openingId == null,
            'invalid_cutover_state',
          );
          return PortableJournalCutoverState.gated(
            status: status,
            verifiedOpeningValues: values == null ? null : _map(values),
          );
        }
        return PortableJournalCutoverState.established(
          status: status,
          hasActivePosting: active,
          cutoverDate: _date(date),
          openingJournalId: _text(openingId),
          verifiedOpeningValues: values == null ? null : _map(values),
        );
      });
}

/// An immutable journal entry embedded in the portable envelope, combining
/// a validated [BalancedJournal] with source and correction lineage.
final class PortableJournalEntry {
  PortableJournalEntry({
    required this.journal,
    required this.sourceType,
    this.sourceRecordId,
    this.correctedFromJournalId,
    this.replacementJournalId,
    required this.recordedAt,
    Map<String, Object?>? metadata,
  }) : metadata = _optionalSnapshot(metadata) ?? const {} {
    validate();
  }

  final BalancedJournal journal;
  final String sourceType;
  final String? sourceRecordId;
  final String? correctedFromJournalId;
  final String? replacementJournalId;
  final String recordedAt;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => {
    'id': journal.id,
    'effectiveDate': journal.effectiveDate.toString(),
    'policy': {
      'currency': journal.policy.currency,
      'scale': journal.policy.scale,
      'maximumLineUnits': journal.policy.maximumLineUnits.toString(),
      'maximumSideUnits': journal.policy.maximumSideUnits.toString(),
      'maximumLines': journal.policy.maximumLines,
      'allowZeroLines': journal.policy.allowZeroLines,
    },
    'lines': [
      for (final line in journal.lines)
        {
          'accountId': line.accountId,
          'side': line.side.name,
          'amountUnits': line.amountUnits.toString(),
          'currency': line.currency,
          'scale': line.scale,
        },
    ],
    'totalUnits': journal.totalUnits.toString(),
    if (journal.reversesId != null) 'reversesId': journal.reversesId,
    if (journal.reason != null) 'reason': journal.reason,
    'sourceType': sourceType,
    if (sourceRecordId != null) 'sourceRecordId': sourceRecordId,
    if (correctedFromJournalId != null)
      'correctedFromJournalId': correctedFromJournalId,
    if (replacementJournalId != null)
      'replacementJournalId': replacementJournalId,
    'recordedAt': recordedAt,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  void validate() {
    _guard('invalid_journal', () {
      _text(sourceType);
      _timestamp(recordedAt);
      for (final id in [
        sourceRecordId,
        correctedFromJournalId,
        replacementJournalId,
      ]) {
        if (id != null) _text(id);
      }
      final opening =
          sourceType == RestaurantJournalSourceType.cutoverOpening.name ||
          journal.reversesId != null;
      _policy(journal.policy, opening: opening);
      if (sourceType == RestaurantJournalSourceType.cutoverOpening.name) {
        _require(!journal.policy.allowZeroLines, 'invalid_journal');
      }
      BalancedJournal.validate(
        id: journal.id,
        effectiveDate: journal.effectiveDate,
        lines: journal.lines,
        policy: journal.policy,
      );
    });
  }

  /// A reversal needs its previously decoded original to validate both stored
  /// line data and Madar's immutable reversal link. It is never reconstructed
  /// from unchecked input.
  factory PortableJournalEntry.fromJson(
    Map<String, Object?> json, {
    BalancedJournal? originalJournal,
  }) => _guard('invalid_journal', () {
    _keys(json, const {
      'id',
      'effectiveDate',
      'policy',
      'lines',
      'totalUnits',
      'reversesId',
      'reason',
      'sourceType',
      'sourceRecordId',
      'correctedFromJournalId',
      'replacementJournalId',
      'recordedAt',
      'metadata',
    });
    final id = _text(json['id']);
    final date = _date(json['effectiveDate']);
    final rawPolicy = _map(json['policy']);
    _keys(rawPolicy, const {
      'currency',
      'scale',
      'maximumLineUnits',
      'maximumSideUnits',
      'maximumLines',
      'allowZeroLines',
    });
    final policy = JournalPolicy(
      currency: _text(rawPolicy['currency']),
      scale: _integer(rawPolicy['scale']),
      maximumLineUnits: _units(rawPolicy['maximumLineUnits']),
      maximumSideUnits: _units(rawPolicy['maximumSideUnits']),
      maximumLines: _integer(rawPolicy['maximumLines']),
      allowZeroLines: _boolean(rawPolicy['allowZeroLines']),
    );
    final lines = <JournalLine>[];
    for (final raw in _list(json['lines'])) {
      final line = _map(raw);
      _keys(line, const {
        'accountId',
        'side',
        'amountUnits',
        'currency',
        'scale',
      });
      final side = _text(line['side']);
      _require(side == 'debit' || side == 'credit', 'invalid_journal');
      lines.add(
        JournalLine(
          accountId: _text(line['accountId']),
          side: side == 'debit' ? JournalSide.debit : JournalSide.credit,
          amountUnits: _units(line['amountUnits']),
          currency: _text(line['currency']),
          scale: _integer(line['scale']),
        ),
      );
    }
    var balanced = BalancedJournal.validate(
      id: id,
      effectiveDate: date,
      lines: lines,
      policy: policy,
    );
    _require(
      _units(json['totalUnits']) == balanced.totalUnits,
      'invalid_journal',
    );
    final reversesId = _optionalText(json['reversesId']);
    final reason = _optionalText(json['reason']);
    if (reversesId != null) {
      _require(
        originalJournal != null &&
            originalJournal.id == reversesId &&
            originalJournal.reversesId == null &&
            reason != null,
        'invalid_reversal_target',
      );
      final inverse = originalJournal!.reversed(
        id: id,
        effectiveDate: date,
        reason: reason!,
      );
      _require(
        _sameJournalValue(balanced, inverse) &&
            date == originalJournal.effectiveDate,
        'invalid_reversal_target',
      );
      balanced = inverse;
    } else {
      _require(reason == null, 'invalid_journal');
    }
    return PortableJournalEntry(
      journal: balanced,
      sourceType: _text(json['sourceType']),
      sourceRecordId: _optionalText(json['sourceRecordId']),
      correctedFromJournalId: _optionalText(json['correctedFromJournalId']),
      replacementJournalId: _optionalText(json['replacementJournalId']),
      recordedAt: _text(json['recordedAt']),
      metadata: json['metadata'] == null ? null : _map(json['metadata']),
    );
  });
}

/// The Version 12 portable complete-state envelope.
///
/// Embeds the canonical schema 11 account payload alongside immutable journals,
/// correction lineage, durable command receipts, caller-owned account lineage,
/// and explicit cutover state.
final class PortableJournalState {
  PortableJournalState({
    required this.accountLineage,
    required this.account,
    required this.sourceProvenance,
    required this.cutoverState,
    Iterable<PortableJournalEntry>? journals,
    Iterable<DurableCommandReceipt>? receipts,
    Iterable<String> requiredFeatures = const [],
  }) : version = 12,
       journals = List.unmodifiable(journals ?? const []),
       receipts = List.unmodifiable(receipts ?? const []),
       requiredFeatures = _requiredFeatureSnapshot(requiredFeatures) {
    validate();
  }

  final int version;
  final String accountLineage;
  final AccountDocument account;
  final PortableJournalSourceProvenance sourceProvenance;
  final PortableJournalCutoverState cutoverState;
  final List<PortableJournalEntry> journals;
  final List<DurableCommandReceipt> receipts;
  static const supplierOpeningFeature = 'supplierOpeningAmendments-v1';
  static const supportedRequiredFeatures = {supplierOpeningFeature};
  final List<String> requiredFeatures;

  PortableJournalState copyWith({
    String? accountLineage,
    AccountDocument? account,
    PortableJournalSourceProvenance? sourceProvenance,
    PortableJournalCutoverState? cutoverState,
    Iterable<PortableJournalEntry>? journals,
    Iterable<DurableCommandReceipt>? receipts,
    Iterable<String>? requiredFeatures,
  }) {
    return PortableJournalState(
      accountLineage: accountLineage ?? this.accountLineage,
      account: account ?? this.account,
      sourceProvenance: sourceProvenance ?? this.sourceProvenance,
      cutoverState: cutoverState ?? this.cutoverState,
      journals: journals ?? this.journals,
      receipts: receipts ?? this.receipts,
      requiredFeatures: requiredFeatures ?? this.requiredFeatures,
    );
  }

  void validate() => _guard('invalid_payload', () {
    _require(
      accountLineage.isNotEmpty && accountLineage == accountLineage.trim(),
      'invalid_account_lineage',
    );
    _text(accountLineage);
    _require(
      requiredFeatures.toSet().length == requiredFeatures.length &&
          requiredFeatures.every((f) => f == supplierOpeningFeature),
      'unsupported_required_feature',
    );
    _require(
      (!journals.any((j) => j.sourceType == 'supplierOpeningAmendment') &&
              !receipts.any(
                (r) =>
                    r.status == DurableCommandStatus.committed &&
                    r.identity.canonicalPayloadIdentity.contains(
                      '"commandType":"supplier_opening_amendment"',
                    ),
              )) ||
          requiredFeatures.contains(supplierOpeningFeature),
      'missing_required_feature',
    );
    sourceProvenance.validate();
    cutoverState.validate();
    final canonical = const LegacyAccountCodec().decodeJson(account.toJson());
    _require(
      _sameValue(canonical.toJson(), account.toJson()),
      'invalid_account_payload',
    );
    final byId = <String, PortableJournalEntry>{};
    final reversed = <String>{};
    for (final entry in journals) {
      entry.validate();
      _require(
        !byId.containsKey(entry.journal.id),
        'duplicate_journal_identity',
      );
      final targetId = entry.journal.reversesId;
      if (targetId != null) {
        final original = byId[targetId];
        _require(
          original != null &&
              original.journal.reversesId == null &&
              reversed.add(targetId),
          'invalid_reversal_target',
        );
        final inverse = original!.journal.reversed(
          id: entry.journal.id,
          effectiveDate: entry.journal.effectiveDate,
          reason: entry.journal.reason ?? '',
        );
        _require(
          _sameJournalValue(entry.journal, inverse) &&
              entry.journal.effectiveDate == original.journal.effectiveDate,
          'invalid_reversal_target',
        );
        _policy(
          entry.journal.policy,
          opening:
              original.sourceType ==
              RestaurantJournalSourceType.cutoverOpening.name,
        );
      }
      byId[entry.journal.id] = entry;
    }
    for (final entry in journals) {
      final corrected = entry.correctedFromJournalId;
      final replacement = entry.replacementJournalId;
      if (corrected != null) {
        _require(
          corrected != entry.journal.id && byId.containsKey(corrected),
          'invalid_correction_target',
        );
      }
      if (replacement != null) {
        final target = byId[replacement];
        _require(
          replacement != entry.journal.id &&
              target != null &&
              target.correctedFromJournalId ==
                  (entry.journal.reversesId ?? entry.journal.id),
          'invalid_correction_target',
        );
      }
      final visited = <String>{entry.journal.id};
      var link = entry.correctedFromJournalId;
      while (link != null) {
        _require(visited.add(link), 'invalid_correction_target');
        link = byId[link]?.correctedFromJournalId;
      }
    }
    if (cutoverState.openingJournalId != null) {
      final opening = byId[cutoverState.openingJournalId];
      _require(
        opening != null &&
            opening.sourceType ==
                RestaurantJournalSourceType.cutoverOpening.name &&
            opening.journal.reversesId == null &&
            opening.journal.effectiveDate == cutoverState.cutoverDate,
        'invalid_cutover_state',
      );
    }
    final opIds = <String>{};
    final revisions = <StorageFence, int>{};
    for (var i = 0; i < receipts.length; i++) {
      final r = receipts[i];
      r.identity.validate();
      _text(r.identity.operationId);
      _text(r.identity.canonicalPayloadIdentity);
      _optionalString(r.outcomePayload);
      _optionalString(r.rejectionCode);
      _optionalString(r.rejectionMessage);
      _text(r.fence.storeId);
      _text(r.fence.generation);
      _require(
        opIds.add(r.identity.operationId),
        'duplicate_receipt_operation_id',
      );
      _require(r.sequence == i + 1, 'invalid_receipt_sequence');
      _require(
        r.committedRevision > (revisions[r.fence] ?? 0),
        'invalid_receipt_revision',
      );
      revisions[r.fence] = r.committedRevision;
      _require(
        r.status == DurableCommandStatus.rejected
            ? r.rejectionCode != null &&
                  r.rejectionCode!.isNotEmpty &&
                  r.rejectionMessage != null &&
                  r.rejectionMessage!.isNotEmpty
            : r.rejectionCode == null && r.rejectionMessage == null,
        'invalid_receipt',
      );
    }
  });

  PortableJournalState addJournal(PortableJournalEntry entry) =>
      copyWith(journals: [...journals, entry]);

  PortableJournalState attachReceipt(DurableCommandReceipt receipt) =>
      copyWith(receipts: [...receipts, receipt]);

  factory PortableJournalState.fromJson(Map<String, Object?> json) =>
      _guard('invalid_payload', () {
        _keys(json, const {
          'version',
          'accountLineage',
          'sourceProvenance',
          'cutoverState',
          'account',
          'journals',
          'receipts',
          'requiredFeatures',
        });
        _require(
          json['version'] is int && json['version'] == 12,
          'unsupported_version',
        );
        final rawAccount = _map(json['account']);
        _require(
          rawAccount['version'] is int && rawAccount['version'] == 11,
          'invalid_account_payload',
        );
        final account = const LegacyAccountCodec().decodeJson(rawAccount);
        _require(
          _sameValue(rawAccount, account.toJson()),
          'invalid_account_payload',
        );
        final journals = <PortableJournalEntry>[];
        final byId = <String, BalancedJournal>{};
        for (final raw in _list(json['journals'])) {
          final map = _map(raw);
          final target = _optionalText(map['reversesId']);
          final entry = PortableJournalEntry.fromJson(
            map,
            originalJournal: byId[target],
          );
          _require(
            !byId.containsKey(entry.journal.id),
            'duplicate_journal_identity',
          );
          journals.add(entry);
          byId[entry.journal.id] = entry.journal;
        }
        return PortableJournalState(
          requiredFeatures: json['requiredFeatures'] == null
              ? const []
              : _list(json['requiredFeatures']).map((v) => _text(v)),
          accountLineage: _text(
            json['accountLineage'],
            code: 'invalid_account_lineage',
          ),
          account: account,
          sourceProvenance: PortableJournalSourceProvenance.fromJson(
            _map(json['sourceProvenance']),
          ),
          cutoverState: PortableJournalCutoverState.fromJson(
            _map(json['cutoverState']),
          ),
          journals: journals,
          receipts: [
            for (final raw in _list(json['receipts']))
              _receiptFromJson(_map(raw)),
          ],
        );
      });

  static DurableCommandReceipt _receiptFromJson(Map<String, Object?> json) {
    _keys(json, const {
      'identity',
      'status',
      'outcomePayload',
      'rejectionCode',
      'rejectionMessage',
      'committedRevision',
      'fence',
      'sequence',
    });
    final id = _map(json['identity']);
    final fence = _map(json['fence']);
    _keys(id, const {
      'operationId',
      'payloadVersion',
      'canonicalPayloadIdentity',
    });
    _keys(fence, const {'storeId', 'generation'});
    final status = _text(json['status']);
    _require(status == 'committed' || status == 'rejected', 'invalid_receipt');
    return DurableCommandReceipt(
      identity: DurableCommandIdentity(
        operationId: _text(id['operationId']),
        payloadVersion: _integer(id['payloadVersion']),
        canonicalPayloadIdentity: _text(id['canonicalPayloadIdentity']),
      ),
      status: status == 'committed'
          ? DurableCommandStatus.committed
          : DurableCommandStatus.rejected,
      outcomePayload: _optionalString(json['outcomePayload']),
      rejectionCode: _optionalString(json['rejectionCode']),
      rejectionMessage: _optionalString(json['rejectionMessage']),
      committedRevision: _integer(json['committedRevision']),
      fence: StorageFence(
        storeId: _text(fence['storeId']),
        generation: _text(fence['generation']),
      ),
      sequence: _integer(json['sequence']),
    );
  }

  Map<String, Object?> toJson() => {
    'version': version,
    if (requiredFeatures.isNotEmpty) 'requiredFeatures': requiredFeatures,
    'accountLineage': accountLineage,
    'sourceProvenance': sourceProvenance.toJson(),
    'cutoverState': cutoverState.toJson(),
    'account': account.toJson(),
    'journals': [for (final j in journals) j.toJson()],
    'receipts': [for (final r in receipts) _receiptToJson(r)],
  };

  static Map<String, Object?> _receiptToJson(DurableCommandReceipt r) => {
    'identity': {
      'operationId': r.identity.operationId,
      'payloadVersion': r.identity.payloadVersion,
      'canonicalPayloadIdentity': r.identity.canonicalPayloadIdentity,
    },
    'status': r.status.name,
    if (r.outcomePayload != null) 'outcomePayload': r.outcomePayload,
    if (r.rejectionCode != null) 'rejectionCode': r.rejectionCode,
    if (r.rejectionMessage != null) 'rejectionMessage': r.rejectionMessage,
    'committedRevision': r.committedRevision,
    'fence': {'storeId': r.fence.storeId, 'generation': r.fence.generation},
    'sequence': r.sequence,
  };
}

List<String> _requiredFeatureSnapshot(Iterable<String> features) {
  final values = <String>[];
  for (final feature in features) {
    _require(
      PortableJournalState.supportedRequiredFeatures.contains(feature) &&
          !values.contains(feature),
      'unsupported_required_feature',
    );
    values.add(feature);
  }
  return List.unmodifiable(values..sort());
}

T _guard<T>(String code, T Function() action) {
  try {
    return action();
  } on PortableJournalException {
    rethrow;
  } on AccountCodecException catch (error) {
    throw PortableJournalException(error.code, 'Invalid embedded account.');
  } catch (_) {
    throw PortableJournalException(code, 'Invalid portable journal state.');
  }
}

void _require(bool valid, String code) {
  if (!valid) {
    throw PortableJournalException(code, 'Invalid portable journal state.');
  }
}

Map<String, Object?> _map(Object? value) {
  _require(value is Map<String, Object?>, 'invalid_payload');
  return value as Map<String, Object?>;
}

List<Object?> _list(Object? value) {
  _require(value is List<Object?>, 'invalid_payload');
  return value as List<Object?>;
}

void _keys(Map<String, Object?> value, Set<String> allowed) =>
    _require(value.keys.every(allowed.contains), 'unsupported_fields');
String _text(Object? value, {String code = 'invalid_payload'}) {
  _require(value is String && value.isNotEmpty && value.trim() == value, code);
  final result = value as String;
  _require(utf8.decode(utf8.encode(result)) == result, code);
  return result;
}

String? _optionalText(Object? value) => value == null ? null : _text(value);
String? _optionalString(Object? value) {
  _require(value == null || value is String, 'invalid_payload');
  if (value is String) {
    _require(utf8.decode(utf8.encode(value)) == value, 'invalid_payload');
  }
  return value as String?;
}

int _integer(Object? value) {
  _require(value is int, 'invalid_payload');
  return value as int;
}

bool _boolean(Object? value) {
  _require(value is bool, 'invalid_payload');
  return value as bool;
}

BigInt _units(Object? value) {
  final text = _text(value);
  _require(RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(text), 'invalid_journal');
  return BigInt.parse(text);
}

DateOnly _date(Object? value) =>
    DateOnly.parse(_text(value), minimumYear: 1000, maximumYear: 9999);
void _timestamp(String value) {
  _text(value);
  final match = RegExp(
    r'^([0-9]{4}-[0-9]{2}-[0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(?:\.[0-9]{1,6})?(?:Z|[+-][0-9]{2}:[0-9]{2})$',
  ).firstMatch(value);
  _require(
    match != null && DateTime.tryParse(value) != null,
    'invalid_timestamp',
  );
  _date(match!.group(1));
  _require(
    int.parse(match.group(2)!) < 24 &&
        int.parse(match.group(3)!) < 60 &&
        int.parse(match.group(4)!) < 60,
    'invalid_timestamp',
  );
}

Map<String, Object?>? _optionalSnapshot(Map<String, Object?>? value) =>
    value == null
    ? null
    : _snapshot(value, Set<Object>.identity()) as Map<String, Object?>;
Object? _snapshot(Object? value, Set<Object> active) {
  if (value == null || value is bool) return value;
  if (value is String) {
    _optionalString(value);
    return value;
  }
  if (value is int) {
    _require(
      BigInt.from(value).abs() <=
          RestaurantJournalPolicies.maximumSafeAggregate,
      'invalid_metadata',
    );
    return value;
  }
  _require(
    value is Map<String, Object?> || value is List<Object?>,
    'invalid_metadata',
  );
  _require(active.length < 100 && active.add(value), 'invalid_metadata');
  try {
    if (value is Map<String, Object?>) {
      return Map<String, Object?>.unmodifiable(
        value.map((k, v) {
          _optionalString(k);
          return MapEntry(k, _snapshot(v, active));
        }),
      );
    }
    return List<Object?>.unmodifiable(
      (value as List<Object?>).map((v) => _snapshot(v, active)),
    );
  } finally {
    active.remove(value);
  }
}

void _policy(JournalPolicy p, {required bool opening}) {
  final cap = opening
      ? RestaurantJournalPolicies.opening
      : RestaurantJournalPolicies.standard;
  _require(
    p.currency == 'IQD' &&
        p.scale == 0 &&
        p.maximumLineUnits > BigInt.zero &&
        p.maximumSideUnits > BigInt.zero &&
        p.maximumLineUnits <= cap.maximumLineUnits &&
        p.maximumSideUnits <= cap.maximumSideUnits &&
        p.maximumLines >= 2 &&
        p.maximumLines <= cap.maximumLines,
    'invalid_journal',
  );
}

bool _sameJournalValue(BalancedJournal a, BalancedJournal b) =>
    a.policy.currency == b.policy.currency &&
    a.policy.scale == b.policy.scale &&
    a.policy.maximumLineUnits == b.policy.maximumLineUnits &&
    a.policy.maximumSideUnits == b.policy.maximumSideUnits &&
    a.policy.maximumLines == b.policy.maximumLines &&
    a.policy.allowZeroLines == b.policy.allowZeroLines &&
    a.totalUnits == b.totalUnits &&
    a.lines.length == b.lines.length &&
    List.generate(a.lines.length, (i) {
      final x = a.lines[i], y = b.lines[i];
      return x.accountId == y.accountId &&
          x.side == y.side &&
          x.amountUnits == y.amountUnits &&
          x.currency == y.currency &&
          x.scale == y.scale;
    }).every((same) => same);

bool _sameValue(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _sameValue(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => _sameValue(a[i], b[i])).every((x) => x);
  }
  return a == b;
}
