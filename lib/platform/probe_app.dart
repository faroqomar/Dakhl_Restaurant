import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../capabilities/capability_probe_view_model.dart';

/// Development-only Arabic copy. This probe has no product routes.
abstract final class ProbeCopy {
  static const title = 'اختبار تقني — بيانات تجريبية فقط';
  static const note =
      'بيئة تطوير معزولة. تستخدم هذه الأدوات ملفاً تجريبياً فقط. نجاح المشاركة أو الطباعة يعني تسليم الطلب للنظام ولا يثبت وصوله أو طباعته.';
  static const open = 'فتح ملف تجريبي';
  static const export = 'تصدير الملف التجريبي';
  static const write = 'حفظ وإعادة قراءة التجربة';
  static const reopen = 'قراءة المحفوظ بعد إعادة التشغيل';
  static const pdf = 'إنشاء PDF عربي دون إنترنت';
  static const share = 'فتح نافذة المشاركة';
  static const print = 'فتح نافذة الطباعة';
  static String status(ProbeState state) => switch (state) {
    ProbeState.idle => 'جاهز للاختبار',
    ProbeState.running => 'جارٍ الاختبار…',
    ProbeState.success => 'اكتمل الاختبار',
    ProbeState.cancelled => 'أُلغي الاختيار',
    ProbeState.failure => 'تعذّر الاختبار. يمكن إعادة المحاولة.',
  };
}

final class ProbeApp extends StatelessWidget {
  const ProbeApp({super.key, required this.viewModel, this.textScaler});
  final CapabilityProbeViewModel viewModel;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dakhl_Restaurant Phase00 Dev Probe',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      fontFamily: 'Amiri',
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff245b45)),
      scaffoldBackgroundColor: const Color(0xfffaf8f1),
      useMaterial3: true,
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: _ProbeView(viewModel: viewModel),
  );
}

final class _ProbeView extends StatelessWidget {
  const _ProbeView({required this.viewModel});
  final CapabilityProbeViewModel viewModel;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final busy = viewModel.state == ProbeState.running;
          Widget action(
            String key,
            String label,
            Future<void> Function() run, {
            bool enabled = true,
          }) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton(
              key: ValueKey(key),
              onPressed: busy || !enabled ? null : run,
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 56),
                padding: const EdgeInsets.all(16),
              ),
              child: Text(label, textAlign: TextAlign.center),
            ),
          );
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FocusTraversalGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      ProbeCopy.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text(ProbeCopy.note),
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        ProbeCopy.status(viewModel.state),
                        key: const ValueKey('probe-status'),
                      ),
                    ),
                    if (viewModel.failure != null)
                      Text(
                        viewModel.failure!.code,
                        textDirection: TextDirection.ltr,
                      ),
                    const SizedBox(height: 24),
                    action(
                      'open-synthetic',
                      ProbeCopy.open,
                      viewModel.importSynthetic,
                    ),
                    action(
                      'export-synthetic',
                      ProbeCopy.export,
                      viewModel.exportSynthetic,
                    ),
                    action(
                      'write-reopen',
                      ProbeCopy.write,
                      viewModel.writeAndReopen,
                    ),
                    action('reopen', ProbeCopy.reopen, viewModel.reopen),
                    action(
                      'generate-pdf',
                      ProbeCopy.pdf,
                      viewModel.generatePdf,
                    ),
                    action(
                      'share-pdf',
                      ProbeCopy.share,
                      viewModel.sharePdf,
                      enabled: viewModel.pdfBytes != null,
                    ),
                    action(
                      'print-pdf',
                      ProbeCopy.print,
                      viewModel.printPdf,
                      enabled: viewModel.pdfBytes != null,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
