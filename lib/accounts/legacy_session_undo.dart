import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';

import '../accounting/journal_command_host.dart' show canonicalIdentity;
import '../catalog/catalog_formatters.dart';
import '../inventory/inventory_commands.dart';
import '../inventory/stock_session_undo.dart';
import 'account_document.dart';
import 'accounts_repository.dart';
import 'metadata_session_undo.dart';

/// Source-only undo for the normal account path. Financial writes remain gated;
/// metadata uses the same whitelist as portable accounts and stock uses reversals.
final class LegacySessionUndoController extends ChangeNotifier {
  LegacySessionUndoController({
    required this.repository,
    required this.isWriteBlocked,
  });
  final AccountsRepository repository;
  final bool Function() isWriteBlocked;
  DocumentSnapshot? _latest;
  final _stack = <(AccountDocument, AccountDocument)>[];
  AccountDocument? _pending;
  bool _busy = false, _disposed = false;
  String? errorCode;
  bool get busy => _busy;
  bool get needsReadback => _pending != null;
  bool get canUndo => !_busy && !isWriteBlocked() && _stack.isNotEmpty;
  int get length => _stack.length;
  bool _equal(Object? a, Object? b) =>
      canonicalIdentity({'v': a}) == canonicalIdentity({'v': b});
  void observe() {
    if (_disposed || _busy || needsReadback) return;
    final next = repository.snapshot;
    if (next == null) return;
    final old = _latest;
    _latest = next;
    if (old == null || old.fence != next.fence) {
      _stack.clear();
    } else if (old.payload != next.payload) {
      final before = repository.codec.decodeBytes(utf8.encode(old.payload));
      final after = repository.document!;
      if (!_equal(before.toJson()['sales'], after.toJson()['sales']) ||
          !_equal(
            before.toJson()['saleReturns'],
            after.toJson()['saleReturns'],
          )) {
        _stack.clear();
      } else {
        _stack.add((before, after));
        if (_stack.length > 30) _stack.removeAt(0);
      }
    }
    notifyListeners();
  }

  CapabilityFailure<void> _fail(String code) {
    errorCode = code;
    return CapabilityFailure(code, 'The undo was not confirmed.');
  }

  Future<CapabilityResult<void>> undo() async {
    if (_disposed || _busy || isWriteBlocked()) return _fail('busy');
    if (_stack.isEmpty) return _fail('nothing_to_undo');
    final current = repository.document, expected = repository.snapshot;
    if (current == null ||
        expected == null ||
        expected.fence != _latest?.fence ||
        expected.revision != _latest?.revision ||
        expected.payload != _latest?.payload) {
      return _fail('stale_undo_snapshot');
    }
    _busy = true;
    notifyListeners();
    try {
      CapabilityResult<AccountDocument> result;
      if (_pending != null) {
        result = await repository.reconcile();
      } else {
        if (repository.hasUnknownWrite || repository.hasUnknownWorkspaceWrite) {
          return _fail('commit_unknown');
        }
        final (before, after) = _stack.last;
        final oldJson = before.toJson(), afterJson = after.toJson();
        if (!_equal(oldJson['stockEntries'], afterJson['stockEntries'])) {
          final plan = StockSessionUndoPlan.prepareAccounts(
            before: before,
            after: after,
            current: current,
          );
          result = await InventoryCommands(repository).reverseMovement(
            plan.entryId,
            archiveCreatedProductId: plan.archiveCreatedProductId,
            newId: CatalogFormatters.generateId('undo-stock'),
            reason: 'تراجع عن حركة المخزن السابقة',
            createdAt: CatalogFormatters.currentIsoTimestamp(),
            expected: expected,
          );
          // Retain exact attempted candidate on uncertain repository writes.
          if (repository.hasUnknownWrite) {
            // Reconciliation validates the repository's captured token/payload.
            _pending = current;
          }
        } else {
          final candidate = MetadataUndoPlan.prepareAccounts(
            before: before,
            after: after,
            current: current,
          ).candidate;
          _pending = candidate;
          result = await repository.save(candidate);
        }
      }
      if (result is CapabilitySuccess<AccountDocument>) {
        _latest = repository.snapshot;
        _stack.removeLast();
        _pending = null;
        errorCode = null;
        return const CapabilitySuccess(null);
      }
      final code = result is CapabilityFailure<AccountDocument>
          ? result.code
          : 'cancelled';
      if (code != 'commit_unknown' && code != DocumentErrorCodes.pendingWrite) {
        _pending = null;
      }
      return _fail(code);
    } on FormatException catch (error) {
      _pending = null;
      return _fail(error.message);
    } on Object {
      if (!repository.hasUnknownWrite) _pending = null;
      return _fail(
        repository.hasUnknownWrite ? 'commit_unknown' : 'undo_not_supported',
      );
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
