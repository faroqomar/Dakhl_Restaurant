import 'dart:io';

import 'package:dakhl_restaurant/platform/shell_preferences_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';

void main() {
  late Directory sandbox;
  setUp(
    () async =>
        sandbox = await Directory.systemTemp.createTemp('dakhl-shell-path-'),
  );
  tearDown(() async => sandbox.delete(recursive: true));

  test('preferences use their own development child and database', () async {
    final resolver = ShellPreferencesDirectory(
      applicationSupport: () async => sandbox,
    );
    final result = await resolver.databasePath();
    final path = (result as CapabilitySuccess<String>).value;
    expect(
      path,
      '${await sandbox.resolveSymbolicLinks()}/dakhl_restaurant_phase01_shell/preferences.sqlite',
    );
    expect(
      await Directory('${sandbox.path}/dakhl_restaurant_phase00_devprobe')
          .exists(),
      isFalse,
    );
  });

  for (final legacy in ['Daftar', 'com.eros.daftar', 'com.daftar.restaurant']) {
    test('rejects legacy app directory $legacy without mutation', () async {
      final support = await Directory('${sandbox.path}/$legacy').create();
      final result = await ShellPreferencesDirectory(
        applicationSupport: () async => support,
      ).databasePath();
      expect(
        (result as CapabilityFailure<String>).code,
        'legacy_storage_rejected',
      );
      expect(await support.list().toList(), isEmpty);
    });
  }

  test('legacy-named home ancestor does not reject development support', () async {
    final support = await Directory(
      '${sandbox.path}/Users/Daftar/Library/Application Support/com.eros.dakhlrestaurant.phase00',
    ).create(recursive: true);
    final result = await ShellPreferencesDirectory(
      applicationSupport: () async => support,
    ).databasePath();
    expect(result, isA<CapabilitySuccess<String>>());
    expect(
      (result as CapabilitySuccess<String>).value,
      '${await support.resolveSymbolicLinks()}/${ShellPreferencesDirectory.leaf}/preferences.sqlite',
    );
  });

  for (final location in [
    'Library/Application Support/Daftar/nested',
    'Library/Containers/com.eros.daftar/Data/Library/Application Support',
    'data/user/0/com.daftar.restaurant/files',
    'data/data/com.eros.daftar/files',
  ]) {
    test('rejects actual legacy app storage identity $location', () async {
      final support = await Directory('${sandbox.path}/$location')
          .create(recursive: true);
      final result = await ShellPreferencesDirectory(
        applicationSupport: () async => support,
      ).databasePath();
      expect(
        (result as CapabilityFailure<String>).code,
        'legacy_storage_rejected',
      );
      expect(await support.list().toList(), isEmpty);
    });
  }

  test(
    'canonical alias into nested legacy support is rejected without mutation',
    () async {
      final legacy = await Directory(
        '${sandbox.path}/Library/Application Support/Daftar/nested',
      ).create(recursive: true);
      final alias = Link('${sandbox.path}/valid-development-support');
      await alias.create(legacy.path);
      final result = await ShellPreferencesDirectory(
        applicationSupport: () async => Directory(alias.path),
      ).databasePath();
      expect(
        (result as CapabilityFailure<String>).code,
        'legacy_storage_rejected',
      );
      expect(await legacy.list().toList(), isEmpty);
    },
  );

  test(
    'lexical legacy support alias is rejected even with safe canonical target',
    () async {
      final target = await Directory('${sandbox.path}/safe-target').create();
      final parent = await Directory(
        '${sandbox.path}/Library/Application Support',
      ).create(recursive: true);
      final alias = Link('${parent.path}/Daftar');
      await alias.create(target.path);
      final result = await ShellPreferencesDirectory(
        applicationSupport: () async => Directory(alias.path),
      ).databasePath();
      expect(
        (result as CapabilityFailure<String>).code,
        'legacy_storage_rejected',
      );
      expect(await target.list().toList(), isEmpty);
    },
  );

  test('does not follow a linked preferences root', () async {
    final target = await Directory('${sandbox.path}/unrelated').create();
    await Link('${sandbox.path}/dakhl_restaurant_phase01_shell')
        .create(target.path);
    final result = await ShellPreferencesDirectory(
      applicationSupport: () async => sandbox,
    ).databasePath();
    expect((result as CapabilityFailure<String>).code, 'unsafe_storage_root');
    expect(await target.list().toList(), isEmpty);
  });

  test('does not follow an existing linked database destination', () async {
    final root = await Directory(
      '${sandbox.path}/dakhl_restaurant_phase01_shell',
    ).create();
    final target = await File('${sandbox.path}/protected')
        .writeAsString('preserve');
    await Link('${root.path}/preferences.sqlite').create(target.path);
    final result = await ShellPreferencesDirectory(
      applicationSupport: () async => sandbox,
    ).databasePath();
    expect((result as CapabilityFailure<String>).code, 'unsafe_storage_root');
    expect(await target.readAsString(), 'preserve');
  });

  test('directory failures become sanitized outcomes', () async {
    final result = await ShellPreferencesDirectory(
      applicationSupport: () async => throw FileSystemException('private path'),
    ).databasePath();
    final failure = result as CapabilityFailure<String>;
    expect(failure.code, 'app_support_unavailable');
    expect(failure.message, isNot(contains('private path')));
  });
}
