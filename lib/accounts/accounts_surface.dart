import 'dart:async';

import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';

import '../ui/components.dart';
import '../ui/dialogs.dart';
import '../ui/theme.dart';
import 'accounts_view_model.dart';

String accountStatus(AccountsViewModel model) => switch (model.state) {
  AccountsState.loading => 'جارٍ تحميل الحسابات…',
  AccountsState.absent => 'لا توجد حسابات محفوظة بعد',
  AccountsState.saving => 'جارٍ الحفظ…',
  AccountsState.saved => 'محفوظ على جهازك',
  AccountsState.protected => 'تعذّر فتح الحسابات',
  AccountsState.commitUnknown => 'تعذّر تأكيد الحفظ؛ أعد التحقق.',
  AccountsState.conflict =>
    'تغيّرت الحسابات المحفوظة؛ أعد قراءتها قبل المتابعة.',
  AccountsState.importReady => 'النسخة المحددة جاهزة للاستبدال',
  AccountsState.recoveryReady => 'النسخة المحلية السابقة جاهزة للاستعادة',
  AccountsState.failed => switch (model.failureCode) {
    'unsupported_version' || 'unsupported_format' => 'إصدار الملف غير مدعوم',
    'invalid_payload' || 'invalid_workspace' => 'الملف غير صالح للاستيراد',
    'payload_too_large' || 'input_too_large' => 'حجم الملف أكبر من المسموح',
    'no_previous_copy' => 'لا توجد نسخة محلية سابقة',
    'file_unreadable' || 'file_unavailable' => 'تعذّر فتح الملف',
    _ => 'تعذّر الحفظ',
  },
};

/// Approved Phase02 persistence states within the existing restaurant shell.
class AccountsSurface extends StatelessWidget {
  const AccountsSurface({super.key, required this.model, this.transfer});
  final AccountsViewModel model;
  final FileTransferCapability? transfer;

  Future<void> _confirm(BuildContext context, {required bool recovery}) async {
    final selected = recovery
        ? model.recoverySelection != null
        : model.pendingImport != null;
    if (!selected) return;
    final accepted = await showDakhlDialog<bool>(
      context: context,
      title: recovery
          ? 'استعادة النسخة المحلية السابقة؟'
          : 'استبدال الحسابات الحالية؟',
      body: Text(
        recovery
            ? 'ستُستبدل الحسابات بالنسخة المحلية السابقة. تبقى ملفات الحسابات الحالية محفوظة.'
            : 'ستُستبدل الحسابات بالنسخة المحددة. تبقى ملفات الحسابات الحالية محفوظة.',
      ),
      actions: [
        DakhlButton(
          label: 'إلغاء',
          autofocus: true,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        DakhlButton(
          label: recovery ? 'استعادة النسخة السابقة' : 'استبدال الحسابات',
          kind: DakhlButtonKind.primary,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    if (accepted != true) {
      model.cancelImport();
      return;
    }
    if (recovery) {
      await model.confirmRecovery();
    } else {
      await model.confirmImport();
    }
  }

  Future<void> _choose(BuildContext context) async {
    final capability = transfer;
    if (capability == null) return;
    final outcome = await model.pickImport(capability);
    if (!context.mounted ||
        outcome == ImportPickOutcome.cancelled ||
        outcome == ImportPickOutcome.superseded) {
      return;
    }
    if (outcome == ImportPickOutcome.selected && model.pendingImport != null) {
      await _confirm(context, recovery: false);
      return;
    }
    if (model.state != AccountsState.failed) return;
    final chooseAgain = await showDakhlDialog<bool>(
      context: context,
      title: accountStatus(model),
      body: const Text(
        'تحقّق من الملف واختر نسخة أخرى. لم تتغيّر الحسابات الحالية.',
      ),
      actions: [
        DakhlButton(
          label: 'إلغاء',
          autofocus: true,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        DakhlButton(
          label: 'اختيار ملف آخر',
          kind: DakhlButtonKind.primary,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    if (chooseAgain == true && context.mounted) await _choose(context);
  }

  Future<void> _previous(BuildContext context) async {
    await model.selectPrevious();
    if (context.mounted && model.recoverySelection != null) {
      await _confirm(context, recovery: true);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.all(DakhlTokens.gutter(constraints.maxWidth)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'الإعدادات والنسخ',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 20),
            DakhlPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'البيانات والنسخ',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      accountStatus(model),
                      style: TextStyle(
                        color:
                            model.state == AccountsState.failed ||
                                model.state == AccountsState.protected ||
                                model.state == AccountsState.commitUnknown
                            ? DakhlTokens.red
                            : DakhlTokens.ink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (model.state == AccountsState.failed)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('تغييراتك ما زالت معروضة. أعد المحاولة.'),
                    ),
                  if (model.state == AccountsState.protected)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'الحسابات الحالية محفوظة دون تغيير. يمكنك إعادة المحاولة أو فحص النسخة المحلية السابقة.',
                      ),
                    ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      DakhlButton(
                        label: 'حفظ الحسابات',
                        kind: DakhlButtonKind.primary,
                        onPressed:
                            model.canMutate &&
                                model.pendingImport == null &&
                                model.recoverySelection == null
                            ? () => unawaited(model.save())
                            : null,
                      ),
                      DakhlButton(
                        label: 'استيراد الحسابات',
                        onPressed: model.canImport && transfer != null
                            ? () => unawaited(_choose(context))
                            : null,
                      ),
                      DakhlButton(
                        label: 'تصدير الحسابات',
                        onPressed:
                            !model.busy &&
                                model.document != null &&
                                transfer != null
                            ? () => unawaited(model.exportTo(transfer!))
                            : null,
                      ),
                      DakhlButton(
                        label: 'استعادة النسخة السابقة',
                        onPressed: model.canSelectRecovery
                            ? () => unawaited(_previous(context))
                            : null,
                      ),
                    ],
                  ),
                  if (model.pendingImport != null ||
                      model.recoverySelection != null) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        DakhlButton(
                          label: model.recoverySelection != null
                              ? 'استعادة النسخة السابقة'
                              : 'استبدال الحسابات',
                          kind: DakhlButtonKind.primary,
                          onPressed:
                              !model.busy &&
                                  !model.needsAuthorityReload &&
                                  model.state != AccountsState.commitUnknown
                              ? () => unawaited(
                                  _confirm(
                                    context,
                                    recovery: model.recoverySelection != null,
                                  ),
                                )
                              : null,
                        ),
                        DakhlButton(
                          label: 'إلغاء',
                          onPressed:
                              !model.busy &&
                                  !model.needsAuthorityReload &&
                                  model.state != AccountsState.commitUnknown
                              ? model.cancelImport
                              : null,
                        ),
                      ],
                    ),
                  ],
                  if (model.state == AccountsState.commitUnknown ||
                      model.state == AccountsState.conflict ||
                      model.state == AccountsState.protected ||
                      model.state == AccountsState.failed) ...[
                    const SizedBox(height: 16),
                    DakhlButton(
                      label: model.state == AccountsState.commitUnknown
                          ? 'إعادة التحقق'
                          : 'إعادة المحاولة',
                      onPressed: model.busy
                          ? null
                          : () => unawaited(
                              model.state == AccountsState.commitUnknown
                                  ? model.reconcile()
                                  : model.needsAuthorityReload
                                  ? model.retry()
                                  : model.state == AccountsState.protected
                                  ? model.initialize()
                                  : model.pendingImport != null
                                  ? _confirm(context, recovery: false)
                                  : model.recoverySelection != null
                                  ? _confirm(context, recovery: true)
                                  : model.retry(),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
