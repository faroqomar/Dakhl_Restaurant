import 'dart:convert';
import 'dart:io';

import 'package:dakhl_restaurant/app/source_collation_runtime.dart';

/// Isolated consumer load check; this process never boots the restaurant app.
void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Provide one bundled native library path.');
    exitCode = 64;
    return;
  }
  final runtime = SourceCollationRuntime.loadLibrary(args.single);
  if (runtime == null) {
    stdout.writeln(jsonEncode({'status': 'unavailable'}));
    exitCode = 1;
    return;
  }
  try {
    if (runtime.events.compare('café', 'cafe\u0301') != 0 ||
        runtime.events.compare('a\u0000b', 'a\u0000c') >= 0 ||
        runtime.materialNames.compare('ماء', 'ماء') != 0) {
      throw StateError('Synthetic bundled collation check failed.');
    }
    stdout.writeln(
      jsonEncode({
        'status': 'passed',
        'profiles': [
          runtime.events.profile.identifier,
          runtime.materialNames.profile.identifier,
        ],
        'scope': 'explicit-path load with synthetic strings; no app or account bootstrap',
      }),
    );
  } finally {
    runtime.close();
  }
}
