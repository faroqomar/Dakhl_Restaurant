import 'dart:io';

import 'package:madar_application/madar_application.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// App-specific development isolation; persistence is implemented by Madar.
final class ShellPreferencesDirectory {
  ShellPreferencesDirectory({Future<Directory> Function()? applicationSupport})
    : _applicationSupport =
          applicationSupport ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _applicationSupport;
  static const leaf = 'dakhl_restaurant_phase01_shell';

  Future<CapabilityResult<String>> databasePath() async {
    try {
      final support = await _applicationSupport();
      final canonical = await support.resolveSymbolicLinks();
      final segments = [
        ...p.split(p.normalize(support.absolute.path)),
        ...p.split(p.normalize(canonical)),
      ];
      if (segments.any(
        (part) => RegExp(
          r'^(daftar|com\.(?:eros\.)?daftar(?:\..*)?)$',
          caseSensitive: false,
        ).hasMatch(part),
      )) {
        return const CapabilityFailure(
          'legacy_storage_rejected',
          'Legacy data locations are forbidden.',
        );
      }
      final root = Directory(p.join(canonical, leaf));
      final type = await FileSystemEntity.type(root.path, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.directory) {
        return _unsafe();
      }
      await root.create();
      if (await root.resolveSymbolicLinks() != root.path) return _unsafe();
      final databasePath = p.join(root.path, 'preferences.sqlite');
      final databaseType = await FileSystemEntity.type(
        databasePath,
        followLinks: false,
      );
      if (databaseType != FileSystemEntityType.notFound &&
          databaseType != FileSystemEntityType.file) {
        return _unsafe();
      }
      return CapabilitySuccess(databasePath);
    } on Object {
      return const CapabilityFailure(
        'app_support_unavailable',
        'Isolated application support is unavailable.',
      );
    }
  }

  CapabilityFailure<String> _unsafe() => const CapabilityFailure(
    'unsafe_storage_root',
    'Development preferences require a private local directory.',
  );
}
