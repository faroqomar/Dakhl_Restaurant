import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounts/accounts_surface.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_accounts_surface.dart';
import 'package:dakhl_restaurant/accounts/portable_account_transfer_controller.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/app/app.dart';
import 'package:dakhl_restaurant/app/portable_restaurant_host.dart';
import 'package:dakhl_restaurant/sales/ticket_workspace.dart';
import 'package:dakhl_restaurant/shell/shell_view_model.dart';
import 'package:dakhl_restaurant/ui/components.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;
import '../support/preferences_store.dart';

final class MockTransfer implements FileTransferCapability {
  Uint8List? savedBytes;
  CapabilityResult<Uint8List>? openResult;
  bool failSave = false;
  int saveCount = 0;
  int openCount = 0;

  @override
  Future<CapabilityResult<Uint8List>> open() async {
    openCount++;
    return openResult ?? const CapabilityCancelled();
  }

  @override
  Future<CapabilityResult<void>> save(Uint8List bytes) async {
    saveCount++;
    if (failSave) {
      return const CapabilityFailure('file_unavailable', 'Save denied.');
    }
    savedBytes = bytes;
    return const CapabilitySuccess(null);
  }
}

PortableJournalState createTestState({
  required String lineage,
  required String restaurantName,
  String? journalId,
}) {
  final date = DateOnly.parse(
    '2026-11-01',
    minimumYear: 1000,
    maximumYear: 9999,
  );
  final emptyDoc = const LegacyAccountCodec().empty();
  final docJson = Map<String, Object?>.from(emptyDoc.toJson());
  final prefs = Map<String, Object?>.from(docJson['preferences'] as Map);
  final rest = Map<String, Object?>.from(prefs['restaurant'] as Map);
  rest['name'] = restaurantName;
  prefs['restaurant'] = rest;
  docJson['preferences'] = prefs;
  docJson['products'] = [
    {
      'id': 'p1',
      'name': 'Shawarma Product',
      'code': '',
      'unit': 'piece',
      'group': '',
      'price': 1500,
      'minStock': 0,
      'trackStock': false,
      'archived': false,
    },
  ];
  final account = const LegacyAccountCodec().decodeJson(docJson);

  final jId = journalId ?? 'opening-1';
  final opening = RestaurantJournalMapper().mapVerifiedCutoverOpening(
    journalId: jId,
    effectiveDate: date,
    verifiedPhysicalRegisterCash: BigInt.from(50000),
    verifiedCashboxBalance: BigInt.zero,
    verifiedSupplierDebts: {},
  );

  return PortableJournalState(
    accountLineage: lineage,
    account: account,
    sourceProvenance: const PortableJournalSourceProvenance(
      sourceVersion: 11,
      enrolledAt: '2026-11-01T00:00:00Z',
      migrated: false,
    ),
    cutoverState: PortableJournalCutoverState.established(
      cutoverDate: date,
      openingJournalId: jId,
    ),
    journals: [
      PortableJournalEntry(
        journal: opening.journal,
        sourceType: RestaurantJournalSourceType.cutoverOpening.name,
        sourceRecordId: '$jId-src',
        recordedAt: '2026-11-01T00:00:00Z',
      ),
    ],
    receipts: [
      const DurableCommandReceipt(
        identity: DurableCommandIdentity(
          operationId: 'op-initial',
          payloadVersion: 1,
          canonicalPayloadIdentity: 'hash-initial',
        ),
        status: DurableCommandStatus.committed,
        committedRevision: 1,
        fence: StorageFence(storeId: 'store', generation: 'gen-init'),
        sequence: 1,
        outcomePayload: '{"status":"ok"}',
      ),
    ],
  );
}

void main() {
  const codec = PortableJournalCodec();

  for (final replaceGeneration in [false, true]) {
    testWidgets(
      'data reload adopts operational authority (replacement=$replaceGeneration)',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = FixtureStore();
        final initial = createTestState(
          lineage: 'reload-old',
          restaurantName: 'Old',
        );
        final seeded = await store.writeDocument(
          codec.encodeState(initial),
          writeToken: 'seed',
        );
        final snapshot = (seeded as CapabilitySuccess<DocumentSnapshot>).value;
        ShellViewModel? shell;
        await tester.pumpWidget(
          PortableRestaurantHost(
            store: store,
            initialSnapshot: snapshot,
            compareText: (a, b) => a.compareTo(b),
            freshTicket: () => TicketDraft(
              id: 'reload-ticket',
              date: '2026-11-08',
              orderType: 'سفري',
              discount: '',
              note: '',
              lines: const [],
            ),
            preferencesStore: MemoryPreferencesStore(),
            onShellReady: (value) => shell = value,
          ),
        );
        await tester.pumpAndSettle();
        final host = tester.state<PortableRestaurantHostState>(
          find.byType(PortableRestaurantHost),
        );
        final oldSession = host.session;
        await shell!.navigate('settings');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('النسخ والبيانات'));
        await tester.tap(find.text('النسخ والبيانات'));
        await tester.pumpAndSettle();
        final next = createTestState(
          lineage: replaceGeneration ? 'reload-new' : 'reload-old',
          restaurantName: 'Reloaded',
        );
        final written = await store.writeDocument(
          codec.encodeState(next),
          writeToken: 'external',
          expected: snapshot,
          replaceGeneration: replaceGeneration,
        );
        expect(written, isA<CapabilitySuccess<DocumentSnapshot>>());
        await tester.ensureVisible(
          find.byKey(const Key('portable-reload-button')),
        );
        await tester.tap(find.byKey(const Key('portable-reload-button')));
        await tester.pumpAndSettle();
        expect(host.session, isNot(same(oldSession)));
        expect(host.session!.snapshot.payload, store.document!.payload);
        expect(host.session!.snapshot.fence, store.document!.fence);
        expect(host.session!.settings.values.name, 'Reloaded');
        expect(
          host.transferController!.snapshot.payload,
          host.session!.snapshot.payload,
        );
        expect(host.generation, 2);
      },
    );
  }

  testWidgets(
    'mounts host, initializes operations session and transfer controller, and renders app',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = createTestState(
        lineage: 'lineage-test-1',
        restaurantName: 'مطعم الأصالة الأول',
      );
      final store = FixtureStore();
      final seed = await store.writeDocument(
        codec.encodeState(state),
        writeToken: 'seed-1',
      );
      final snapshot = (seed as CapabilitySuccess<DocumentSnapshot>).value;
      final transfer = MockTransfer();
      final preferences = MemoryPreferencesStore();

      ShellViewModel? shell;
      await tester.pumpWidget(
        PortableRestaurantHost(
          store: store,
          initialSnapshot: snapshot,
          compareText: (a, b) => a.compareTo(b),
          freshTicket: () => TicketDraft(
            id: 'fresh-1',
            date: '2026-11-08',
            orderType: 'سفري',
            discount: '',
            note: '',
            lines: const [],
          ),
          preferencesStore: preferences,
          transfer: transfer,
          onShellReady: (value) => shell = value,
        ),
      );
      await tester.pumpAndSettle();

      final hostState = tester.state<PortableRestaurantHostState>(
        find.byType(PortableRestaurantHost),
      );

      expect(hostState.session, isNotNull);
      expect(hostState.transferController, isNotNull);
      expect(hostState.committedSnapshot.fence, snapshot.fence);
      expect(hostState.generation, 1);
      expect(find.byType(DakhlRestaurantApp), findsOneWidget);
      expect(shell, isNotNull);
    },
  );

  testWidgets(
    'propagates acknowledged session snapshot advances to transfer controller and export view',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = createTestState(
        lineage: 'lineage-sync-test',
        restaurantName: 'مطعم التحديث المستمر',
      );
      final store = FixtureStore();
      final seed = await store.writeDocument(
        codec.encodeState(state),
        writeToken: 'seed-sync',
      );
      final snapshot = (seed as CapabilitySuccess<DocumentSnapshot>).value;
      final transfer = MockTransfer();

      ShellViewModel? shell;
      await tester.pumpWidget(
        PortableRestaurantHost(
          store: store,
          initialSnapshot: snapshot,
          compareText: (a, b) => a.compareTo(b),
          freshTicket: () => TicketDraft(
            id: 'fresh-sale',
            date: '2026-11-08',
            orderType: 'سفري',
            discount: '',
            note: '',
            lines: const [],
          ),
          preferencesStore: MemoryPreferencesStore(),
          transfer: transfer,
          onShellReady: (value) => shell = value,
        ),
      );
      await tester.pumpAndSettle();

      final hostState = tester.state<PortableRestaurantHostState>(
        find.byType(PortableRestaurantHost),
      );

      final initialRevision = hostState.transferController!.snapshot.revision;
      final initialJournalCount = hostState.transferController!.journals.length;

      // Perform a sale in the active session
      await tester.tap(
        find.widgetWithText(DakhlButton, 'إضافة Shawarma Product'),
      );
      await tester.pumpAndSettle();
      final pay = find.widgetWithText(DakhlButton, 'تأكيد البيع النقدي');
      expect(pay, findsOneWidget);
      await tester.tap(pay);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('تم تأكيد البيع النقدي'), findsOneWidget);
      await tester.tap(find.byTooltip('إغلاق النافذة'));
      await tester.pumpAndSettle();

      // Ensure session is synchronized
      await hostState.session!.synchronize();
      await tester.pumpAndSettle();

      // Controller snapshot must have advanced to newest acknowledged snapshot
      expect(
        hostState.transferController!.snapshot.revision,
        greaterThan(initialRevision),
      );
      expect(
        hostState.transferController!.snapshot.revision,
        hostState.session!.snapshot.revision,
      );
      expect(
        hostState.transferController!.journals.length,
        greaterThan(initialJournalCount),
      );

      // Navigate to settings and verify file export view shows updated journal count
      await shell!.navigate('settings');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('النسخ والبيانات'));
      await tester.tap(find.text('النسخ والبيانات'));
      await tester.pumpAndSettle();

      expect(find.byType(PortableAccountsSurface), findsOneWidget);
      expect(find.byType(AccountsSurface), findsNothing);
      expect(
        find.text('${hostState.transferController!.journals.length} قيد'),
        findsOneWidget,
      );

      // Export file and verify it contains the newest state, not the initial stale account
      final exportBtn = find.byKey(const Key('portable-export-button'));
      await tester.ensureVisible(exportBtn);
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      expect(transfer.saveCount, 1);
      final decodedExport = codec.decodeBytes(transfer.savedBytes!);
      expect(
        decodedExport.journals.length,
        hostState.transferController!.journals.length,
      );
      expect(decodedExport.account.toJson()['sales'], isNotEmpty);
    },
  );

  testWidgets(
    'mutual write exclusion: transfer controller activity blocks session peer writes',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = createTestState(
        lineage: 'lineage-mutex-test',
        restaurantName: 'مطعم الحماية المتبادلة',
      );
      final store = FixtureStore();
      final seed = await store.writeDocument(
        codec.encodeState(state),
        writeToken: 'seed-mutex',
      );
      final snapshot = (seed as CapabilitySuccess<DocumentSnapshot>).value;
      final transfer = MockTransfer();

      await tester.pumpWidget(
        PortableRestaurantHost(
          store: store,
          initialSnapshot: snapshot,
          compareText: (a, b) => a.compareTo(b),
          freshTicket: () => TicketDraft(
            id: 'fresh-mutex',
            date: '2026-11-08',
            orderType: 'سفري',
            discount: '',
            note: '',
            lines: const [],
          ),
          preferencesStore: MemoryPreferencesStore(),
          transfer: transfer,
        ),
      );
      await tester.pumpAndSettle();

      final hostState = tester.state<PortableRestaurantHostState>(
        find.byType(PortableRestaurantHost),
      );

      // Prepare an import candidate in transfer controller
      final candidateState = createTestState(
        lineage: 'lineage-candidate',
        restaurantName: 'مطعم جديد مرشح',
      );
      final prep = hostState.transferController!.prepareImport(
        codec.encodeBytes(candidateState),
      );
      expect(prep, isA<CapabilitySuccess<PendingPortableAccountImport>>());
      expect(hostState.transferController!.hasPendingImport, isTrue);

      // Peer write in session (saveSettings) must be blocked because import candidate is pending
      final saveBlocked = await hostState.session!.saveSettings();
      expect(saveBlocked, isA<CapabilityFailure<void>>());
      expect((saveBlocked as CapabilityFailure).code, 'busy');

      // Cancel import candidate
      hostState.transferController!.cancelImport();
      expect(hostState.transferController!.hasPendingImport, isFalse);

      // Session saveSettings can now proceed
      final saveAllowed = await hostState.session!.saveSettings();
      expect(saveAllowed, isA<CapabilitySuccess<void>>());
    },
  );

  testWidgets(
    'mutual write exclusion: dirty settings and pending session writers block transfer write/import',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = createTestState(
        lineage: 'lineage-dirty-test',
        restaurantName: 'مطعم الحماية من الكتابة غير المحفوظة',
      );
      final store = FixtureStore();
      final seed = await store.writeDocument(
        codec.encodeState(state),
        writeToken: 'seed-dirty',
      );
      final snapshot = (seed as CapabilitySuccess<DocumentSnapshot>).value;
      final transfer = MockTransfer();

      await tester.pumpWidget(
        PortableRestaurantHost(
          store: store,
          initialSnapshot: snapshot,
          compareText: (a, b) => a.compareTo(b),
          freshTicket: () => TicketDraft(
            id: 'fresh-dirty',
            date: '2026-11-08',
            orderType: 'سفري',
            discount: '',
            note: '',
            lines: const [],
          ),
          preferencesStore: MemoryPreferencesStore(),
          transfer: transfer,
        ),
      );
      await tester.pumpAndSettle();

      final hostState = tester.state<PortableRestaurantHostState>(
        find.byType(PortableRestaurantHost),
      );

      // Dirty the restaurant settings without saving
      final currentValues = hostState.session!.settings.values;
      hostState.session!.settings.replace(
        currentValues.copyWith(name: 'اسم مطعم معدل ولم يحفظ'),
      );
      expect(hostState.session!.settings.isDirty, isTrue);

      // Transfer export / import must be blocked while dirty settings are pending
      expect(hostState.transferController!.isWriteBlocked(), isTrue);
      final exportResult = await hostState.transferController!.exportTo(
        transfer,
      );
      expect(exportResult, isA<CapabilityFailure<void>>());
      expect((exportResult as CapabilityFailure).code, 'busy');

      // Discard dirty changes
      await hostState.session!.reloadSettings(discardChanges: true);
      expect(hostState.session!.settings.isDirty, isFalse);
      expect(hostState.transferController!.isWriteBlocked(), isFalse);

      // Export now succeeds
      final exportAllowed = await hostState.transferController!.exportTo(
        transfer,
      );
      expect(exportAllowed, isA<CapabilitySuccess<void>>());
    },
  );

  testWidgets(
    'confirmed replacement import disposes old controllers, preserves committed snapshot, and rekeys app by generation',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = createTestState(
        lineage: 'lineage-old',
        restaurantName: 'مطعم الجيل القديم',
      );
      final store = FixtureStore();
      final seed = await store.writeDocument(
        codec.encodeState(state),
        writeToken: 'seed-old',
      );
      final snapshot = (seed as CapabilitySuccess<DocumentSnapshot>).value;
      final transfer = MockTransfer();

      await tester.pumpWidget(
        PortableRestaurantHost(
          store: store,
          initialSnapshot: snapshot,
          compareText: (a, b) => a.compareTo(b),
          freshTicket: () => TicketDraft(
            id: 'fresh-import',
            date: '2026-11-08',
            orderType: 'سفري',
            discount: '',
            note: '',
            lines: const [],
          ),
          preferencesStore: MemoryPreferencesStore(),
          transfer: transfer,
        ),
      );
      await tester.pumpAndSettle();

      final hostState = tester.state<PortableRestaurantHostState>(
        find.byType(PortableRestaurantHost),
      );

      final oldSession = hostState.session!;
      final oldTransfer = hostState.transferController!;
      final oldGen = hostState.generation;

      // Prepare replacement import
      final candidateState = createTestState(
        lineage: 'lineage-replacement',
        restaurantName: 'مطعم الجيل الجديد المستورد',
      );
      final prep = oldTransfer.prepareImport(codec.encodeBytes(candidateState));
      expect(prep, isA<CapabilitySuccess<PendingPortableAccountImport>>());

      // Confirm import
      final confirmed = await oldTransfer.confirmImport();
      expect(confirmed, isA<CapabilitySuccess<void>>());

      // Trigger import applied on host
      await hostState.handleImportApplied(oldTransfer.snapshot);
      await tester.pumpAndSettle();

      // Generation advanced, old controllers replaced
      expect(hostState.generation, greaterThan(oldGen));
      expect(hostState.session, isNot(same(oldSession)));
      expect(hostState.transferController, isNot(same(oldTransfer)));
      expect(hostState.committedSnapshot.fence, isNot(snapshot.fence));
      expect(
        hostState.session!.snapshot.payload,
        contains('مطعم الجيل الجديد المستورد'),
      );
    },
  );

  testWidgets(
    'reopen failure preserves committed snapshot and shows recoverable protected failure (never re-imports)',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = createTestState(
        lineage: 'lineage-fail-test',
        restaurantName: 'مطعم اختبار التعافي',
      );
      final store = FixtureStore();
      final seed = await store.writeDocument(
        codec.encodeState(state),
        writeToken: 'seed-fail',
      );
      final snapshot = (seed as CapabilitySuccess<DocumentSnapshot>).value;
      final transfer = MockTransfer();

      await tester.pumpWidget(
        PortableRestaurantHost(
          store: store,
          initialSnapshot: snapshot,
          compareText: (a, b) => a.compareTo(b),
          freshTicket: () => TicketDraft(
            id: 'fresh-fail',
            date: '2026-11-08',
            orderType: 'سفري',
            discount: '',
            note: '',
            lines: const [],
          ),
          preferencesStore: MemoryPreferencesStore(),
          transfer: transfer,
        ),
      );
      await tester.pumpAndSettle();

      final hostState = tester.state<PortableRestaurantHostState>(
        find.byType(PortableRestaurantHost),
      );

      // Perform a valid replacement commit in store
      final replacementState = createTestState(
        lineage: 'lineage-fail-test',
        restaurantName: 'مطعم الحساب المحفوظ المحمي',
      );
      final replacementSeed = await store.writeDocument(
        codec.encodeState(replacementState),
        writeToken: 'replacement-token',
        expected: snapshot,
        replaceGeneration: true,
      );
      final committedReplacement =
          (replacementSeed as CapabilitySuccess<DocumentSnapshot>).value;

      // Simulate a transient failure during reopen
      store.readFailure = 'transient_read_failure';

      // Apply imported replacement to host
      await hostState.handleImportApplied(committedReplacement);
      await tester.pumpAndSettle();

      // Preserves committed snapshot
      expect(hostState.committedSnapshot, committedReplacement);
      expect(hostState.reopenError, isNotNull);

      // Renders recoverable protected failure panel
      expect(
        find.byKey(const Key('portable-reopen-failure-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('portable-reopen-failure-status')),
        findsOneWidget,
      );
      final retryBtn = find.byKey(const Key('portable-reopen-retry-button'));
      expect(retryBtn, findsOneWidget);

      // Recover store and retry reopen
      store.readFailure = null;
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      // Host recovers cleanly
      expect(
        find.byKey(const Key('portable-reopen-failure-panel')),
        findsNothing,
      );
      expect(find.byType(DakhlRestaurantApp), findsOneWidget);
      expect(hostState.session, isNotNull);
      expect(
        hostState.session!.snapshot.payload,
        contains('مطعم الحساب المحفوظ المحمي'),
      );
      expect(hostState.reopenError, isNull);
    },
  );

  testWidgets('borrowed store lifecycle is preserved across host disposal', (
    tester,
  ) async {
    final state = createTestState(
      lineage: 'lineage-store-lifecycle',
      restaurantName: 'مطعم دورة حياة وحدة التخزين',
    );
    final store = FixtureStore();
    final seed = await store.writeDocument(
      codec.encodeState(state),
      writeToken: 'seed-lifecycle',
    );
    final snapshot = (seed as CapabilitySuccess<DocumentSnapshot>).value;

    await tester.pumpWidget(
      PortableRestaurantHost(
        store: store,
        initialSnapshot: snapshot,
        compareText: (a, b) => a.compareTo(b),
        freshTicket: () => TicketDraft(
          id: 'fresh-lifecycle',
          date: '2026-11-08',
          orderType: 'سفري',
          discount: '',
          note: '',
          lines: const [],
        ),
        preferencesStore: MemoryPreferencesStore(),
      ),
    );
    await tester.pumpAndSettle();

    // Unmount host
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    // Verify borrowed store document remains readable and unmodified
    final read = await store.readDocument();
    expect(read, isA<CapabilitySuccess<DocumentSnapshot?>>());
    expect((read as CapabilitySuccess<DocumentSnapshot?>).value, snapshot);
  });
}
