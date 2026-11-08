import 'package:madar_application/madar_application.dart';

import '../accounting/financial_session_undo.dart';
import '../accounting/journal_command_host.dart' show canonicalIdentity;
import 'account_document.dart';
import 'portable_journal_state.dart';
import 'accounts_repository.dart';
import 'portable_journal_codec.dart';
import 'portable_metadata_repository_bridge.dart';
import 'metadata_undo_plan.dart';

export 'metadata_undo_plan.dart';

bool _sameValue(Object? a, Object? b) =>
    canonicalIdentity({'value': a}) == canonicalIdentity({'value': b});

/// Saves a captured metadata compensation through the existing borrowed bridge.
/// No synthetic durable receipt or workspace rewrite is introduced.
final class MetadataSessionUndoAdapter implements FinancialUndoAdapter {
  MetadataSessionUndoAdapter({
    required this.repository,
    required this.bridge,
    this.label = 'تعديل البيانات',
  });
  final AccountsRepository repository;
  final PortableMetadataRepositoryBridge bridge;
  @override
  final String label;
  static bool _sameSnapshot(DocumentSnapshot a, DocumentSnapshot b) =>
      a.fence == b.fence &&
      a.revision == b.revision &&
      a.writeToken == b.writeToken &&
      a.payload == b.payload;
  @override
  FinancialUndoAttempt prepare({
    required PortableJournalState before,
    required PortableJournalState after,
    required PortableJournalState current,
  }) {
    final candidate = MetadataUndoPlan.prepare(
      before: before,
      after: after,
      current: current,
    ).candidate;
    return captureMetadataUndoAttempt(
      repository: repository,
      bridge: bridge,
      current: current,
      commit: (_) => repository.save(candidate),
    );
  }
}

/// Captures existing repository authority without refreshing or touching dirty
/// workspace state. The callback must use this exact expected revision.
FinancialUndoAttempt captureMetadataUndoAttempt({
  required AccountsRepository repository,
  required PortableMetadataRepositoryBridge bridge,
  required PortableJournalState current,
  required Future<CapabilityResult<AccountDocument>> Function(DocumentSnapshot)
  commit,
}) {
  final expected = repository.snapshot;
  final complete = bridge.snapshot;
  if (expected == null ||
      expected.fence != complete.fence ||
      expected.revision != complete.revision ||
      !_sameValue(
        const PortableJournalCodec().decodeState(complete.payload).toJson(),
        current.toJson(),
      )) {
    throw const FormatException('stale_undo_snapshot');
  }
  var ownsPending = false;
  return FinancialUndoAttempt.metadata(() async {
    CapabilityResult<AccountDocument> result;
    if (ownsPending) {
      result = await repository.reconcile();
    } else {
      final actual = repository.snapshot;
      if (actual == null ||
          !MetadataSessionUndoAdapter._sameSnapshot(actual, expected) ||
          !MetadataSessionUndoAdapter._sameSnapshot(
            bridge.snapshot,
            complete,
          )) {
        return const CapabilityFailure(
          'stale_undo_snapshot',
          'Metadata authority changed.',
        );
      }
      if (repository.hasUnknownWrite ||
          repository.hasUnknownWorkspaceWrite ||
          bridge.needsReadback) {
        return const CapabilityFailure(
          'busy',
          'Resolve the original operation first.',
        );
      }
      result = await commit(expected);
    }
    if (result is CapabilitySuccess<AccountDocument>) {
      ownsPending = false;
      return CapabilitySuccess(bridge.snapshot);
    }
    if (result is CapabilityFailure<AccountDocument>) {
      ownsPending = repository.hasUnknownWrite;
      return CapabilityFailure(
        ownsPending ? 'commit_unknown' : result.code,
        result.message,
      );
    }
    return const CapabilityCancelled();
  });
}
