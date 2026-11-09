import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/platform/completion_performance_scenarios.dart';

void main() {
  test('nonvisual options reject unknown cases and unsafe run identities', () {
    for (final args in [
      ['--case', 'orders.process'],
      ['--case', 'catalog.lookup', '--run-id', '../unsafe'],
      ['--case', 'catalog.lookup', '--iterations', '0'],
      ['--case', 'catalog.lookup', '--case', 'settings.save'],
    ]) {
      expect(
        () => CompletionPerformanceOptions.parse(args),
        throwsFormatException,
      );
    }
  });
  for (final operation in completionPerformanceCases) {
    test(
      '$operation executes real command and survives adapter reopen',
      () async {
        final fixture = await CompletionPerformanceFixture.create(
          'test',
          operation,
        );
        final directory = fixture.directory;
        try {
          expect(
            fixture.repository.document!.toJson()['products'],
            hasLength(1000),
          );
          await fixture.run();
          await fixture.verifyDurable();
        } finally {
          await fixture.close();
        }
        expect(await Directory(directory.path).exists(), isFalse);
      },
    );
  }
  test(
    'lookup consumes results and writes no account or workspace revision',
    () async {
      final fixture = await CompletionPerformanceFixture.create(
        'lookup',
        'catalog.lookup',
      );
      try {
        final document = fixture.repository.snapshot;
        final workspace = fixture.repository.workspaceSnapshot;
        await fixture.run();
        expect(fixture.lookupIds, ['product-999']);
        expect(fixture.repository.snapshot, same(document));
        expect(fixture.repository.workspaceSnapshot, same(workspace));
      } finally {
        await fixture.close();
      }
    },
  );
}
