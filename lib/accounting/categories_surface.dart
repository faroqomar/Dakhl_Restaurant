import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';

import '../ui/dakhl_ui.dart';
import 'categories_view_model.dart';

Future<CategoryRecord?> showCategoryEditor(
  BuildContext context, {
  required CategoriesViewModel model,
  required CategoryDraft draft,
  required bool Function() canWrite,
}) => showDialog<CategoryRecord>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _CategoryEditor(model: model, draft: draft, canWrite: canWrite),
);

/// Approved C4 category presentation; mutations remain in the app ViewModel.
class CategoriesSurface extends StatelessWidget {
  const CategoriesSurface({
    super.key,
    required this.model,
    required this.canWrite,
  });
  final CategoriesViewModel model;
  final bool Function() canWrite;

  Future<void> _edit(BuildContext context, [CategoryRecord? record]) async {
    if (!canWrite() || model.busy) return;
    final draft = record == null
        ? model.newCategoryDraft()
        : model.editCategoryDraft(record.id);
    if (draft == null) return;
    await showCategoryEditor(
      context,
      model: model,
      draft: draft,
      canWrite: canWrite,
    );
  }

  Future<void> _classify(
    BuildContext context,
    CategoryRecord row,
    CategoryType type,
  ) async {
    if (!canWrite() || model.busy) return;
    final result = await model.setCategoryType(row.id, type);
    if (context.mounted && result is! CapabilitySuccess<CategoryRecord>) {
      showDakhlToast(
        context,
        'تعذّر الحفظ. بقي التصنيف المحفوظ؛ أعد قراءة الحساب قبل المحاولة.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1200
            ? 4
            : width >= 760
            ? 2
            : 1;
        final rows = model.allCategories;
        return SingleChildScrollView(
          padding: EdgeInsets.all(DakhlTokens.gutter(width)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 20,
                runSpacing: 12,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('المصاريف / الخانات'),
                      Text(
                        'الخانات',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const Text(
                        'اختار لكل خانة رئيسية أو إضافية. أي تغيير ينحفظ تلقائياً.',
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: canWrite() && !model.busy
                        ? () => _edit(context)
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة خانة'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (model.busy) const LinearProgressIndicator(),
              if (model.lastErrorCode != null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('تعذّر حفظ التغيير؛ بقيت البيانات المحفوظة.'),
                ),
              DakhlPanel(
                child: LayoutBuilder(
                  builder: (context, panel) => Wrap(
                    spacing: 24,
                    runSpacing: 16,
                    children: [
                      if (rows.isEmpty)
                        const Text('لا توجد خانات. أضف خانة للبدء.'),
                      for (final row in rows)
                        SizedBox(
                          width:
                              ((panel.maxWidth - (columns - 1) * 24) / columns)
                                  .clamp(0, double.infinity),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: DakhlTokens.line),
                              ),
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                Text(row.name),
                                DropdownButton<CategoryType>(
                                  value: row.type,
                                  onChanged: canWrite() && !model.busy
                                      ? (value) {
                                          if (value != null) {
                                            _classify(context, row, value);
                                          }
                                        }
                                      : null,
                                  items: const [
                                    DropdownMenuItem(
                                      value: CategoryType.primary,
                                      child: Text('رئيسية'),
                                    ),
                                    DropdownMenuItem(
                                      value: CategoryType.additional,
                                      child: Text('إضافية'),
                                    ),
                                  ],
                                ),
                                if (row.isBuiltIn)
                                  const Text('خانة أصلية محفوظة')
                                else
                                  OutlinedButton(
                                    onPressed: canWrite() && !model.busy
                                        ? () => _edit(context, row)
                                        : null,
                                    child: Text(
                                      row.isArchived
                                          ? 'تعديل / تفعيل'
                                          : 'تعديل / إيقاف',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({
    required this.model,
    required this.draft,
    required this.canWrite,
  });
  final CategoriesViewModel model;
  final CategoryDraft draft;
  final bool Function() canWrite;
  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.draft.name,
  );
  bool _busy = false, _changed = false;
  String? _error;
  Future<bool> _dismiss() async =>
      !_busy && (!_changed || await showDakhlDiscardDialog(context));
  Future<void> _save() async {
    if (_busy || !widget.canWrite()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.draft.name = _name.text;
    try {
      final result = await widget.model.saveCategory(widget.draft);
      if (!mounted) return;
      if (result is CapabilitySuccess<CategoryRecord>) {
        Navigator.of(context).pop(result.value);
        return;
      }
      setState(() {
        _error = switch (result) {
          CapabilityFailure(:final code) when code == 'invalid_name' =>
            'أدخل اسم خانة صحيحاً (حتى ٨٠ حرفاً).',
          CapabilityFailure(:final code) when code == 'duplicate_name' =>
            'اسم الخانة موجود مسبقاً.',
          _ => 'تعذّر الحفظ. بقيت مدخلاتك؛ أعد قراءة الحساب قبل المحاولة.',
        };
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<CategoryRecord>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) async {
      if (!didPop && await _dismiss() && context.mounted) {
        Navigator.of(context).pop();
      }
    },
    child: DakhlDialog(
      title: widget.draft.isExisting ? 'تعديل خانة' : 'إضافة خانة',
      onClose: _busy
          ? null
          : () async {
              if (await _dismiss() && context.mounted) {
                Navigator.of(context).pop();
              }
            },
      body: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('اسم الخانة ينحفظ ويظهر بكل الأيام.'),
            const SizedBox(height: 24),
            TextField(
              controller: _name,
              autofocus: true,
              enabled: !_busy && !widget.draft.isBuiltIn,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'اسم الخانة',
                hintText: 'مثلاً: الغاز، مشتريات، أجور...',
              ),
              onChanged: (_) => _changed = true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CategoryType>(
              initialValue: widget.draft.type,
              decoration: const InputDecoration(labelText: 'نوع الخانة'),
              items: const [
                DropdownMenuItem(
                  value: CategoryType.primary,
                  child: Text('رئيسية'),
                ),
                DropdownMenuItem(
                  value: CategoryType.additional,
                  child: Text('إضافية'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null) {
                        widget.draft.type = value;
                        _changed = true;
                      }
                    },
            ),
            if (widget.draft.isExisting && !widget.draft.isBuiltIn)
              SwitchListTile(
                title: const Text('الخانة مفعّلة'),
                value: !widget.draft.isArchived,
                onChanged: _busy
                    ? null
                    : (enabled) => setState(() {
                        widget.draft.isArchived = !enabled;
                        _changed = true;
                      }),
              ),
            const SizedBox(height: 16),
            const Text('كل خانة جديدة تقبل مبلغ وملاحظات اختيارية.'),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  if (await _dismiss() && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _busy || !widget.canWrite() ? null : _save,
          child: Text(_busy ? 'جارٍ الحفظ...' : 'حفظ الخانة'),
        ),
      ],
    ),
  );
}
