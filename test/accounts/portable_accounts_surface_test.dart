import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_account_transfer_controller.dart';
import 'package:dakhl_restaurant/accounts/portable_accounts_surface.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/ui/theme.dart';

import 'accounts_view_model_test.dart' show FixtureStore;

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

Widget testHarness({
  required Widget child,
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  theme: DakhlTheme.light,
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: Scaffold(body: child),
    ),
  ),
);

void main() {
  const codec = PortableJournalCodec();
  late FixtureStore store;
  late PortableAccountTransferController controller;
  late MockTransfer transfer;
  var writeBlocked = false;

  PortableJournalState createSampleState({
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

  setUp(() async {
    writeBlocked = false;
    transfer = MockTransfer();
    final state = createSampleState(
      lineage: 'lineage-current',
      restaurantName: 'مطعم الأصالة الحالي',
      journalId: 'j-current',
    );
    store = FixtureStore();
    final seed = await store.writeDocument(
      codec.encodeState(state),
      writeToken: 'seed-token',
    );
    final snapshot = (seed as CapabilitySuccess<DocumentSnapshot>).value;
    controller = PortableAccountTransferController(
      store: store,
      snapshot: snapshot,
      isWriteBlocked: () => writeBlocked,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  testWidgets(
    'previous-copy action prepares complete recovery summary without writing',
    (tester) async {
      store.previous = PreviousDocument(
        snapshot: controller.snapshot,
        identity: 'retained-copy',
      );
      await tester.pumpWidget(
        testHarness(child: PortableAccountsSurface(controller: controller)),
      );
      final writes = store.writes;
      await tester.tap(find.byKey(const Key('portable-previous-button')));
      await tester.pumpAndSettle();
      expect(controller.pendingImport!.isRecovery, isTrue);
      expect(find.text('ملخص النسخة السابقة'), findsOneWidget);
      expect(find.text('فواتير الشراء'), findsOneWidget);
      expect(store.writes, writes);
      final cancel = find.byKey(const Key('portable-cancel-button'));
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(controller.hasPendingImport, isFalse);
      expect(store.writes, writes);
    },
  );

  testWidgets(
    'renders approved C7 phone-settings-data header, status, export, and import cards',
    (tester) async {
      await tester.pumpWidget(
        testHarness(
          child: PortableAccountsSurface(
            controller: controller,
            transfer: transfer,
          ),
        ),
      );

      // C7 phone-settings-data texts
      expect(find.text('نسخة إضافية، وراحة بال'), findsOneWidget);
      expect(
        find.text(
          'الحسابات تنحفظ تلقائياً على جهازك. احتفظ بنسخة إضافية بمكان مستقل.',
        ),
        findsOneWidget,
      );
      expect(find.text('حالة النسخ الاحتياطية'), findsOneWidget);
      expect(find.text('محفوظ على جهازك'), findsOneWidget);
      expect(find.text('مطعم الأصالة الحالي'), findsOneWidget);
      expect(find.text('lineage-current'), findsNothing);
      expect(find.text('جيل التخزين'), findsNothing);

      // Cards
      expect(find.text('تصدير نسخة احتياطية'), findsOneWidget);
      expect(find.byKey(const Key('portable-export-button')), findsOneWidget);

      expect(find.text('استيراد نسخة محفوظة'), findsOneWidget);
      expect(find.byKey(const Key('portable-import-button')), findsOneWidget);
      expect(find.byKey(const Key('portable-candidate-summary')), findsNothing);
    },
  );

  testWidgets(
    'export saves exact canonical bytes and displays success status',
    (tester) async {
      await tester.pumpWidget(
        testHarness(
          child: PortableAccountsSurface(
            controller: controller,
            transfer: transfer,
          ),
        ),
      );

      final exportBtn = find.byKey(const Key('portable-export-button'));
      await tester.ensureVisible(exportBtn);
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      expect(transfer.saveCount, 1);
      expect(transfer.savedBytes, isNotNull);
      expect(transfer.savedBytes, controller.exportBytes());
      expect(find.text('تم تصدير النسخة الاحتياطية بنجاح.'), findsOneWidget);
    },
  );

  testWidgets(
    'failed export retains error and provides exact export retry button',
    (tester) async {
      transfer.failSave = true;

      await tester.pumpWidget(
        testHarness(
          child: PortableAccountsSurface(
            controller: controller,
            transfer: transfer,
          ),
        ),
      );

      final exportBtn = find.byKey(const Key('portable-export-button'));
      await tester.ensureVisible(exportBtn);
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      expect(transfer.saveCount, 1);
      expect(find.textContaining('تعذّر تصدير الحسابات'), findsOneWidget);

      final retryBtn = find.byKey(const Key('portable-export-retry-button'));
      expect(retryBtn, findsOneWidget);

      // Retry succeeds when transfer capability recovers
      transfer.failSave = false;
      await tester.ensureVisible(retryBtn);
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(transfer.saveCount, 2);
      expect(transfer.savedBytes, controller.exportBytes());
      expect(find.text('تم تصدير النسخة الاحتياطية بنجاح.'), findsOneWidget);
      expect(
        find.byKey(const Key('portable-export-retry-button')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'pickImport prepares actual candidate summary and cancel discards it',
    (tester) async {
      final candidateState = createSampleState(
        lineage: 'lineage-candidate',
        restaurantName: 'مطعم النخيل المرشح',
        journalId: 'j-candidate',
      );
      final candidateBytes = codec.encodeBytes(candidateState);
      transfer.openResult = CapabilitySuccess(candidateBytes);

      await tester.pumpWidget(
        testHarness(
          child: PortableAccountsSurface(
            controller: controller,
            transfer: transfer,
          ),
        ),
      );

      final importBtn = find.byKey(const Key('portable-import-button'));
      await tester.ensureVisible(importBtn);
      await tester.tap(importBtn);
      await tester.pumpAndSettle();

      // Candidate summary panel appears
      expect(
        find.byKey(const Key('portable-candidate-summary')),
        findsOneWidget,
      );
      expect(find.text('ملخص النسخة المراد استيرادها'), findsOneWidget);
      expect(find.text('مطعم النخيل المرشح'), findsOneWidget);
      expect(find.text('lineage-candidate'), findsNothing);
      expect(find.text('فواتير الشراء'), findsOneWidget);
      expect(find.text('سجلات السلف السابقة'), findsOneWidget);
      expect(find.text('إصدار النسخة'), findsOneWidget);

      // Current state not modified
      expect(controller.accountLineage, 'lineage-current');

      // Cancel import
      final cancelBtn = find.byKey(const Key('portable-cancel-button'));
      await tester.ensureVisible(cancelBtn);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('portable-candidate-summary')), findsNothing);
      expect(controller.hasPendingImport, false);
      expect(store.writes, 1); // Only the initial setup write
    },
  );

  testWidgets(
    'confirmImport triggers guarded dialog, performs replacement with source preservation, and invokes onImportApplied',
    (tester) async {
      final candidateState = createSampleState(
        lineage: 'lineage-applied',
        restaurantName: 'مطعم الهدى البديل',
        journalId: 'j-applied',
      );
      final candidateBytes = codec.encodeBytes(candidateState);
      transfer.openResult = CapabilitySuccess(candidateBytes);

      DocumentSnapshot? appliedSnapshot;

      await tester.pumpWidget(
        testHarness(
          child: PortableAccountsSurface(
            controller: controller,
            transfer: transfer,
            onImportApplied: (snap) => appliedSnapshot = snap,
          ),
        ),
      );

      // 1. Pick file
      final importBtn = find.byKey(const Key('portable-import-button'));
      await tester.ensureVisible(importBtn);
      await tester.tap(importBtn);
      await tester.pumpAndSettle();

      // 2. Tap confirm button to open dialog
      final confirmBtn = find.byKey(const Key('portable-confirm-button'));
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Dialog is shown
      expect(find.text('استبدال الحسابات الحالية؟'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.textContaining('مطعم الهدى البديل'),
        ),
        findsOneWidget,
      );

      // Confirm in dialog (the primary button inside dialog)
      final dialogConfirm = find.descendant(
        of: find.byType(Dialog),
        matching: find.text('استبدال الحسابات'),
      );
      await tester.tap(dialogConfirm);
      await tester.pumpAndSettle();

      // Verified outcomes:
      // 1. Source preserved in archives
      expect(store.archives, 1);
      // 2. Controller state replaced
      expect(controller.accountLineage, 'lineage-applied');
      expect(
        controller.account.preferences.restaurant['name'],
        'مطعم الهدى البديل',
      );
      // 3. onImportApplied callback invoked
      expect(appliedSnapshot, isNotNull);
      expect(appliedSnapshot!.revision, controller.snapshot.revision);
      // 4. Success status banner shown
      expect(
        find.text('تم استبدال الحسابات بنجاح وحفظ النسخة السابقة.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('portable-candidate-summary')), findsNothing);
    },
  );

  testWidgets(
    'commit_unknown triggers reconciliation status banner and button',
    (tester) async {
      final candidateState = createSampleState(
        lineage: 'lineage-unknown',
        restaurantName: 'مطعم مجهول الحسم',
      );
      controller.prepareImport(codec.encodeBytes(candidateState));

      store.throwAfterCommit = true;

      await tester.pumpWidget(
        testHarness(
          child: PortableAccountsSurface(
            controller: controller,
            transfer: transfer,
          ),
        ),
      );

      // Tap confirm button
      final confirmBtn = find.byKey(const Key('portable-confirm-button'));
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Confirm in dialog
      final dialogConfirm = find.descendant(
        of: find.byType(Dialog),
        matching: find.text('استبدال الحسابات'),
      );
      await tester.tap(dialogConfirm);
      await tester.pumpAndSettle();

      expect(controller.needsReadback, true);
      expect(find.byKey(const Key('portable-status-unknown')), findsOneWidget);
      expect(
        find.text('تعذّر تأكيد الحفظ؛ أعد التحقق للتأكد من حالة النسخة.'),
        findsOneWidget,
      );

      // Tap retry on status banner to reconcile
      final retryBtn = find.descendant(
        of: find.byKey(const Key('portable-status-unknown')),
        matching: find.text('إعادة المحاولة'),
      );
      await tester.ensureVisible(retryBtn);
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(controller.needsReadback, false);
      expect(controller.accountLineage, 'lineage-unknown');
      expect(
        find.text('تم التحقق من الحفظ بنجاح واعتماد النسخة المستوردة.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'renders cleanly on narrow 320px width with 200% text scale (Pattern E/F)',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        testHarness(
          textScaler: const TextScaler.linear(2),
          child: PortableAccountsSurface(
            controller: controller,
            transfer: transfer,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('نسخة إضافية، وراحة بال'), findsOneWidget);

      final exportBtn = find.byKey(const Key('portable-export-button'));
      await tester.ensureVisible(exportBtn);
      expect(exportBtn, findsOneWidget);

      final importBtn = find.byKey(const Key('portable-import-button'));
      await tester.ensureVisible(importBtn);
      expect(importBtn, findsOneWidget);
    },
  );
}
