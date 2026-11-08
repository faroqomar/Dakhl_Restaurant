import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/accounts_view_model.dart';
import 'package:dakhl_restaurant/accounts/accounts_surface.dart';
import 'package:dakhl_restaurant/app/accounts_store.dart';
import 'package:dakhl_restaurant/app/app.dart';
import 'package:dakhl_restaurant/catalog/catalog_formatters.dart';
import 'package:dakhl_restaurant/catalog/inventory_surface.dart';
import 'package:dakhl_restaurant/catalog/product_form_dialog.dart';
import 'package:dakhl_restaurant/catalog/stock_movement_dialog.dart';
import 'package:dakhl_restaurant/ui/components.dart';
import 'package:dakhl_restaurant/shell/shell_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';

import '../support/preferences_store.dart';
import '../accounts/accounts_view_model_test.dart' show FixtureStore;

// Retained C1 acceptance regressions: host widget controls and a real temporary
// SQLite/PowerSync store. These do not establish native-device acceptance.
void main() {
  testWidgets('mounted save freezes submitted input and rejects busy taps', (
    tester,
  ) async {
    final fixture = await _mount(tester);
    await _openAndFill(tester);
    final catalog = tester
        .widget<ProductFormDialog>(find.byType(ProductFormDialog))
        .viewModel;
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    fixture.store.nextWriteGate = gate;
    final writes = fixture.store.documentWriteCalls;
    final before = fixture.repository.snapshot!;
    await _tap(tester, find.widgetWithText(DakhlButton, 'حفظ التغيير'));
    await _until(tester, () => fixture.store.documentWriteCalls == writes + 1);
    final submitted = fixture.store.submitted.last;
    expect(catalog.busy, isTrue);
    final nameField = find.descendant(
      of: find.widgetWithText(DakhlField, 'اسم الصنف'),
      matching: find.byType(TextFormField),
    );
    expect(tester.widget<TextFormField>(nameField).enabled, isFalse);
    expect(
      tester
          .widget<DakhlButton>(find.widgetWithText(DakhlButton, 'حفظ التغيير'))
          .busy,
      isTrue,
    );
    // A late controller callback cannot change the already submitted intent.
    tester.widget<TextFormField>(nameField).controller!.text = 'late callback';
    await _tap(tester, find.widgetWithText(DakhlButton, 'حفظ التغيير'));
    expect(fixture.store.documentWriteCalls, writes + 1);
    expect(catalog.busy, isTrue);
    expect(catalog.errorCode, isNull);
    expect(fixture.repository.snapshot, before);
    gate.complete();
    await _until(
      tester,
      () => find.byType(ProductFormDialog).evaluate().isEmpty,
    );
    final payload = jsonDecode(submitted.payload) as Map;
    expect(
      fixture.repository.document!.toJson()['products'],
      payload['products'],
    );
    expect((payload['products'] as List).single['name'], 'C1 recovery draft');
    expect(fixture.repository.snapshot!.revision, before.revision + 1);
    expect(fixture.repository.snapshot!.writeToken, submitted.token);
    expect(find.text('late callback'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'disposed mounted form cannot publish into a replacement account',
    (tester) async {
      final first = await _mount(tester);
      await _openAndFill(tester);
      final firstCatalog = tester
          .widget<ProductFormDialog>(find.byType(ProductFormDialog))
          .viewModel;
      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      first.store.nextWriteGate = gate;
      final writes = first.store.documentWriteCalls;
      await _tap(tester, find.widgetWithText(DakhlButton, 'حفظ التغيير'));
      await _until(tester, () => first.store.documentWriteCalls == writes + 1);
      await _until(
        tester,
        () => first.store.innerWriteResults.length == writes + 1,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      // The delayed source uses real SQLite. Replacement storage is an explicit
      // memory fixture: this case checks mounted callback isolation, not another
      // simultaneous native database lifecycle.
      final secondStore = FixtureStore();
      final secondRepository = AccountsRepository(store: secondStore);
      final secondAccounts = AccountsViewModel(repository: secondRepository);
      await secondAccounts.initialize();
      await secondAccounts.save();
      addTearDown(secondAccounts.dispose);
      await tester.pumpWidget(_visibleApp(secondAccounts));
      await _until(
        tester,
        () => find.byType(InventorySurface).evaluate().isNotEmpty,
      );
      await _openAndFill(tester);
      await tester.enterText(
        find.widgetWithText(DakhlField, 'اسم الصنف'),
        'replacement draft',
      );
      final secondSnapshot = secondRepository.snapshot;
      final secondWrites = secondStore.writes;
      final secondCatalog = tester
          .widget<ProductFormDialog>(find.byType(ProductFormDialog))
          .viewModel;
      gate.complete();
      await _until(tester, () => !firstCatalog.busy);
      final saved =
          first.store.innerWriteResults.last
              as CapabilitySuccess<DocumentSnapshot>;
      expect(
        (jsonDecode(saved.value.payload)['products'] as List).single['name'],
        'C1 recovery draft',
      );
      expect(find.byType(ProductFormDialog), findsOneWidget);
      expect(find.text('replacement draft'), findsOneWidget);
      expect(secondRepository.snapshot, secondSnapshot);
      expect(secondRepository.document!.toJson()['products'], isEmpty);
      expect(secondStore.writes, secondWrites);
      expect(secondCatalog.busy, isFalse);
      expect(secondCatalog.errorCode, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'stock form retains input after an actual precommit store fault',
    (tester) async {
      var armed = false;
      var faults = 0;
      final fixture = await _mount(
        tester,
        checkpoint: (point) async {
          if (armed && point == 'transaction.before_commit') {
            armed = false;
            faults++;
            throw const FileSystemException(
              'Synthetic C1 stock checkpoint failure',
            );
          }
        },
      );
      await _openAndFill(tester);
      await _tap(tester, find.widgetWithText(DakhlButton, 'حفظ التغيير'));
      await _until(
        tester,
        () => find.byType(ProductFormDialog).evaluate().isEmpty,
      );
      await _tap(tester, find.widgetWithText(DakhlButton, 'تزويد / تسوية'));
      await _until(
        tester,
        () => find.byType(StockMovementDialog).evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.widgetWithText(DakhlField, 'الكمية (قطعة)'),
        '2.5',
      );
      await tester.enterText(
        find.widgetWithText(DakhlField, 'التاريخ'),
        '2001-01-02',
      );
      await tester.enterText(
        find.widgetWithText(DakhlField, 'ملاحظات (اختياري)'),
        'retained stock reason',
      );
      final catalog = tester
          .widget<StockMovementDialog>(find.byType(StockMovementDialog))
          .viewModel;
      final before = fixture.repository.snapshot!;
      armed = true;
      await _tap(tester, find.widgetWithText(DakhlButton, 'حفظ التغيير'));
      await _until(
        tester,
        () => faults == 1 && !catalog.busy && catalog.errorCode != null,
      );
      expect(fixture.repository.snapshot, before);
      expect(find.byType(StockMovementDialog), findsOneWidget);
      expect(find.text('2.5'), findsOneWidget);
      expect(find.text('2001-01-02'), findsOneWidget);
      expect(find.text('retained stock reason'), findsOneWidget);
      expect(
        find.text(CatalogFormatters.errorMessage(catalog.errorCode!)),
        findsOneWidget,
      );
      final disk = await tester.runAsync(fixture.durable.readDocument);
      final persisted = (disk as CapabilitySuccess<DocumentSnapshot?>).value!;
      expect(persisted.payload, before.payload);
      expect(persisted.revision, before.revision);
      expect(persisted.fence, before.fence);
      expect(persisted.writeToken, before.writeToken);
      await _tap(tester, find.widgetWithText(DakhlButton, 'حفظ التغيير'));
      await _until(
        tester,
        () => find.byType(StockMovementDialog).evaluate().isEmpty,
      );
      final entries =
          fixture.repository.document!.toJson()['stockEntries'] as List;
      expect(entries, hasLength(2));
      expect(entries.last['quantity'], 2.5);
      expect(entries.last['date'], '2001-01-02');
      expect(entries.last['note'], 'retained stock reason');
      expect(fixture.repository.snapshot!.revision, before.revision + 1);
      expect(find.text('7.5 قطعة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scenario in [
    (committed: true, shell: false),
    (committed: false, shell: false),
    (committed: true, shell: true),
  ]) {
    final committed = scenario.committed;
    testWidgets(
      'visible unknown save reads back ${committed ? 'one committed product' : 'no invented success'} through ${scenario.shell ? 'shell' : 'settings'}',
      (tester) async {
        final fixture = await _mount(tester);

        final repo = fixture.repository;
        await _openAndFill(tester);

        final baseline = repo.snapshot;
        if (committed) {
          fixture.store.loseNextAcknowledgement = true;
        } else {
          fixture.store.unknownBeforeCommit = true;
        }
        await _tap(tester, find.widgetWithText(DakhlButton, 'حفظ التغيير'));
        await _until(
          tester,
          () => find
              .text(CatalogFormatters.errorMessage('commit_unknown'))
              .evaluate()
              .isNotEmpty,
        );
        expect(repo.hasUnknownWrite, isTrue);
        expect(repo.snapshot, baseline);
        expect(repo.document!.toJson()['products'], isEmpty);
        expect(find.text('C1 recovery draft'), findsOneWidget);
        expect(find.text('الصورة المختارة: كباب لحم'), findsOneWidget);
        final attempts = fixture.store.documentWriteCalls;
        final submitted =
            jsonDecode(fixture.store.submitted.last.payload) as Map;
        final submittedProduct = (submitted['products'] as List).single as Map;
        final submittedOpening =
            (submitted['stockEntries'] as List).single as Map;
        expect(submittedOpening['productId'], submittedProduct['id']);
        expect(submittedOpening['date'], '2001-01-01');
        expect(submittedOpening['quantity'], 5);
        final token = fixture.store.submitted.last.token;
        await _tap(tester, find.widgetWithText(DakhlButton, 'حفظ التغيير'));
        expect(fixture.store.documentWriteCalls, attempts);
        expect(fixture.store.submitted.last.token, token);
        expect(repo.hasUnknownWrite, isTrue);

        // Modal dismissal asks before dropping input. Continuing retains it.
        await _tap(tester, find.widgetWithText(DakhlButton, 'إلغاء'));
        await _tap(tester, find.widgetWithText(DakhlButton, 'متابعة التعديل'));
        expect(find.text('C1 recovery draft'), findsOneWidget);
        expect(repo.hasUnknownWrite, isTrue);
        await _tap(tester, find.widgetWithText(DakhlButton, 'إلغاء'));
        await _tap(tester, find.widgetWithText(DakhlButton, 'تجاهل التغييرات'));
        await _until(
          tester,
          () => find.byType(ProductFormDialog).evaluate().isEmpty,
        );

        // Catalog writes also need shell-level pending confirmation. Accounts
        // state can remain saved while the repository fences an unknown write.
        expect(fixture.accounts.state, AccountsState.saved);
        expect(find.text('تعذّر تأكيد الحفظ؛ أعد التحقق.'), findsOneWidget);
        expect(
          find.widgetWithText(DakhlButton, 'إعادة المحاولة'),
          findsOneWidget,
        );

        final resolves = fixture.store.resolveCalls;
        final reads = fixture.store.readCalls;
        if (scenario.shell) {
          await _tap(
            tester,
            find.widgetWithText(DakhlButton, 'إعادة المحاولة'),
          );
        } else {
          // Use the existing account readback control via real shell navigation.
          await _tap(tester, find.widgetWithText(DakhlButton, 'الإعدادات'));
          await _tap(tester, find.text('النسخ والبيانات'));
          await _until(
            tester,
            () => find.byType(AccountsSurface).evaluate().isNotEmpty,
          );
          expect(
            tester
                .widget<DakhlButton>(
                  find.widgetWithText(DakhlButton, 'حفظ الحسابات'),
                )
                .onPressed,
            isNull,
          );
          await _tap(
            tester,
            find.descendant(
              of: find.byType(AccountsSurface),
              matching: find.widgetWithText(DakhlButton, 'إعادة التحقق'),
            ),
          );
        }
        await _until(
          tester,
          () => !fixture.accounts.busy && !repo.hasUnknownWrite,
        );
        expect(fixture.store.resolveCalls, resolves + 1);
        expect(fixture.store.readCalls, greaterThan(reads));
        expect(fixture.store.documentWriteCalls, attempts);
        if (committed) {
          expect(fixture.accounts.state, AccountsState.saved);
          final actual = repo.document!.toJson();
          expect(actual['products'], [submittedProduct]);
          expect(actual['stockEntries'], [submittedOpening]);
          expect(repo.snapshot!.writeToken, token);
          expect(repo.snapshot!.revision, baseline!.revision + 1);
          await _tap(tester, find.widgetWithText(DakhlButton, 'المخزن'));

          await _until(
            tester,
            () => find.byType(InventorySurface).evaluate().isNotEmpty,
          );
          expect(find.text('C1 recovery draft'), findsOneWidget);
          expect(find.byType(ProductFormDialog), findsNothing);
          final expected = repo.snapshot;
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(fixture.durable.close);
          final reopened = fixture.openStore();
          try {
            final result = await tester.runAsync(reopened.readDocument);
            expect(result, isA<CapabilitySuccess<DocumentSnapshot?>>());
            final actual =
                (result as CapabilitySuccess<DocumentSnapshot?>).value!;
            expect(actual.payload, expected!.payload);
            expect(actual.fence, expected.fence);
            expect(actual.revision, expected.revision);
            expect(actual.writeToken, expected.writeToken);
          } finally {
            await tester.runAsync(reopened.close);
          }
        } else {
          expect(fixture.accounts.state, AccountsState.conflict);
          expect(fixture.accounts.failureCode, 'stale_revision');
          expect(repo.snapshot, baseline);
          expect(repo.document!.toJson()['products'], isEmpty);
          expect(repo.document!.toJson()['stockEntries'], isEmpty);
          expect(
            find.text('تغيّرت الحسابات المحفوظة؛ أعد قراءتها قبل المتابعة.'),
            findsWidgets,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('visible precommit failure retains draft and retries once', (
    tester,
  ) async {
    final fixture = await _mount(tester);

    await _openAndFill(tester);

    final before = fixture.repository.snapshot;
    fixture.store.failBeforeCommit = true;
    await _tap(tester, find.widgetWithText(DakhlButton, 'حفظ التغيير'));
    await _until(
      tester,
      () => find
          .text(CatalogFormatters.errorMessage('unavailable'))
          .evaluate()
          .isNotEmpty,
    );
    expect(fixture.repository.snapshot, before);
    expect(fixture.repository.hasUnknownWrite, isFalse);
    expect(find.text('C1 recovery draft'), findsOneWidget);
    final attempts = fixture.store.documentWriteCalls;
    final firstPayload =
        jsonDecode(fixture.store.submitted.last.payload) as Map;
    await _tap(
      tester,
      find.descendant(
        of: find.byType(ProductFormDialog),
        matching: find.widgetWithText(DakhlButton, 'إعادة المحاولة'),
      ),
    );
    await _until(
      tester,
      () => find.byType(ProductFormDialog).evaluate().isEmpty,
    );
    expect(fixture.store.documentWriteCalls, attempts + 1);
    final saved = fixture.repository.document!.toJson();
    expect(saved['products'], firstPayload['products']);
    expect(saved['stockEntries'], hasLength(1));
    expect(
      (saved['stockEntries'] as List).single['productId'],
      (saved['products'] as List).single['id'],
    );
    expect(find.text('C1 recovery draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'clean archive uncertainty rebuilds shell and verifies without writing again',
    (tester) async {
      final fixture = await _mount(tester);
      await _openAndFill(tester);
      await _tap(tester, find.widgetWithText(DakhlButton, 'حفظ التغيير'));
      await _until(
        tester,
        () => find.byType(ProductFormDialog).evaluate().isEmpty,
      );
      await _tap(tester, find.widgetWithText(DakhlButton, 'تعديل'));
      await _until(
        tester,
        () => find.byType(ProductFormDialog).evaluate().isNotEmpty,
      );
      fixture.store.loseNextAcknowledgement = true;
      await _tap(
        tester,
        find.widgetWithText(DakhlButton, 'إيقاف الصنف مؤقتاً'),
      );
      await _until(tester, () => fixture.repository.hasUnknownWrite);
      final writes = fixture.store.documentWriteCalls;
      final submittedToken = fixture.store.submitted.last.token;
      expect(fixture.accounts.state, AccountsState.saved);
      // No field was edited, so Cancel does not emit a shell dirty-reset event.
      await _tap(tester, find.widgetWithText(DakhlButton, 'إلغاء'));
      await _until(
        tester,
        () => find.byType(ProductFormDialog).evaluate().isEmpty,
      );
      expect(find.text('تعذّر تأكيد الحفظ؛ أعد التحقق.'), findsOneWidget);
      await _tap(tester, find.widgetWithText(DakhlButton, 'إعادة المحاولة'));
      await _until(tester, () => !fixture.repository.hasUnknownWrite);
      expect(fixture.store.documentWriteCalls, writes);
      expect(fixture.repository.snapshot!.writeToken, submittedToken);
      final saved = fixture.repository.document!.toJson();
      expect((saved['products'] as List).single['archived'], isTrue);
      expect(saved['stockEntries'], hasLength(1));
      expect(find.text('محفوظ على جهازك'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<_Fixture> _mount(
  WidgetTester tester, {
  WorkspaceCheckpoint? checkpoint,
}) async {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final root = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('dakhl-c1-visible-'),
  ))!;
  AppAccountsStore openStore() => AppAccountsStore(
    openStore: () => PowerSyncLocalDocumentWorkspaceStore.open(
      directoryPath: root.path,
      checkpoint: checkpoint,
    ),
  );
  final durable = openStore();
  final store = _FaultStore(durable);
  final repository = AccountsRepository(store: store);
  final accounts = AccountsViewModel(repository: repository);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    accounts.dispose();
    await tester.runAsync(() async {
      await durable.close();
      await root.delete(recursive: true);
    });
  });

  await tester.runAsync(() async {
    await accounts.initialize();
    await accounts.save();
  });

  expect(accounts.state, AccountsState.saved);
  // Native-backed initialization starts inside initState. Keep its asynchronous
  // chain in the real zone, including the mounted sales workspace bootstrap.
  ShellViewModel? shell;
  await tester.runAsync(
    () => tester.pumpWidget(
      _visibleApp(accounts, onShellReady: (value) => shell = value),
    ),
  );
  try {
    await _until(
      tester,
      () =>
          find.byType(InventorySurface).evaluate().isNotEmpty && !accounts.busy,
    );
  } on Object {
    fail(
      'C1 mount: account=${accounts.state} busy=${accounts.busy} '
      'shell=${shell?.bootstrapState} route=${shell?.routeId} failure=${shell?.failureCode}',
    );
  }
  return _Fixture(repository, accounts, durable, store, openStore);
}

Widget _visibleApp(
  AccountsViewModel accounts, {
  ValueChanged<ShellViewModel>? onShellReady,
}) => DakhlRestaurantApp(
  accounts: accounts,
  onShellReady: onShellReady,
  preferencesStore: MemoryPreferencesStore(
    snapshot: PreferenceSnapshot(
      payload: jsonEncode({
        'schemaVersion': 1,
        'lastRouteId': 'inventory',
        'shortcuts': [
          'sales',
          'inventory',
          'expenses',
          'cash',
          'materials',
          'settings',
        ],
      }),
      revision: 1,
    ),
  ),
);

Future<void> _openAndFill(WidgetTester tester) async {
  await _tap(tester, find.widgetWithText(DakhlButton, 'إضافة صنف').first);
  await _until(
    tester,
    () => find.byType(ProductFormDialog).evaluate().isNotEmpty,
  );
  for (final field in <String, String>{
    'اسم الصنف': 'C1 recovery draft',
    'سعر البيع بالدينار · د.ع': '14000',
    'الكمية الافتتاحية': '5',
    'تاريخ الكمية': '2001-01-01',
  }.entries) {
    final finder = find.widgetWithText(DakhlField, field.key);
    await tester.ensureVisible(finder);
    await tester.enterText(finder, field.value);
  }
  await _tap(tester, find.bySemanticsLabel('اختيار صورة كباب لحم'));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);

  await tester.ensureVisible(finder);

  await tester.pump();

  await tester.runAsync(() => tester.tap(finder));

  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 200; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 25));
    if (ready()) {
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
  }
  fail('C1 visible workflow did not reach the expected state.');
}

final class _Fixture {
  _Fixture(
    this.repository,
    this.accounts,
    this.durable,
    this.store,
    this.openStore,
  );
  final AccountsRepository repository;
  final AccountsViewModel accounts;
  final AppAccountsStore durable;
  final _FaultStore store;
  final AppAccountsStore Function() openStore;
}

/// Test-only fault transport over the actual SQLite-backed store.
final class _FaultStore implements LocalDocumentWorkspaceStore {
  _FaultStore(this.inner);
  final LocalDocumentWorkspaceStore inner;
  bool loseNextAcknowledgement = false;
  bool failBeforeCommit = false;
  bool unknownBeforeCommit = false;
  int readCalls = 0;
  int resolveCalls = 0;
  final submitted = <({String payload, String token})>[];
  int documentWriteCalls = 0;
  Completer<void>? nextWriteGate;
  final innerWriteResults = <CapabilityResult<DocumentSnapshot>>[];
  @override
  Future<CapabilityResult<DocumentSnapshot>> writeDocument(
    String payload, {
    required String writeToken,
    DocumentSnapshot? expected,
    bool replaceGeneration = false,
  }) async {
    documentWriteCalls++;
    submitted.add((payload: payload, token: writeToken));
    final gate = nextWriteGate;
    nextWriteGate = null;
    if (failBeforeCommit || unknownBeforeCommit) {
      final code = unknownBeforeCommit ? 'commit_unknown' : 'unavailable';
      failBeforeCommit = false;
      unknownBeforeCommit = false;
      return CapabilityFailure(code, 'Synthetic failure before commit.');
    }
    final result = await inner.writeDocument(
      payload,
      writeToken: writeToken,
      expected: expected,
      replaceGeneration: replaceGeneration,
    );
    innerWriteResults.add(result);
    if (gate != null) await gate.future;
    if (loseNextAcknowledgement &&
        result is CapabilitySuccess<DocumentSnapshot>) {
      loseNextAcknowledgement = false;
      return const CapabilityFailure(
        'commit_unknown',
        'Synthetic acknowledgement loss after commit.',
      );
    }
    return result;
  }

  @override
  Future<CapabilityResult<DocumentSnapshot?>> readDocument() => () {
    readCalls++;
    return inner.readDocument();
  }();
  @override
  Future<CapabilityResult<DocumentSnapshot>> resumeInitialCreation(
    String payload, {
    required String writeToken,
  }) => inner.resumeInitialCreation(payload, writeToken: writeToken);
  @override
  Future<CapabilityResult<WorkspaceState>> readWorkspace(StorageFence fence) =>
      inner.readWorkspace(fence);
  @override
  Future<CapabilityResult<WorkspaceSnapshot>> writeWorkspace(
    String payload, {
    required StorageFence fence,
    required int? expectedRevision,
    required String writeToken,
  }) => inner.writeWorkspace(
    payload,
    fence: fence,
    expectedRevision: expectedRevision,
    writeToken: writeToken,
  );
  @override
  Future<CapabilityResult<PreviousDocument?>> readPrevious() =>
      inner.readPrevious();
  @override
  Future<CapabilityResult<String>> preserveSource(List<int> bytes) =>
      inner.preserveSource(bytes);
  @override
  Future<CapabilityResult<DocumentSnapshot>> recoverPrevious(
    PreviousDocument previous, {
    required String payload,
    required String writeToken,
  }) =>
      inner.recoverPrevious(previous, payload: payload, writeToken: writeToken);
  @override
  Future<CapabilityResult<void>> resolvePendingWrite() => () {
    resolveCalls++;
    return inner.resolvePendingWrite();
  }();
  @override
  Future<void> close() => inner.close();
}
