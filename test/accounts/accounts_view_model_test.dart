import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/accounts_view_model.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/workspace_document.dart';

final class FixtureStore implements LocalDocumentWorkspaceStore {
  DocumentSnapshot? document;
  PreviousDocument? previous;
  String? readFailure, writeFailure;
  int writes = 0,
      archives = 0,
      workspaceWrites = 0,
      resumes = 0,
      previousReads = 0;
  bool throwAfterCommit = false;
  WorkspaceSnapshot? workspace;
  WorkspaceState? workspaceReadOverride;
  String? workspaceWriteFailure;
  Completer<CapabilityResult<DocumentSnapshot?>>? delayedRead;
  @override
  Future<CapabilityResult<DocumentSnapshot?>> readDocument() async =>
      delayedRead?.future ??
      (readFailure == null
          ? CapabilitySuccess(document)
          : CapabilityFailure(readFailure!, 'Fixture read failure'));
  @override
  Future<CapabilityResult<DocumentSnapshot>> writeDocument(
    String payload, {
    required String writeToken,
    DocumentSnapshot? expected,
    bool replaceGeneration = false,
  }) async {
    writes++;
    if (writeFailure != null) {
      return CapabilityFailure(writeFailure!, 'Fixture failure');
    }
    if (expected != document) {
      return const CapabilityFailure('stale_revision', 'Stale');
    }
    final old = document;
    if (old != null) {
      previous = PreviousDocument(snapshot: old, identity: 'backup');
    }
    document = DocumentSnapshot(
      payload: payload,
      revision: (old?.revision ?? 0) + 1,
      fence: StorageFence(
        storeId: 'store',
        generation: replaceGeneration
            ? 'generation-$writes'
            : old?.fence.generation ?? 'first',
      ),
      writeToken: writeToken,
    );
    if (throwAfterCommit) throw StateError('Lost acknowledgement');
    return CapabilitySuccess(document!);
  }

  @override
  Future<CapabilityResult<DocumentSnapshot>> resumeInitialCreation(
    String payload, {
    required String writeToken,
  }) {
    resumes++;
    return writeDocument(payload, writeToken: writeToken);
  }

  @override
  Future<CapabilityResult<WorkspaceState>> readWorkspace(
    StorageFence fence,
  ) async => CapabilitySuccess(
    workspaceReadOverride ?? WorkspaceState(fence: fence, snapshot: workspace),
  );
  @override
  Future<CapabilityResult<WorkspaceSnapshot>> writeWorkspace(
    String payload, {
    required StorageFence fence,
    required int? expectedRevision,
    required String writeToken,
  }) async {
    workspaceWrites++;
    if (document?.fence != fence || expectedRevision != workspace?.revision) {
      return const CapabilityFailure('conflict', 'Stale fixture authority');
    }
    if (workspaceWriteFailure != null &&
        workspaceWriteFailure != 'commit_unknown') {
      return CapabilityFailure(
        workspaceWriteFailure!,
        'Definite fixture failure',
      );
    }
    workspace = WorkspaceSnapshot(
      payload: payload,
      revision: (workspace?.revision ?? 0) + 1,
      fence: fence,
      writeToken: writeToken,
    );
    if (workspaceWriteFailure != null) {
      return CapabilityFailure(
        workspaceWriteFailure!,
        'Fixture acknowledgement',
      );
    }
    return CapabilitySuccess(workspace!);
  }

  @override
  Future<CapabilityResult<PreviousDocument?>> readPrevious() async {
    previousReads++;
    return CapabilitySuccess(previous);
  }

  @override
  Future<CapabilityResult<DocumentSnapshot>> recoverPrevious(
    PreviousDocument selected, {
    required String payload,
    required String writeToken,
  }) async {
    writes++;
    document = DocumentSnapshot(
      payload: payload,
      revision: 1,
      fence: const StorageFence(storeId: 'recovered', generation: 'fresh'),
      writeToken: writeToken,
    );
    return CapabilitySuccess(document!);
  }

  @override
  Future<CapabilityResult<void>> resolvePendingWrite() async =>
      const CapabilitySuccess(null);
  @override
  Future<CapabilityResult<String>> preserveSource(List<int> bytes) async {
    archives++;
    return const CapabilitySuccess('source');
  }

  @override
  Future<void> close() async {}
}

final class FixtureTransfer implements FileTransferCapability {
  const FixtureTransfer(this.result);
  final CapabilityResult<Uint8List> result;
  @override
  Future<CapabilityResult<Uint8List>> open() async => result;
  @override
  Future<CapabilityResult<void>> save(Uint8List bytes) async =>
      const CapabilitySuccess(null);
}

final class RetriableExport implements FileTransferCapability {
  bool fail = true;
  int saves = 0;
  @override
  Future<CapabilityResult<Uint8List>> open() async =>
      const CapabilityCancelled();
  @override
  Future<CapabilityResult<void>> save(Uint8List bytes) async {
    saves++;
    return fail
        ? const CapabilityFailure('file_unavailable', 'Fixture failure')
        : const CapabilitySuccess(null);
  }
}

void main() {
  for (final foreignState in [true, false]) {
    test(
      'workspace readback refuses foreign ${foreignState ? 'state' : 'snapshot'} authority',
      () async {
        final store = FixtureStore();
        final repository = AccountsRepository(store: store);
        final model = AccountsViewModel(repository: repository);
        await model.initialize();
        await model.save();
        store.workspaceWriteFailure = 'commit_unknown';
        await model.saveWorkspace(WorkspaceDocument.empty(), model.fence!);
        final committed = store.workspace!;
        const foreign = StorageFence(storeId: 'other', generation: 'foreign');
        store.workspaceReadOverride = WorkspaceState(
          fence: foreignState ? foreign : model.fence!,
          snapshot: WorkspaceSnapshot(
            payload: committed.payload,
            revision: committed.revision,
            fence: foreignState ? committed.fence : foreign,
            writeToken: committed.writeToken,
          ),
        );
        await model.retry();
        expect(repository.hasUnknownWrite, isTrue);
        expect(model.exportBytes(), isNull);
        expect(store.writes, 1);
        expect(store.workspaceWrites, 1);
        store.workspaceReadOverride = null;
        await model.retry();
        expect(repository.hasUnknownWrite, isFalse);
        expect(model.state, AccountsState.saved);
        expect(store.workspace, same(committed));
      },
    );
  }
  test(
    'export retry cannot acknowledge or rewrite an unsaved workspace',
    () async {
      final store = FixtureStore();
      final model = AccountsViewModel(
        repository: AccountsRepository(store: store),
      );
      await model.initialize();
      await model.save();
      store.workspaceWriteFailure = 'unavailable';
      await model.saveWorkspace(WorkspaceDocument.empty(), model.fence!);
      final transfer = RetriableExport();
      await model.exportTo(transfer);
      transfer.fail = false;
      await model.retry();
      expect(transfer.saves, 2);
      expect(store.writes, 1);
      expect(store.workspaceWrites, 1);
      expect(model.failureCode, 'workspace_unsaved');
      store.workspaceWriteFailure = null;
      await model.retry();
      expect(store.workspaceWrites, 2);
      expect(model.state, AccountsState.saved);
    },
  );
  test('workspace uncertainty survives failed reopen until fresh validated readback', () async {
    final store = FixtureStore();
    final model = AccountsViewModel(
      repository: AccountsRepository(store: store),
    );
    await model.initialize();
    await model.save();
    final primary = store.document!;
    store.workspaceWriteFailure = 'commit_unknown';
    await model.saveWorkspace(
      WorkspaceDocument(
        active: const {'note': 'committed'},
        form: const {},
        held: const [],
      ),
      model.fence!,
    );
    expect(model.state, AccountsState.commitUnknown);
    store.readFailure = 'unavailable';
    await model.initialize();
    expect(model.document, isNull);
    expect(model.state, AccountsState.commitUnknown);
    expect(model.repository.hasUnknownWrite, isTrue);
    await model.retry();
    expect(model.repository.hasUnknownWrite, isTrue);
    store.readFailure = null;
    store.document = DocumentSnapshot(
      payload: '{broken',
      revision: primary.revision,
      fence: primary.fence,
      writeToken: primary.writeToken,
    );
    await model.retry();
    expect(model.repository.hasUnknownWrite, isTrue);
    expect(model.exportBytes(), isNull);
    store.document = primary;
    await model.retry();
    expect(model.state, AccountsState.saved);
    expect(model.repository.hasUnknownWrite, isFalse);
    expect(model.workspace.active['note'], 'committed');
    expect(model.exportBytes(), isNotNull);
    expect(store.writes, 1);
    expect(store.workspaceWrites, 1);
  });
  test('recovery lookup retry never creates an empty account', () async {
    final store = FixtureStore();
    final model = AccountsViewModel(
      repository: AccountsRepository(store: store),
    );
    await model.initialize();
    await model.selectPrevious();
    expect(model.failureCode, 'no_previous_copy');
    await model.retry();
    expect(store.previousReads, 2);
    expect(store.writes, 0);
    expect(store.workspaceWrites, 0);
    expect(store.document, isNull);
    expect(model.failureCode, 'no_previous_copy');
  });

  test('definite workspace failure does not commit fixture state', () async {
    final store = FixtureStore();
    final model = AccountsViewModel(
      repository: AccountsRepository(store: store),
    );
    await model.initialize();
    await model.save();
    store.workspaceWriteFailure = 'unavailable';
    await model.saveWorkspace(WorkspaceDocument.empty(), model.fence!);
    expect(store.workspace, isNull);
    store.workspaceWriteFailure = null;
    await model.retry();
    expect(model.state, AccountsState.saved);
    final saved = store.workspace!;
    final stale = await store.writeWorkspace(
      '{}',
      fence: model.fence!,
      expectedRevision: null,
      writeToken: 'stale',
    );
    expect(stale, isA<CapabilityFailure<WorkspaceSnapshot>>());
    expect(store.workspace, same(saved));
  });

  test(
    'export retry uses the same transfer without writing accounts',
    () async {
      final store = FixtureStore();
      final model = AccountsViewModel(
        repository: AccountsRepository(store: store),
      );
      await model.initialize();
      await model.save();
      final saved = store.document;
      final transfer = RetriableExport();
      await model.exportTo(transfer);
      expect(model.failureCode, 'file_unavailable');
      transfer.fail = false;
      await model.retry();
      expect(transfer.saves, 2);
      expect(store.writes, 1);
      expect(store.document, same(saved));
      expect(model.state, AccountsState.saved);
      expect(model.failureCode, isNull);
    },
  );

  test(
    'failed reopen revokes export authority and retains creation protection',
    () async {
      for (final failure in [
        'unavailable',
        'incomplete_state',
        'invalid_payload',
      ]) {
        final store = FixtureStore();
        final model = AccountsViewModel(
          repository: AccountsRepository(store: store),
        );
        await model.initialize();
        await model.save();
        final saved = store.document!;
        if (failure == 'invalid_payload') {
          store.document = DocumentSnapshot(
            payload: '{broken',
            revision: saved.revision,
            fence: saved.fence,
            writeToken: saved.writeToken,
          );
        } else {
          store.readFailure = failure;
        }
        await model.initialize();
        expect(model.state, AccountsState.protected);
        expect(model.document, isNull);
        expect(model.exportBytes(), isNull);
        expect(model.repository.initialCreationBlocked, isFalse);
        await model.save();
        expect(store.writes, 1);
        store.readFailure = null;
        store.document = saved;
        await model.initialize();
        expect(model.state, AccountsState.saved);
        expect(model.document, isNotNull);
        expect(model.exportBytes(), isNotNull);
      }
    },
  );
  test('first absence remains unsaved until an explicit save', () async {
    final store = FixtureStore();
    final model = AccountsViewModel(
      repository: AccountsRepository(store: store),
    );
    await model.initialize();
    expect(model.state, AccountsState.absent);
    expect(store.writes, 0);
    await model.save();
    expect(model.state, AccountsState.saved);
    expect(store.writes, 1);
  });
  test(
    'unsupported/corrupt read protects data and never creates defaults',
    () async {
      final store = FixtureStore()..readFailure = 'unsupported_format';
      final model = AccountsViewModel(
        repository: AccountsRepository(store: store),
      );
      await model.initialize();
      await model.save();
      expect(model.state, AccountsState.protected);
      expect(store.writes, 0);
    },
  );
  test('cancel and invalid import do not write or preserve a source', () async {
    final store = FixtureStore();
    final model = AccountsViewModel(
      repository: AccountsRepository(store: store),
    );
    await model.initialize();
    model.prepareImport(utf8.encode('{broken'));
    expect(store.writes, 0);
    expect(store.archives, 0);
    model.prepareImport(
      const LegacyAccountCodec().encode(const LegacyAccountCodec().empty()),
    );
    model.cancelImport();
    expect(model.pendingImport, isNull);
    expect(store.writes, 0);
    expect(store.archives, 0);
  });
  test('failed replacement retains pending input and old fence', () async {
    final store = FixtureStore();
    final model = AccountsViewModel(
      repository: AccountsRepository(store: store),
    );
    await model.initialize();
    await model.save();
    final oldFence = model.fence;
    model.prepareImport(
      const LegacyAccountCodec().encode(const LegacyAccountCodec().empty()),
    );
    store.writeFailure = 'backup_publication_failed';
    await model.confirmImport();
    expect(model.state, AccountsState.failed);
    expect(model.pendingImport, isNotNull);
    expect(model.fence, oldFence);
  });
  test(
    'successful replacement creates a fresh fence and clears selection',
    () async {
      final store = FixtureStore();
      final model = AccountsViewModel(
        repository: AccountsRepository(store: store),
      );
      await model.initialize();
      await model.save();
      final before = store.document;
      model.prepareImport(
        const LegacyAccountCodec().encode(const LegacyAccountCodec().empty()),
      );
      await model.confirmImport();
      expect(model.fence, isNot(before!.fence));
      expect(model.pendingImport, isNull);
      expect(model.state, AccountsState.saved);
    },
  );
  test(
    'unknown commit gates retry until an explicit authoritative readback',
    () async {
      final store = FixtureStore()..writeFailure = 'commit_unknown';
      final model = AccountsViewModel(
        repository: AccountsRepository(store: store),
      );
      await model.initialize();
      await model.save();
      expect(model.state, AccountsState.commitUnknown);
      final writes = store.writes;
      await model.save();
      expect(store.writes, writes);
      await model.reconcile();
      expect(model.state, AccountsState.conflict);
    },
  );
  test(
    'exception after commit protects retry and resolves matching token',
    () async {
      final store = FixtureStore();
      final model = AccountsViewModel(
        repository: AccountsRepository(store: store),
      );
      await model.initialize();
      store.throwAfterCommit = true;
      await model.save();
      expect(model.state, AccountsState.commitUnknown);
      final writes = store.writes;
      await model.save();
      expect(store.writes, writes);
      await model.reconcile();
      expect(model.state, AccountsState.saved);
    },
  );
  test(
    'workspace unknown uses workspace readback and does not rewrite account',
    () async {
      final store = FixtureStore();
      final model = AccountsViewModel(
        repository: AccountsRepository(store: store),
      );
      await model.initialize();
      await model.save();
      store.workspaceWriteFailure = 'commit_unknown';
      await model.saveWorkspace(
        WorkspaceDocument(
          active: const {'nonce': 'draft'},
          form: const {},
          held: const [],
        ),
        model.fence!,
      );
      expect(model.state, AccountsState.commitUnknown);
      final count = store.workspaceWrites;
      await model.reconcile();
      expect(model.state, AccountsState.saved);
      expect(store.workspaceWrites, count);
      expect(store.writes, 1);
    },
  );
  test(
    'retired workspace callbacks after recovery cannot bind to new authority',
    () async {
      final store = FixtureStore();
      final model = AccountsViewModel(
        repository: AccountsRepository(store: store),
      );
      await model.initialize();
      await model.save();
      await model.save();
      final old = model.fence!;
      await model.selectPrevious();
      await model.confirmRecovery();
      expect(model.fence, isNot(old));
      await model.saveWorkspace(WorkspaceDocument.empty(), old);
      expect(store.workspaceWrites, 0);
    },
  );
  test('incomplete first creation requires explicit matching-source resume, never defaults', () async {
    final store = FixtureStore()..readFailure = 'incomplete_state';
    final model = AccountsViewModel(
      repository: AccountsRepository(store: store),
    );
    await model.initialize();
    await model.save();
    expect(store.writes, 0);
    model.prepareImport(
      model.repository.codec.encode(model.repository.codec.empty()),
    );
    expect(model.pendingImport, isNotNull);
    await model.confirmImport();
    expect(model.state, AccountsState.saved);
    expect(store.resumes, 1);
  });
  test(
    'first explicit account save seeds the existing six-slot device fallback',
    () async {
      final store = FixtureStore();
      final model = AccountsViewModel(
        repository: AccountsRepository(store: store),
      );
      await model.initialize();
      const slots = ['settings', '', 'sales', 'cash', 'sales', 'materials'];
      model.seedDeviceFallback(slots);
      await model.save();
      expect(model.accountShortcuts, slots);
    },
  );
  test('failed workspace stays unsaved across successful account and shortcut saves', () async {
    final store = FixtureStore();
    final model = AccountsViewModel(
      repository: AccountsRepository(store: store),
    );
    await model.initialize();
    await model.save();
    store.workspaceWriteFailure = 'unavailable';
    await model.saveWorkspace(
      WorkspaceDocument(
        active: const {'note': 'retained'},
        form: const {},
        held: const [],
      ),
      model.fence!,
    );
    expect(model.state, AccountsState.failed);
    await model.save();
    expect(model.state, AccountsState.failed);
    expect(model.workspace.active['note'], 'retained');
    expect(
      await model.saveShortcuts(const [
        'settings',
        '',
        'sales',
        'cash',
        'sales',
        'materials',
      ]),
      isTrue,
    );
    expect(model.state, AccountsState.failed);
    store.workspaceWriteFailure = null;
    await model.retry();
    expect(model.state, AccountsState.saved);
  });
  test('conflict retry rereads authority and preserves pending import for fresh confirmation', () async {
    final store = FixtureStore();
    final model = AccountsViewModel(
      repository: AccountsRepository(store: store),
    );
    await model.initialize();
    await model.save();
    final old = store.document!;
    store.document = DocumentSnapshot(
      payload: old.payload,
      revision: old.revision + 1,
      fence: old.fence,
      writeToken: 'another-writer',
    );
    model.prepareImport(
      model.repository.codec.encode(model.repository.codec.empty()),
    );
    await model.confirmImport();
    expect(model.state.name, 'conflict');
    final writes = store.writes;
    await model.save();
    expect(store.writes, writes);
    await model.retry();
    expect(model.pendingImport, isNotNull);
    expect(store.writes, writes);
    await model.confirmImport();
    expect(model.state, AccountsState.saved);
  });
  test(
    'oversized active plus40held is retained without a write or stuck busy',
    () async {
      final store = FixtureStore();
      final model = AccountsViewModel(
        repository: AccountsRepository(store: store),
      );
      await model.initialize();
      await model.save();
      final workspace = WorkspaceDocument(
        active: {'note': 'x' * (20 * 1024 * 1024)},
        form: const {},
        held: List.generate(40, (_) => const <String, String>{}),
      );
      await model.saveWorkspace(workspace, model.fence!);
      expect(model.busy, isFalse);
      expect(model.state, AccountsState.failed);
      expect(model.failureCode, 'payload_too_large');
      expect(store.workspaceWrites, 0);
      expect(model.workspace.active['note']!.length, 20 * 1024 * 1024);
    },
  );
  test('new picker failure or cancellation never selects the retained prior import', () async {
    final store = FixtureStore();
    final model = AccountsViewModel(
      repository: AccountsRepository(store: store),
    );
    await model.initialize();
    model.prepareImport(
      model.repository.codec.encode(model.repository.codec.empty()),
    );
    final retained = model.pendingImport;
    final failed = await model.pickImport(
      FixtureTransfer(
        CapabilitySuccess(Uint8List.fromList(utf8.encode('{invalid'))),
      ),
    );
    expect(failed.toString(), 'ImportPickOutcome.failed');
    expect(model.pendingImport, same(retained));
    final cancelled = await model.pickImport(
      const FixtureTransfer(CapabilityCancelled()),
    );
    expect(cancelled.name, 'cancelled');
    expect(model.pendingImport, same(retained));
    expect(store.writes, 0);
  });
  test('canceling a selection cannot acknowledge a failed workspace or clear conflict', () async {
    final store = FixtureStore();
    final model = AccountsViewModel(
      repository: AccountsRepository(store: store),
    );
    await model.initialize();
    await model.save();
    store.workspaceWriteFailure = 'unavailable';
    await model.saveWorkspace(
      WorkspaceDocument(
        active: const {'note': 'retained'},
        form: const {},
        held: const [],
      ),
      model.fence!,
    );
    model.prepareImport(
      model.repository.codec.encode(model.repository.codec.empty()),
    );
    model.cancelImport();
    expect(model.state, AccountsState.failed);
    store.workspaceWriteFailure = null;
    await model.retry();
    final old = store.document!;
    store.document = DocumentSnapshot(
      payload: old.payload,
      revision: old.revision + 1,
      fence: old.fence,
      writeToken: 'another',
    );
    model.prepareImport(
      model.repository.codec.encode(model.repository.codec.empty()),
    );
    await model.confirmImport();
    model.cancelImport();
    expect(model.state, AccountsState.conflict);
    expect(model.canMutate, isFalse);
  });
}
