import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/workspace_document.dart';
import 'package:dakhl_restaurant/sales/ticket_workspace.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;

TicketDraft draft(String id, {bool populated = true}) => TicketDraft(
  id: id,
  date: '2026-11-07',
  orderType: 'سفري',
  discount: '٥٠٠',
  note: 'ملاحظة',
  lines: populated
      ? [
          TicketLine(
            productId: 'p',
            quantityUnits: BigInt.from(1250),
            price: 12000,
          ),
        ]
      : [],
);
Future<AccountsRepository> repository(LocalDocumentWorkspaceStore store) async {
  final result = AccountsRepository(store: store);
  await result.open();
  await result.save(const LegacyAccountCodec().empty());
  return result;
}

final class DelayedWorkspaceStore implements LocalDocumentWorkspaceStore {
  final inner = FixtureStore();
  final committed = Completer<void>();
  final acknowledge = Completer<void>();

  @override
  Future<CapabilityResult<WorkspaceSnapshot>> writeWorkspace(
    String payload, {
    required StorageFence fence,
    required int? expectedRevision,
    required String writeToken,
  }) async {
    final result = await inner.writeWorkspace(
      payload,
      fence: fence,
      expectedRevision: expectedRevision,
      writeToken: writeToken,
    );
    committed.complete();
    await acknowledge.future;
    return result;
  }

  @override
  Future<CapabilityResult<DocumentSnapshot?>> readDocument() =>
      inner.readDocument();
  @override
  Future<CapabilityResult<DocumentSnapshot>> writeDocument(
    String payload, {
    required String writeToken,
    DocumentSnapshot? expected,
    bool replaceGeneration = false,
  }) => inner.writeDocument(
    payload,
    writeToken: writeToken,
    expected: expected,
    replaceGeneration: replaceGeneration,
  );
  @override
  Future<CapabilityResult<DocumentSnapshot>> resumeInitialCreation(
    String payload, {
    required String writeToken,
  }) => inner.resumeInitialCreation(payload, writeToken: writeToken);
  @override
  Future<CapabilityResult<WorkspaceState>> readWorkspace(StorageFence fence) =>
      inner.readWorkspace(fence);
  @override
  Future<CapabilityResult<PreviousDocument?>> readPrevious() =>
      inner.readPrevious();
  @override
  Future<CapabilityResult<DocumentSnapshot>> recoverPrevious(
    PreviousDocument selected, {
    required String payload,
    required String writeToken,
  }) =>
      inner.recoverPrevious(selected, payload: payload, writeToken: writeToken);
  @override
  Future<CapabilityResult<void>> resolvePendingWrite() =>
      inner.resolvePendingWrite();
  @override
  Future<CapabilityResult<String>> preserveSource(List<int> bytes) =>
      inner.preserveSource(bytes);
  @override
  Future<void> close() => inner.close();
}

void main() {
  test(
    'sale finalized during workspace acknowledgement cannot publish a draft',
    () async {
      final corpus = jsonDecode(
        File('test/fixtures/accounts/oracle.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final raw =
          (corpus['cases'] as List).cast<Map<String, dynamic>>().singleWhere(
                (c) => c['name'] == 'all-entities-history',
              )['input']
              as Map<String, dynamic>;
      final account = const LegacyAccountCodec().decodeJson(raw);
      final soldId =
          ((account.toJson()['sales'] as List).first as Map)['id'] as String;
      final store = DelayedWorkspaceStore();
      final repo = await repository(store);
      final c = TicketWorkspaceController(repo);
      await c.load(draft('prior'));
      final fence = repo.snapshot!.fence;
      final pending = c.saveActive(draft(soldId));
      await store.committed.future;
      expect(await repo.save(account), isA<CapabilitySuccess<void>>());
      expect(repo.snapshot!.fence, fence);
      store.acknowledge.complete();
      expect((await pending as CapabilityFailure).code, 'finalized_ticket');
      expect(c.state!.active.id, 'prior');
      // The workspace did commit; rejection must not claim a rollback.
      expect(
        TicketWorkspace.fromEnvelope(
          WorkspaceDocument.decode(store.inner.workspace!.payload),
          draft('unused'),
        ).active.id,
        soldId,
      );
      expect(
        (await c.load(draft('unused')) as CapabilityFailure).code,
        'finalized_ticket',
      );
      expect(c.state, isNull);
    },
  );

  test(
    'stored sale identities cannot be revived as active or held drafts',
    () async {
      final corpus = jsonDecode(
        File('test/fixtures/accounts/oracle.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final raw =
          (corpus['cases'] as List).cast<Map<String, dynamic>>().singleWhere(
                (c) => c['name'] == 'all-entities-history',
              )['input']
              as Map<String, dynamic>;
      final account = const LegacyAccountCodec().decodeJson(raw);
      final soldId =
          ((account.toJson()['sales'] as List).first as Map)['id'] as String;
      final store = FixtureStore();
      final repo = await repository(store);
      await repo.save(account);
      final c = TicketWorkspaceController(repo);
      expect(
        (await c.load(draft(soldId)) as CapabilityFailure).code,
        'finalized_ticket',
      );
      expect(c.state, isNull);
      expect(store.workspaceWrites, 0);
    },
  );

  test(
    'workspace revision is observable for stale controller checks',
    () async {
      final repo = await repository(FixtureStore());
      expect(repo.workspaceSnapshot, isNull);
    },
  );
  test(
    'hold/resume swap and restart preserve snapshots and unrelated forms',
    () async {
      final store = FixtureStore();
      final repo = await repository(store);
      await repo.saveWorkspace(
        WorkspaceDocument(active: {}, held: [], form: {'expense': 'keep'}),
        repo.snapshot!.fence,
      );
      final c = TicketWorkspaceController(repo);
      await c.load(draft('a'));
      expect(
        await c.hold(
          label: ' الطلب ',
          heldId: 'h1',
          fresh: draft('b', populated: false),
          savedAt: '2026-11-07T10:00:00Z',
        ),
        isA<CapabilitySuccess<void>>(),
      );
      expect(c.state!.held.single.label, 'الطلب');
      expect(c.state!.active.id, 'b');
      await c.saveActive(draft('c'));
      await c.resume(
        'h1',
        swapId: 'h2',
        swapLabel: 'نشط',
        savedAt: '2026-11-07T11:00:00Z',
      );
      expect(c.state!.active.id, 'a');
      expect(c.state!.active.lines.single.price, 12000);
      expect(c.state!.held.single.draft.id, 'c');
      expect(c.state!.form['expense'], 'keep');
      final reopened = AccountsRepository(store: store);
      await reopened.open();
      final other = TicketWorkspaceController(reopened);
      await other.load(draft('unused'));
      expect(other.state!.active.id, 'a');
      expect(other.state!.active.discount, '٥٠٠');
      expect(other.state!.active.note, 'ملاحظة');
      expect(
        store.document!.revision,
        1,
      ); // workspace operations never post account effects
    },
  );
  test('definite failure retains both tickets and permits retry', () async {
    final store = FixtureStore();
    final repo = await repository(store);
    final c = TicketWorkspaceController(repo);
    await c.load(draft('a'));
    store.workspaceWriteFailure = 'disk_full';
    expect(
      await c.hold(
        label: '',
        heldId: 'h',
        fresh: draft('b', populated: false),
        savedAt: '2026-11-07T10:00:00Z',
      ),
      isA<CapabilityFailure<void>>(),
    );
    expect(c.state!.active.id, 'a');
    expect(c.state!.held, isEmpty);
    store.workspaceWriteFailure = null;
    expect(
      await c.hold(
        label: '',
        heldId: 'h',
        fresh: draft('b', populated: false),
        savedAt: '2026-11-07T10:00:00Z',
      ),
      isA<CapabilitySuccess<void>>(),
    );
  });
  test(
    'unknown acknowledgement blocks retry then reads actual committed state',
    () async {
      final store = FixtureStore();
      final repo = await repository(store);
      final c = TicketWorkspaceController(repo);
      await c.load(draft('a'));
      store.workspaceWriteFailure = 'commit_unknown';
      await c.hold(
        label: '',
        heldId: 'h',
        fresh: draft('b', populated: false),
        savedAt: '2026-11-07T10:00:00Z',
      );
      expect(c.state!.active.id, 'a');
      final writes = store.workspaceWrites;
      expect(
        (await c.saveActive(draft('x')) as CapabilityFailure).code,
        'commit_unknown',
      );
      expect(store.workspaceWrites, writes);
      store.workspaceWriteFailure = null;
      expect(await c.reconcile(), isA<CapabilitySuccess<void>>());
      expect(c.state!.active.id, 'b');
      expect(c.state!.held.single.draft.id, 'a');
    },
  );
  test(
    'two controllers sharing repository cannot overwrite a newer revision',
    () async {
      final store = FixtureStore();
      final repo = await repository(store);
      final a = TicketWorkspaceController(repo),
          b = TicketWorkspaceController(repo);
      await a.load(draft('a'));
      await b.load(draft('b'));
      await a.saveActive(draft('saved'));
      expect(
        (await b.saveActive(draft('stale')) as CapabilityFailure).code,
        'stale_revision',
      );
      expect(store.workspaceWrites, 1);
    },
  );
  test(
    'same-revision in-flight writes conflict through underlying CAS',
    () async {
      final store = FixtureStore();
      final repo = await repository(store);
      final a = TicketWorkspaceController(repo),
          b = TicketWorkspaceController(repo);
      await a.load(draft('a'));
      await b.load(draft('b'));
      final first = a.saveActive(draft('first'));
      final second = b.saveActive(draft('second'));
      expect(await first, isA<CapabilitySuccess<void>>());
      expect(await second, isA<CapabilityFailure<void>>());
      expect(a.state!.active.id, 'first');
      expect(b.state!.active.id, 'b');
    },
  );
  test('generation replacement rejects stale workspace controller', () async {
    final store = FixtureStore();
    final repo = await repository(store);
    final c = TicketWorkspaceController(repo);
    await c.load(draft('old'));
    await store.writeDocument(
      store.document!.payload,
      writeToken: 'replacement',
      expected: store.document,
      replaceGeneration: true,
    );
    await repo.open();
    expect(
      (await c.saveActive(draft('new')) as CapabilityFailure).code,
      'stale_generation',
    );
    expect(store.workspaceWrites, 0);
  });
  test(
    'unknown old workspace is protected rather than silently discarded',
    () async {
      final store = FixtureStore();
      final repo = await repository(store);
      await repo.saveWorkspace(
        WorkspaceDocument(active: {'old': 'retain'}, form: {}, held: []),
        repo.snapshot!.fence,
      );
      final c = TicketWorkspaceController(repo);
      expect(
        (await c.load(draft('new')) as CapabilityFailure).code,
        'unsupported_ticket_workspace',
      );
      expect(c.state, isNull);
      expect(
        (await c.saveActive(draft('new')) as CapabilityFailure).code,
        'not_loaded',
      );
    },
  );
  test(
    '40 held limit rejects hold but permits atomic swap and delete',
    () async {
      final store = FixtureStore();
      final repo = await repository(store);
      final c = TicketWorkspaceController(repo);
      await c.load(draft('a'));
      for (var i = 0; i < 40; i++) {
        if (i > 0) await c.saveActive(draft('a$i'));
        await c.hold(
          label: '',
          heldId: 'h$i',
          fresh: draft('empty$i', populated: false),
          savedAt: '2026-11-07T10:00:00Z',
        );
      }
      await c.saveActive(draft('last'));
      final writes = store.workspaceWrites;
      expect(
        (await c.hold(
          label: '',
          heldId: 'overflow',
          fresh: draft('empty', populated: false),
          savedAt: '2026-11-07T10:00:00Z',
        ) as CapabilityFailure).code,
        'held_limit',
      );
      expect(store.workspaceWrites, writes);
      await c.resume(
        'h0',
        swapId: 'swap',
        swapLabel: 'آخر',
        savedAt: '2026-11-07T10:00:00Z',
      );
      expect(c.state!.held.length, 40);
      await c.deleteHeld('swap');
      expect(c.state!.held.length, 39);
    },
  );
  test('real local adapter persists typed workspace across reopen', () async {
    final root = await Directory.systemTemp.createTemp('ticket-workspace-');
    addTearDown(() => root.delete(recursive: true));
    final opened = await PowerSyncLocalDocumentWorkspaceStore.open(
      directoryPath: root.path,
    );
    final store =
        (opened as CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>)
            .value;
    try {
      final repo = await repository(store);
      final c = TicketWorkspaceController(repo);
      await c.load(draft('a'));
      await c.saveActive(draft('saved'));
    } finally {
      await store.close();
    }
    final second = (await PowerSyncLocalDocumentWorkspaceStore.open(
      directoryPath: root.path,
    ) as CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>).value;
    try {
      final repo = AccountsRepository(store: second);
      await repo.open();
      final c = TicketWorkspaceController(repo);
      expect(await c.load(draft('unused')), isA<CapabilitySuccess<void>>());
      expect(c.state!.active.id, 'saved');
    } finally {
      await second.close();
    }
  });
}
