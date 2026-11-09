import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_payment_correction_commands.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_payment_history.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_spending_commands.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';

import 'restaurant_journal_payment_correction_commands_test.dart' as f;
import 'support/payment_correction_fixtures.dart';
import 'restaurant_journal_sale_safety_test.dart'
    show LostCommitAcknowledgementStore;

const codec = PortableJournalCodec();
Future<DocumentSnapshot> snapshot(LocalDocumentWorkspaceStore store) async =>
    (await store.readDocument() as CapabilitySuccess<DocumentSnapshot?>).value!;
Future<PortableJournalState> stateOf(LocalDocumentWorkspaceStore store) async =>
    codec.decodeState((await snapshot(store)).payload);
void main() {
  late Directory temp;
  final stores = <LocalDocumentWorkspaceStore>[];
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dakhl-payment-correction-');
  });
  tearDown(() async {
    for (final s in stores.reversed) {
      await s.close();
    }
    stores.clear();
    if (temp.existsSync()) await temp.delete(recursive: true);
  });
  Future<PowerSyncLocalDocumentWorkspaceStore> open({
    WorkspaceCheckpoint? checkpoint,
    String? path,
  }) async {
    final r = await PowerSyncLocalDocumentWorkspaceStore.open(
      directoryPath: path ?? temp.path,
      checkpoint: checkpoint,
    );
    final s =
        (r as CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>).value;
    stores.add(s);
    return s;
  }

  Future<StorageFence> seed(LocalDocumentWorkspaceStore s) async {
    final initial = await s.writeDocument(
      codec.encodeState(paymentSeed()),
      writeToken: 'seed',
    );
    final fence = (initial as CapabilitySuccess<DocumentSnapshot>).value.fence;
    final c = RestaurantJournalSpendingCommandCoordinator(store: s);
    expect(
      await c.executeInvoice(paymentInvoice(fence: fence)),
      isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
    );
    expect(
      await c.executePayment(paymentCreate(fence: fence)),
      isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
    );
    return fence;
  }

  test(
    'one revision edit/delete, reopen and all historical receipts replay',
    () async {
      var s = await open();
      final fence = await seed(s);
      final first = await stateOf(s);
      final edit = f.paymentEdit(first, fence: fence);
      final c = RestaurantJournalPaymentCorrectionCoordinator(store: s);
      final before = await snapshot(s);
      expect(
        await c.execute(edit),
        isA<DurableCommandSuccess<RestaurantJournalPaymentCorrectionOutcome>>(),
      );
      expect((await snapshot(s)).revision, before.revision + 1);
      final edited = await stateOf(s);
      final deletion = f.paymentDelete(edited, fence: fence);
      expect(
        await c.execute(deletion),
        isA<DurableCommandSuccess<RestaurantJournalPaymentCorrectionOutcome>>(),
      );
      final finalSnap = await snapshot(s);
      await s.close();
      stores.remove(s);
      s = await open();
      final reopened = RestaurantJournalPaymentCorrectionCoordinator(store: s);
      expect(
        await reopened.execute(edit),
        isA<
          DurableCommandReplayed<RestaurantJournalPaymentCorrectionOutcome>
        >(),
      );
      expect(
        await reopened.execute(deletion),
        isA<
          DurableCommandReplayed<RestaurantJournalPaymentCorrectionOutcome>
        >(),
      );
      expect(
        await RestaurantJournalSpendingCommandCoordinator(store: s)
            .executePayment(paymentCreate(fence: fence)),
        isA<DurableCommandReplayed<RestaurantJournalSpendingOutcome>>(),
      );
      expect((await snapshot(s)).payload, finalSnap.payload);
      expect((await snapshot(s)).revision, finalSnap.revision);
      expect((await stateOf(s)).receipts.length, 4);
    },
  );
  for (final deleting in [false, true]) {
    test(
      'actual precommit rollback/retry ${deleting ? 'delete' : 'edit'}',
      () async {
        var fail = false, hits = 0;
        final s = await open(
          checkpoint: (boundary) async {
            if (fail && boundary == 'transaction.before_commit') {
              hits++;
              throw StateError('synthetic payment precommit');
            }
          },
        );
        final fence = await seed(s);
        final state = await stateOf(s);
        final command = deleting
            ? f.paymentDelete(state, fence: fence, target: 'payment-journal')
            : f.paymentEdit(state, fence: fence);
        final c = RestaurantJournalPaymentCorrectionCoordinator(store: s);
        final before = await snapshot(s);
        fail = true;
        expect(
          await c.execute(command),
          isA<
            DurableCommandFailure<RestaurantJournalPaymentCorrectionOutcome>
          >(),
        );
        fail = false;
        expect(hits, 1);
        expect((await snapshot(s)).payload, before.payload);
        expect((await snapshot(s)).revision, before.revision);
        expect(
          await c.execute(command),
          isA<
            DurableCommandSuccess<RestaurantJournalPaymentCorrectionOutcome>
          >(),
        );
        expect(
          await c.execute(command),
          isA<
            DurableCommandReplayed<RestaurantJournalPaymentCorrectionOutcome>
          >(),
        );
        expect((await snapshot(s)).revision, before.revision + 1);
      },
    );
  }
  test(
    'genuinely committed lost acknowledgement resolves/reopens exactly once',
    () async {
      var s = await open();
      final fence = await seed(s);
      final wrapper = LostCommitAcknowledgementStore(s)..loseNextWrite = true;
      final command = f.paymentEdit(await stateOf(s), fence: fence);
      final result = await RestaurantJournalPaymentCorrectionCoordinator(
        store: wrapper,
      ).execute(command);
      expect(
        result,
        isA<
          DurableCommandReplayed<RestaurantJournalPaymentCorrectionOutcome>
        >(),
      );
      expect(wrapper.writes, 1);
      final saved = await snapshot(s);
      await s.close();
      stores.remove(s);
      s = await open();
      expect((await stateOf(s)).journals.length, 5);
      expect((await stateOf(s)).receipts.length, 3);
      expect(
        await RestaurantJournalPaymentCorrectionCoordinator(store: s)
            .execute(command),
        isA<
          DurableCommandReplayed<RestaurantJournalPaymentCorrectionOutcome>
        >(),
      );
      expect((await snapshot(s)).payload, saved.payload);
    },
  );
  test(
    'changed payload, stale fence and foreign lineage do not write',
    () async {
      final s = await open();
      final fence = await seed(s);
      final state = await stateOf(s);
      final c = RestaurantJournalPaymentCorrectionCoordinator(store: s);
      expect(
        await c.execute(f.paymentEdit(state, fence: fence)),
        isA<DurableCommandSuccess<RestaurantJournalPaymentCorrectionOutcome>>(),
      );
      final before = await snapshot(s);
      final changed = await c.execute(
        f.paymentEdit(state, fence: fence, note: 'edited'),
      );
      expect(
        changed,
        isA<DurableCommandFailure<RestaurantJournalPaymentCorrectionOutcome>>()
            .having((r) => r.code, 'code', 'changed_payload_rejected'),
      );
      final versionChanged = await c.execute(
        f.paymentEdit(state, fence: fence, payloadVersion: 2),
      );
      expect(
        versionChanged,
        isA<DurableCommandFailure<RestaurantJournalPaymentCorrectionOutcome>>()
            .having((r) => r.code, 'code', 'changed_payload_rejected'),
      );
      final stale = await c.execute(f.paymentEdit(state));
      expect(
        stale,
        isA<DurableCommandFailure<RestaurantJournalPaymentCorrectionOutcome>>()
            .having((r) => r.code, 'code', 'stale_authority_fence'),
      );
      final current = await stateOf(s);
      final foreign = codec.encodeState(
        current.copyWith(accountLineage: 'other-lineage'),
      );
      await s.writeDocument(foreign, writeToken: 'foreign', expected: before);
      final swapped = await snapshot(s);
      expect(
        await c.execute(f.paymentEdit(state, fence: fence)),
        isA<DurableCommandFailure<RestaurantJournalPaymentCorrectionOutcome>>(),
      );
      expect((await snapshot(s)).payload, swapped.payload);
    },
  );
  test(
    'tampered stored payment intent fails replay without new write',
    () async {
      final s = await open();
      final fence = await seed(s);
      final command = f.paymentEdit(await stateOf(s), fence: fence);
      final c = RestaurantJournalPaymentCorrectionCoordinator(store: s);
      expect(
        await c.execute(command),
        isA<DurableCommandSuccess<RestaurantJournalPaymentCorrectionOutcome>>(),
      );
      final snap = await snapshot(s);
      final state = codec.decodeState(snap.payload);
      final raw = jsonDecode(
        jsonEncode(state.account.toJson()),
      ) as Map<String, Object?>;
      (raw['payments'] as List).single['note'] = 'forged';
      await s.writeDocument(
        codec.encodeState(
          state.copyWith(account: const LegacyAccountCodec().decodeJson(raw)),
        ),
        writeToken: 'tamper',
        expected: snap,
      );
      final bad = await snapshot(s);
      expect(
        await c.execute(command),
        isA<DurableCommandFailure<RestaurantJournalPaymentCorrectionOutcome>>(),
      );
      expect((await snapshot(s)).payload, bad.payload);
      expect((await snapshot(s)).revision, bad.revision);
    },
  );
  for (final deleting in [false, true]) {
    test(
      'fresh owner restore permits ${deleting ? 'delete' : 'edit'} despite revision reset',
      () async {
        var s = await open();
        await seed(s);
        final before = await snapshot(s);
        await s.close();
        stores.remove(s);
        final dir = await Directory('${temp.path}/restored').create();
        s = await open(path: dir.path);
        final r = await s.writeDocument(before.payload, writeToken: 'restore');
        final snap = (r as CapabilitySuccess<DocumentSnapshot>).value;
        expect(snap.revision, 1);
        final state = await stateOf(s);
        final command = deleting
            ? f.paymentDelete(
                state,
                fence: snap.fence,
                target: 'payment-journal',
              )
            : f.paymentEdit(state, fence: snap.fence);
        expect(
          await RestaurantJournalPaymentCorrectionCoordinator(store: s)
              .execute(command),
          isA<
            DurableCommandSuccess<RestaurantJournalPaymentCorrectionOutcome>
          >(),
        );
        expect(
          RestaurantJournalPaymentHistory.validate(
            state: await stateOf(s),
            paymentId: 'payment',
            mapper: RestaurantJournalMapper(),
          ),
          true,
        );
        expect(
          await RestaurantJournalPaymentCorrectionCoordinator(store: s)
              .execute(command),
          isA<
            DurableCommandReplayed<RestaurantJournalPaymentCorrectionOutcome>
          >(),
        );
      },
    );
  }
}
