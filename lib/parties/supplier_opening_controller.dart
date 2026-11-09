import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';

import '../accounts/account_document.dart';
import '../accounts/legacy_account_codec.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import '../accounting/journal_command_host.dart';
import '../accounting/restaurant_journal_mapper.dart';
import 'supplier_opening_commands.dart';

/// Borrowed-store owner for explicitly initialized and verified portable state.
final class SupplierOpeningController extends ChangeNotifier {
  SupplierOpeningController({
    required LocalDocumentWorkspaceStore store,
    required DocumentSnapshot snapshot,
    required this.isWriteBlocked,
    this.onSnapshot,
    this.acceptedOpeningEquityAccountId,
    RestaurantJournalMapper? mapper,
  }) : _snapshot = snapshot,
       _state = const PortableJournalCodec().decodeState(snapshot.payload),
       coordinator = SupplierOpeningCoordinator(
         host: JournalCommandHost(store: store),
         mapper: mapper,
       ),
       authorityFence = snapshot.fence;

  final SupplierOpeningCoordinator coordinator;
  final String? acceptedOpeningEquityAccountId;
  final StorageFence authorityFence;
  final bool Function() isWriteBlocked;
  final void Function(DocumentSnapshot)? onSnapshot;
  DocumentSnapshot _snapshot;
  PortableJournalState _state;
  SupplierOpeningCommand? _pending;
  bool _busy = false, _disposed = false;
  String? errorCode;
  bool get busy => _busy;
  bool get needsReadback => _pending != null;
  bool get canWrite =>
      !_state.cutoverState.isGated &&
      acceptedOpeningEquityAccountId ==
          coordinator.mapper.profile.openingEquityAccountId;
  DocumentSnapshot get snapshot => _snapshot;
  AccountDocument get account => _state.account;
  SupplierOpeningCommand? get pendingCommand => _pending;

  List<SupplierOpeningCommand> amendments(String supplierId) {
    SupplierOpeningHistory.validate(_state, supplierId, coordinator.mapper);
    final values = <SupplierOpeningCommand>[];
    for (final receipt in _state.receipts.where(
      (r) => r.status == DurableCommandStatus.committed,
    )) {
      try {
        final intent = jsonDecode(receipt.identity.canonicalPayloadIdentity);
        if (intent is Map &&
            intent['commandType'] == SupplierOpeningCommand.commandType &&
            intent['supplierId'] == supplierId) {
          values.add(
            SupplierOpeningCommand.fromIntent(
              intent.cast<String, Object?>(),
              coordinator.mapper,
            ),
          );
        }
      } on FormatException {
        // Other operation families can retain non-JSON payload identities.
      }
    }
    return List.unmodifiable(values);
  }

  SupplierOpeningCommand capture({
    required String operationId,
    required String supplierId,
    required BigInt openingBalance,
    required String reason,
    required String recordedAt,
    Map<String, Object?> supplierValues = const {},
  }) {
    if (_disposed || busy || needsReadback || isWriteBlocked()) {
      throw const FormatException('busy');
    }
    if (!canWrite) {
      throw const FormatException('unmapped_supplier_opening_equity');
    }
    if (supplierValues.keys.any(
      (k) => !{'name', 'phone', 'note', 'categoryId', 'archived'}.contains(k),
    )) {
      throw const FormatException('invalid_supplier_metadata_change');
    }
    final rows = SupplierOpeningHistory.suppliers(_state, supplierId);
    if (rows.length > 1) throw const FormatException('ambiguous_supplier');
    final before = rows.isEmpty ? null : rows.single;
    final after = <String, Object?>{
      if (before != null)
        ...before
      else ...{
        'id': supplierId,
        'name': '',
        'phone': '',
        'note': '',
        'categoryId': '',
        'archived': false,
        'materials': <Object?>[],
      },
      ...supplierValues,
      'openingBalance': openingBalance.toInt(),
    };
    final raw = <String, Object?>{..._state.account.toJson()};
    raw['suppliers'] = [
      for (final row in raw['suppliers']! as List)
        if ((row as Map)['id'] == supplierId) after else row,
      if (before == null) after,
    ];
    late AccountDocument normalized;
    try {
      normalized = const LegacyAccountCodec().decodeJson(raw);
    } on AccountCodecException catch (error) {
      throw FormatException(error.code);
    }
    final normalizedAfter = (normalized.toJson()['suppliers']! as List)
        .cast<Map<String, Object?>>()
        .singleWhere((s) => s['id'] == supplierId);
    final base = SupplierOpeningHistory.baseOpening(_state);
    final family = SupplierOpeningHistory.validate(
      _state,
      supplierId,
      coordinator.mapper,
    );
    return SupplierOpeningCommand(
      operationId: operationId,
      accountLineage: _state.accountLineage,
      fence: authorityFence,
      supplierId: supplierId,
      recordedAt: recordedAt,
      reason: reason,
      cutoverDate: _state.cutoverState.cutoverDate!,
      baseOpeningJournalId: base.journal.id,
      baseOpeningSha256: SupplierOpeningHistory.openingHash(base),
      acceptedOpeningEquityAccountId: acceptedOpeningEquityAccountId,
      supplierBefore: before,
      supplierAfter: normalizedAfter,
      previousOperationId: family.lastOperationId,
      mapper: coordinator.mapper,
    );
  }

  CapabilityResult<void> acceptSnapshot(DocumentSnapshot next) {
    if (_disposed || _busy || needsReadback) {
      return const CapabilityFailure(
        'busy',
        'Resolve the opening operation first.',
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
    _snapshot = next;
    _state = state;
  }

  Future<DurableCommandResult<SupplierOpeningOutcome>> retry() async {
    final command = _pending;
    if (command == null) {
      return const DurableCommandFailure(
        code: 'no_pending_operation',
        message: 'No opening needs readback.',
      );
    }
    return submit(command);
  }

  Future<DurableCommandResult<SupplierOpeningOutcome>> submit(
    SupplierOpeningCommand command,
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
        message: 'Retry the exact opening operation first.',
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
        case DurableCommandFailure(
          :final code,
          :final latestSnapshot,
          :final receipt,
        ):
          errorCode = code;
          if (latestSnapshot != null && receipt != null) {
            _accept(latestSnapshot);
            onSnapshot?.call(latestSnapshot);
          }
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
        message: 'Supplier opening acknowledgement needs readback.',
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
