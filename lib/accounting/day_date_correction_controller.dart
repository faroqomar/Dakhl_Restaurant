import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';

import '../accounts/account_document.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import 'day_date_correction_commands.dart';
import 'day_date_plan.dart';
import 'journal_command_host.dart';
import 'restaurant_journal_mapper.dart';

/// Borrowed-store owner for a caller-initialized portable account. Composition
/// must include this owner's busy/readback state in reciprocal write exclusion.
final class DayDateCorrectionController extends ChangeNotifier {
  DayDateCorrectionController({
    required LocalDocumentWorkspaceStore store,
    required DocumentSnapshot snapshot,
    required this.isWriteBlocked,
    this.onSnapshot,
    this.acceptedCounterAccountId,
    RestaurantJournalMapper? mapper,
  }) : _snapshot = snapshot,
       _state = const PortableJournalCodec().decodeState(snapshot.payload),
       coordinator = DayDateCorrectionCoordinator(
         host: JournalCommandHost(store: store),
         mapper: mapper,
       ),
       authorityFence = snapshot.fence;
  final DayDateCorrectionCoordinator coordinator;
  final String? acceptedCounterAccountId;
  final StorageFence authorityFence;
  final bool Function() isWriteBlocked;
  final void Function(DocumentSnapshot)? onSnapshot;
  DocumentSnapshot _snapshot;
  PortableJournalState _state;
  DayDateCorrectionCommand? _pending;
  bool _busy = false, _disposed = false;
  String? errorCode;
  bool get busy => _busy;
  bool get needsReadback => _pending != null;
  DocumentSnapshot get snapshot => _snapshot;
  AccountDocument get account => _state.account;
  DayDatePlan preview({
    required String from,
    required String to,
    String? end,
  }) => DayDatePlan.create(account, from: from, to: to, end: end);
  DayDateCorrectionCommand capture({
    required String operationId,
    required String from,
    required String to,
    String? end,
    required String reason,
    required String recordedAt,
    DurableCommandIdentity? inverseOf,
  }) {
    if (_busy || needsReadback || isWriteBlocked()) {
      throw const FormatException('busy');
    }
    return DayDateCorrectionCommand.capture(
      state: _state,
      fence: authorityFence,
      expectedRevision: _snapshot.revision,
      operationId: operationId,
      from: from,
      to: to,
      end: end,
      reason: reason,
      recordedAt: recordedAt,
      mapper: coordinator.mapper,
      acceptedCounterAccountId: acceptedCounterAccountId,
      inverseOf: inverseOf,
    );
  }

  CapabilityResult<void> acceptSnapshot(DocumentSnapshot next) {
    if (_disposed || _busy || needsReadback) {
      return const CapabilityFailure(
        'busy',
        'Resolve the current date correction first.',
      );
    }
    try {
      _accept(next);
      _notify();
      return const CapabilitySuccess(null);
    } on Object {
      return const CapabilityFailure(
        'stale_snapshot',
        'Snapshot was not accepted.',
      );
    }
  }

  void _accept(DocumentSnapshot next) {
    if (next.fence != authorityFence ||
        next.revision < _snapshot.revision ||
        (next.revision == _snapshot.revision &&
            (next.payload != _snapshot.payload ||
                next.writeToken != _snapshot.writeToken))) {
      throw const FormatException('stale_snapshot');
    }
    final state = const PortableJournalCodec().decodeState(next.payload);
    if (state.accountLineage != _state.accountLineage) {
      throw const FormatException('account_lineage_mismatch');
    }
    _state = state;
    _snapshot = next;
  }

  Future<DurableCommandResult<DayDateCorrectionOutcome>> retry() async {
    final command = _pending;
    if (command == null) {
      return const DurableCommandFailure(
        code: 'no_pending_operation',
        message: 'No date correction needs readback.',
      );
    }
    return submit(command);
  }

  Future<DurableCommandResult<DayDateCorrectionOutcome>> submit(
    DayDateCorrectionCommand command,
  ) async {
    if (_disposed || _busy || isWriteBlocked()) {
      return const DurableCommandFailure(
        code: 'busy',
        message: 'Another workflow is pending.',
      );
    }
    if (_pending != null && _pending!.identity != command.identity) {
      return const DurableCommandFailure(
        code: 'commit_unknown',
        message: 'Resolve the captured date correction first.',
      );
    }
    if (command.accountLineage != _state.accountLineage ||
        command.fence != authorityFence) {
      return const DurableCommandFailure(
        code: 'stale_authority_fence',
        message: 'Account authority changed.',
      );
    }
    _busy = true;
    _pending = command;
    errorCode = null;
    _notify();
    try {
      final result = await coordinator.execute(command);
      switch (result) {
        case DurableCommandSuccess(:final snapshot) ||
            DurableCommandReplayed(:final snapshot):
          _accept(snapshot);
          _pending = null;
          onSnapshot?.call(snapshot);
        case DurableCommandFailure(:final code):
          errorCode = code;
          if (code != DurableCommandErrorCodes.commitUnknown &&
              code != DocumentErrorCodes.pendingWrite) {
            _pending = null;
          }
      }
      return result;
    } on Object {
      errorCode = 'commit_unknown';
      return const DurableCommandFailure(
        code: 'commit_unknown',
        message: 'Date correction acknowledgement is unresolved.',
      );
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
