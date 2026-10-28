import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../capabilities/capability_contracts.dart';

typedef ApplicationSupportDirectory = Future<Directory> Function();

/// Creates only the fixed development child. Never resolves a legacy data root.
final class NativeProbeDirectory {
  NativeProbeDirectory({ApplicationSupportDirectory? applicationSupport})
    : _applicationSupport =
          applicationSupport ?? getApplicationSupportDirectory;

  static const leaf = 'dakhl_restaurant_phase00_devprobe';
  final ApplicationSupportDirectory _applicationSupport;

  Future<CapabilityResult<Directory>> resolve() async {
    try {
      final support = await _applicationSupport();
      final canonical = await support.resolveSymbolicLinks();
      final segments = p.split(p.normalize(canonical));
      if (segments.any(
        (part) => RegExp(
          r'^(daftar|com\.daftar(?:\..*)?)$',
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
        return const CapabilityFailure(
          'unsafe_storage_root',
          'Development root must be a real directory.',
        );
      }
      await root.create();
      if (await root.resolveSymbolicLinks() != root.path) {
        return const CapabilityFailure(
          'unsafe_storage_root',
          'Development root changed during resolution.',
        );
      }
      return CapabilitySuccess(root);
    } on Object {
      return const CapabilityFailure(
        'app_support_unavailable',
        'Isolated application support is unavailable.',
      );
    }
  }
}
