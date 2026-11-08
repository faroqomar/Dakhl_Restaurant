import 'dart:async';

import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';

import '../ui/components.dart';
import '../ui/dialogs.dart';
import '../ui/theme.dart';
import 'portable_account_transfer_controller.dart';

/// Localized Arabic description of transfer capability failure codes.
String portableTransferErrorMessage(String code) => switch (code) {
  'unsupported_version' ||
  'unsupported_format' => 'إصدار الملف غير مدعوم (يتطلب الإصدار 12)',
  'invalid_payload' || 'invalid_workspace' => 'الملف غير صالح للاستيراد',
  'payload_too_large' ||
  'input_too_large' => 'حجم الملف أكبر من المسموح (الحد الأقصى 20 ميغابايت)',
  'stale_revision' ||
  'conflict' => 'تغيّرت الحسابات المحفوظة؛ أعد قراءتها قبل المتابعة.',
  'commit_unknown' => 'تعذّر تأكيد الحفظ؛ أعد التحقق.',
  'no_previous_copy' => 'لا توجد نسخة سابقة متاحة للاستعادة.',
  'no_pending_import' => 'لا توجد نسخة جاهزة للاستيراد.',
  'file_unreadable' ||
  'file_unavailable' ||
  'native_open_failed' => 'تعذّر فتح أو قراءة الملف.',
  'cancelled' => 'تم إلغاء اختيار الملف.',
  'busy' => 'العملية قيد التنفيذ حالياً.',
  'disposed' => 'تم إنهاء واجهة النقل.',
  'corrupt_state' || 'unsupported_fields' => 'محتوى الملف غير صالح أو تالف.',
  'unsaved_import' => 'توجد نسخة مستوردة قيد الانتظار؛ ألغها أولاً.',
  'account_missing' => 'لم يتم العثور على وثيقة الحسابات في وحدة التخزين.',
  _ => 'تعذّر إكمال العملية ($code).',
};

/// Portable accounts data and backup surface conforming to the approved C7
/// `phone-settings-data` frame and shared Phase 02 patterns (A-status, B-file-errors,
/// C-recovery, E-narrow-recovery, F-large-text).
///
/// It provides concrete import/export/settings data UI over [PortableAccountTransferController]
/// and [FileTransferCapability]. When a replacement import is confirmed and committed,
/// it notifies via [onImportApplied] so that the parent composition owner can reopen
/// the session after generation replacement.
class PortableAccountsSurface extends StatefulWidget {
  const PortableAccountsSurface({
    super.key,
    required this.controller,
    this.transfer,
    this.onImportApplied,
  });

  final PortableAccountTransferController controller;
  final FileTransferCapability? transfer;
  final ValueChanged<DocumentSnapshot>? onImportApplied;

  @override
  State<PortableAccountsSurface> createState() =>
      _PortableAccountsSurfaceState();
}

class _PortableAccountsSurfaceState extends State<PortableAccountsSurface> {
  String? _statusMessage;
  DakhlStatusKind _statusKind = DakhlStatusKind.info;
  bool _lastExportFailed = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(PortableAccountsSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  bool get _isInteractionBlocked =>
      widget.controller.busy ||
      widget.controller.isWriteBlocked() ||
      widget.controller.needsReadback;

  Future<void> _export({bool retry = false}) async {
    final transfer = widget.transfer;
    if (transfer == null || _isInteractionBlocked) return;

    setState(() {
      _lastExportFailed = false;
      _statusMessage = null;
    });

    final result = await widget.controller.exportTo(transfer, retry: retry);
    if (!mounted) return;

    setState(() {
      if (result is CapabilitySuccess<void>) {
        _lastExportFailed = false;
        _statusMessage = 'تم تصدير النسخة الاحتياطية بنجاح.';
        _statusKind = DakhlStatusKind.saved;
      } else if (result is CapabilityFailure<void>) {
        _lastExportFailed = true;
        _statusMessage =
            'تعذّر تصدير الحسابات: ${portableTransferErrorMessage(result.code)}';
        _statusKind = DakhlStatusKind.error;
      }
    });
  }

  Future<void> _pickImport() async {
    final transfer = widget.transfer;
    if (transfer == null || _isInteractionBlocked) return;

    setState(() {
      _statusMessage = null;
    });

    final outcome = await widget.controller.pickImport(transfer);
    if (!mounted) return;

    setState(() {
      if (outcome is CapabilityCancelled) {
        // User cancelled picker gracefully; retain state.
        return;
      }
      if (outcome case CapabilityFailure(:final code)) {
        _statusMessage =
            'تعذّر استيراد الملف: ${portableTransferErrorMessage(code)}';
        _statusKind = DakhlStatusKind.error;
        return;
      }
      if (outcome is CapabilitySuccess<PendingPortableAccountImport>) {
        _statusMessage = 'النسخة المحددة جاهزة للمعاينة وتأكيد الاستبدال.';
        _statusKind = DakhlStatusKind.info;
      }
    });
  }

  Future<void> _preparePrevious() async {
    if (_isInteractionBlocked || widget.controller.hasPendingImport) return;
    final result = await widget.controller.preparePrevious();
    if (!mounted) return;
    setState(() {
      _statusKind = result is CapabilitySuccess
          ? DakhlStatusKind.info
          : DakhlStatusKind.error;
      _statusMessage = result is CapabilitySuccess
          ? 'النسخة السابقة جاهزة للمعاينة. أكد الاستعادة بعد مراجعة المحتوى.'
          : portableTransferErrorMessage((result as CapabilityFailure).code);
    });
  }

  void _cancelImport() {
    if (_isInteractionBlocked) return;
    widget.controller.cancelImport();
    setState(() {
      _statusMessage = 'تم إلغاء الاستيراد؛ تم الإبقاء على الحسابات الحالية.';
      _statusKind = DakhlStatusKind.info;
    });
  }

  Future<void> _confirmImport() async {
    if (!widget.controller.hasPendingImport || _isInteractionBlocked) return;

    final candidate = widget.controller.pendingImport!;
    final restaurantName = candidate
        .state
        .account
        .preferences
        .restaurant['name']
        ?.trim();
    final displayName = (restaurantName != null && restaurantName.isNotEmpty)
        ? restaurantName
        : 'النسخة المحددة';

    final accepted = await showDakhlDialog<bool>(
      context: context,
      title: 'استبدال الحسابات الحالية؟',
      body: Text(
        'ستُستبدل الحسابات بالنسخة المحددة ($displayName). '
        'تُحفظ نسخة من البيانات الحالية تلقائياً في سجل النسخ قبل الاستبدال.',
      ),
      actions: [
        DakhlButton(
          label: 'إلغاء',
          autofocus: true,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        DakhlButton(
          label: 'استبدال الحسابات',
          kind: DakhlButtonKind.primary,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );

    if (accepted != true || !mounted) {
      return;
    }

    final result = await widget.controller.confirmImport();
    if (!mounted) return;

    setState(() {
      if (result is CapabilitySuccess<void>) {
        _statusMessage = 'تم استبدال الحسابات بنجاح وحفظ النسخة السابقة.';
        _statusKind = DakhlStatusKind.saved;
        widget.onImportApplied?.call(widget.controller.snapshot);
      } else if (result is CapabilityFailure<void>) {
        _statusMessage =
            'تعذّر استبدال الحسابات: ${portableTransferErrorMessage(result.code)}';
        _statusKind = DakhlStatusKind.error;
      }
    });
  }

  Future<void> _reconcile() async {
    if (widget.controller.busy || widget.controller.isWriteBlocked()) return;

    final result = await widget.controller.reconcile();
    if (!mounted) return;

    setState(() {
      if (result is CapabilitySuccess<void>) {
        _statusMessage = 'تم التحقق من الحفظ بنجاح واعتماد النسخة المستوردة.';
        _statusKind = DakhlStatusKind.saved;
        widget.onImportApplied?.call(widget.controller.snapshot);
      } else if (result is CapabilityFailure<void>) {
        _statusMessage =
            'تعذّر إعادة التحقق: ${portableTransferErrorMessage(result.code)}';
        _statusKind = DakhlStatusKind.error;
      }
    });
  }

  Future<void> _reload() async {
    if (widget.controller.busy || widget.controller.isWriteBlocked()) return;

    final before = widget.controller.snapshot;
    final result = await widget.controller.reload(discardPendingImport: true);
    if (!mounted) return;

    setState(() {
      if (result is CapabilitySuccess<void>) {
        _statusMessage = 'تم تحديث حالة الحسابات بنجاح من وحدة التخزين.';
        _statusKind = DakhlStatusKind.saved;
        final after = widget.controller.snapshot;
        if (after.fence != before.fence ||
            after.revision != before.revision ||
            after.payload != before.payload ||
            after.writeToken != before.writeToken) {
          widget.onImportApplied?.call(after);
        }
      } else if (result is CapabilityFailure<void>) {
        _statusMessage =
            'تعذّر تحديث الحالة: ${portableTransferErrorMessage(result.code)}';
        _statusKind = DakhlStatusKind.error;
      }
    });
  }

  Widget _buildStatusBanner() {
    final controller = widget.controller;

    if (controller.busy) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: DakhlStatus(
          message: 'جارٍ تنفيذ العملية وحفظ البيانات…',
          kind: DakhlStatusKind.saving,
        ),
      );
    }

    if (controller.needsReadback) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DakhlStatus(
          key: const Key('portable-status-unknown'),
          message: 'تعذّر تأكيد الحفظ؛ أعد التحقق للتأكد من حالة النسخة.',
          kind: DakhlStatusKind.error,
          onRetry: _reconcile,
        ),
      );
    }

    if (controller.requiresReload) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DakhlStatus(
          key: const Key('portable-status-reload'),
          message: 'تغيّرت الحسابات المحفوظة في وحدة التخزين؛ أعد قراءتها قبل المتابعة.',
          kind: DakhlStatusKind.error,
          onRetry: _reload,
        ),
      );
    }

    if (_statusMessage != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DakhlStatus(
          key: const Key('portable-status-message'),
          message: _statusMessage!,
          kind: _statusKind,
          onCancel: () => setState(() => _statusMessage = null),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCandidateSummary(PendingPortableAccountImport pending) {
    final candidateState = pending.state;
    final restaurantName = candidateState.account.preferences.restaurant['name']
        ?.trim();
    final displayName = (restaurantName != null && restaurantName.isNotEmpty)
        ? restaurantName
        : 'بدون اسم';

    return DakhlPanel(
      key: const Key('portable-candidate-summary'),
      borderColor: DakhlTokens.focus,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Semantics(
                header: true,
                child: Text(
                  pending.isRecovery
                      ? 'ملخص النسخة السابقة'
                      : 'ملخص النسخة المراد استيرادها',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const DakhlBadge('مرشحة للاستبدال'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'سيتم استبدال الحسابات بالبيانات التالية بعد تأكيدك. '
            'تُحفظ نسخة الملف الأصلي دون تغيير قبل الاستبدال.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: DakhlTokens.muted),
          ),
          const SizedBox(height: 14),
          _buildInfoRow('اسم المطعم في النسخة', displayName),
          _buildInfoRow(
            'عدد القيود اليومية',
            '${candidateState.journals.length}',
          ),
          _buildInfoRow(
            'عدد الإيصالات الموثقة',
            '${candidateState.receipts.length}',
          ),
          _buildInfoRow(
            'تاريخ بداية السجل المالي',
            candidateState.cutoverState.cutoverDate?.toString() ?? 'غير محدد',
          ),
          _buildInfoRow('حجم الملف', '${pending.byteLength} بايت'),
          ..._coverageRows(pending),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              DakhlButton(
                key: const Key('portable-confirm-button'),
                label: 'استبدال الحسابات',
                kind: DakhlButtonKind.primary,
                busy: widget.controller.busy,
                onPressed: _isInteractionBlocked ? null : _confirmImport,
              ),
              DakhlButton(
                key: const Key('portable-cancel-button'),
                label: 'إلغاء',
                onPressed: _isInteractionBlocked ? null : _cancelImport,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _coverageRows(PendingPortableAccountImport pending) {
    final source = pending.state.account.toJson();
    const labels = <String, String>{
      'days': 'الأيام',
      'categories': 'الفئات',
      'products': 'المنتجات',
      'stockEntries': 'حركات المخزون',
      'sales': 'المبيعات',
      'saleReturns': 'المرتجعات',
      'suppliers': 'الموردون',
      'materials': 'المواد',
      'invoices': 'فواتير الشراء',
      'payments': 'الدفعات',
      'debts': 'الديون الإضافية',
      'transactions': 'حركات الصندوق',
      'transfers': 'التحويلات',
      'workers': 'سجلات العمال السابقة',
      'savingsEntries': 'سجلات السلف السابقة',
    };
    return [
      _buildInfoRow('إصدار النسخة', '12'),
      for (final entry in labels.entries)
        _buildInfoRow(entry.value, switch (source[entry.key]) {
          List values => '${values.length}',
          Map values => '${values.length}',
          _ => '0',
        }),
    ];
  }

  Widget _buildInfoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: DakhlTokens.muted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: DakhlTokens.muted),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final currentRestaurant = controller.account.preferences.restaurant['name']
        ?.trim();
    final displayName =
        (currentRestaurant != null && currentRestaurant.isNotEmpty)
        ? currentRestaurant
        : 'بدون اسم';

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.all(DakhlTokens.gutter(constraints.maxWidth)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header matching C7 phone-settings-data
            Semantics(
              header: true,
              child: Text(
                'نسخة إضافية، وراحة بال',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'الحسابات تنحفظ تلقائياً على جهازك. احتفظ بنسخة إضافية بمكان مستقل.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: DakhlTokens.muted),
            ),
            const SizedBox(height: 20),

            _buildStatusBanner(),

            // Panel 1: Current Backup & Authority Status
            DakhlPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'حالة النسخ الاحتياطية',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const DakhlBadge('محفوظ على جهازك'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'نسخة الحساب الكاملة على هذا الجهاز.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: DakhlTokens.muted),
                  ),
                  const SizedBox(height: 14),
                  _buildInfoRow('اسم المطعم الحالي', displayName),
                  _buildInfoRow(
                    'سجلات القيود',
                    '${controller.journals.length} قيد',
                  ),
                  _buildInfoRow(
                    'الإيصالات الموثقة',
                    '${controller.receipts.length} إيصال',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      DakhlButton(
                        key: const Key('portable-previous-button'),
                        label: 'معاينة النسخة السابقة',
                        onPressed:
                            (_isInteractionBlocked ||
                                controller.hasPendingImport)
                            ? null
                            : _preparePrevious,
                      ),
                      DakhlButton(
                        key: const Key('portable-reload-button'),
                        label: 'تحديث الحالة',
                        busy: controller.busy,
                        onPressed: _isInteractionBlocked ? null : _reload,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Panel 2: Candidate Import Summary (if pending)
            if (controller.hasPendingImport) ...[
              _buildCandidateSummary(controller.pendingImport!),
              const SizedBox(height: 18),
            ],

            // Panel 3: Export Section
            DakhlPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'تصدير نسخة احتياطية',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'كل الحسابات والمبيعات والمخزن والإعدادات بملف واحد بصيغة الإصدار 12.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: DakhlTokens.muted),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      DakhlButton(
                        key: const Key('portable-export-button'),
                        label: 'تصدير نسخة',
                        kind: DakhlButtonKind.primary,
                        busy: controller.busy,
                        onPressed:
                            (_isInteractionBlocked || widget.transfer == null)
                            ? null
                            : () => _export(retry: false),
                      ),
                      if (_lastExportFailed ||
                          controller.hasRetainedExportBytes)
                        DakhlButton(
                          key: const Key('portable-export-retry-button'),
                          label: 'إعادة محاولة التصدير',
                          kind: DakhlButtonKind.primary,
                          busy: controller.busy,
                          onPressed:
                              (_isInteractionBlocked || widget.transfer == null)
                              ? null
                              : () => _export(retry: true),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Panel 4: Import Section
            DakhlPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'استيراد نسخة محفوظة',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'يستبدل الحسابات الحالية بعد معاينتها وتأكيدك. نحفظ نسخة من البيانات الحالية قبل الاستبدال.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: DakhlTokens.muted),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      DakhlButton(
                        key: const Key('portable-import-button'),
                        label: 'استيراد نسخة',
                        busy: controller.busy,
                        onPressed:
                            (_isInteractionBlocked || widget.transfer == null)
                            ? null
                            : _pickImport,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
