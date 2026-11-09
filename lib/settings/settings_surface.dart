import 'package:flutter/material.dart';
import 'package:madar_application/madar_application.dart';

import '../accounts/account_document.dart';
import '../shell/shell_routes.dart';
import '../ui/components.dart';
import '../ui/dialogs.dart';
import '../ui/theme.dart';
import 'account_settings.dart';
import 'account_settings_controller.dart';
import 'portable_settings_controller.dart';

/// Selected C7 reference presentation. Account backup/import/recovery stays in
/// the supplied existing data surface, with its original confirmation gates.
class SettingsSurface extends StatefulWidget {
  const SettingsSurface({
    super.key,
    this.controller,
    this.portableController,
    required this.dataSurface,
    this.onPendingChanged,
    this.onNavigate,
    this.onSave,
    this.onReconcile,
    this.onUndo,
    this.appVersion = '0.0.0+1',
  }) : assert((controller == null) != (portableController == null));
  final AccountSettingsController? controller;
  final PortableSettingsController? portableController;
  final Widget dataSurface;
  final ValueChanged<bool>? onPendingChanged;
  final ValueChanged<String>? onNavigate;
  final Future<CapabilityResult<void>> Function()? onSave, onReconcile;
  final VoidCallback? onUndo;
  final String appVersion;
  @override
  State<SettingsSurface> createState() => _SettingsSurfaceState();
}

class _SettingsSurfaceState extends State<SettingsSurface> {
  final _name = TextEditingController(),
      _contact = TextEditingController(),
      _footer = TextEditingController(),
      _newType = TextEditingController();
  int _section = 0;
  bool _saving = false;
  String? _message;
  AccountSettingsValues get _values =>
      widget.controller?.values ?? widget.portableController!.values;
  bool get _dirty =>
      widget.controller?.isDirty ?? widget.portableController!.isDirty;
  bool get _busy =>
      _saving || (widget.controller?.isBusy ?? widget.portableController!.busy);
  bool get _unknown =>
      widget.portableController?.needsReadback ??
      widget.controller!.repository.hasUnknownWrite;
  AccountDocument get _account =>
      widget.controller?.repository.document ??
      widget.portableController!.account;
  @override
  void initState() {
    super.initState();
    _syncFields();
    widget.portableController?.addListener(_external);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pending();
    });
  }

  @override
  void didUpdateWidget(SettingsSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.portableController != widget.portableController) {
      oldWidget.portableController?.removeListener(_external);
      widget.portableController?.addListener(_external);
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.portableController != widget.portableController) {
      _syncFields();
    }
    // Legacy repository readback can clear uncertainty without replacing the
    // settings editor; refresh the shell's pending navigation signal as well.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pending();
    });
  }

  void _syncFields() {
    for (final pair in [
      (_name, _values.name),
      (_contact, _values.contact),
      (_footer, _values.footer),
    ]) {
      if (pair.$1.text != pair.$2) pair.$1.text = pair.$2;
    }
  }

  void _external() {
    if (mounted) {
      setState(_syncFields);
      _pending();
    }
  }

  void _pending() => widget.onPendingChanged?.call(
    _dirty || _newType.text.isNotEmpty || _busy || _unknown,
  );
  void _replace(AccountSettingsValues next) {
    widget.controller?.replace(next);
    widget.portableController?.replace(next);
    setState(() {
      _message = null;
    });
    _pending();
  }

  bool _workflow(AccountSettingsValues next) {
    try {
      (AccountSettingsDraft(_account)..replace(next)).prepareSave(_account);
      _replace(next);
      return true;
    } on Object {
      setState(() {
        _message =
            'أضف نوعاً فريداً، مع نوع متاح واحد على الأقل وبحد أقصى 20 نوعاً.';
      });
      return false;
    }
  }

  void _moveType(String name, int delta) {
    final list = [..._values.activeOrderTypes];
    final index = list.indexOf(name), target = list.indexOf(name) + delta;
    if (index < 0 || target < 0 || target >= list.length) return;
    list.insert(target, list.removeAt(index));
    _workflow(_values.copyWith(activeOrderTypes: list));
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_newType.text.isNotEmpty) {
      setState(() {
        _message = 'أضف نوع الطلب المكتوب أو امسحه قبل الحفظ.';
      });
      return;
    }
    setState(() {
      _saving = true;
    });
    _pending();
    try {
      final result =
          await (widget.onSave?.call() ??
              widget.controller?.save() ??
              widget.portableController!.save());
      if (!mounted) return;
      setState(() {
        _message = result is CapabilitySuccess<void>
            ? 'تم حفظ الإعدادات.'
            : _unknown
            ? 'تعذّر تأكيد الحفظ. أعد التحقق قبل المحاولة.'
            : 'تعذّر حفظ الإعدادات. راجع القيم أو أعد فتح الإعدادات إذا تغيّرت الحسابات.';
        _syncFields();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
        _pending();
      }
    }
  }

  void _discard() {
    widget.controller?.discard();
    widget.portableController?.discard();
    setState(() {
      _newType.clear();
      _syncFields();
      _message = null;
    });
    _pending();
  }

  Future<void> _rename(String name) async {
    var edited = name;
    final value = await showDakhlDialog<String>(
      context: context,
      title: 'تعديل نوع الطلب',
      body: TextFormField(
        initialValue: name,
        onChanged: (v) => edited = v,
        autofocus: true,
        maxLength: 60,
        decoration: const InputDecoration(labelText: 'اسم نوع الطلب'),
      ),
      actions: [
        DakhlButton(
          label: 'إلغاء',
          onPressed: () => Navigator.of(context).pop(),
        ),
        DakhlButton(
          label: 'حفظ',
          onPressed: () => Navigator.of(context).pop(edited.trim()),
        ),
      ],
    );
    if (value != null && mounted) {
      _workflow(
        _values.copyWith(
          activeOrderTypes: [
            for (final t in _values.activeOrderTypes) t == name ? value : t,
          ],
          disabledOrderTypes: [
            for (final t in _values.disabledOrderTypes) t == name ? value : t,
          ],
        ),
      );
    }
  }

  Widget _identity() => LayoutBuilder(
    builder: (context, constraints) {
      final form = DakhlPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'هوية وصل المطعم',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('settings-name'),
              controller: _name,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'اسم المطعم في الوصل',
              ),
              onChanged: (v) => _replace(_values.copyWith(name: v)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contact,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'رقم أو عنوان للتواصل · اختياري',
              ),
              onChanged: (v) => _replace(_values.copyWith(contact: v)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _footer,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'عبارة أسفل الوصل · اختياري',
              ),
              onChanged: (v) => _replace(_values.copyWith(footer: v)),
            ),
          ],
        ),
      );
      final preview = DakhlPanel(
        child: Column(
          children: [
            const Text('معاينة مباشرة · دفتر / وصل بيع نقدي'),
            const SizedBox(height: 24),
            Text(
              _values.name.isEmpty ? 'اسم مطعمك' : _values.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(_values.contact),
            const SizedBox(height: 28),
            const Divider(),
            const Text('الصنف                         الكمية · المبلغ'),
            const SizedBox(height: 36),
            const Text('تفاصيل طلبك تظهر هنا عند البيع'),
            const SizedBox(height: 36),
            const Divider(),
            Text(_values.footer),
            const SizedBox(height: 20),
            const Text('تحفظ التغييرات للوصولات القادمة.'),
          ],
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'اسم مطعمك على كل وصل',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text('عدّل معلومات الوصل، وشوف شكلها قبل الحفظ.'),
          const SizedBox(height: 24),
          if (constraints.maxWidth >= 950)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: form),
                const SizedBox(width: 24),
                SizedBox(width: 320, child: preview),
              ],
            )
          else ...[
            form,
            const SizedBox(height: 20),
            preview,
          ],
        ],
      );
    },
  );
  Widget _workflowSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'وصول أسرع، وبيع أوضح',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const Text('اختار صفحاتك المفضلة وأنواع طلباتك.'),
      const SizedBox(height: 24),
      DakhlPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'اختصارات الشريط العلوي',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text('ترتيبها هنا هو ترتيبها من اليمين لليسار.'),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, box) => Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (var i = 0; i < _values.shortcuts.length; i++)
                    SizedBox(
                      width: box.maxWidth < 500
                          ? box.maxWidth
                          : (box.maxWidth - 28) / 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'shortcut-$i-${_values.shortcuts[i]}',
                            ),
                            initialValue: _values.shortcuts[i],
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'الاختصار ${i + 1}',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('بدون اختصار'),
                              ),
                              for (final route in ShellRoutes.destinations)
                                DropdownMenuItem(
                                  value: route.id,
                                  child: Text(route.label),
                                ),
                            ],
                            onChanged: _busy
                                ? null
                                : (value) {
                                    final list = [..._values.shortcuts]
                                      ..[i] = value!;
                                    _workflow(
                                      _values.copyWith(shortcuts: list),
                                    );
                                  },
                          ),
                          TextButton(
                            onPressed: _busy || i == 0
                                ? null
                                : () {
                                    final list = [..._values.shortcuts];
                                    final previous = list[i - 1];
                                    list[i - 1] = list[i];
                                    list[i] = previous;
                                    _workflow(
                                      _values.copyWith(shortcuts: list),
                                    );
                                  },
                            child: const Text('نقل لليمين'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      DakhlPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'أنواع الطلبات',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'أضف أنواع شغلك، وحدد النوع الافتراضي للبيع. لا تتغير أسماء الطلبات المحفوظة.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('default-${_values.activeOrderTypes.first}'),
              initialValue: _values.activeOrderTypes.first,
              decoration: const InputDecoration(labelText: 'النوع الافتراضي'),
              items: [
                for (final t in _values.activeOrderTypes)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: _busy
                  ? null
                  : (t) => _workflow(
                      _values.copyWith(
                        activeOrderTypes: [
                          t!,
                          ..._values.activeOrderTypes.where((x) => x != t),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            for (final t in [
              ..._values.activeOrderTypes,
              ..._values.disabledOrderTypes,
            ])
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(t),
                  if (_values.activeOrderTypes.contains(t)) ...[
                    IconButton(
                      tooltip: 'نقل لأعلى',
                      onPressed: _busy || _values.activeOrderTypes.first == t
                          ? null
                          : () => _moveType(t, -1),
                      icon: const Icon(Icons.arrow_upward, size: 18),
                    ),
                    IconButton(
                      tooltip: 'نقل لأسفل',
                      onPressed: _busy || _values.activeOrderTypes.last == t
                          ? null
                          : () => _moveType(t, 1),
                      icon: const Icon(Icons.arrow_downward, size: 18),
                    ),
                  ],
                  TextButton(
                    onPressed: _busy ? null : () => _rename(t),
                    child: const Text('تعديل'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            final enabled = _values.activeOrderTypes.contains(
                              t,
                            );
                            _workflow(
                              _values.copyWith(
                                activeOrderTypes: enabled
                                    ? _values.activeOrderTypes
                                          .where((x) => x != t)
                                          .toList()
                                    : [..._values.activeOrderTypes, t],
                                disabledOrderTypes: enabled
                                    ? [..._values.disabledOrderTypes, t]
                                    : _values.disabledOrderTypes
                                          .where((x) => x != t)
                                          .toList(),
                              ),
                            );
                          },
                    child: Text(
                      _values.activeOrderTypes.contains(t) ? 'تعطيل' : 'تفعيل',
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _workflow(
                            _values.copyWith(
                              activeOrderTypes: _values.activeOrderTypes
                                  .where((x) => x != t)
                                  .toList(),
                              disabledOrderTypes: _values.disabledOrderTypes
                                  .where((x) => x != t)
                                  .toList(),
                            ),
                          ),
                    child: const Text('حذف'),
                  ),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newType,
                    onChanged: (_) {
                      setState(() {});
                      _pending();
                    },
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: 'نوع طلب جديد',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          final accepted = _workflow(
                            _values.copyWith(
                              activeOrderTypes: [
                                ..._values.activeOrderTypes,
                                _newType.text.trim(),
                              ],
                            ),
                          );
                          if (accepted) _newType.clear();
                          _pending();
                        },
                  child: const Text('إضافة'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      DakhlPanel(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            const Text('تعديل قوائم التطبيق'),
            for (final item in [
              ('categories', 'خانات المصاريف'),
              ('materials', 'المواد والأسعار'),
              ('inventory', 'أصناف البيع'),
            ])
              DakhlButton(
                label: item.$2,
                onPressed: widget.onNavigate == null
                    ? null
                    : () => widget.onNavigate!(item.$1),
              ),
          ],
        ),
      ),
    ],
  );
  Widget _about() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'دفتر، لحسابات مطعمك',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const Text('مساحة محلية خاصة لإدارة شغلك اليومي.'),
      const SizedBox(height: 24),
      DakhlPanel(
        child: Wrap(
          spacing: 48,
          runSpacing: 24,
          children: [
            Text('إصدار التطبيق\n${widget.appVersion}'),
            const Text('اللغة والاتجاه\nالعربية · من اليمين لليسار'),
            const Text('العملة\nالدينار العراقي · د.ع'),
            const Text('الحفظ\nمحلي على هذا الجهاز'),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const DakhlPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ملاحظات الحساب'),
            Text('اليومي والقاصة منفصلان. حصة القاصة تخصم مرة واحدة.'),
            Divider(),
            Text(
              'الرصيد مو صافي الربح. هذا سجل مبالغ نقدية، وليس تقرير أرباح.',
            ),
            Divider(),
            Text(
              'قائمة المورد تسجل الدين؛ التسديد يدخل بالمصاريف ويخصم من مصدر الدفع.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      DakhlPanel(
        child: Wrap(
          spacing: 20,
          children: [
            const Text('التراجع عن آخر تغيير'),
            DakhlButton(label: 'تراجع عن آخر تغيير', onPressed: widget.onUndo),
          ],
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty && _newType.text.isEmpty && !_busy && !_unknown,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الإعدادات والنسخ',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Text('رتّب دفتر بالطريقة اللي تناسب شغلك.'),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              for (var i = 0; i < 4; i++)
                TextButton(
                  onPressed: () => setState(() {
                    _section = i;
                  }),
                  style: TextButton.styleFrom(
                    backgroundColor: _section == i ? DakhlTokens.soft : null,
                  ),
                  child: Text(
                    [
                      'المطعم والوصل',
                      'البيع والاختصارات',
                      'النسخ والبيانات',
                      'عن دفتر',
                    ][i],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _section == 2
              ? widget.dataSurface
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _section == 0
                      ? _identity()
                      : _section == 1
                      ? _workflowSection()
                      : _about(),
                ),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Semantics(liveRegion: true, child: Text(_message!)),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: DakhlPanel(
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _dirty || _newType.text.isNotEmpty
                        ? 'عندك تعديلات غير محفوظة'
                        : 'إعداداتك محفوظة',
                  ),
                  DakhlButton(
                    key: const Key('settings-save'),
                    label: 'حفظ التغييرات',
                    busy: _busy,
                    kind: DakhlButtonKind.primary,
                    onPressed: !_dirty || _busy || _unknown ? null : _save,
                  ),
                  DakhlButton(
                    label: 'إلغاء التعديلات',
                    onPressed:
                        (!_dirty && _newType.text.isEmpty) || _busy || _unknown
                        ? null
                        : _discard,
                  ),
                  if (_unknown)
                    DakhlButton(
                      label: 'إعادة التحقق',
                      onPressed: _busy
                          ? null
                          : () async {
                              final result =
                                  await (widget.onReconcile?.call() ??
                                      widget.portableController?.reconcile() ??
                                      widget.controller!.repository
                                          .reconcile());
                              if (mounted) {
                                setState(() {
                                  _message = result is CapabilitySuccess
                                      ? 'أعد فتح الإعدادات لقراءة الحالة المحفوظة.'
                                      : 'تعذّر التحقق. تبقى التعديلات محفوظة هنا.';
                                });
                              }
                            },
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
  @override
  void dispose() {
    widget.portableController?.removeListener(_external);
    _name.dispose();
    _contact.dispose();
    _footer.dispose();
    _newType.dispose();
    super.dispose();
  }
}
