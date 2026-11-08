import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/settings/portable_settings_controller.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;

void main() {
  const codec = PortableJournalCodec();
  late FixtureStore store;
  late PortableSettingsController controller;
  late PortableJournalState initial;
  var blocked = false;
  setUp(() async {
    blocked = false;
    final date = DateOnly.parse(
      '2026-11-01',
      minimumYear: 1000,
      maximumYear: 9999,
    );
    final opening = RestaurantJournalMapper().mapVerifiedCutoverOpening(
      journalId: 'opening',
      effectiveDate: date,
      verifiedPhysicalRegisterCash: BigInt.from(10000),
      verifiedCashboxBalance: BigInt.zero,
      verifiedSupplierDebts: {},
    );
    initial = PortableJournalState(
      accountLineage: 'lineage',
      account: const LegacyAccountCodec().empty(),
      sourceProvenance: const PortableJournalSourceProvenance(
        sourceVersion: 11,
        enrolledAt: '2026-11-01T00:00:00Z',
        migrated: false,
      ),
      cutoverState: PortableJournalCutoverState.established(
        cutoverDate: date,
        openingJournalId: 'opening',
      ),
      journals: [
        PortableJournalEntry(
          journal: opening.journal,
          sourceType: RestaurantJournalSourceType.cutoverOpening.name,
          sourceRecordId: 'opening-source',
          recordedAt: '2026-11-01T00:00:00Z',
        ),
      ],
      receipts: [
        const DurableCommandReceipt(
          identity: DurableCommandIdentity(
            operationId: 'previous',
            payloadVersion: 1,
            canonicalPayloadIdentity: 'previous-payload',
          ),
          status: DurableCommandStatus.committed,
          committedRevision: 1,
          fence: StorageFence(
            storeId: 'historic-store',
            generation: 'historic-generation',
          ),
          sequence: 1,
          outcomePayload: '{"saved":true}',
        ),
      ],
    );
    store = FixtureStore();
    final result = await store.writeDocument(
      codec.encodeState(initial),
      writeToken: 'initial',
    );
    controller = PortableSettingsController(
      store: store,
      snapshot: (result as CapabilitySuccess<DocumentSnapshot>).value,
      isWriteBlocked: () => blocked,
    );
  });
  tearDown(() => controller.dispose());

  test(
    'metadata save preserves the complete journal envelope and revisions',
    () async {
      controller.replace(
        controller.values.copyWith(name: ' مطعم ', footer: 'شكراً'),
      );
      expect(await controller.save(), isA<CapabilitySuccess<void>>());
      final saved = codec.decodeState(store.document!.payload);
      expect(saved.account.preferences.restaurant['name'], 'مطعم');
      expect(saved.account.preferences.restaurant['footer'], 'شكراً');
      final restored = saved.copyWith(account: initial.account);
      expect(restored.toJson(), initial.toJson());
      expect(controller.snapshot, same(store.document));
      expect(controller.isDirty, false);
    },
  );

  test(
    'unknown write blocks retries then reconciles while retaining later edits',
    () async {
      controller.replace(controller.values.copyWith(name: 'First'));
      store.throwAfterCommit = true;
      expect(
        (await controller.save() as CapabilityFailure).code,
        'commit_unknown',
      );
      expect(controller.needsReadback, true);
      controller.replace(controller.values.copyWith(name: 'Second'));
      final writes = store.writes;
      expect(
        (await controller.save() as CapabilityFailure).code,
        'commit_unknown',
      );
      expect(store.writes, writes);
      expect(await controller.reconcile(), isA<CapabilitySuccess<void>>());
      expect(controller.account.preferences.restaurant['name'], 'First');
      expect(controller.values.name, 'Second');
      expect(controller.isDirty, true);
      store.throwAfterCommit = false;
      expect(await controller.save(), isA<CapabilitySuccess<void>>());
      expect(controller.account.preferences.restaurant['name'], 'Second');
    },
  );

  test(
    'external pending commands and stale revisions never overwrite state',
    () async {
      controller.replace(controller.values.copyWith(name: 'Edited'));
      blocked = true;
      expect((await controller.save() as CapabilityFailure).code, 'busy');
      blocked = false;
      await store.writeDocument(
        codec.encodeState(initial),
        writeToken: 'other',
        expected: store.document,
      );
      final writes = store.writes;
      expect(
        (await controller.save() as CapabilityFailure).code,
        'stale_revision',
      );
      expect(store.writes, writes);
      expect(
        (await controller.load() as CapabilityFailure).code,
        'unsaved_changes',
      );
      expect(
        await controller.load(discardChanges: true),
        isA<CapabilitySuccess<void>>(),
      );
      expect(controller.values.name, '');
      final gated = initial.copyWith(
        cutoverState: PortableJournalCutoverState.gated(),
      );
      await store.writeDocument(
        codec.encodeState(gated),
        writeToken: 'gated',
        expected: store.document,
      );
      expect(await controller.load(), isA<CapabilitySuccess<void>>());
      controller.replace(controller.values.copyWith(name: 'Gated metadata'));
      expect(await controller.save(), isA<CapabilitySuccess<void>>());
      expect(
        codec.decodeState(store.document!.payload).cutoverState.isGated,
        true,
      );
    },
  );
}
