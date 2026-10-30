import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dakhl_restaurant/ui/dialogs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/accounts_view_model.dart';
import 'package:dakhl_restaurant/accounts/accounts_surface.dart';
import 'package:dakhl_restaurant/ui/theme.dart';

import 'accounts_view_model_test.dart' show FixtureStore, FixtureTransfer;

void main() {
  testWidgets(
    'protected failure is persistent and reachable at320px200percent',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = FixtureStore()..readFailure = 'corrupt_primary';
      final model = AccountsViewModel(
        repository: AccountsRepository(store: store),
      );
      await model.initialize();
      await tester.pumpWidget(
        MaterialApp(
          theme: DakhlTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: AccountsSurface(model: model)),
            ),
          ),
        ),
      );
      expect(find.text('تعذّر فتح الحسابات'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('استعادة النسخة السابقة'));
      await tester.tap(find.text('استعادة النسخة السابقة'));
      await tester.pump();
      expect(store.writes, 0);
    },
  );
  testWidgets('replacement dialog Escape cancels without a write', (
    tester,
  ) async {
    final store = FixtureStore();
    final model = AccountsViewModel(
      repository: AccountsRepository(store: store),
    );
    await model.initialize();
    model.prepareImport(
      model.repository.codec.encode(model.repository.codec.empty()),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: DakhlTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: AccountsSurface(model: model)),
        ),
      ),
    );
    await tester.tap(find.text('استبدال الحسابات'));
    await tester.pumpAndSettle();
    expect(find.text('استبدال الحسابات الحالية؟'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(model.pendingImport, isNull);
    expect(store.writes, 0);
  });
  testWidgets(
    'narrow replacement with large text and keyboard keeps safe action reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final store = FixtureStore();
      final model = AccountsViewModel(
        repository: AccountsRepository(store: store),
      );
      await model.initialize();
      model.prepareImport(
        model.repository.codec.encode(model.repository.codec.empty()),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: DakhlTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(body: AccountsSurface(model: model)),
        ),
      );
      final confirm = find.text('استبدال الحسابات');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final cancel = find.descendant(
        of: find.byType(DakhlDialog),
        matching: find.text('إلغاء'),
      );
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(model.pendingImport, isNull);
      expect(store.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
  for (final cancel in [false, true]) {
    testWidgets(
      'latest picker attempt never confirms retained A; cancel=$cancel',
      (tester) async {
        final store = FixtureStore()
          ..writeFailure = 'backup_publication_failed';
        final model = AccountsViewModel(
          repository: AccountsRepository(store: store),
        );
        await model.initialize();
        model.prepareImport(
          model.repository.codec.encode(model.repository.codec.empty()),
        );
        await model.confirmImport();
        final selected = model.pendingImport;
        final transfer = FixtureTransfer(
          cancel
              ? const CapabilityCancelled()
              : CapabilitySuccess(Uint8List.fromList(utf8.encode('{bad'))),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: DakhlTheme.light,
            home: Scaffold(
              body: AccountsSurface(model: model, transfer: transfer),
            ),
          ),
        );
        await tester.tap(find.text('استيراد الحسابات'));
        await tester.pumpAndSettle();
        expect(find.text('استبدال الحسابات الحالية؟'), findsNothing);
        expect(model.pendingImport, same(selected));
        if (cancel) {
          expect(find.byType(DakhlDialog), findsNothing);
        } else {
          expect(
            find.descendant(
              of: find.byType(DakhlDialog),
              matching: find.text('الملف غير صالح للاستيراد'),
            ),
            findsOneWidget,
          );
        }
      },
    );
  }
  testWidgets(
    'conflict retry reloads before retained import can be confirmed',
    (tester) async {
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
        writeToken: 'other',
      );
      model.prepareImport(
        model.repository.codec.encode(model.repository.codec.empty()),
      );
      await model.confirmImport();
      await tester.pumpWidget(
        MaterialApp(
          theme: DakhlTheme.light,
          home: Scaffold(body: AccountsSurface(model: model)),
        ),
      );
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(model.state, AccountsState.importReady);
      expect(find.byType(DakhlDialog), findsNothing);
      expect(model.pendingImport, isNotNull);
    },
  );
}
