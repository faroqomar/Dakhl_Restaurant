"""Visible native-raster registration and workload-comparability contracts."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

MODULE = Path(__file__).parents[1] / 'run_benchmarks.py'
spec = importlib.util.spec_from_file_location('visible_runner', MODULE)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

class VisibleOperationsTests(unittest.TestCase):
    def test_visible_entrypoints_and_boundaries(self):
        entries = [entry for entry in json.loads(runner.REGISTRY.read_text())['operations'] if entry.get('harness') == 'visible-operations']
        self.assertEqual({e['id'] for e in entries}, {'orders.process', 'catalog.add_item', 'sales.add_item', 'visible.suppliers.ledger'})
        for entry in entries:
            self.assertEqual(runner.operation_target(entry), 'lib/platform/visible_performance_main.dart')
            self.assertEqual(runner.operation_fixture_source(entry), 'lib/platform/visible_performance_scenarios.dart')
            self.assertEqual(runner.operation_timeout(entry), 900)
            self.assertEqual(entry['defaultIterations'], 20)
            self.assertIn('2x DPR', entry['scope'])
            self.assertIn('sampled RAM/CPU window', entry['scope'])
            self.assertIn('not a performance result', entry['verification'])

    def test_visible_fixture_fingerprint_changes_with_reused_seed_and_ui_workload(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'lib/platform/visible_performance_scenarios.dart'
            source.parent.mkdir(parents=True)
            source.write_text('visible workload v1')
            seed = root / 'lib/platform/review_performance_scenarios.dart'
            seed.write_text('shared seed v1')
            entry = dict(harness='visible-operations', scenarioVersion='1')
            with patch.object(runner, 'ROOT', root):
                fingerprint = runner.operation_fixture_fingerprint(entry, 'sales.add_item', 'small')
                self.assertEqual(fingerprint, runner.operation_fixture_fingerprint(entry, 'sales.add_item', 'largest'))
                seed.write_text('shared seed v2')
                changed_seed = runner.operation_fixture_fingerprint(entry, 'sales.add_item', 'small')
                self.assertNotEqual(fingerprint, changed_seed)
                source.write_text('visible workload v2')
                changed_ui = runner.operation_fixture_fingerprint(entry, 'sales.add_item', 'small')
                self.assertNotEqual(changed_seed, changed_ui)
                self.assertNotEqual(changed_ui, runner.operation_fixture_fingerprint(entry, 'orders.process', 'small'))
                self.assertNotEqual(changed_ui, runner.operation_fixture_fingerprint(dict(entry, scenarioVersion='2'), 'sales.add_item', 'small'))

if __name__ == '__main__':
    unittest.main()
