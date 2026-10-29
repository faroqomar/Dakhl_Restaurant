import 'dart:async';
import 'dart:convert';

import 'package:dakhl_restaurant/shell/shell_preferences.dart';
import 'package:dakhl_restaurant/shell/shell_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';

void main() {
  late _Store store;
  late ShellViewModel model;

  setUp(() {
    store = _Store();
    model = ShellViewModel(store: store);
  });
  tearDown(() => model.dispose());

  test(
    'initial read gates commands and does not enqueue a ghost save',
    () async {
      final gate = Completer<CapabilityResult<PreferenceSnapshot?>>();
      store.reader = (_) => gate.future;
      final initialization = model.initialize();
      expect(model.bootstrapState, ShellBootstrapState.initializing);
      expect(await model.navigate('cash'), ShellNavigationResult.gated);
      expect(model.beginShortcutEditing(), isFalse);
      expect(store.writes, isEmpty);
      gate.complete(const CapabilitySuccess(null));
      await initialization;
      expect(model.bootstrapState, ShellBootstrapState.ready);
      expect(model.routeId, 'sales');
      expect(store.writes, isEmpty);
    },
  );

  test(
    'restores exact accepted route and configured slots without writing',
    () async {
      store.snapshot = _snapshot('invoices', [
        'cash',
        '',
        'cash',
        'sales',
        'settings',
        'materials',
      ], 3);
      await model.initialize();
      expect(model.routeId, 'invoices');
      expect(model.shortcuts, [
        'cash',
        '',
        'cash',
        'sales',
        'settings',
        'materials',
      ]);
      expect(model.preferenceRevision, 3);
      expect(store.writes, isEmpty);
      expect(model.hasUnsavedPreferences, isFalse);
    },
  );

  for (final payload in [
    'not json',
    jsonEncode({'schemaVersion': 5}),
  ]) {
    test(
      'protected stored payload cannot be overwritten by navigation: $payload',
      () async {
        store.snapshot = PreferenceSnapshot(payload: payload, revision: 9);
        await model.initialize();
        expect(model.bootstrapState, ShellBootstrapState.protectedReadFailure);
        expect(model.canEditShortcuts, isFalse);
        expect(await model.navigate('cash'), ShellNavigationResult.changed);
        expect(model.routeId, 'cash');
        expect(store.writes, isEmpty);
        expect(store.snapshot!.payload, payload);
        await model.retrySave();
        expect(store.writes, isEmpty);
      },
    );
  }

  test(
    'unavailable store allows only session navigation until a successful retry',
    () async {
      store.reader = (_) async =>
          const CapabilityFailure('unavailable', 'storage unavailable');
      await model.initialize();
      expect(model.bootstrapState, ShellBootstrapState.protectedReadFailure);
      await model.navigate('cash');
      expect(store.writes, isEmpty);
      store.reader = null;
      store.snapshot = _snapshot('inventory', [
        'settings',
        '',
        '',
        '',
        '',
        'cash',
      ], 2);
      await model.retryRead();
      expect(model.bootstrapState, ShellBootstrapState.ready);
      expect(model.routeId, 'cash');
      expect(model.shortcuts.first, 'settings');
      expect(store.writes, isEmpty);
      await model.navigate('payments');
      expect(_decoded(store.writes.single.payload).routeId, 'payments');
      expect(store.writes.single.expectedRevision, 2);
    },
  );

  test(
    'a delayed retry cannot replace newer route intent or auto-save',
    () async {
      store.reader = (_) async =>
          const CapabilityFailure('unavailable', 'unavailable');
      await model.initialize();
      final gate = Completer<CapabilityResult<PreferenceSnapshot?>>();
      store.reader = (_) => gate.future;
      final retry = model.retryRead();
      await model.navigate('cash');
      gate.complete(
        CapabilitySuccess(
          _snapshot('inventory', ['cash', '', '', '', '', ''], 6),
        ),
      );
      await retry;
      expect(model.routeId, 'cash');
      expect(model.shortcuts.first, 'cash');
      expect(store.writes, isEmpty);
    },
  );

  test('only the newest read response can establish stored state', () async {
    final first = Completer<CapabilityResult<PreferenceSnapshot?>>();
    final second = Completer<CapabilityResult<PreferenceSnapshot?>>();
    var reads = 0;
    store.reader = (_) => ++reads == 1 ? first.future : second.future;
    final a = model.initialize();
    final b = model.retryRead();
    second.complete(
      CapabilitySuccess(_snapshot('cash', ['cash', '', '', '', '', ''], 2)),
    );
    await b;
    first.complete(
      CapabilitySuccess(
        _snapshot('inventory', ['inventory', '', '', '', '', ''], 1),
      ),
    );
    await a;
    expect(model.routeId, 'cash');
    expect(model.preferenceRevision, 2);
    expect(store.writes, isEmpty);
  });

  test('navigate unknown or retired route falls back to Sales', () async {
    await model.initialize();
    await model.navigate('inventory');
    await model.navigate('savings');
    expect(model.routeId, 'sales');
    await model.navigate('bogus');
    expect(model.routeId, 'sales');
    expect(store.writes.map((w) => _decoded(w.payload).routeId), [
      'inventory',
      'sales',
    ]);
  });

  test(
    'canceling a dirty-form discard retains content, route and storage',
    () async {
      await model.initialize();
      model.setFormDraft({'supplier': 'synthetic supplier', 'quantity': '2'});
      expect(model.dirtyForm, isTrue);
      expect(
        await model.navigate('invoices', confirmDiscard: () async => false),
        ShellNavigationResult.cancelled,
      );
      expect(model.routeId, 'sales');
      expect(model.formDraft['quantity'], '2');
      expect(model.dirtyForm, isTrue);
      expect(store.writes, isEmpty);
      expect(
        await model.navigate('invoices', confirmDiscard: () async => true),
        ShellNavigationResult.changed,
      );
      expect(model.formDraft, isEmpty);
      expect(model.dirtyForm, isFalse);
      expect(store.writes, hasLength(1));
    },
  );

  test(
    'missing discard callback cannot silently discard a dirty form',
    () async {
      await model.initialize();
      model.markFormDirty(true);
      expect(await model.navigate('cash'), ShellNavigationResult.cancelled);
      expect(model.dirtyForm, isTrue);
      expect(store.writes, isEmpty);
    },
  );

  test(
    'session ticket survives navigation and never enters stored payload',
    () async {
      await model.initialize();
      model.setTicketPresentation({'line': 'synthetic', 'quantity': '2'});
      await model.navigate('cash');
      await model.navigate('sales');
      expect(model.ticketPresentation, {'line': 'synthetic', 'quantity': '2'});
      expect(
        () => model.ticketPresentation['quantity'] = '99',
        throwsUnsupportedError,
      );
      for (final write in store.writes) {
        expect((jsonDecode(write.payload) as Map).keys.toSet(), {
          'schemaVersion',
          'lastRouteId',
          'shortcuts',
        });
        expect(write.payload, isNot(contains('synthetic')));
      }
    },
  );

  test(
    'shortcut draft preserves duplicates, empties and cancel behavior',
    () async {
      await model.initialize();
      expect(model.beginShortcutEditing(), isTrue);
      model.setShortcut(0, 'cash');
      model.setShortcut(1, 'cash');
      model.setShortcut(2, 'savings');
      expect(model.shortcutDraft!.take(3), ['cash', 'cash', '']);
      expect(model.shortcuts.first, 'sales');
      model.cancelShortcutEditing();
      expect(model.shortcutDraft, isNull);
      expect(model.shortcuts.first, 'sales');
      expect(store.writes, isEmpty);
      model.beginShortcutEditing();
      model.setShortcut(0, 'cash');
      await model.saveShortcuts();
      expect(model.shortcuts.first, 'cash');
      expect(model.shortcutDraft, isNull);
      expect(store.writes, hasLength(1));
    },
  );

  test('failed shortcut save retains input and acknowledged configuration for retry', () async {
    await model.initialize();
    model.beginShortcutEditing();
    model.setShortcut(0, 'cash');
    store.writer = (_, _, _) async =>
        const CapabilityFailure('unavailable', 'unavailable');
    await model.saveShortcuts();
    expect(model.saveState, ShellSaveState.failed);
    expect(model.shortcutDraft!.first, 'cash');
    expect(model.shortcuts.first, 'sales');
    expect(model.hasUnsavedPreferences, isTrue);
    store.writer = null;
    await model.retrySave();
    expect(model.saveState, ShellSaveState.saved);
    expect(model.shortcuts.first, 'cash');
    expect(model.shortcutDraft, isNull);
  });

  test(
    'overlapping navigation saves serialize and use the acknowledged revision',
    () async {
      await model.initialize();
      final gate = Completer<CapabilityResult<PreferenceSnapshot>>();
      var active = 0;
      var maxActive = 0;
      store.writer = (_, payload, revision) async {
        active++;
        if (active > maxActive) maxActive = active;
        if (store.writes.length == 1) {
          final result = await gate.future;
          active--;
          return result;
        }
        active--;
        return CapabilitySuccess(
          PreferenceSnapshot(payload: payload, revision: revision! + 1),
        );
      };
      final a = model.navigate('cash');
      await _until(() => store.writes.length == 1);
      final b = model.navigate('inventory');
      expect(model.routeId, 'inventory');
      expect(model.saveState, ShellSaveState.saving);
      expect(store.writes, hasLength(1));
      gate.complete(
        CapabilitySuccess(
          PreferenceSnapshot(payload: store.writes.first.payload, revision: 1),
        ),
      );
      await Future.wait([a, b]);
      expect(maxActive, 1);
      expect(store.writes.map((w) => w.expectedRevision), [null, 1]);
      expect(_decoded(store.writes.last.payload).routeId, 'inventory');
      expect(model.saveState, ShellSaveState.saved);
      expect(model.hasUnsavedPreferences, isFalse);
    },
  );

  test(
    'a definitive failed save does not flush later queued intent automatically',
    () async {
      await model.initialize();
      final gate = Completer<CapabilityResult<PreferenceSnapshot>>();
      store.writer = (_, _, _) => gate.future;
      final a = model.navigate('cash');
      await _until(() => store.writes.length == 1);
      final b = model.navigate('inventory');
      gate.complete(const CapabilityFailure('unavailable', 'unavailable'));
      await Future.wait([a, b]);
      expect(store.writes, hasLength(1));
      expect(model.routeId, 'inventory');
      expect(model.hasUnsavedPreferences, isTrue);
      store.writer = null;
      await model.retrySave();
      expect(_decoded(store.writes.last.payload).routeId, 'inventory');
    },
  );

  test('conflict rereads but does not overwrite a newer snapshot', () async {
    await model.initialize();
    store.snapshot = _snapshot('settings', ['settings', '', '', '', '', ''], 4);
    await model.navigate('cash');
    expect(model.saveState, ShellSaveState.conflict);
    expect(model.routeId, 'cash');
    expect(store.reads, 2);
    expect(store.writes, hasLength(1));
    expect(_decoded(store.snapshot!.payload).routeId, 'settings');
    await model.retrySave();
    expect(store.writes, hasLength(1));
    expect(_decoded(store.snapshot!.payload).routeId, 'settings');
  });

  test(
    'uncertain commit recovers an identical persisted snapshot before retrying',
    () async {
      await model.initialize();
      store.writer = (_, payload, _) async {
        store.snapshot = PreferenceSnapshot(payload: payload, revision: 1);
        return const CapabilityFailure(
          'commit_unknown',
          'commit acknowledgement unknown',
        );
      };
      await model.navigate('cash');
      expect(model.saveState, ShellSaveState.commitUnknown);
      await model.retrySave();
      expect(store.writes, hasLength(1));
      expect(model.saveState, ShellSaveState.saved);
      expect(model.preferenceRevision, 1);
      expect(model.hasUnsavedPreferences, isFalse);
    },
  );

  test(
    'overlapping uncertain retries share one recovery read and close safely',
    () async {
      await model.initialize();
      store.writer = (_, payload, _) async {
        store.snapshot = PreferenceSnapshot(payload: payload, revision: 1);
        return const CapabilityFailure('commit_unknown', 'unknown');
      };
      await model.navigate('cash');
      final gate = Completer<CapabilityResult<PreferenceSnapshot?>>();
      store.reader = (_) => gate.future;
      final first = model.retrySave();
      final second = model.retrySave();
      final completion = Future.wait([first, second]);
      final busyDuringRecovery = model.busy;
      final readingDuringRecovery = model.readInProgress;
      final canEditDuringRecovery = model.canEditShortcuts;
      gate.complete(CapabilitySuccess(store.snapshot));
      await completion;
      expect(store.reads, 2, reason: 'Bootstrap plus one recovery read.');
      expect(store.writes, hasLength(1));
      expect(busyDuringRecovery, isTrue);
      expect(readingDuringRecovery, isTrue);
      expect(canEditDuringRecovery, isFalse);
      expect(model.saveState, ShellSaveState.saved);
      expect(model.hasUnsavedPreferences, isFalse);
      expect(model.busy, isFalse);
      expect(model.readInProgress, isFalse);
    },
  );

  test(
    'later navigation intent survives uncertain recovery without a stale write',
    () async {
      await model.initialize();
      store.writer = (_, payload, _) async {
        store.snapshot = PreferenceSnapshot(payload: payload, revision: 1);
        return const CapabilityFailure('commit_unknown', 'unknown');
      };
      await model.navigate('cash');
      final gate = Completer<CapabilityResult<PreferenceSnapshot?>>();
      store.reader = (_) => gate.future;
      final recovery = model.retrySave();
      final repeated = model.retrySave();
      final completion = Future.wait([recovery, repeated]);
      await model.navigate('inventory');
      expect(model.routeId, 'inventory');
      expect(store.writes, hasLength(1));
      final committed = store.snapshot;
      store.writer = null;
      store.reader = null;
      gate.complete(CapabilitySuccess(committed));
      await completion;
      expect(store.reads, 2);
      expect(store.writes, hasLength(2));
      expect(store.writes.last.expectedRevision, 1);
      expect(_decoded(store.writes.last.payload).routeId, 'inventory');
      expect(model.routeId, 'inventory');
      expect(model.saveState, ShellSaveState.saved);
      expect(model.hasUnsavedPreferences, isFalse);
    },
  );

  test(
    'disposed uncertain recovery ignores its late read without notification',
    () async {
      final separate = ShellViewModel(store: store);
      await separate.initialize();
      store.writer = (_, payload, _) async {
        store.snapshot = PreferenceSnapshot(payload: payload, revision: 1);
        return const CapabilityFailure('commit_unknown', 'unknown');
      };
      await separate.navigate('cash');
      final gate = Completer<CapabilityResult<PreferenceSnapshot?>>();
      store.reader = (_) => gate.future;
      var notices = 0;
      separate.addListener(() => notices++);
      final recovery = separate.retrySave();
      separate.dispose();
      final before = notices;
      gate.complete(CapabilitySuccess(store.snapshot));
      await recovery;
      expect(notices, before);
      expect(store.writes, hasLength(1));
    },
  );

  test(
    'uncertain commit cannot overwrite unrelated data found on retry',
    () async {
      await model.initialize();
      store.writer = (_, _, _) async =>
          const CapabilityFailure('commit_unknown', 'unknown');
      await model.navigate('cash');
      store.snapshot = _snapshot('settings', [
        'settings',
        '',
        '',
        '',
        '',
        '',
      ], 7);
      await model.retrySave();
      expect(model.saveState, ShellSaveState.conflict);
      expect(store.writes, hasLength(1));
      expect(_decoded(store.snapshot!.payload).routeId, 'settings');
    },
  );

  test(
    'healthy reread gates writes and preserves newer session intent',
    () async {
      await model.initialize();
      final gate = Completer<CapabilityResult<PreferenceSnapshot?>>();
      store.reader = (_) => gate.future;
      final retry = model.retryRead();
      await model.navigate('cash');
      expect(store.writes, isEmpty);
      gate.complete(
        CapabilitySuccess(
          _snapshot('inventory', ['settings', '', '', '', '', ''], 3),
        ),
      );
      await retry;
      expect(model.routeId, 'cash');
      expect(model.preferenceRevision, 3);
      expect(model.shortcuts.first, 'settings');
      expect(store.writes, isEmpty);
      expect(model.hasUnsavedPreferences, isTrue);
      store.reader = null;
      store.snapshot = _snapshot('inventory', [
        'settings',
        '',
        '',
        '',
        '',
        '',
      ], 3);
      await model.navigate('cash');
      expect(store.writes, hasLength(1));
      expect(store.writes.single.expectedRevision, 3);
      expect(_decoded(store.writes.single.payload).routeId, 'cash');
    },
  );

  test(
    'canceling a definitively failed shortcut edit leaves no ghost retry',
    () async {
      await model.initialize();
      model.beginShortcutEditing();
      model.setShortcut(0, 'cash');
      store.writer = (_, _, _) async =>
          const CapabilityFailure('unavailable', 'unavailable');
      await model.saveShortcuts();
      model.cancelShortcutEditing();
      expect(model.shortcutDraft, isNull);
      expect(model.hasUnsavedPreferences, isFalse);
      store.writer = null;
      await model.retrySave();
      expect(store.writes, hasLength(1));
      expect(model.shortcuts.first, 'sales');
    },
  );

  test('initialize is idempotent once the bootstrap has completed', () async {
    await model.initialize();
    await model.navigate('cash');
    store.reader = (_) async => CapabilitySuccess(
      _snapshot('inventory', ['inventory', '', '', '', '', ''], 5),
    );
    await model.initialize();
    expect(store.reads, 1);
    expect(model.routeId, 'cash');
    expect(model.preferenceRevision, 1);
    expect(model.shortcuts.first, 'sales');
  });

  test('a failing discard prompt cannot discard input or navigate', () async {
    await model.initialize();
    model.setFormDraft({'quantity': '2'});
    final result = await model.navigate(
      'cash',
      confirmDiscard: () async => throw StateError('prompt disposed'),
    );
    expect(result, ShellNavigationResult.cancelled);
    expect(model.formDraft['quantity'], '2');
    expect(model.routeId, 'sales');
    expect(store.writes, isEmpty);
  });

  test('session undo does not intercept native text editing', () async {
    await model.initialize();
    var count = 0;
    model.registerSessionUndo(() => count++);
    expect(model.dispatchUndo(textEditing: true), isFalse);
    expect(count, 0);
    expect(model.dispatchUndo(), isTrue);
    expect(count, 1);
    expect(model.dispatchUndo(), isFalse);
    expect(store.writes, isEmpty);
  });

  test('disposed model ignores a delayed read and queued commands', () async {
    final separate = ShellViewModel(store: store);
    final gate = Completer<CapabilityResult<PreferenceSnapshot?>>();
    store.reader = (_) => gate.future;
    var notices = 0;
    separate.addListener(() => notices++);
    final load = separate.initialize();
    separate.dispose();
    final before = notices;
    gate.complete(
      CapabilitySuccess(_snapshot('cash', ['cash', '', '', '', '', ''], 1)),
    );
    await load;
    expect(notices, before);
    expect(await separate.navigate('inventory'), ShellNavigationResult.gated);
    expect(store.writes, isEmpty);
  });
}

PreferenceSnapshot _snapshot(String route, List<String> slots, int revision) =>
    PreferenceSnapshot(
      payload: ShellPreferences(routeId: route, shortcuts: slots).encode(),
      revision: revision,
    );
ShellPreferences _decoded(String payload) => ShellPreferences.decode(payload);

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 20 && !condition(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(
    condition(),
    isTrue,
    reason: 'Expected deterministic async milestone.',
  );
}

final class _Write {
  const _Write(this.payload, this.expectedRevision);
  final String payload;
  final int? expectedRevision;
}

final class _Store implements LocalPreferencesStore {
  PreferenceSnapshot? snapshot;
  Future<CapabilityResult<PreferenceSnapshot?>> Function(String namespace)?
  reader;
  Future<CapabilityResult<PreferenceSnapshot>> Function(
    String namespace,
    String payload,
    int? expectedRevision,
  )?
  writer;
  final writes = <_Write>[];
  var reads = 0;

  @override
  Future<CapabilityResult<PreferenceSnapshot?>> read(String namespace) async {
    expect(namespace, 'dakhl_restaurant.shell.v1');
    reads++;
    return reader == null ? CapabilitySuccess(snapshot) : reader!(namespace);
  }

  @override
  Future<CapabilityResult<PreferenceSnapshot>> replace(
    String namespace,
    String payload, {
    int? expectedRevision,
  }) async {
    expect(namespace, 'dakhl_restaurant.shell.v1');
    writes.add(_Write(payload, expectedRevision));
    if (writer != null) return writer!(namespace, payload, expectedRevision);
    if (snapshot?.revision != expectedRevision) {
      return const CapabilityFailure(
        'conflict',
        'The stored revision changed.',
      );
    }
    snapshot = PreferenceSnapshot(
      payload: payload,
      revision: (expectedRevision ?? 0) + 1,
    );
    return CapabilitySuccess(snapshot!);
  }
}
