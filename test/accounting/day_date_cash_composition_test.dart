import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounting/day_date_correction_commands.dart';
import 'package:dakhl_restaurant/accounting/day_date_correction_controller.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_external_cash_commands.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/app/restaurant_operations_session.dart';

import '../accounting/restaurant_journal_invoice_correction_commands_test.dart'
    show setup, date;
import '../sales/sales_workflow_session_test.dart' show fixture, fresh;

const codec = PortableJournalCodec();
void main() {
  test(
    'mapped cash date child supports original replay and later correction',
    () async {
      final (store, owner) = await setup();
      addTearDown(owner.dispose);
      final cash = RestaurantJournalExternalCashCoordinator(store: store);
      final original = ExternalCashCommand.create(
        operationId: 'cash-create',
        accountLineage: 'lineage',
        expectedFence: store.document!.fence,
        transactionId: 'cash',
        journalId: 'cash-journal',
        recordedAt: '2026-11-07T10:00:00Z',
        acceptedCounterAccountId: 'equity:owner',
        mapper: RestaurantJournalMapper(),
        date: date('2026-11-07'),
        amount: BigInt.from(100),
        type: 'deposit',
        note: 'External',
      );
      expect(await cash.execute(original), isA<DurableCommandSuccess>());
      final c = DayDateCorrectionController(
        store: store,
        snapshot: store.document!,
        isWriteBlocked: () => false,
        acceptedCounterAccountId: 'equity:owner',
      );
      addTearDown(c.dispose);
      final shift = c.capture(
        operationId: 'cash-shift',
        from: '2026-11-07',
        to: '2026-11-08',
        reason: 'Correct date',
        recordedAt: '2026-11-10T10:00:00Z',
      );
      final result = await c.submit(shift);
      expect(
        result,
        isA<DurableCommandSuccess>(),
        reason: result is DurableCommandFailure<DayDateCorrectionOutcome>
            ? result.code
            : '',
      );
      expect(await cash.execute(original), isA<DurableCommandReplayed>());
      final state = codec.decodeState(store.document!.payload),
          active = RestaurantJournalExternalCashHistory.activePosting(
            codec.decodeState(store.document!.payload),
            'cash',
            RestaurantJournalMapper(),
          )!;
      final row = (state.account.toJson()['transactions']! as List)
          .cast<Map<String, Object?>>()
          .single;
      final edit = ExternalCashCommand.edit(
        operationId: 'cash-later',
        accountLineage: 'lineage',
        expectedFence: store.document!.fence,
        transactionId: 'cash',
        journalId: 'cash-later-journal',
        inverseJournalId: 'cash-later-inverse',
        expectedActiveJournalId: active.journal.id,
        expectedSource: row,
        reason: 'Note',
        recordedAt: '2026-11-10T11:00:00Z',
        acceptedCounterAccountId: 'equity:owner',
        mapper: RestaurantJournalMapper(),
        date: date('2026-11-08'),
        amount: BigInt.from(100),
        type: 'deposit',
        note: 'Later',
      );
      expect(await cash.execute(edit), isA<DurableCommandSuccess>());
      expect(await c.coordinator.execute(shift), isA<DurableCommandReplayed>());
    },
  );
  test(
    'pending dates exclude peers and confirmed shift updates all readers',
    () async {
      final (store, snapshot) = await fixture();
      final state = codec.decodeState(snapshot.payload);
      final seeded = await store.writeDocument(
        codec.encodeState(
          state.copyWith(
            account: const LegacyAccountCodec().decodeJson({
              ...state.account.toJson(),
              'days': {
                '2026-11-07': {
                  'expenses': <Object?>[],
                  'chickenUsed': 2,
                  'chickenLeft': 0,
                  'balance': null,
                  'totalOverride': null,
                  'remaining': null,
                },
              },
            }),
          ),
        ),
        writeToken: 'day-seed',
        expected: snapshot,
      );
      final opened = await RestaurantOperationsSession.open(
        store: store,
        snapshot: (seeded as CapabilitySuccess<DocumentSnapshot>).value,
        compareText: (a, b) => a.compareTo(b),
        fresh: fresh('active'),
      );
      final session =
          (opened as CapabilitySuccess<RestaurantOperationsSession>).value;
      addTearDown(session.dispose);
      final command = session.dayDates.capture(
        operationId: 'date-shift',
        from: '2026-11-07',
        to: '2026-11-08',
        reason: 'Date',
        recordedAt: '2026-11-10T10:00:00Z',
      );
      store.writeFailure = 'commit_unknown';
      expect(
        await session.dayDates.submit(command),
        isA<DurableCommandFailure>(),
      );
      expect(session.dayDates.needsReadback, true);
      final writes = store.writes;
      expect(
        (await session.sales.addProduct('p') as CapabilityFailure).code,
        'busy',
      );
      session.settings.replace(
        session.settings.values.copyWith(name: 'Keep draft'),
      );
      expect((await session.saveSettings() as CapabilityFailure).code, 'busy');
      expect(store.writes, writes);
      store.writeFailure = null;
      expect(await session.dayDates.retry(), isA<DurableCommandSuccess>());
      await session.synchronize();
      expect(session.dayDates.needsReadback, false);
      expect(
        (session.sales.operations.account.toJson()['days']! as Map).containsKey(
          '2026-11-08',
        ),
        true,
      );
      expect(
        session.metadataRepository.snapshot!.revision,
        session.dayDates.snapshot.revision,
      );
      expect(
        session.dailyRegister.snapshot.revision,
        session.dayDates.snapshot.revision,
      );
      expect(session.settings.isDirty, true);
    },
  );
}
