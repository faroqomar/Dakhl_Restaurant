"""Review workflow routing and separate-operation registration contract."""
import importlib.util
import json
from pathlib import Path
import unittest

MODULE = Path(__file__).parents[1] / 'run_benchmarks.py'
spec = importlib.util.spec_from_file_location('review_benchmark_runner', MODULE)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

class ReviewOperationTests(unittest.TestCase):
    def test_routes_to_review_entrypoint_and_fixture(self):
        entry = {'phase': 'Completion', 'harness': 'review-operations'}
        self.assertEqual(runner.operation_target(entry), 'lib/platform/review_performance_main.dart')
        self.assertEqual(runner.operation_fixture_source(entry), 'lib/platform/review_performance_scenarios.dart')

    def test_independent_real_workflow_registry(self):
        entries = [x for x in json.loads(runner.REGISTRY.read_text())['operations'] if x.get('harness') == 'review-operations']
        self.assertEqual(len(entries), 36)
        self.assertEqual(len({x['id'] for x in entries}), 36)
        self.assertTrue({'review.suppliers.additional_debt', 'review.cash.external_deposit', 'review.categories.save', 'review.suppliers.opening_write'} <= {x['id'] for x in entries})
        for entry in entries:
            self.assertEqual(entry['defaultIterations'], 20)
            self.assertEqual(entry['fixtureProfile'], 'review-operations-v1')
            self.assertIn('No UI', entry['scope'])
            self.assertIn('not a performance result', entry['verification'])

if __name__ == '__main__':
    unittest.main()
