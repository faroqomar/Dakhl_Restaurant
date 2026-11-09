import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';

import '../catalog/catalog_formatters.dart';
import '../ui/components.dart';
import '../ui/dialogs.dart';
import 'ticket_workspace.dart';

typedef HoldTicketAction = Future<CapabilityResult<void>> Function(
  String label,
  String heldId,
  TicketDraft fresh,
  String savedAt,
);
typedef ResumeTicketAction = Future<CapabilityResult<void>> Function(
  String id,
  String swapId,
  String savedAt,
);

Future<void> showHoldOrderDialog(
  BuildContext context, {
  required Listenable updates,
  required TicketDraft Function() fresh,
  required TicketDraft? Function() active,
  required List<HeldTicket> Function() held,
  required bool Function() needsReadback,
  required HoldTicketAction hold,
  required Future<CapabilityResult<void>> Function() reconcile,
  ValueChanged<bool>? onDirty,
}) async {
  String name = '';
  final heldId = CatalogFormatters.generateId('held');
  final successor = fresh();
  final stamp = CatalogFormatters.currentIsoTimestamp();
  final original = active()?.id;
  bool saving = false, dirty = false;
  String? error;
  StateSetter? update;
  Future<bool> discard() async {
    if (saving || needsReadback()) return false;
    if (!dirty) return true;
    final confirm = await showDakhlDialog<bool>(
      context: context,
      title: 'إهمال اسم الطلب؟',
      body: const Text('الطلب لم يُعلّق بعد؛ تبقى فاتورتك الحالية محفوظة.'),
      actions: [
        Builder(
          builder: (ctx) => DakhlButton(
            label: 'إهمال التغييرات',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ),
      ],
    );
    if (confirm == true) onDirty?.call(false);
    return confirm == true;
  }

  await showDakhlDialog<void>(
    context: context,
    title: 'تعليق الطلب',
    subtitle: 'احفظ الطلب وافتح طلباً جديداً.',
    body: StatefulBuilder(
      builder: (ctx, set) {
        update = set;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DakhlField(
              label: 'اسم الطلب (اختياري)',
              value: name,
              autofocus: true,
              enabled: !saving && !needsReadback(),
              onChanged: (value) {
                name = value;
                dirty = true;
                onDirty?.call(true);
              },
            ),
            if (error != null) DakhlStatus(message: error!),
          ],
        );
      },
    ),
    actions: [
      StatefulBuilder(
        builder: (ctx, set) => DakhlButton(
          label: needsReadback()
              ? 'إعادة التحقق من التعليق'
              : 'تعليق وفتح طلب جديد',
          kind: DakhlButtonKind.primary,
          busy: saving,
          onPressed: saving
              ? null
              : () async {
                  saving = true;
                  update?.call(() {});
                  set(() {});
                  CapabilityResult<void> result;
                  try {
                    if (needsReadback()) {
                      result = await reconcile();
                      if (result is CapabilitySuccess<void> &&
                          !(active()?.id == successor.id &&
                              held().any(
                                (h) => h.id == heldId && h.draft.id == original,
                              ))) {
                        result = const CapabilityFailure(
                          'unconfirmed_hold',
                          'Hold was not confirmed.',
                        );
                      }
                    } else {
                      result = await hold(name, heldId, successor, stamp);
                    }
                  } on Object {
                    result = const CapabilityFailure(
                      'unavailable',
                      'Hold unavailable.',
                    );
                  }
                  if (!ctx.mounted) return;
                  saving = false;
                  if (result is CapabilitySuccess<void>) {
                    dirty = false;
                    onDirty?.call(false);
                    Navigator.of(ctx).pop();
                  } else {
                    error = needsReadback()
                        ? 'تعذّر تأكيد التعليق؛ أعد التحقق قبل المحاولة.'
                        : CatalogFormatters.errorMessage(
                            result is CapabilityFailure
                                ? result.code
                                : 'unavailable',
                          );
                    update?.call(() {});
                    set(() {});
                  }
                },
        ),
      ),
    ],
    canDismiss: discard,
  );
  update = null;
}

Future<void> showHeldOrdersDialog(
  BuildContext context, {
  required Listenable updates,
  required List<HeldTicket> Function() held,
  required TicketDraft? Function() active,
  required bool Function() needsReadback,
  required ResumeTicketAction resume,
  required Future<CapabilityResult<void>> Function(String) delete,
  required Future<CapabilityResult<void>> Function() reconcile,
}) async {
  bool working = false;
  String? error;
  Future<bool> remove(HeldTicket item) async {
    bool saving = false;
    String? failure;
    return await showDakhlDialog<bool>(
          context: context,
          title: 'حذف الطلب المعلق؟',
          body: Text(
            'سيُحذف ${item.label} من الطلبات المعلقة؛ لا يتغير أي بيع محفوظ.',
          ),
          actions: [
            StatefulBuilder(
              builder: (ctx, set) => Column(
                children: [
                  if (failure != null) DakhlStatus(message: failure!),
                  DakhlButton(
                    label: needsReadback()
                        ? 'إعادة التحقق من الحذف'
                        : 'حذف الطلب',
                    kind: DakhlButtonKind.danger,
                    busy: saving,
                    onPressed: saving
                        ? null
                        : () async {
                            set(() => saving = true);
                            CapabilityResult<void> result;
                            try {
                              if (needsReadback()) {
                                result = await reconcile();
                                if (result is CapabilitySuccess<void> &&
                                    held().any((h) => h.id == item.id)) {
                                  result = const CapabilityFailure(
                                    'unconfirmed_delete',
                                    'Deletion was not confirmed.',
                                  );
                                }
                              } else {
                                result = await delete(item.id);
                              }
                            } on Object {
                              result = const CapabilityFailure(
                                'unavailable',
                                'Deletion unavailable.',
                              );
                            }
                            if (!ctx.mounted) return;
                            set(() {
                              saving = false;
                              failure = result is CapabilitySuccess<void>
                                  ? null
                                  : CatalogFormatters.errorMessage(
                                      result is CapabilityFailure
                                          ? result.code
                                          : 'unavailable',
                                    );
                            });
                            if (result is CapabilitySuccess<void>) {
                              Navigator.of(ctx).pop(true);
                            }
                          },
                  ),
                ],
              ),
            ),
          ],
          canDismiss: () async => !saving && !needsReadback(),
        ) ==
        true;
  }

  await showDakhlDialog<void>(
    context: context,
    title: 'الطلبات المعلقة',
    body: StatefulBuilder(
      builder: (ctx, set) => AnimatedBuilder(
        animation: updates,
        builder: (ctx, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (held().isEmpty)
              const DakhlEmptyState(
                title: 'ماكو طلبات معلقة',
                message: 'علّق طلباً من فاتورتك الحالية لتكمله لاحقاً.',
              ),
            for (final item in held())
              DakhlPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextButton(
                      onPressed: working || needsReadback()
                          ? null
                          : () async {
                              final swap = CatalogFormatters.generateId('held');
                              final stamp =
                                  CatalogFormatters.currentIsoTimestamp();
                              set(() {
                                working = true;
                                error = null;
                              });
                              final result = await resume(item.id, swap, stamp);
                              if (!ctx.mounted) return;
                              if (result is CapabilitySuccess<void>) {
                                Navigator.of(ctx).pop();
                                return;
                              }
                              set(() {
                                working = false;
                                error = CatalogFormatters.errorMessage(
                                  result is CapabilityFailure
                                      ? result.code
                                      : 'unavailable',
                                );
                              });
                            },
                      child: Text(item.label),
                    ),
                    Text(
                      '${item.draft.lines.length} أصناف · ${item.draft.date}',
                    ),
                    DakhlButton(
                      label: 'حذف ${item.label}',
                      onPressed: working || needsReadback()
                          ? null
                          : () async {
                              await remove(item);
                              if (ctx.mounted) set(() {});
                            },
                    ),
                  ],
                ),
              ),
            if (error != null) DakhlStatus(message: error!),
            if (needsReadback())
              DakhlButton(
                label: 'إعادة التحقق من الطلبات',
                onPressed: working
                    ? null
                    : () async {
                        set(() => working = true);
                        final result = await reconcile();
                        if (ctx.mounted) {
                          set(() {
                            working = false;
                            error = result is CapabilitySuccess<void>
                                ? null
                                : CatalogFormatters.errorMessage(
                                    result is CapabilityFailure
                                        ? result.code
                                        : 'unavailable',
                                  );
                          });
                        }
                      },
              ),
          ],
        ),
      ),
    ),
    actions: const [],
    canDismiss: () async => !working && !needsReadback(),
  );
}
