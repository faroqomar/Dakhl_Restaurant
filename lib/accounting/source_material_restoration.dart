import '../accounts/account_document.dart';
import '../accounts/legacy_account_codec.dart';
import '../accounts/metadata_undo_plan.dart';
import 'journal_command_host.dart';

/// Source-only inline-material inverse composed into a financial correction.
/// Current unrelated material records/fields survive the same candidate write.
final class SourceMaterialRestoration {
  SourceMaterialRestoration({
    required Iterable<Object?> before,
    required Iterable<Object?> after,
  }) : values = freezeMap({'before': before.toList(), 'after': after.toList()});
  final Map<String, Object?> values;
  factory SourceMaterialRestoration.fromJson(Map<String, Object?> json) {
    if (json.keys.toSet().difference({'before', 'after'}).isNotEmpty) {
      throw const FormatException('invalid_material_restoration');
    }
    return SourceMaterialRestoration(
      before: json['before']! as List,
      after: json['after']! as List,
    );
  }
  Map<String, Object?> toJson() => values;
  AccountDocument apply(AccountDocument candidate) {
    if (canonicalIdentity({'materials': values['before']}) ==
        canonicalIdentity({'materials': values['after']})) {
      return candidate;
    }
    return MetadataUndoPlan.prepareAccounts(
      before: const LegacyAccountCodec().decodeJson({
        ...candidate.toJson(),
        'materials': values['before'],
      }),
      after: const LegacyAccountCodec().decodeJson({
        ...candidate.toJson(),
        'materials': values['after'],
      }),
      current: candidate,
    ).candidate;
  }
}
