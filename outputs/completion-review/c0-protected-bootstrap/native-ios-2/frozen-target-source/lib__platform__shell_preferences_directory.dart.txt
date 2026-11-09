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
      if (_isLegacyAppStorage(support.absolute.path) ||
          _isLegacyAppStorage(canonical)) {
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

  /// A home/user-created ancestor is not an application identity. Check the
  /// supplied support leaf and platform storage identity positions, including
  /// both lexical and resolved paths so aliases cannot bypass isolation.
  bool _isLegacyAppStorage(String path) {
    final parts = p.split(p.normalize(path));
    final legacy = RegExp(
      r'^(daftar|com\.(?:eros\.)?daftar(?:\..*)?)$',
      caseSensitive: false,
    );
    if (parts.isNotEmpty && legacy.hasMatch(parts.last)) return true;
    for (var index = 0; index < parts.length; index++) {
      if (!legacy.hasMatch(parts[index])) continue;
      if (index >= 2 &&
          parts[index - 2].toLowerCase() == 'library' &&
          const {
            'application support',
            'containers',
            'group containers',
          }.contains(parts[index - 1].toLowerCase())) {
        return true;
      }
      if (index >= 2 &&
          parts[index - 2] == 'data' &&
          parts[index - 1] == 'data') {
        return true;
      }
      if (index >= 3 &&
          parts[index - 3] == 'data' &&
          const {'user', 'user_de'}.contains(parts[index - 2]) &&
          int.tryParse(parts[index - 1]) != null) {
        return true;
      }
    }
    return false;
  }

  CapabilityFailure<String> _unsafe() => const CapabilityFailure(
    'unsafe_storage_root',
    'Development preferences require a private local directory.',
  );
}
