"""C1 registration/routing specifications; require the proposed patch first."""
import importlib.util
import json
from pathlib import Path
import unittest


MODULE = Path(__file__).parents[1] / 'run_benchmarks.py'
spec = importlib.util.spec_from_file_location('c1_app_benchmark_runner', MODULE)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

C1_IDS = {
    'c1.catalog.lookup', 'c1.catalog.filter', 'c1.catalog.page',
    'c1.product.create', 'c1.product.edit', 'c1.product.photo_select_save',
    'c1.stock.post', 'c1.stock.reverse', 'c1.stock.history',
}


class C1OperationRegistrationTests(unittest.TestCase):
    def test_c1_routes_to_its_separate_real_command_entrypoint(self):
        entry = {'phase': 'Completion', 'harness': 'c1-operations'}
        self.assertEqual(runner.operation_target(entry),
                         'lib/platform/c1_performance_main.dart')
        self.assertEqual(runner.operation_fixture_source(entry),
                         'lib/platform/c1_performance_scenarios.dart')

    def test_c1_registry_keeps_independent_cases_and_explicit_boundaries(self):
        operations = json.loads(runner.REGISTRY.read_text())['operations']
        selected = [entry for entry in operations if entry.get('harness') == 'c1-operations']
        self.assertEqual({entry['id'] for entry in selected}, C1_IDS)
        self.assertEqual(len(selected), 9)
        for entry in selected:
            self.assertEqual(entry['status'], 'ready')
            self.assertEqual(entry['defaultIterations'], 20)
            self.assertEqual(entry['measurementKind'], 'workflow')
            self.assertEqual(entry['fixtureProfile'], 'c1-operations-v1')
            self.assertIn('No UI', entry['scope'])
            self.assertIn('not a performance result', entry['verification'])
        photo = next(entry for entry in selected if entry['id'] == 'c1.product.photo_select_save')
        self.assertIn('bundled asset read', photo['scope'])
        self.assertIn('image decode', photo['scope'])

    def test_original_prepared_lookup_has_a_distinct_scope_and_series(self):
        entries = {entry['id']: entry for entry in json.loads(runner.REGISTRY.read_text())['operations']}
        self.assertEqual(entries['catalog.lookup']['harness'], 'completion-nonvisual')
        self.assertEqual(entries['catalog.lookup']['fixtureProfile'], 'completion-v1')
        self.assertEqual(entries['c1.catalog.lookup']['harness'], 'c1-operations')
        self.assertIn('stock projection', entries['c1.catalog.lookup']['scope'])


if __name__ == '__main__':
    unittest.main()
