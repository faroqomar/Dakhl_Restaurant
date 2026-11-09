/// One app-owned destination. Screen visibility is never authorization.
final class ShellDestination {
  const ShellDestination({
    required this.id,
    required this.label,
    required this.group,
    this._navigationLabel,
  });

  final String id;
  final String label;
  final String group;
  final String? _navigationLabel;
  String get navigationLabel => _navigationLabel ?? label;
}

/// Stable presentation identifiers, distinct from any future business schema.
abstract final class ShellRoutes {
  static const sales = 'sales';
  static const destinations = <ShellDestination>[
    ShellDestination(id: sales, label: 'المبيعات', group: 'البيع والمخزن'),
    ShellDestination(
      id: 'sale-history',
      label: 'سجل المبيعات',
      group: 'البيع والمخزن',
    ),
    ShellDestination(id: 'inventory', label: 'المخزن', group: 'البيع والمخزن'),
    ShellDestination(
      id: 'expenses',
      label: 'المصاريف اليومية',
      group: 'الحسابات',
    ),
    ShellDestination(id: 'statement', label: 'كشف الحساب', group: 'الحسابات'),
    ShellDestination(
      id: 'suppliers',
      label: 'الموردون',
      group: 'المشتريات والموردون',
    ),
    ShellDestination(
      id: 'invoices',
      label: 'فواتير المشتريات',
      group: 'المشتريات والموردون',
    ),
    ShellDestination(
      id: 'materials',
      label: 'المواد والأسعار',
      group: 'المشتريات والموردون',
    ),
    ShellDestination(
      id: 'payments',
      label: 'التسديدات',
      group: 'المشتريات والموردون',
    ),
    ShellDestination(id: 'cash', label: 'القاصة', group: 'الحسابات'),
    ShellDestination(id: 'categories', label: 'الخانات', group: 'الإدارة'),
    ShellDestination(
      id: 'settings',
      label: 'الإعدادات',
      group: 'الإدارة',
      navigationLabel: 'الإعدادات والنسخ',
    ),
  ];

  static const groupOrder = <String>[
    'البيع والمخزن',
    'المشتريات والموردون',
    'الحسابات',
    'الإدارة',
  ];

  static const defaultShortcuts = <String>[
    sales,
    'inventory',
    'sale-history',
    'expenses',
    'cash',
    'settings',
  ];

  static bool contains(String id) => destinations.any((item) => item.id == id);
  static String normalizeRoute(String id) => contains(id) ? id : sales;
  static String normalizeShortcut(String id) => contains(id) ? id : '';

  static ShellDestination destination(String id) =>
      destinations.firstWhere((item) => item.id == normalizeRoute(id));
}
