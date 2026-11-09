// Standalone acceptance driver, deliberately independent of flutter_test.
// Run with the existing package/native-assets mappings, without pub or builds:
// dart --packages=.dart_tool/package_config.json
//   test/accounts/legacy_corpus_restart_conformance_driver.dart RECEIPT_DIRECTORY
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'support/legacy_corpus_restart_child.dart' as child;

final _liveChildren = <Process>{};

Future<void> verifyMissingStoreGuard(Directory root) async {
  final missingFixture = Directory('${root.path}/must-not-reseed');
  StateError? failure;
  try {
    await child.verifyExisting(missingFixture, {}, {});
  } on StateError catch (error) {
    failure = error;
  }
  child.require(
    failure?.message == 'Missing existing store',
    'Missing-store verifier did not fail at its pre-open guard',
  );
  child.require(
    !await missingFixture.exists(),
    'Missing-store verification created fixture data',
  );
}

Future<Map<String, Object?>> sourceIdentity() async {
  final files = <String, Object?>{};
  for (final path in [
    'test/fixtures/accounts/oracle.json',
    'test/accounts/legacy_corpus_restart_conformance_driver.dart',
    'test/accounts/support/legacy_corpus_restart_child.dart',
    'pubspec.yaml',
    'pubspec.lock',
    '.dart_tool/package_config.json',
    '.dart_tool/native_assets.yaml',
    'engine-dependency.json',
  ]) {
    final file = File(path);
    if (await file.exists()) {
      files[path] = child.digest(await file.readAsBytes());
    }
  }
  // Bind all app runtime and consumed engine Dart source without Git mutation.
  for (final path in [
    'lib',
    '../Madar_Engine/packages/domain/lib',
    '../Madar_Engine/packages/application/lib',
    '../Madar_Engine/packages/data/lib',
  ]) {
    final sourceFiles = <String, Object?>{};
    await for (final entity in Directory(path).list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        sourceFiles[entity.path.substring(path.length + 1)] = child.digest(
          await entity.readAsBytes(),
        );
      }
    }
    files[path] = {
      'sha256': child.mapDigest(sourceFiles),
      'files': sourceFiles.length,
    };
  }
  return files;
}

Future<Map<String, Object?>> storage() async {
  final sizes = <String, Object?>{};
  for (final path in ['.git', '.dart_tool', 'outputs', 'test/accounts']) {
    final result = await Process.run('/usr/bin/du', ['-sk', path]);
    child.require(result.exitCode == 0, 'Storage measurement failed for $path');
    sizes[path] = int.parse(
      (result.stdout as String).trim().split(RegExp(r'\s+')).first,
    );
  }
  final free = await Process.run('/bin/df', ['-k', '.']);
  child.require(free.exitCode == 0, 'Free-disk measurement failed');
  final columns = (free.stdout as String)
      .trim()
      .split('\n')
      .last
      .split(RegExp(r'\s+'));
  final temporaryObjects = <String>[];
  await for (final entity in Directory('.git/objects').list()) {
    if (entity is Directory &&
        entity.path.split('/').last.startsWith('tmp_objdir-')) {
      temporaryObjects.add(entity.path);
    }
  }
  return {
    'freeKiB': int.parse(columns[3]),
    'sizesKiB': sizes,
    'gitTemporaryObjectDirectories': temporaryObjects,
  };
}

Future<Map<String, Object?>> runChild(
  String mode,
  Directory fixtureRoot,
  Directory receiptRoot,
) async {
  final resultFile = File('${receiptRoot.path}/$mode.json');
  final arguments = [
    '--packages=${File('.dart_tool/package_config.json').absolute.path}',
    File('test/accounts/support/legacy_corpus_restart_child.dart')
        .absolute
        .path,
    fixtureRoot.path,
    mode,
    resultFile.path,
  ];
  final started = DateTime.now().toUtc();
  final process = await Process.start(
    Platform.resolvedExecutable,
    arguments,
    workingDirectory: Directory.current.path,
  );
  _liveChildren.add(process);
  final stdoutText = StringBuffer();
  final stderrText = StringBuffer();
  void collect(StringBuffer buffer, String text) {
    const limit = 16384;
    if (buffer.length < limit) {
      buffer.write(
        text.substring(0, text.length.clamp(0, limit - buffer.length)),
      );
    }
  }

  final outDrain = process.stdout
      .transform(utf8.decoder)
      .forEach((text) => collect(stdoutText, text));
  final errDrain = process.stderr
      .transform(utf8.decoder)
      .forEach((text) => collect(stderrText, text));
  int? code;
  var timedOut = false;
  try {
    code = await process.exitCode.timeout(const Duration(seconds: 150));
    _liveChildren.remove(process);
  } on TimeoutException {
    timedOut = true;
    process.kill(ProcessSignal.sigkill);
    code = await process.exitCode.timeout(const Duration(seconds: 10));
    _liveChildren.remove(process);
  } finally {
    if (code == null) {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode.timeout(const Duration(seconds: 10));
      _liveChildren.remove(process);
    }
    await Future.wait([outDrain, errDrain]);
  }
  // A zero writer exit plus an absent OS process precedes verifier launch.
  final absent = await Process.run('/bin/ps', [
    '-p',
    '${process.pid}',
    '-o',
    'pid=',
  ]);
  final report = <String, Object?>{
    'mode': mode,
    'pid': process.pid,
    'arguments': arguments,
    'startedUtc': started.toIso8601String(),
    'finishedUtc': DateTime.now().toUtc().toIso8601String(),
    'exitCode': code,
    'timedOut': timedOut,
    'processAbsent':
        absent.exitCode == 1 && (absent.stdout as String).trim().isEmpty,
    'stdout': stdoutText.toString(),
    'stderr': stderrText.toString(),
  };
  await File('${receiptRoot.path}/$mode-process.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(report),
    flush: true,
  );
  child.require(
    !timedOut && code == 0,
    '$mode process failed; inspect $mode-process.json',
  );
  child.require(
    report['processAbsent'] == true,
    '$mode process absence not established',
  );
  child.require(
    await resultFile.exists(),
    '$mode did not write its complete receipt',
  );
  final receipt = jsonDecode(await resultFile.readAsString()) as Map;
  child.require(
    receipt['pid'] == process.pid && receipt['status'] == 'passed',
    '$mode receipt identity/status mismatch',
  );
  return report;
}

Future<void> main(List<String> args) async {
  child.require(args.length == 1, 'Supply a NEW canonical receipt directory');
  final receipts = Directory(args.single).absolute;
  child.require(
    !await receipts.exists(),
    'Receipt directory exists; preserve prior attempt',
  );
  await receipts.create(recursive: true);
  final started = DateTime.now().toUtc();
  final baseline = await storage();
  child.require(
    (baseline['freeKiB'] as int) >= 10 * 1024 * 1024,
    'Storage threshold reached; stop before creating fixtures',
  );
  final source = await sourceIdentity();
  final root = await Directory.systemTemp.createTemp(
    'dakhl-legacy-corpus-restart-',
  );
  await File('${root.path}/.legacy-corpus-owned')
      .writeAsString('synthetic-only');
  final summary = <String, Object?>{
    'format': 'dakhl-legacy-corpus-process-acceptance-v1',
    'startedUtc': started.toIso8601String(),
    'status': 'failed',
    'sourceBefore': source,
    'storageBefore': baseline,
    'fixtureRoot': root.path,
    'fixtureKind': 'synthetic-frozen-corpus',
    'exportOperation': 'AccountsRepository.codec.encode, shared by AccountsViewModel.exportBytes',
    'engineRuntimeApiChanges': 'N/A; public existing store only',
    'nativeUiAndSchema12Activation': 'not exercised',
  };
  Object? caught;
  StackTrace? caughtStack;
  try {
    child.loadCorpus();
    await verifyMissingStoreGuard(root);
    summary['missingStoreFailsWithoutReseeding'] = true;
    summary['writerProcess'] = await runChild('writer', root, receipts);
    // The verifier reads this exact writer manifest and existing stores only.
    await File('${root.path}/writer.json').writeAsBytes(
      await File('${receipts.path}/writer.json').readAsBytes(),
      flush: true,
    );
    summary['verifierProcess'] = await runChild('verify', root, receipts);
    final writer = jsonDecode(
      await File('${receipts.path}/writer.json').readAsString(),
    ) as Map;
    final verifier = jsonDecode(
      await File('${receipts.path}/verify.json').readAsString(),
    ) as Map;
    child.require(
      writer['pid'] != verifier['pid'] &&
          writer['bootNonce'] != verifier['bootNonce'],
      'Writer/verifier process isolation failed',
    );
    child.equal(
      (writer['cases'] as List).map((entry) => entry['name']).toList(),
      [...child.positiveNames, ...child.rejectionNames],
      'writer exact case identities',
    );
    summary['positiveCases'] = child.positiveNames.length;
    summary['protectedRejections'] = child.rejectionNames.length;
    summary['writerBootNonce'] = writer['bootNonce'];
    summary['verifierBootNonce'] = verifier['bootNonce'];
    summary['status'] = 'passed';
  } on Object catch (error, stack) {
    caught = error;
    caughtStack = stack;
    summary['error'] = error.toString();
    summary['stack'] = stack.toString().split('\n').take(12).join('\n');
  } finally {
    final size = await Process.run('/usr/bin/du', ['-sk', root.path]);
    summary['fixtureKiBReclaimed'] = int.parse(
      (size.stdout as String).trim().split(RegExp(r'\s+')).first,
    );
    // Retain uncertain active-process state rather than deleting its files.
    if (_liveChildren.isEmpty) {
      await root.delete(recursive: true);
    } else {
      summary['status'] = 'failed';
      summary['retainedFixtureReason'] = 'Owned child exit remains unconfirmed';
      summary['unconfirmedChildPids'] = _liveChildren
          .map((p) => p.pid)
          .toList();
    }
    summary['fixtureRemoved'] = !await root.exists();
    final finalSource = await sourceIdentity();
    summary['sourceAfter'] = finalSource;
    summary['sourceUnchanged'] =
        child.canonical(source) == child.canonical(finalSource);
    if (summary['sourceUnchanged'] != true) summary['status'] = 'failed';
    summary['storageAfter'] = await storage();
    summary['finishedUtc'] = DateTime.now().toUtc().toIso8601String();
    summary['receiptHashes'] = {
      for (final name in [
        'writer.json',
        'verify.json',
        'writer-process.json',
        'verify-process.json',
      ])
        if (await File('${receipts.path}/$name').exists())
          name: child.digest(
            await File('${receipts.path}/$name').readAsBytes(),
          ),
    };
    await File('${receipts.path}/result.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(summary),
      flush: true,
    );
  }
  if (caught != null) Error.throwWithStackTrace(caught, caughtStack!);
  child.require(
    summary['status'] == 'passed',
    'Source changed during acceptance',
  );
  stdout.writeln(
    jsonEncode({
      'status': 'passed',
      'positiveCases': 23,
      'protectedRejections': 4,
      'result': '${receipts.path}/result.json',
    }),
  );
}
