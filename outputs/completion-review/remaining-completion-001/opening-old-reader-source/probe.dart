import 'dart:convert';
import 'dart:io';
import 'accounts/portable_journal_state.dart' as old;
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
void main() {
 final base = old.PortableJournalState(
   accountLineage: 'synthetic-old-reader',
   account: const LegacyAccountCodec().empty(),
   sourceProvenance: const old.PortableJournalSourceProvenance(sourceVersion: 11, enrolledAt: '2026-11-08T00:00:00Z', migrated: false),
   cutoverState: old.PortableJournalCutoverState.gated(),
 ).toJson();
 old.PortableJournalState.fromJson(base);
 final feature = <String,Object?>{...base, 'requiredFeatures': ['supplierOpeningAmendments-v1']};
 try { old.PortableJournalState.fromJson(feature); stderr.writeln('Old reader incorrectly accepted required feature'); exitCode=1; }
 on old.PortableJournalException catch (error) {
   if (error.code != 'unsupported_fields') {stderr.writeln(error.code); exitCode=1; return;}
   print(jsonEncode({'oldBaselineAccepted': true, 'openingRequiredFeatureRejected': true, 'rejectionCode': error.code}));
 }
}
