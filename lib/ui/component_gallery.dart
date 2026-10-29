import 'package:flutter/material.dart';

import 'components.dart';
import 'dialogs.dart';
import 'icons.dart';
import 'theme.dart';

/// Development-only synthetic component surface; no business repository access.
class Phase01ComponentGallery extends StatefulWidget {
  const Phase01ComponentGallery({super.key});
  @override
  State<Phase01ComponentGallery> createState() =>
      _Phase01ComponentGalleryState();
}

class _Phase01ComponentGalleryState extends State<Phase01ComponentGallery> {
  final _moneyFocus = FocusNode();
  @override
  void dispose() {
    _moneyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final stack = DakhlTokens.stacked(context, c.maxWidth);
      final width = stack ? c.maxWidth - 28 : (c.maxWidth - 76) / 3;
      Widget section(String title, List<Widget> children) => SizedBox(
        width: width,
        child: DakhlPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      );
      return SingleChildScrollView(
        padding: EdgeInsets.all(DakhlTokens.gutter(c.maxWidth)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'المكونات وحالات التفاعل',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const Text('بيئة تطوير · بيانات توضيحية'),
            const SizedBox(height: 24),
            Wrap(
              spacing: 14,
              runSpacing: 20,
              children: [
                section('الحقول وحالاتها', [
                  DakhlField(
                    label: 'المبلغ · دينار عراقي',
                    kind: DakhlFieldKind.money,
                    initialValue: '25,000',
                    focusNode: _moneyFocus,
                  ),
                  DakhlButton(
                    label: 'معاينة التركيز',
                    onPressed: _moneyFocus.requestFocus,
                  ),
                  const DakhlField(
                    label: 'التاريخ',
                    kind: DakhlFieldKind.date,
                    initialValue: '2026/10/27',
                  ),
                  const DakhlField(
                    label: 'الكمية',
                    kind: DakhlFieldKind.quantity,
                    initialValue: '2',
                  ),
                  const DakhlField(
                    label: 'قيمة غير صالحة',
                    initialValue: 'غير صالح',
                    errorText: 'يرجى مراجعة القيمة',
                  ),
                  DakhlSelect<String>(
                    label: 'النوع',
                    value: 'اختيار',
                    items: const [
                      DropdownMenuItem(value: 'اختيار', child: Text('اختيار')),
                    ],
                    onChanged: (_) {},
                  ),
                  const DakhlButton(label: 'غير متاح'),
                ]),
                section('الحفظ والتنبيهات', [
                  const DakhlStatus(
                    message: 'جارٍ الحفظ...',
                    kind: DakhlStatusKind.saving,
                  ),
                  const SizedBox(height: 12),
                  const DakhlStatus(
                    message: 'محفوظ على جهازك',
                    kind: DakhlStatusKind.saved,
                  ),
                  const SizedBox(height: 12),
                  DakhlStatus(
                    message: 'تعذر الحفظ. أعد المحاولة.',
                    kind: DakhlStatusKind.error,
                    onRetry: () {},
                    onCancel: () {},
                  ),
                  const SizedBox(height: 16),
                  const DakhlButton(
                    label: 'حفظ التغييرات',
                    busy: true,
                    kind: DakhlButtonKind.primary,
                  ),
                  DakhlButton(
                    label: 'إظهار تنبيه',
                    onPressed: () => showDakhlToast(context, 'محفوظ على جهازك'),
                  ),
                ]),
                section('حالات العرض', [
                  const DakhlLoadingState(),
                  const SizedBox(height: 16),
                  DakhlEmptyState(onRetry: () {}),
                  const SizedBox(height: 16),
                  const DakhlBadge('جاهز'),
                  const SizedBox(height: 16),
                  DakhlButton(
                    label: 'تغييرات غير محفوظة',
                    icon: DakhlIconKind.undo,
                    onPressed: () => showDakhlDiscardDialog(context),
                  ),
                  DakhlButton(
                    label: 'نافذة قياسية',
                    onPressed: () => showDakhlDialog<void>(
                      context: context,
                      title: 'نافذة قياسية',
                      body: const Text('بيانات توضيحية'),
                      actions: [
                        Builder(
                          builder: (context) => DakhlButton(
                            label: 'إغلاق',
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ],
            ),
            const SizedBox(height: 20),
            DakhlFilterBar(
              actions: [
                DakhlButton(
                  label: 'تطبيق التصفية',
                  onPressed: () {},
                  kind: DakhlButtonKind.primary,
                ),
                DakhlButton(label: 'مسح / الكل', onPressed: () {}),
              ],
              children: const [
                DakhlField(label: 'البحث'),
                DakhlField(label: 'من', kind: DakhlFieldKind.date),
                DakhlField(label: 'إلى', kind: DakhlFieldKind.date),
              ],
            ),
            const SizedBox(height: 16),
            const DakhlTable(
              columns: ['التاريخ', 'البيان', 'المبلغ · د.ع'],
              numericColumns: {0, 2},
              rows: [
                ['2026/10/27', 'بيان توضيحي', '125,000'],
              ],
            ),
            const SizedBox(height: 16),
            DakhlPagination(caption: 'صفحة 1 من 2 · 60 نتيجة', onNext: () {}),
          ],
        ),
      );
    },
  );
}
