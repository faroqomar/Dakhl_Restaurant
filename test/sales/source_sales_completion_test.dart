import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_sale_commands.dart';
import 'package:dakhl_restaurant/catalog/catalog_formatters.dart';
import 'package:dakhl_restaurant/sales/return_proposal.dart';
import 'package:dakhl_restaurant/sales/sales_history_surface.dart';
import 'package:dakhl_restaurant/sales/sales_history_view_model.dart';
import 'package:dakhl_restaurant/sales/sales_operations_view_model.dart';
import 'package:dakhl_restaurant/sales/sales_surface.dart';
import 'package:dakhl_restaurant/sales/sales_view_model.dart';
import 'package:dakhl_restaurant/sales/ticket_workspace.dart';
import 'package:dakhl_restaurant/ui/components.dart';
import 'package:dakhl_restaurant/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;
import '../accounting/restaurant_journal_sale_conformance_test.dart'
    show UnknownAckStore;
import 'sales_workflow_session_test.dart' show fixture;
import 'sales_view_model_test.dart' show repository, fresh;

class RefundAckStore extends UnknownAckStore {
  RefundAckStore(super.inner);
  bool loseNext = false, blocked = false;
  @override
  Future<CapabilityResult<DocumentSnapshot>> writeDocument(
    String payload, {
    required String writeToken,
    DocumentSnapshot? expected,
    bool replaceGeneration = false,
  }) async {
    final result = await super.writeDocument(
      payload,
      writeToken: writeToken,
      expected: expected,
      replaceGeneration: replaceGeneration,
    );
    if (loseNext && result is CapabilitySuccess<DocumentSnapshot>) {
      loseNext = false;
      blocked = true;
      return const CapabilityFailure('commit_unknown', 'Lost acknowledgement.');
    }
    return result;
  }

  @override
  Future<CapabilityResult<DocumentSnapshot?>> readDocument() => blocked
      ? Future.value(
          const CapabilityFailure('commit_unknown', 'Resolve before read.'),
        )
      : super.readDocument();
  @override
  Future<CapabilityResult<void>> resolvePendingWrite() => blocked
      ? Future.value(
          const CapabilityFailure('commit_unknown', 'Resolution unavailable.'),
        )
      : super.resolvePendingWrite();
}

Future<
  (
    FixtureStore,
    RefundAckStore,
    SalesOperationsViewModel,
    SalesHistoryViewModel,
  )
>
sale() async {
  final (store, snapshot) = await fixture();
  const codec = PortableJournalCodec();
  final state = codec.decodeState(snapshot.payload);
  final account = const LegacyAccountCodec().decodeJson({
    ...state.account.toJson(),
    'products': [
      for (final p
          in (state.account.toJson()['products'] as List)
              .cast<Map<String, Object?>>())
        {...p, 'trackStock': true},
    ],
    'stockEntries': [
      {
        'id': 'stock',
        'productId': 'p',
        'kind': 'opening',
        'date': '2026-11-01',
        'quantity': 10,
        'note': '',
        'createdAt': '2026-11-01T00:00:00Z',
      },
    ],
  });
  final seeded = await store.writeDocument(
    codec.encodeState(state.copyWith(account: account)),
    writeToken: 'tracked-seed',
    expected: snapshot,
  );
  final wrapped = RefundAckStore(store);
  final operations = SalesOperationsViewModel(
    commands: RestaurantJournalSaleCommandCoordinator(store: wrapped),
    snapshot: (seeded as CapabilitySuccess<DocumentSnapshot>).value,
  );
  final intent = operations.checkoutIntent(
    ticket: TicketDraft(
      id: 'sale',
      date: '2026-11-07',
      orderType: 'سفري',
      discount: '1',
      note: '',
      lines: [
        TicketLine(
          productId: 'p',
          quantityUnits: BigInt.from(3000),
          price: 1000,
        ),
      ],
    ),
    operationId: 'sale-op',
    journalId: 'sale-journal',
    recordedAt: '2026-11-07T12:00:00Z',
  );
  expect(
    await operations.submit(intent),
    isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
  );
  final history = SalesHistoryViewModel(operations: operations)..select('sale');
  return (store, wrapped, operations, history);
}

Finder field(String label) => find.descendant(
  of: find.widgetWithText(DakhlField, label),
  matching: find.byType(TextFormField),
);
Widget frame(Widget body) => MaterialApp(
  theme: DakhlTheme.light,
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: body),
  ),
);
Future<void> returnForm(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(DakhlButton, 'إرجاع أصناف'));
  await tester.tap(find.widgetWithText(DakhlButton, 'إرجاع أصناف'));
  await tester.pumpAndSettle();
}

void main() {
  test('uncertain fractional refund retries captured intent without repeating cash or journal', () async {
    final (store, wrapped, operations, history) = await sale();
    addTearDown(history.dispose);
    addTearDown(operations.dispose);
    final today = CatalogFormatters.today().toString();
    final request = [
      ReturnLineRequest(
        productId: 'p',
        quantityUnits: BigInt.from(1000),
        restock: true,
      ),
    ];
    expect(history.quoteReturn(request).amount, BigInt.from(999));
    final before = store.writes;
    expect(
      await history.returnSale(
        date: today,
        today: today,
        reason: 'Original return',
        lines: request,
        cashConfirmed: false,
      ),
      isA<CapabilityFailure<void>>(),
    );
    expect(store.writes, before);
    wrapped.loseNext = true;
    expect(
      await history.returnSale(
        date: today,
        today: today,
        reason: 'Original return',
        lines: request,
        cashConfirmed: true,
      ),
      isA<CapabilityFailure<void>>(),
    );
    expect(history.pendingReturn, true);
    final afterUnknown = store.writes;
    wrapped.blocked = false;
    expect(
      await history.returnSale(
        date: '2099-01-01',
        today: today,
        reason: 'Changed ignored',
        lines: [
          ReturnLineRequest(
            productId: 'p',
            quantityUnits: BigInt.from(2000),
            restock: false,
          ),
        ],
        cashConfirmed: false,
      ),
      isA<CapabilitySuccess<void>>(),
    );
    expect(store.writes, afterUnknown);
    expect(history.selectedReturns.single['amount'], 999);
    expect(history.selectedReturns.single['reason'], 'Original return');
    expect(
      ((history.selectedReturns.single['lines'] as List).single
          as Map)['restock'],
      true,
    );
    expect(history.stateLabel(history.selected!), 'مرتجع جزئي');
    expect(
      history.quoteReturn([
        ReturnLineRequest(
          productId: 'p',
          quantityUnits: BigInt.from(2000),
          restock: false,
        ),
      ]).amount,
      BigInt.from(2000),
    );
  });
  testWidgets(
    'positive partial and remaining full refund require cash confirmation and preserve original sale',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (_, _, operations, history) = await sale();
      addTearDown(history.dispose);
      addTearDown(operations.dispose);
      final original = operations.account.toJson()['sales'];
      await tester.pumpWidget(
        frame(
          SalesHistorySurface(
            document: operations.account,
            operations: operations,
            initialSaleId: 'sale',
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final (quantity, amount, reason) in [
        ('1', '999', 'First return'),
        ('2', '2,000', 'Remaining return'),
      ]) {
        if (quantity == '2') {
          await tester.ensureVisible(
            find.widgetWithText(DakhlButton, 'عرض الوصل'),
          );
          await tester.tap(find.widgetWithText(DakhlButton, 'عرض الوصل'));
          await tester.pumpAndSettle();
        }
        await returnForm(tester);
        await tester.enterText(field('كمية Product'), quantity);
        await tester.enterText(field('سبب المرتجع'), reason);
        await tester.pump();
        expect(find.text('المبلغ المطلوب رده: $amount د.ع'), findsOneWidget);
        final submit = find.widgetWithText(
          DakhlButton,
          'تسجيل المرتجع ورد المبلغ',
        );
        expect(tester.widget<DakhlButton>(submit).onPressed, isNull);
        await tester.ensureVisible(
          find.byKey(const ValueKey('return-cash-confirmation')),
        );
        await tester.tap(
          find.byKey(const ValueKey('return-cash-confirmation')),
        );
        await tester.pump();
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
      }
      expect(operations.account.toJson()['sales'], original);
      expect(operations.account.toJson()['saleReturns'], hasLength(2));
      expect(history.history!.refunded, BigInt.from(2999));
      expect(history.stateLabel(history.selected!), 'مرتجعة بالكامل');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'held empty, typed name, lost acknowledgement and confirmed delete preserve drafts',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final store = FixtureStore();
      final repo = await repository(store);
      final model = SalesViewModel(repo);
      addTearDown(model.dispose);
      await model.load(fresh('draft'));
      await tester.pumpWidget(frame(SalesSurface(model: model)));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DakhlButton, 'الطلبات المعلقة · 0'));
      await tester.pumpAndSettle();
      expect(find.text('ماكو طلبات معلقة'), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is DakhlIconButton && w.label == 'إغلاق النافذة',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await model.addProduct('p0');
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(DakhlButton, 'تعليق الطلب'),
      );
      await tester.tap(find.widgetWithText(DakhlButton, 'تعليق الطلب'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.enterText(field('اسم الطلب (اختياري)'), 'Keep typed name');
      store.workspaceWriteFailure = 'commit_unknown';
      await tester.ensureVisible(
        find.widgetWithText(DakhlButton, 'تعليق وفتح طلب جديد'),
      );
      await tester.tap(find.widgetWithText(DakhlButton, 'تعليق وفتح طلب جديد'));
      await tester.pumpAndSettle();
      expect(model.needsReadback, true);
      expect(find.text('Keep typed name'), findsOneWidget);
      store.workspaceWriteFailure = null;
      await tester.tap(
        find.widgetWithText(DakhlButton, 'إعادة التحقق من التعليق'),
      );
      await tester.pumpAndSettle();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(model.held.single.label, 'Keep typed name');
      expect(model.active!.lines, isEmpty);
      await tester.ensureVisible(
        find.widgetWithText(DakhlButton, 'الطلبات المعلقة · 1'),
      );
      await tester.tap(find.widgetWithText(DakhlButton, 'الطلبات المعلقة · 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DakhlButton, 'حذف Keep typed name'));
      await tester.pumpAndSettle();
      expect(find.text('حذف الطلب المعلق؟'), findsOneWidget);
      await tester.tap(find.widgetWithText(DakhlButton, 'حذف الطلب'));
      await tester.pumpAndSettle();
      expect(model.held, isEmpty);
      expect(find.text('ماكو طلبات معلقة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
