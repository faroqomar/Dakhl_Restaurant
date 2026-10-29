import 'dart:convert';
import 'dart:io';

import 'package:dakhl_restaurant/app/app.dart';
import 'package:dakhl_restaurant/app/bootstrap.dart';
import 'package:dakhl_restaurant/shell/shell_preferences.dart';
import 'package:dakhl_restaurant/shell/shell_routes.dart';
import 'package:dakhl_restaurant/ui/dakhl_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:madar_application/madar_application.dart';

/// Retained native acceptance: real target metrics/IME, synthetic form text,
/// reviewed Madar preferences adapter, no domain records or Save submission.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    'native Android keyboard and cancel retain the synthetic invoice',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      final store = AppPreferencesStore.native();
      addTearDown(store.close);
      final before = await store.read(ShellPreferences.namespace);
      expect(before, isA<CapabilitySuccess<PreferenceSnapshot?>>());
      final initial = (before as CapabilitySuccess<PreferenceSnapshot?>).value;
      final original = initial == null
          ? ShellPreferences.defaults()
          : ShellPreferences.decode(initial.payload);
      await tester.pumpWidget(DakhlRestaurantApp(preferencesStore: store));

      Future<void> until(bool Function() condition, String reason) async {
        final deadline = DateTime.now().add(const Duration(seconds: 12));
        while (!condition() && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(condition(), isTrue, reason: reason);
      }

      await until(
        () =>
            find.byType(DakhlShellView).evaluate().isNotEmpty &&
            !tester.widget<DakhlShellView>(find.byType(DakhlShellView)).busy,
        'Native preferences bootstrap must complete before UI interaction.',
      );
      await tester.pumpAndSettle();
      final view = tester.view;
      final ratio = view.devicePixelRatio;
      final logical = view.physicalSize / ratio;
      final initialInset = view.viewInsets.bottom / ratio;
      expect(logical.width, lessThanOrEqualTo(760));
      expect(initialInset, 0);
      expect(
        Directionality.of(tester.element(find.byType(Phase01RouteSurface))),
        TextDirection.rtl,
      );

      Future<void> navigate(String id) async {
        await tester.tap(find.byTooltip('القائمة الرئيسية'));
        await tester.pumpAndSettle();
        final item = find
            .widgetWithText(
              DakhlButton,
              ShellRoutes.destination(id).navigationLabel,
            )
            .last;
        await tester.ensureVisible(item);
        await tester.tap(item);
        await until(
          () =>
              tester
                      .widget<Phase01RouteSurface>(
                        find.byType(Phase01RouteSurface),
                      )
                      .routeId ==
                  id &&
              !tester.widget<DakhlShellView>(find.byType(DakhlShellView)).busy,
          'Requested presentation route must become visible and acknowledge save.',
        );
        await tester.pumpAndSettle();
      }

      await navigate('invoices');
      await tester.tap(find.widgetWithText(DakhlButton, 'قائمة جديدة'));
      await tester.pumpAndSettle();
      final form = find.byType(DakhlInvoiceForm);
      final material = find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is DakhlField && widget.label == 'المادة',
        ),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(material);
      await tester.tap(material);
      await until(
        () => view.viewInsets.bottom > 0,
        'The real Android soft keyboard must supply a positive runtime inset.',
      );
      const sample = 'مادة توضيحية للاختبار';
      // Fixture text is injected through Flutter's adopted integration-test input;
      // the IME itself and its window insets remain the actual Android runtime.
      await tester.enterText(material, sample);
      await tester.pumpAndSettle();
      final keyboardInset = view.viewInsets.bottom / ratio;
      expect(keyboardInset, greaterThan(0));
      final keyboardTop = logical.height - keyboardInset;
      final save = find.widgetWithText(DakhlButton, 'حفظ القائمة والتسديد');
      final cancel = find.widgetWithText(DakhlButton, 'إلغاء');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(keyboardTop));
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      expect(cancel.hitTestable(), findsOneWidget);
      expect(tester.getBottomRight(cancel).dy, lessThanOrEqualTo(keyboardTop));
      expect(
        tester
            .widget<Phase01RouteSurface>(find.byType(Phase01RouteSurface))
            .formDraft['material'],
        sample,
      );
      // Host captures a genuine OS screenshot during this bounded stable state.
      // ignore: avoid_print
      print('PHASE01_ANDROID_STAGE_keyboard');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );

      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.text('تغييرات غير محفوظة'), findsOneWidget);
      final keep = find.widgetWithText(DakhlButton, 'متابعة التعديل');
      await tester.ensureVisible(keep);
      await tester.tap(keep);
      await tester.pumpAndSettle();
      expect(form, findsOneWidget);
      await tester.ensureVisible(material);
      final editable = tester.widget<EditableText>(
        find.descendant(of: material, matching: find.byType(EditableText)),
      );
      expect(editable.controller.text, sample);
      expect(
        tester
            .widget<Phase01RouteSurface>(find.byType(Phase01RouteSurface))
            .formDraft['material'],
        sample,
      );
      // ignore: avoid_print
      print('PHASE01_ANDROID_STAGE_retained');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );

      // Explicitly discard only this synthetic session draft; never submit Save.
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      final discard = find.widgetWithText(DakhlButton, 'تجاهل التغييرات');
      await tester.ensureVisible(discard);
      await tester.tap(discard);
      await tester.pumpAndSettle();
      expect(find.byType(DakhlInvoiceForm), findsNothing);
      expect(
        tester
            .widget<Phase01RouteSurface>(find.byType(Phase01RouteSurface))
            .formDraft,
        isEmpty,
      );
      await navigate(original.routeId);
      final after = await store.read(ShellPreferences.namespace);
      expect(after, isA<CapabilitySuccess<PreferenceSnapshot?>>());
      final restored = (after as CapabilitySuccess<PreferenceSnapshot?>).value;
      expect(restored, isNotNull);
      expect(ShellPreferences.decode(restored!.payload), original);
      final evidence = <String, Object>{
        'pid': pid,
        'logicalWidth': logical.width,
        'logicalHeight': logical.height,
        'devicePixelRatio': ratio,
        'initialKeyboardInset': initialInset,
        'actualKeyboardInset': keyboardInset,
        'runtimeTextScale':
            MediaQuery.textScalerOf(
              tester.element(find.byType(Phase01RouteSurface)),
            ).scale(16) /
            16,
        'narrowLayout': logical.width <= 760,
        'saveAndCancelAboveKeyboard': true,
        'cancelRetainedSyntheticText': true,
        'syntheticDraftDiscarded': true,
        'originalPreferencesRestored': true,
        'initialSnapshotPresent': initial != null,
        'domainSaveSubmitted': false,
      };
      binding.reportData = evidence;
      // ignore: avoid_print
      print('PHASE01_ANDROID_RESULT=${jsonEncode(evidence)}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
