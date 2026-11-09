import 'dart:convert';

import 'package:madar_application/madar_application.dart';

import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import 'restaurant_journal_mapper.dart';

/// Deeply freezes maps and nested collections so caller mutations cannot
/// affect the command's internal state.
Map<String, Object?> freezeMap(Map<String, Object?> map) =>
    CommandSnapshot().copy(map) as Map<String, Object?>;

/// Deeply freezes an iterable of items into an unmodifiable list with an
/// optional upper bound check.
List<T> freezeList<T>(
  Iterable<T> values, {
  int? maxCount,
  String errorCode = 'invalid_list_count',
}) {
  final items = <T>[];
  for (final value in values) {
    if (maxCount != null && items.length == maxCount) {
      throw FormatException(errorCode);
    }
    items.add(value);
  }
  return List.unmodifiable(items);
}

/// Recursively sorts map keys to generate deterministic JSON representations.
Object? canonicalize(Object? value) {
  if (value is Map<String, Object?>) {
    final keys = value.keys.toList()..sort();
    return {for (final key in keys) key: canonicalize(value[key])};
  }
  if (value is List) {
    return value.map(canonicalize).toList();
  }
  return value;
}

/// Computes a bounded, deterministic, sorted JSON payload identity string.
String canonicalIdentity(Map<String, Object?> values) {
  final payload = jsonEncode(canonicalize(freezeMap(values)));
  if (utf8.encode(payload).length > DocumentLimits.accountBytes) {
    throw const FormatException('command_payload_too_large');
  }
  return payload;
}

/// Validates command payload data structure, size, nesting, and value ranges.
final class CommandSnapshot {
  final active = Set<Object>.identity();
  int bytes = 0;

  void take(int count) {
    bytes += count;
    if (bytes > DocumentLimits.accountBytes) {
      throw const FormatException('command_payload_too_large');
    }
  }

  void text(String value) {
    if (value.length > DocumentLimits.accountBytes - bytes) {
      throw const FormatException('command_payload_too_large');
    }
    final encoded = utf8.encode(value);
    if (utf8.decode(encoded) != value) {
      throw const FormatException('invalid_command_payload');
    }
    take(encoded.length + 2);
  }

  Object? copy(Object? value) {
    if (value == null || value is bool) {
      take(5);
      return value;
    }
    if (value is String) {
      text(value);
      return value;
    }
    if (value is num && value.isFinite) {
      if (value is int &&
          BigInt.from(value).abs() >
              RestaurantJournalPolicies.maximumSafeAggregate) {
        throw const FormatException('invalid_command_payload');
      }
      take(value.toString().length);
      return value;
    }
    if ((value is! Map<String, Object?> && value is! List<Object?>) ||
        active.length >= 100 ||
        !active.add(value)) {
      throw const FormatException('invalid_command_payload');
    }
    take(2);
    try {
      if (value is Map<String, Object?>) {
        return Map<String, Object?>.unmodifiable(
          value.map((key, item) {
            text(key);
            take(2);
            return MapEntry(key, copy(item));
          }),
        );
      }
      return List<Object?>.unmodifiable(
        (value as List<Object?>).map((item) {
          take(1);
          return copy(item);
        }),
      );
    } finally {
      active.remove(value);
    }
  }
}

/// Enforces app lineage at every coordinator decode/extract/attach/encode,
/// and validates replayed outcome payloads against the current complete state.
final class LineageScopedJournalCodec
    implements DurableCommandStateCodec<PortableJournalState> {
  LineageScopedJournalCodec({
    required this.inner,
    required this.accountLineage,
    required this.targetIdentity,
    this.validateReplayOutcome,
    this.expectedRevision,
  });

  final PortableJournalCodec inner;
  final String accountLineage;
  final DurableCommandIdentity targetIdentity;
  final bool Function(String outcomePayload, PortableJournalState state)?
  validateReplayOutcome;

  final int? expectedRevision;
  bool revisionMismatch = false;
  bool lineageMismatch = false;
  PortableJournalState? decodedState;

  PortableJournalState check(PortableJournalState state) {
    if (state.accountLineage != accountLineage) {
      lineageMismatch = true;
      throw const FormatException('account_lineage_mismatch');
    }
    return state;
  }

  @override
  PortableJournalState decodeState(String payload) {
    final state = check(inner.decodeState(payload));
    decodedState = state;
    return state;
  }

  @override
  String encodeState(PortableJournalState state) =>
      inner.encodeState(check(state));

  @override
  Iterable<DurableCommandReceipt> extractReceipts(PortableJournalState state) {
    final receipts = inner.extractReceipts(check(state));
    for (final receipt in receipts) {
      if (receipt.identity == targetIdentity &&
          receipt.status == DurableCommandStatus.committed) {
        final payload = receipt.outcomePayload;
        if (payload == null) {
          throw const FormatException('missing_outcome_payload');
        }
        if (validateReplayOutcome != null &&
            !validateReplayOutcome!(payload, state)) {
          throw const FormatException('outcome_mismatch');
        }
      }
    }
    return receipts;
  }

  @override
  PortableJournalState attachReceipt(
    PortableJournalState state,
    DurableCommandReceipt receipt,
  ) {
    if (expectedRevision != null &&
        receipt.identity == targetIdentity &&
        receipt.committedRevision != expectedRevision! + 1) {
      revisionMismatch = true;
      throw const FormatException('stale_expected_revision');
    }
    return check(inner.attachReceipt(check(state), receipt));
  }
}

/// App-level complete-state command host coordinating single-store atomic
/// execution, fence validation, lineage checks, and proposal evaluation.
final class JournalCommandHost {
  JournalCommandHost({
    required this.store,
    DurableCommandCoordinator? coordinator,
    PortableJournalCodec? codec,
  }) : coordinator = coordinator ?? DurableCommandCoordinator(store: store),
       codec = codec ?? const PortableJournalCodec() {
    if (!identical(this.coordinator.store, store)) {
      throw ArgumentError('Coordinator must use the same store owner.');
    }
  }

  final LocalDocumentWorkspaceStore store;
  final DurableCommandCoordinator coordinator;
  final PortableJournalCodec codec;

  /// Executes any durable restaurant complete-state command.
  Future<DurableCommandResult<TOutcome>> execute<TOutcome>({
    required DurableCommandIdentity identity,
    required String accountLineage,
    required StorageFence? expectedFence,
    int? expectedRevision,
    required bool Function(String outcomePayload, PortableJournalState state)
    validateReplayOutcome,
    required TOutcome Function(String outcomePayload) parseOutcome,
    required DurableProposalEvaluation<PortableJournalState, TOutcome> Function(
      PortableJournalState state,
      StorageFence fence,
    )
    evaluateProposal,
    String missingAuthorityFenceMessage =
        'Capture account authority before submitting a command.',
    String accountLineageMismatchCode = 'account_lineage_mismatch',
    String cutoverGatedCode = 'cutover_gated',
  }) async {
    if (expectedFence == null) {
      return DurableCommandFailure(
        code: 'missing_authority_fence',
        message: missingAuthorityFenceMessage,
      );
    }

    final targetFence = expectedFence;
    final scoped = LineageScopedJournalCodec(
      inner: codec,
      accountLineage: accountLineage,
      targetIdentity: identity,
      validateReplayOutcome: validateReplayOutcome,
      expectedRevision: expectedRevision,
    );

    final result =
        await coordinator.executeCommand<PortableJournalState, TOutcome>(
          identity: identity,
          codec: scoped,
          expectedFence: targetFence,
          replayedOutcomeMapper: (receipt) {
            final payload = receipt.outcomePayload;
            if (payload == null || scoped.decodedState == null) {
              throw const FormatException('invalid_outcome_payload');
            }
            return parseOutcome(payload);
          },
          proposal: (state, fence) {
            if (state == null || state.accountLineage != accountLineage) {
              return DurableProposalEvaluation.reject(
                rejectionCode: accountLineageMismatchCode,
                rejectionMessage: 'Account lineage mismatch in proposal.',
              );
            }

            if (fence != targetFence) {
              return const DurableProposalEvaluation.reject(
                rejectionCode: DurableCommandErrorCodes.staleAuthorityFence,
                rejectionMessage: 'Storage fence mismatch in proposal.',
              );
            }

            if (state.cutoverState.isGated ||
                !state.cutoverState.hasActivePosting ||
                state.cutoverState.cutoverDate == null) {
              return DurableProposalEvaluation.reject(
                rejectionCode: cutoverGatedCode,
                rejectionMessage: 'Posting is refused while cutover state is gated or inactive.',
              );
            }

            return evaluateProposal(state, fence ?? targetFence);
          },
        );

    if (scoped.revisionMismatch && result is DurableCommandFailure<TOutcome>) {
      return DurableCommandFailure(
        code: 'stale_snapshot',
        message: 'Captured document revision changed.',
        latestSnapshot: result.latestSnapshot,
      );
    }
    if (scoped.lineageMismatch && result is DurableCommandFailure<TOutcome>) {
      return DurableCommandFailure(
        code: accountLineageMismatchCode,
        message: 'Account lineage does not match the captured intent.',
        latestSnapshot: result.latestSnapshot,
      );
    }

    return result;
  }
}
