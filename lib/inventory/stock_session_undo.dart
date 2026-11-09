import 'package:madar_domain/madar_domain.dart';

import '../accounting/financial_session_undo.dart';
import '../accounting/journal_command_host.dart' show canonicalIdentity;
import '../accounts/accounts_repository.dart';
import '../accounts/account_document.dart';
import '../accounts/metadata_session_undo.dart';
import '../accounts/portable_journal_state.dart';
import '../accounts/portable_metadata_repository_bridge.dart';
import '../catalog/catalog_formatters.dart';
import 'inventory_commands.dart';

/// Reverses one newly posted stock movement through the established inventory
/// command. Original movement history is retained on its original date.
final class StockMovementSessionUndoAdapter implements FinancialUndoAdapter {
  StockMovementSessionUndoAdapter({
    required this.repository,
    required this.bridge,
    required this.reason,
    this.label = 'حركة المخزن',
  });
  final AccountsRepository repository;
  final PortableMetadataRepositoryBridge bridge;
  final String reason;
  @override
  final String label;
  static bool _same(Object? a, Object? b) =>
      canonicalIdentity({'value': a}) == canonicalIdentity({'value': b});
  @override
  FinancialUndoAttempt prepare({
    required PortableJournalState before,
    required PortableJournalState after,
    required PortableJournalState current,
  }) {
    if (LegacyText.trimJavaScript(reason).isEmpty) {
      throw const FormatException('undo_requires_reason');
    }
    if (before.accountLineage != after.accountLineage ||
        current.accountLineage != after.accountLineage ||
        !_same(
          before.copyWith(account: after.account).toJson(),
          after.toJson(),
        )) {
      throw const FormatException('undo_stock_transition_not_supported');
    }
    final plan = StockSessionUndoPlan.prepareAccounts(
      before: before.account,
      after: after.account,
      current: current.account,
    );
    final commands = InventoryCommands(repository);
    final inverseId = CatalogFormatters.generateId('undo-stock');
    final recordedAt = CatalogFormatters.currentIsoTimestamp();
    return captureMetadataUndoAttempt(
      repository: repository,
      bridge: bridge,
      current: current,
      commit: (expected) => commands.reverseMovement(
        plan.entryId,
        archiveCreatedProductId: plan.archiveCreatedProductId,
        newId: inverseId,
        reason: reason,
        createdAt: recordedAt,
        expected: expected,
      ),
    );
  }
}

/// One atomic stock compensation, optionally archiving the product introduced
/// with its opening. Both historical product and movement identities survive.
final class StockSessionUndoPlan {
  const StockSessionUndoPlan._(this.entryId, this.archiveCreatedProductId);
  final String entryId;
  final String? archiveCreatedProductId;
  static bool _same(Object? a, Object? b) =>
      canonicalIdentity({'v': a}) == canonicalIdentity({'v': b});
  factory StockSessionUndoPlan.prepareAccounts({
    required AccountDocument before,
    required AccountDocument after,
    required AccountDocument current,
  }) {
    final a = {...before.toJson()}, b = {...after.toJson()};
    final oldEntries = a.remove('stockEntries')! as List;
    final newEntries = b.remove('stockEntries')! as List;
    if (newEntries.length != oldEntries.length + 1 ||
        !_same(newEntries.take(oldEntries.length).toList(), oldEntries)) {
      throw const FormatException('undo_stock_transition_not_supported');
    }
    final entry = (newEntries.last as Map).cast<String, Object?>();
    if (entry['reversesId'] != null) {
      throw const FormatException('undo_stock_reversal_not_supported');
    }
    String? archive;
    if (!_same(a, b)) {
      final oldProducts = a.remove('products')! as List,
          newProducts = b.remove('products')! as List;
      if (!_same(a, b) ||
          newProducts.length != oldProducts.length + 1 ||
          !_same(newProducts.take(oldProducts.length).toList(), oldProducts)) {
        throw const FormatException('undo_stock_transition_not_supported');
      }
      final product = newProducts.last as Map;
      if (product['id'] != entry['productId'] ||
          entry['kind'] != 'opening' ||
          product['trackStock'] != true) {
        throw const FormatException('undo_stock_transition_not_supported');
      }
      archive = product['id']! as String;
      final found = (current.toJson()['products'] as List)
          .cast<Map<String, Object?>>()
          .where((p) => p['id'] == archive)
          .toList();
      if (found.length != 1 || !_same(found.single, product)) {
        throw const FormatException('undo_stock_conflict');
      }
    }
    final id = entry['id']! as String;
    final entries = (current.toJson()['stockEntries']! as List).cast<Map>();
    final matching = entries.where((e) => e['id'] == id).toList();
    if (matching.length != 1 ||
        !_same(matching.single, entry) ||
        entries.any((e) => e['reversesId'] == id)) {
      throw const FormatException('undo_stock_conflict');
    }
    return StockSessionUndoPlan._(id, archive);
  }
}
