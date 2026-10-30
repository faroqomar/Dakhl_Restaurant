import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/accounts_view_model.dart';
import 'package:dakhl_restaurant/platform/phase02_performance_scenarios.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;

void main() {
  test('Phase02 arguments reject fabricated cases/unsafe fixture identity', () {
    expect(
      Phase02PerformanceOptions.parse([
        '--case',
        'accounts.save',
        '--iterations',
        '20',
        '--run-id',
        'abc',
        '--fixture',
        'medium',
      ]).fixtureName,
      'medium',
    );
    for (final args in [
      ['--case', 'orders.process'],
      ['--iterations', '0'],
      ['--run-id', '../accounts'],
      ['--fixture', 'real-restaurant'],
    ]) {
      expect(
        () => Phase02PerformanceOptions.parse(args),
        throwsFormatException,
      );
    }
  });
  test('synthetic small/medium fixtures are valid and measurable manifest matches bytes', () {
    for (final name in ['small', 'medium']) {
      final fixture = Phase02Workload.create(name, 'unitfixture');
      expect(fixture.recordCount, name == 'small' ? 10 : 1000);
      expect(fixture.document.sourceVersion, 11);
      expect(fixture.manifest['canonicalBytes'], fixture.canonicalBytes.length);
      expect(jsonDecode(utf8.decode(fixture.legacyBytes))['version'], 1);
      expect(fixture.workspace.held.length, 40);
      expect(fixture.workspace.active, isNotEmpty);
    }
  });
  test(
    'largest bounded synthetic fixture fits independent input/output limits',
    () {
      final fixture = Phase02Workload.create('largest', 'unitfixture');
      expect(fixture.canonicalBytes.length, greaterThan(19 * 1024 * 1024));
      expect(
        fixture.canonicalBytes.length,
        lessThanOrEqualTo(20 * 1024 * 1024),
      );
      expect(fixture.legacyBytes.length, lessThanOrEqualTo(20 * 1024 * 1024));
      expect(fixture.recordCount, 10000);
    },
  );
  test('all six scenarios call actual consumer commands and verify durable outcome', () async {
    for (final operation in phase02PerformanceCases) {
      final fixture = Phase02Workload.create('small', 'unitfixture');
      final store = FixtureStore();
      final model = AccountsViewModel(
        repository: AccountsRepository(store: store),
      );
      await preparePhase02Operation(model, operation, fixture);
      await runPhase02Operation(model, operation, fixture);
      expect(model.state, AccountsState.saved, reason: operation);
      if (operation == 'workspace.save_restore') {
        expect(model.workspace.held.length, 40);
      }
      if (operation == 'accounts.migrate_legacy') {
        expect(model.document!.migrated, isTrue);
      }
      model.dispose();
    }
  });
}
