import 'dart:convert';
import 'dart:io';

import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_transfer_commands.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_transfer_correction_commands.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:madar_domain/madar_domain.dart';

T value<T>(CapabilityResult<T> result) =>
    (result as CapabilitySuccess<T>).value;
const codec = PortableJournalCodec();
final date = DateOnly.parse('2026-01-15', minimumYear: 1000, maximumYear: 9999);
final cutover = DateOnly.parse(
  '2026-01-01',
  minimumYear: 1000,
  maximumYear: 9999,
);

PortableJournalState seed() {
  final account = const LegacyAccountCodec().decodeJson({
    ...const LegacyAccountCodec().empty().toJson(),
    'days': {
      '$date': {
        'expenses': <Object?>[],
        'chickenUsed': 0,
        'chickenLeft': 0,
        'balance': 100000,
        'totalOverride': null,
        'remaining': {
          'amount': 100000,
          'dailySpent': 0,
          'transferred': 0,
          'salesTotal': 0,
        },
      },
    },
  });
  return PortableJournalState(
    accountLineage: 'integrity-lineage',
    account: account,
    sourceProvenance: const PortableJournalSourceProvenance(
      sourceVersion: 11,
      enrolledAt: '2026-01-01T00:00:00.000Z',
      migrated: false,
    ),
    cutoverState: PortableJournalCutoverState.established(
      cutoverDate: cutover,
      openingJournalId: 'opening',
    ),
    journals: [
      PortableJournalEntry(
        journal: RestaurantJournalMapper()
            .mapVerifiedCutoverOpening(
              journalId: 'opening',
              effectiveDate: cutover,
              verifiedPhysicalRegisterCash: BigInt.from(100000),
              verifiedCashboxBalance: BigInt.zero,
              verifiedSupplierDebts: const {},
            )
            .journal,
        sourceType: RestaurantJournalSourceType.cutoverOpening.name,
        recordedAt: '2026-01-01T00:00:00.000Z',
      ),
    ],
    receipts: const [],
  );
}

void main() {
  late Directory directory;
  PowerSyncLocalDocumentWorkspaceStore? store;
  String? armed;
  final fired = <String>[];

  Future<PowerSyncLocalDocumentWorkspaceStore> open() async {
    final result = value(
      await PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: directory.path,
        checkpoint: (point) async {
          if (point == armed) {
            armed = null;
            fired.add(point);
            throw StateError('Synthetic transfer correction fault at $point');
          }
        },
      ),
    );
    store = result;
    return result;
  }

  Future<DocumentSnapshot> snapshot() async =>
      value<DocumentSnapshot?>(await store!.readDocument())!;
  Future<PortableJournalState> read() async =>
      codec.decodeState((await snapshot()).payload);
  Future<void> mutate(void Function(Map<String, Object?>) change) async {
    final before = await snapshot();
    final json = (jsonDecode(before.payload) as Map).cast<String, Object?>();
    change(json);
    final modified = codec.decodeJson(json);
    value(
      await store!.writeDocument(
        codec.encodeState(modified),
        writeToken: 'tamper-${before.revision}',
        expected: before,
      ),
    );
  }

  Map<String, Object?> entry(Map<String, Object?> raw, String id) =>
      (raw['journals'] as List).cast<Map<String, Object?>>().singleWhere(
        (j) => j['id'] == id,
      );
  Map<String, Object?> receipt(Map<String, Object?> raw, String id) =>
      (raw['receipts'] as List).cast<Map<String, Object?>>().singleWhere(
        (r) => (r['identity'] as Map)['operationId'] == id,
      );
  void changeOutcome(
    Map<String, Object?> raw,
    String id,
    void Function(Map<String, Object?>) change,
  ) {
    final r = receipt(raw, id);
    final outcome = (jsonDecode(r['outcomePayload'] as String) as Map)
        .cast<String, Object?>();
    change(outcome);
    r['outcomePayload'] = jsonEncode(outcome);
  }

  void changeAccounts(Map<String, Object?> j) {
    final lines = (j['lines'] as List).cast<Map<String, Object?>>();
    lines[0]['accountId'] = 'asset:unrelated';
    lines[1]['accountId'] = 'income:sales';
  }

  Future<DailyToCashboxTransferCommand> create() async {
    final command = DailyToCashboxTransferCommand(
      operationId: 'create',
      accountLineage: 'integrity-lineage',
      expectedFence: (await snapshot()).fence,
      transferId: 'transfer',
      journalId: 'original',
      date: date,
      amount: BigInt.from(20000),
      recordedAt: '2026-01-15T10:00:00.000Z',
    );
    expect(
      await RestaurantJournalTransferCommandCoordinator(store: store!)
          .execute(command),
      isA<DurableCommandSuccess<RestaurantJournalTransferOutcome>>(),
    );
    return command;
  }

  Future<EditDailyTransferCommand> editCommand({
    String reason = 'increase',
  }) async => EditDailyTransferCommand(
    operationId: 'edit',
    accountLineage: 'integrity-lineage',
    expectedFence: (await snapshot()).fence,
    transferId: 'transfer',
    expectedActiveJournalId: 'original',
    inverseJournalId: 'inverse-edit',
    replacementJournalId: 'replacement',
    newAmount: BigInt.from(30000),
    reason: reason,
    recordedAt: '2026-01-15T11:00:00.000Z',
  );
  Future<DeleteDailyTransferCommand> deleteCommand({
    String target = 'replacement',
    String reason = 'remove',
  }) async => DeleteDailyTransferCommand(
    operationId: 'delete',
    accountLineage: 'integrity-lineage',
    expectedFence: (await snapshot()).fence,
    transferId: 'transfer',
    expectedActiveJournalId: target,
    inverseJournalId: 'inverse-delete',
    reason: reason,
    recordedAt: '2026-01-15T12:00:00.000Z',
  );
  Future<EditDailyTransferCommand> edit() async {
    final cmd = await editCommand();
    expect(
      await RestaurantJournalTransferCorrectionCommandCoordinator(store: store!)
          .executeEdit(cmd),
      isA<DurableCommandSuccess<RestaurantJournalTransferCorrectionOutcome>>(),
    );
    return cmd;
  }

  Future<DeleteDailyTransferCommand> delete() async {
    final cmd = await deleteCommand();
    expect(
      await RestaurantJournalTransferCorrectionCommandCoordinator(store: store!)
          .executeDelete(cmd),
      isA<DurableCommandSuccess<RestaurantJournalTransferCorrectionOutcome>>(),
    );
    return cmd;
  }

  Future<void> failsWithoutWrites(Future<Object> Function() run) async {
    final before = await snapshot();
    expect(await run(), isA<DurableCommandFailure>());
    final after = await snapshot();
    expect(after.revision, before.revision);
    expect(after.payload, before.payload);
    expect(after.fence, before.fence);
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'dakhl-transfer-correction-integrity-',
    );
    armed = null;
    fired.clear();
    await open();
    value(
      await store!.writeDocument(
        codec.encodeState(seed()),
        writeToken: 'initialize',
      ),
    );
  });
  tearDown(() async {
    await store?.close();
    store = null;
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  for (final kind in ['edit', 'delete']) {
    test(
      '$kind rejects an original transfer posting with unrelated accounts before commit',
      () async {
        await create();
        await mutate((raw) => changeAccounts(entry(raw, 'original')));
        final coordinator =
            RestaurantJournalTransferCorrectionCommandCoordinator(
              store: store!,
            );
        if (kind == 'edit') {
          final cmd = await editCommand();
          await failsWithoutWrites(() => coordinator.executeEdit(cmd));
        } else {
          final cmd = await deleteCommand(target: 'original');
          await failsWithoutWrites(() => coordinator.executeDelete(cmd));
        }
      },
    );
  }
  for (final replay in ['create', 'edit']) {
    for (final damage in [
      'replacement accounts',
      'replacement policy',
      'missing edit receipt',
      'fork',
      'forged provenance',
      'outcome date',
    ]) {
      test(
        '$replay replay rejects $damage without changing complete state',
        () async {
          final createCmd = await create();
          final editCmd = await edit();
          await mutate((raw) {
            final replacement = entry(raw, 'replacement');
            switch (damage) {
              case 'replacement accounts':
                changeAccounts(replacement);
              case 'replacement policy':
                (replacement['policy'] as Map)['maximumLines'] = 499;
              case 'missing edit receipt':
                (raw['receipts'] as List).removeWhere(
                  (r) => (r['identity'] as Map)['operationId'] == 'edit',
                );
              case 'fork':
                final fork = (jsonDecode(jsonEncode(replacement)) as Map)
                    .cast<String, Object?>();
                fork['id'] = 'fork';
                (raw['journals'] as List).add(fork);
              case 'forged provenance':
                replacement['recordedAt'] = '2026-01-15T23:00:00.000Z';
                (replacement['metadata'] as Map)['operationId'] = 'forged';
                (replacement['metadata'] as Map)['sourceVersion'] = 9;
                changeOutcome(raw, 'edit', (outcome) {
                  (outcome['metadata'] as Map)['operationId'] = 'forged';
                  (outcome['metadata'] as Map)['sourceVersion'] = 9;
                });
              case 'outcome date':
                changeOutcome(
                  raw,
                  'edit',
                  (outcome) => outcome['effectiveDate'] = '2026-01-16',
                );
            }
          });
          await failsWithoutWrites(
            () => replay == 'create'
                ? RestaurantJournalTransferCommandCoordinator(store: store!)
                      .execute(createCmd)
                : RestaurantJournalTransferCorrectionCommandCoordinator(
                    store: store!,
                  ).executeEdit(editCmd),
          );
        },
      );
    }
  }
  test(
    'delete replay rejects forged historical amount and effective date',
    () async {
      await create();
      await edit();
      final cmd = await delete();
      await mutate(
        (raw) => changeOutcome(raw, 'delete', (outcome) {
          outcome['netAmount'] = '999';
          outcome['effectiveDate'] = '2026-01-16';
        }),
      );
      await failsWithoutWrites(
        () =>
            RestaurantJournalTransferCorrectionCommandCoordinator(store: store!)
                .executeDelete(cmd),
      );
    },
  );
  test('delete replay rejects a missing predecessor receipt with contiguous remaining history', () async {
    await create();
    await edit();
    final cmd = await delete();
    await mutate((raw) {
      (raw['receipts'] as List).removeWhere(
        (r) => (r['identity'] as Map)['operationId'] == 'edit',
      );
      receipt(raw, 'delete')['sequence'] = 2;
    });
    await failsWithoutWrites(
      () =>
          RestaurantJournalTransferCorrectionCommandCoordinator(store: store!)
              .executeDelete(cmd),
    );
  });
  for (final replay in ['create', 'edit', 'delete']) {
    test('$replay replay rejects a different mapper account profile', () async {
      final createCmd = await create();
      final editCmd = await edit();
      final deleteCmd = await delete();
      final mapper = RestaurantJournalMapper(
        profile: const RestaurantAccountProfile(
          cashboxAccountId: 'asset:cash:different',
        ),
      );
      await failsWithoutWrites(
        () => switch (replay) {
          'create' => RestaurantJournalTransferCommandCoordinator(
            store: store!,
            mapper: mapper,
          ).execute(createCmd),
          'edit' => RestaurantJournalTransferCorrectionCommandCoordinator(
            store: store!,
            mapper: mapper,
          ).executeEdit(editCmd),
          _ => RestaurantJournalTransferCorrectionCommandCoordinator(
            store: store!,
            mapper: mapper,
          ).executeDelete(deleteCmd),
        },
      );
    });
  }
  for (final kind in ['edit', 'delete']) {
    test(
      '$kind preserves submitted reason whitespace in durable identity',
      () async {
        await create();
        final coordinator =
            RestaurantJournalTransferCorrectionCommandCoordinator(
              store: store!,
            );
        if (kind == 'edit') {
          final original = await editCommand(reason: 'fix');
          final changed = await editCommand(reason: ' fix ');
          expect(changed.identity, isNot(original.identity));
          expect(
            await coordinator.executeEdit(original),
            isA<
              DurableCommandSuccess<RestaurantJournalTransferCorrectionOutcome>
            >(),
          );
          await failsWithoutWrites(() => coordinator.executeEdit(changed));
        } else {
          final original = await deleteCommand(
            target: 'original',
            reason: 'fix',
          );
          final changed = await deleteCommand(
            target: 'original',
            reason: ' fix ',
          );
          expect(changed.identity, isNot(original.identity));
          expect(
            await coordinator.executeDelete(original),
            isA<
              DurableCommandSuccess<RestaurantJournalTransferCorrectionOutcome>
            >(),
          );
          await failsWithoutWrites(() => coordinator.executeDelete(changed));
        }
      },
    );
    test(
      '$kind rolls back at the actual precommit checkpoint and succeeds once after reopen',
      () async {
        await create();
        final editCmd = await editCommand();
        final deleteCmd = await deleteCommand(target: 'original');
        final before = await snapshot();
        final prior = await read();
        armed = 'transaction.before_commit';
        final coordinator =
            RestaurantJournalTransferCorrectionCommandCoordinator(
              store: store!,
            );
        final result = kind == 'edit'
            ? await coordinator.executeEdit(editCmd)
            : await coordinator.executeDelete(deleteCmd);
        expect(result, isA<DurableCommandFailure>());
        expect(fired, ['transaction.before_commit']);
        final rolledBack = await snapshot();
        expect(rolledBack.payload, before.payload);
        expect(rolledBack.revision, before.revision);
        await store!.close();
        store = null;
        await open();
        expect((await snapshot()).payload, before.payload);
        final retry = RestaurantJournalTransferCorrectionCommandCoordinator(
          store: store!,
        );
        expect(
          kind == 'edit'
              ? await retry.executeEdit(editCmd)
              : await retry.executeDelete(deleteCmd),
          isA<
            DurableCommandSuccess<RestaurantJournalTransferCorrectionOutcome>
          >(),
        );
        final after = await read();
        expect(after.receipts.length, prior.receipts.length + 1);
        expect(
          after.journals.length,
          prior.journals.length + (kind == 'edit' ? 2 : 1),
        );
        expect(
          after.journals.take(prior.journals.length).map((j) => j.toJson()),
          prior.journals.map((j) => j.toJson()),
        );
        expect(
          after.account.toJson()['transfers'],
          kind == 'edit'
              ? [
                  {
                    'id': 'transfer',
                    'date': '$date',
                    'amount': 30000,
                    'createdAt': '2026-01-15T10:00:00.000Z',
                  },
                ]
              : isEmpty,
        );
        final committed = await snapshot();
        expect(committed.revision, before.revision + 1);
        expect(
          kind == 'edit'
              ? await retry.executeEdit(editCmd)
              : await retry.executeDelete(deleteCmd),
          isA<
            DurableCommandReplayed<RestaurantJournalTransferCorrectionOutcome>
          >(),
        );
        expect((await snapshot()).payload, committed.payload);
      },
    );
  }
  for (final kind in ['edit', 'delete']) {
    test(
      '$kind rejects changed explicit policy under the same operation',
      () async {
        await create();
        final coordinator =
            RestaurantJournalTransferCorrectionCommandCoordinator(
              store: store!,
            );
        final policy = JournalPolicy(
          currency: 'IQD',
          scale: 0,
          maximumLineUnits: RestaurantJournalPolicies.defaultLimit,
          maximumSideUnits: RestaurantJournalPolicies.defaultLimit,
          maximumLines: 499,
          allowZeroLines: false,
        );
        final beforeFence = (await snapshot()).fence;
        if (kind == 'edit') {
          final original = await editCommand();
          expect(
            await coordinator.executeEdit(original),
            isA<
              DurableCommandSuccess<RestaurantJournalTransferCorrectionOutcome>
            >(),
          );
          final changed = EditDailyTransferCommand(
            operationId: 'edit',
            accountLineage: 'integrity-lineage',
            expectedFence: beforeFence,
            transferId: 'transfer',
            expectedActiveJournalId: 'original',
            inverseJournalId: 'inverse-edit',
            replacementJournalId: 'replacement',
            newAmount: BigInt.from(30000),
            reason: 'increase',
            recordedAt: '2026-01-15T11:00:00.000Z',
            policy: policy,
          );
          final before = await snapshot();
          final result = await coordinator.executeEdit(changed);
          expect(
            result,
            isA<
              DurableCommandFailure<RestaurantJournalTransferCorrectionOutcome>
            >(),
          );
          expect(
            (result as DurableCommandFailure).code,
            DurableCommandErrorCodes.changedPayloadRejected,
          );
          expect((await snapshot()).payload, before.payload);
        } else {
          final original = await deleteCommand(target: 'original');
          expect(
            await coordinator.executeDelete(original),
            isA<
              DurableCommandSuccess<RestaurantJournalTransferCorrectionOutcome>
            >(),
          );
          final changed = DeleteDailyTransferCommand(
            operationId: 'delete',
            accountLineage: 'integrity-lineage',
            expectedFence: beforeFence,
            transferId: 'transfer',
            expectedActiveJournalId: 'original',
            inverseJournalId: 'inverse-delete',
            reason: 'remove',
            recordedAt: '2026-01-15T12:00:00.000Z',
            policy: policy,
          );
          final before = await snapshot();
          final result = await coordinator.executeDelete(changed);
          expect(
            result,
            isA<
              DurableCommandFailure<RestaurantJournalTransferCorrectionOutcome>
            >(),
          );
          expect(
            (result as DurableCommandFailure).code,
            DurableCommandErrorCodes.changedPayloadRejected,
          );
          expect((await snapshot()).payload, before.payload);
        }
      },
    );
  }
  test(
    'correction constructors reject oversized and malformed Unicode reasons',
    () async {
      await create();
      for (final reason in [
        'x' * (DocumentLimits.accountBytes + 1),
        String.fromCharCode(0xd800),
      ]) {
        expect(
          () => EditDailyTransferCommand(
            operationId: 'e',
            accountLineage: 'integrity-lineage',
            transferId: 'transfer',
            expectedActiveJournalId: 'original',
            inverseJournalId: 'inv',
            replacementJournalId: 'repl',
            newAmount: BigInt.one,
            reason: reason,
            recordedAt: 'now',
          ),
          throwsFormatException,
        );
        expect(
          () => DeleteDailyTransferCommand(
            operationId: 'd',
            accountLineage: 'integrity-lineage',
            transferId: 'transfer',
            expectedActiveJournalId: 'original',
            inverseJournalId: 'inv',
            reason: reason,
            recordedAt: 'now',
          ),
          throwsFormatException,
        );
      }
    },
  );
}
