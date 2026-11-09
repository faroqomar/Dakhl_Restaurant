import '../accounts/account_document.dart';
import '../accounts/legacy_account_codec.dart';
import 'journal_command_host.dart';

/// Optional captured source ordering for a compensating edit. Omission preserves
/// existing command identity and normal source editing behavior.
final class SourceRecordOrder {
  SourceRecordOrder({
    required this.position,
    required Iterable<String> siblingIds,
  }) : siblingIds = List.unmodifiable(siblingIds) {
    if (position < 0 ||
        position > this.siblingIds.length ||
        this.siblingIds.toSet().length != this.siblingIds.length) {
      throw const FormatException('invalid_source_order');
    }
  }
  final int position;
  final List<String> siblingIds;
  Map<String, Object?> toJson() => {
    'position': position,
    'siblingIds': siblingIds,
  };
  factory SourceRecordOrder.fromJson(Map<String, Object?> json) {
    if (json.keys.toSet().difference({'position', 'siblingIds'}).isNotEmpty) {
      throw const FormatException('invalid_source_order');
    }
    return SourceRecordOrder(
      position: json['position']! as int,
      siblingIds: (json['siblingIds']! as List).cast<String>(),
    );
  }
  AccountDocument apply(
    AccountDocument candidate,
    String collection,
    String id,
  ) {
    final rows = (candidate.toJson()[collection]! as List)
        .cast<Map<String, Object?>>();
    final siblings = applyRows(rows, id);
    return const LegacyAccountCodec().decodeJson({
      ...candidate.toJson(),
      collection: siblings,
    });
  }

  List<Map<String, Object?>> applyRows(
    Iterable<Map<String, Object?>> rows,
    String id,
  ) {
    final selected = rows.where((r) => r['id'] == id).toList(),
        siblings = rows.where((r) => r['id'] != id).toList();
    if (selected.length != 1 ||
        canonicalIdentity({'ids': siblings.map((r) => r['id']).toList()}) !=
            canonicalIdentity({'ids': siblingIds}) ||
        siblingIds.contains(id)) {
      throw const FormatException('source_order_changed');
    }
    siblings.insert(position, selected.single);
    return siblings;
  }
}
