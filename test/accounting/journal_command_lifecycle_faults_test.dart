import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dakhl_restaurant/accounting/daily_cash_queries.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/catalog/catalog_stock_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:madar_domain/madar_domain.dart';

import '../support/lifecycle_fault_child.dart';
import 'restaurant_journal_sale_conformance_test.dart' show UnknownAckStore;

// Retained F08 acceptance cases. Existing transaction fault families and generic
// engine activation/kill matrices remain separate, source-bound evidence.
T _value<T>(CapabilityResult<T> result) {
  expect(result, isA<CapabilitySuccess<T>>());
  return (result as CapabilitySuccess<T>).value;
}

Future<DocumentSnapshot> _snapshot(LocalDocumentWorkspaceStore store) async =>
    _value<DocumentSnapshot?>(await store.readDocument())!;

BigInt _net(PortableJournalState state, String account) => state.journals
    .expand((entry) => entry.journal.lines)
    .where((line) => line.accountId == account)
    .fold(
      BigInt.zero,
      (sum, line) =>
          sum +
          (line.side == JournalSide.debit
              ? line.amountUnits
              : -line.amountUnits),
    );

Map<String, dynamic> _expectedSource(
  String kind,
  PortableJournalState before, {
  String invoiceNumber = 'SYNTHETIC-1',
}) {
  final expected =
      jsonDecode(jsonEncode(before.account.toJson())) as Map<String, dynamic>;
  if (kind == 'sale') {
    (expected['sales'] as List).add({
      'id': 'sale',
      'number': 'S-000001',
      'date': '2026-01-03',
      'status': 'completed',
      'orderType': 'صالة',
      'discount': 0,
      'paid': 2000,
      'note': '',
      'createdAt': lifecycleTimestamp,
      'lines': [
        {
          'productId': 'p',
          'name': 'صنف',
          'unit': 'قطعة',
          'trackStock': true,
          'price': 1000,
          'quantity': 2,
        },
      ],
    });
  } else {
    (expected['materials'] as List).add({
      'id': 'inline-material',
      'name': 'Synthetic flour',
      'unit': 'bag',
      'priceCarton': 2000,
      'pricePiece': 100,
      'archived': false,
    });
    (expected['invoices'] as List).add({
      'id': 'invoice',
      'supplierId': 'supplier',
      'number': invoiceNumber,
      'date': '2026-01-04',
      'createdAt': lifecycleTimestamp,
      'note': '',
      'lines': [
        {
          'materialId': 'inline-material',
          'name': 'Synthetic flour',
          'unit': 'bag',
          'quantityCartons': 2,
          'quantityPieces': 2,
          'priceCarton': 2000,
          'pricePiece': 100,
          'quantity': 2,
          'price': 100,
        },
      ],
    });
    (expected['payments'] as List).add({
      'id': 'inline-payment',
      'supplierId': 'supplier',
      'invoiceId': 'invoice',
      'categoryId': 'samoon',
      'date': '2026-01-04',
      'amount': 1500,
      'invoiceAmount': 1500,
      'debtAmount': 0,
      'funding': {'source': 'shared', 'dailyAmount': 900, 'cashAmount': 600},
      'note': '',
      'createdAt': lifecycleTimestamp,
    });
  }
  return expected;
}

void _assertComplete(
  String kind,
  PortableJournalState base,
  DocumentSnapshot snapshot, {
  String invoiceNumber = 'SYNTHETIC-1',
}) {
  final state = lifecycleCodec.decodeState(snapshot.payload);
  expect(
    state.account.toJson(),
    _expectedSource(kind, base, invoiceNumber: invoiceNumber),
  );
  expect(state.accountLineage, base.accountLineage);
  expect(state.journals.first.toJson(), base.journals.single.toJson());
  expect(state.journals.length, kind == 'invoice' ? 3 : 2);
  expect(state.receipts.length, 1);
  final receipt = state.receipts.single;
  expect(receipt.identity.operationId, '$kind-op');
  expect(receipt.sequence, 1);
  expect(receipt.status, DurableCommandStatus.committed);
  expect(receipt.fence, snapshot.fence);
  expect(receipt.committedRevision, snapshot.revision);
  final outcome = jsonDecode(receipt.outcomePayload!) as Map;
  expect(outcome['netAmount'], kind == 'invoice' ? '4200' : '2000');
  expect(outcome['journalId'], '$kind-journal');
  if (kind == 'invoice') expect(outcome['invoiceNumber'], invoiceNumber);
  final added = state.journals
      .skip(1)
      .map(
        (entry) => entry.journal.lines
            .map(
              (line) =>
                  (line.accountId, line.side.name, line.amountUnits.toString()),
            )
            .toList(),
      )
      .toList();
  expect(
    added,
    kind == 'invoice'
        ? [
            [
              ('expense:purchases', 'debit', '4200'),
              ('liability:supplier:supplier', 'credit', '4200'),
            ],
            [
              ('liability:supplier:supplier', 'debit', '1500'),
              ('asset:cash:daily', 'credit', '900'),
              ('asset:cash:cashbox', 'credit', '600'),
            ],
          ]
        : [
            [
              ('asset:cash:daily', 'debit', '2000'),
              ('revenue:sales', 'credit', '2000'),
            ],
          ],
  );
  final stock = CatalogStockHistory.compose(
    state.account,
    productId: 'p',
    today: lifecycleDate('2026-01-06'),
  ).last.runningBalanceUnits;
  expect(stock, BigInt.from(kind == 'sale' ? 3000 : 5000));
  expect(
    _net(state, 'asset:cash:daily'),
    BigInt.from(kind == 'invoice' ? 9100 : 12000),
  );
  expect(
    _net(state, 'asset:cash:cashbox'),
    BigInt.from(kind == 'invoice' ? -600 : 0),
  );
  expect(
    _net(state, 'liability:supplier:supplier'),
    BigInt.from(kind == 'invoice' ? -2700 : 0),
  );
  if (kind == 'invoice') {
    expect(
      DailyCashQueries(state.account).statement().total,
      BigInt.from(1500),
    );
    expect(
      (state.account.toJson()['days'] as Map).values.expand(
        (day) => (day as Map)['expenses'] as List,
      ),
      isEmpty,
    );
  }
}

// Both callers read the same real revision before either can write. The SDK
// still performs all transactions/CAS; this wrapper supplies no copied rules.
final class _ReadBarrierStore extends UnknownAckStore {
  _ReadBarrierStore(super.inner);
  final bothRead = Completer<void>();
  int initialReads = 0;
  int conflicts = 0;
  @override
  Future<CapabilityResult<DocumentSnapshot?>> readDocument() async {
    final result = await inner.readDocument();
    if (initialReads < 2) {
      initialReads++;
      if (initialReads == 2) bothRead.complete();
      await bothRead.future;
    }
    return result;
  }

  @override
  Future<CapabilityResult<DocumentSnapshot>> writeDocument(
    String payload, {
    required String writeToken,
    DocumentSnapshot? expected,
    bool replaceGeneration = false,
  }) async {
    final result = await inner.writeDocument(
      payload,
      writeToken: writeToken,
      expected: expected,
      replaceGeneration: replaceGeneration,
    );
    if (result is CapabilityFailure<DocumentSnapshot> &&
        result.code == DocumentErrorCodes.conflict) {
      conflicts++;
    }
    return result;
  }
}

// Failure occurs after actual inner write success, then after successful
// resolution at the readback seam. It never substitutes a pre-write read fault.
final class _UnavailableReadbackStore extends UnknownAckStore {
  _UnavailableReadbackStore(super.inner);
  bool unavailable = false;
  int actualCommits = 0;
  int failedReadbacks = 0;
  @override
  Future<CapabilityResult<DocumentSnapshot>> writeDocument(
    String payload, {
    required String writeToken,
    DocumentSnapshot? expected,
    bool replaceGeneration = false,
  }) async {
    final result = await inner.writeDocument(
      payload,
      writeToken: writeToken,
      expected: expected,
      replaceGeneration: replaceGeneration,
    );
    if (result is CapabilitySuccess<DocumentSnapshot>) {
      actualCommits++;
      unavailable = true;
      return const CapabilityFailure(
        DocumentErrorCodes.commitUnknown,
        'Lost committed acknowledgement.',
      );
    }
    return result;
  }

  @override
  Future<CapabilityResult<DocumentSnapshot?>> readDocument() async {
    if (unavailable) {
      failedReadbacks++;
      return const CapabilityFailure(
        DocumentErrorCodes.unavailable,
        'Synthetic readback outage.',
      );
    }
    return inner.readDocument();
  }
}

void main() {
  late Directory root;
  final owners = <PowerSyncLocalDocumentWorkspaceStore>[];
  final children = <Process>[];
  setUp(() async {
    root = await Directory.systemTemp.createTemp('dakhl-lifecycle-');
  });
  tearDown(() async {
    for (final child in children) {
      child.kill(ProcessSignal.sigkill);
      await child.exitCode.timeout(const Duration(seconds: 5));
    }
    children.clear();
    for (final owner in owners) {
      await owner.close();
    }
    owners.clear();
    await root.delete(recursive: true);
    expect(await root.exists(), isFalse);
  });
  Future<PowerSyncLocalDocumentWorkspaceStore> open() async {
    final owner = _value(
      await PowerSyncLocalDocumentWorkspaceStore.open(directoryPath: root.path),
    );
    owners.add(owner);
    return owner;
  }

  Future<DocumentSnapshot> seed(
    PowerSyncLocalDocumentWorkspaceStore store,
  ) async => _value(
    await store.writeDocument(
      lifecycleCodec.encodeState(lifecycleSeed()),
      writeToken: 'seed',
    ),
  );

  for (final (kind, boundary) in [
    ('invoice', 'transaction.before_commit'),
    ('sale', 'transaction.after_commit'),
  ]) {
    test(
      'SIGKILL $boundary preserves complete composed $kind and retry/replay',
      () async {
        final owner = await open();
        final before = await seed(owner);
        final base = lifecycleCodec.decodeState(before.payload);
        await owner.close();
        final child = await Process.start('dart', [
          '--packages=${File('.dart_tool/package_config.json').absolute.path}',
          File('test/support/lifecycle_fault_child.dart').absolute.path,
          root.path,
          kind,
          boundary,
        ], workingDirectory: Directory.current.path);
        children.add(child);
        final errors = StringBuffer();
        final errorDrain = child.stderr.transform(utf8.decoder).listen((text) {
          if (errors.length < 8192) {
            errors.write(
              text.substring(0, text.length.clamp(0, 8192 - errors.length)),
            );
          }
        });
        addTearDown(errorDrain.cancel);
        final line = await child.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .firstWhere(
              (line) => line.contains('lifecycle-checkpoint'),
              orElse: () => throw StateError('No actual checkpoint: $errors'),
            )
            .timeout(const Duration(seconds: 30));
        final marker = jsonDecode(line) as Map;
        expect(marker['checkpoint'], boundary);
        expect(marker['kind'], kind);
        expect(marker['pid'], child.pid);
        expect(child.kill(ProcessSignal.sigkill), isTrue);
        expect(
          await child.exitCode.timeout(const Duration(seconds: 5)),
          isNot(0),
        );
        final reopened = await open();
        final actual = await _snapshot(reopened);
        expect(actual.fence, before.fence);
        final committed = boundary == 'transaction.after_commit';
        expect(actual.revision, committed ? 2 : 1);
        if (committed) {
          _assertComplete(kind, base, actual);
        } else {
          expect(actual.payload, before.payload);
          expect(actual.writeToken, before.writeToken);
        }
        final command = lifecycleCommand(kind, before.fence);
        final result = await executeLifecycleCommand(reopened, command);
        expect(
          result,
          committed
              ? isA<DurableCommandReplayed<Object>>()
              : isA<DurableCommandSuccess<Object>>(),
        );
        final after = await _snapshot(reopened);
        expect(after.revision, 2);
        _assertComplete(kind, base, after);
        expect(
          await executeLifecycleCommand(reopened, command),
          isA<DurableCommandReplayed<Object>>(),
        );
        final changed = await executeLifecycleCommand(
          reopened,
          lifecycleCommand(kind, before.fence, changed: true),
        );
        expect(changed, isA<DurableCommandFailure<Object>>());
        expect(
          (changed as DurableCommandFailure<Object>).code,
          DurableCommandErrorCodes.changedPayloadRejected,
        );
        expect((await _snapshot(reopened)).payload, after.payload);
        expect((await _snapshot(reopened)).revision, after.revision);
      },
      skip: Platform.isWindows ? 'SIGKILL requires a POSIX host.' : false,
      timeout: const Timeout(Duration(seconds: 45)),
    );
  }

  for (final changed in [false, true]) {
    test(
      'overlapping ${changed ? 'conflicting' : 'identical'} composed commands use one real CAS result',
      () async {
        final real = await open();
        final before = await seed(real);
        final barrier = _ReadBarrierStore(real);
        final command = lifecycleCommand('invoice', before.fence);
        final results = await Future.wait([
          executeLifecycleCommand(barrier, command),
          executeLifecycleCommand(
            barrier,
            lifecycleCommand('invoice', before.fence, changed: changed),
          ),
        ]).timeout(const Duration(seconds: 15));
        expect(barrier.initialReads, 2);
        expect(barrier.conflicts, greaterThanOrEqualTo(1));
        expect(results.whereType<DurableCommandSuccess<Object>>().length, 1);
        if (changed) {
          final failure = results
              .whereType<DurableCommandFailure<Object>>()
              .single;
          expect(failure.code, DurableCommandErrorCodes.changedPayloadRejected);
        } else {
          expect(results.whereType<DurableCommandReplayed<Object>>().length, 1);
        }
        final actual = await _snapshot(real);
        expect(actual.revision, 2);
        final base = lifecycleCodec.decodeState(before.payload);
        _assertComplete(
          'invoice',
          base,
          actual,
          invoiceNumber:
              changed && results.first is! DurableCommandSuccess<Object>
              ? 'CHANGED'
              : 'SYNTHETIC-1',
        );
        expect(lifecycleCodec.decodeState(actual.payload).receipts.length, 1);
      },
    );
  }

  test('committed multi-journal write stays protected through readback outage and reopens once', () async {
    final real = await open();
    final before = await seed(real);
    final wrapper = _UnavailableReadbackStore(real);
    final command = lifecycleCommand('invoice', before.fence);
    final unknown = await executeLifecycleCommand(wrapper, command);
    expect(unknown, isA<DurableCommandFailure<Object>>());
    expect(
      (unknown as DurableCommandFailure<Object>).code,
      DurableCommandErrorCodes.commitUnknown,
    );
    expect(wrapper.actualCommits, 1);
    expect(wrapper.resolveCalls, greaterThanOrEqualTo(1));
    expect(wrapper.failedReadbacks, greaterThanOrEqualTo(1));
    final committed = await _snapshot(real);
    expect(committed.revision, 2);
    _assertComplete(
      'invoice',
      lifecycleCodec.decodeState(before.payload),
      committed,
    );
    final stillUnknown = await executeLifecycleCommand(wrapper, command);
    expect(stillUnknown, isA<DurableCommandFailure<Object>>());
    expect(wrapper.actualCommits, 1);
    expect((await _snapshot(real)).payload, committed.payload);
    await real.close();
    final reopened = await open();
    expect(
      await executeLifecycleCommand(reopened, command),
      isA<DurableCommandReplayed<Object>>(),
    );
    expect((await _snapshot(reopened)).payload, committed.payload);
    expect((await _snapshot(reopened)).revision, committed.revision);
  });
}
