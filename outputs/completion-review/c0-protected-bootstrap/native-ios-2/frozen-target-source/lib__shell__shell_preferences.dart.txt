import 'dart:convert';

import 'shell_routes.dart';

/// Only device-local navigation preferences enter this payload.
///
/// Form/ticket contents, account identities and financial records are expressly
/// absent. Madar stores the opaque string; this app owns its schema and meaning.
final class ShellPreferences {
  ShellPreferences({required String routeId, required List<String> shortcuts})
    : routeId = ShellRoutes.normalizeRoute(routeId),
      shortcuts = List<String>.unmodifiable(_normalizeSlots(shortcuts));

  factory ShellPreferences.defaults() => ShellPreferences(
    routeId: ShellRoutes.sales,
    shortcuts: ShellRoutes.defaultShortcuts,
  );

  static const namespace = 'dakhl_restaurant.shell.v1';
  static const schemaVersion = 1;
  final String routeId;
  final List<String> shortcuts;

  static List<String> _normalizeSlots(List<String> slots) {
    if (slots.length != 6) {
      throw const ShellPreferencesFormatException('invalid_preferences');
    }
    return slots.map(ShellRoutes.normalizeShortcut).toList(growable: false);
  }

  static ShellPreferences decode(String payload) {
    Object? value;
    try {
      value = jsonDecode(payload);
    } on FormatException {
      throw const ShellPreferencesFormatException('invalid_preferences');
    }
    if (value is! Map<String, dynamic> || value['schemaVersion'] is! int) {
      throw const ShellPreferencesFormatException('invalid_preferences');
    }
    final version = value['schemaVersion'] as int;
    if (version > schemaVersion) {
      throw const ShellPreferencesFormatException(
        'unsupported_preferences_version',
      );
    }
    if (version != schemaVersion ||
        value.length != 3 ||
        value['lastRouteId'] is! String ||
        value['shortcuts'] is! List ||
        (value['shortcuts'] as List).length != 6 ||
        !(value['shortcuts'] as List).every((slot) => slot is String)) {
      throw const ShellPreferencesFormatException('invalid_preferences');
    }
    return ShellPreferences(
      routeId: value['lastRouteId'] as String,
      shortcuts: (value['shortcuts'] as List).cast<String>(),
    );
  }

  String encode() => jsonEncode({
    'schemaVersion': schemaVersion,
    'lastRouteId': routeId,
    'shortcuts': shortcuts,
  });

  ShellPreferences copyWith({String? routeId, List<String>? shortcuts}) =>
      ShellPreferences(
        routeId: routeId ?? this.routeId,
        shortcuts: shortcuts ?? this.shortcuts,
      );

  @override
  bool operator ==(Object other) =>
      other is ShellPreferences &&
      routeId == other.routeId &&
      _equalSlots(shortcuts, other.shortcuts);

  @override
  int get hashCode => Object.hash(routeId, Object.hashAll(shortcuts));

  static bool _equalSlots(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Stable app error classification; never retain an invalid payload in a message.
final class ShellPreferencesFormatException implements Exception {
  const ShellPreferencesFormatException(this.code);
  final String code;

  @override
  String toString() => 'ShellPreferencesFormatException($code)';
}
