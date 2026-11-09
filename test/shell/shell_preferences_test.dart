import 'dart:convert';

import 'package:dakhl_restaurant/shell/shell_preferences.dart';
import 'package:dakhl_restaurant/shell/shell_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all twelve destinations and six defaults are deliberate', () {
    expect(ShellRoutes.destinations.map((item) => item.id), [
      'sales',
      'sale-history',
      'inventory',
      'expenses',
      'statement',
      'suppliers',
      'invoices',
      'materials',
      'payments',
      'cash',
      'categories',
      'settings',
    ]);
    expect(ShellRoutes.defaultShortcuts, [
      'sales',
      'inventory',
      'sale-history',
      'expenses',
      'cash',
      'settings',
    ]);
    expect(
      ShellRoutes.destinations.any((item) => item.id == 'savings'),
      isFalse,
    );
  });

  test(
    'known v1 state normalizes retired and unknown IDs without extra writes',
    () {
      final decoded = ShellPreferences.decode(
        jsonEncode({
          'schemaVersion': 1,
          'lastRouteId': 'missing-route',
          'shortcuts': [
            'sales',
            '',
            'sales',
            'savings',
            'missing-route',
            'cash',
          ],
        }),
      );
      expect(decoded.routeId, 'sales');
      expect(decoded.shortcuts, ['sales', '', 'sales', '', '', 'cash']);
    },
  );

  test('v1 round trip preserves slot order, empty values and duplicates', () {
    final preferences = ShellPreferences(
      routeId: 'invoices',
      shortcuts: ['cash', '', 'cash', 'sales', 'settings', 'materials'],
    );
    final payload = jsonDecode(preferences.encode()) as Map<String, dynamic>;
    expect(payload.keys.toSet(), {'schemaVersion', 'lastRouteId', 'shortcuts'});
    expect(payload['schemaVersion'], 1);
    final roundTrip = ShellPreferences.decode(preferences.encode());
    expect(roundTrip.routeId, 'invoices');
    expect(roundTrip.shortcuts, preferences.shortcuts);
    expect(() => roundTrip.shortcuts[0] = 'sales', throwsUnsupportedError);
  });

  for (final payload in <Object?>[
    null,
    [],
    {
      'schemaVersion': 1,
      'lastRouteId': 'sales',
      'shortcuts': ['cash'],
    },
    {'schemaVersion': 1, 'lastRouteId': 12, 'shortcuts': List.filled(6, '')},
    {
      'schemaVersion': 1,
      'lastRouteId': 'sales',
      'shortcuts': List.filled(6, 1),
    },
    {
      'schemaVersion': 1,
      'lastRouteId': 'sales',
      'shortcuts': List.filled(6, ''),
      'ticket': 'private',
    },
  ]) {
    test('malformed shell payload is rejected: $payload', () {
      expect(
        () => ShellPreferences.decode(jsonEncode(payload)),
        throwsA(
          isA<ShellPreferencesFormatException>().having(
            (e) => e.code,
            'code',
            'invalid_preferences',
          ),
        ),
      );
    });
  }

  test(
    'future app schema is distinct and protected rather than normalized',
    () {
      expect(
        () => ShellPreferences.decode(
          jsonEncode({
            'schemaVersion': 2,
            'lastRouteId': 'sales',
            'shortcuts': List.filled(6, ''),
          }),
        ),
        throwsA(
          isA<ShellPreferencesFormatException>().having(
            (e) => e.code,
            'code',
            'unsupported_preferences_version',
          ),
        ),
      );
    },
  );

  test('invalid JSON is classified without exposing its content', () {
    expect(
      () => ShellPreferences.decode('private malformed payload'),
      throwsA(
        isA<ShellPreferencesFormatException>().having(
          (e) => e.toString(),
          'safe message',
          isNot(contains('private')),
        ),
      ),
    );
  });
}
