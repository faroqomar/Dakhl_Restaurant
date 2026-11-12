import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PlanGroupingTest(unittest.TestCase):
    def test_retained_capture_mapping_covers_each_original_phase_once(self):
        current = json.loads(
            (ROOT / 'docs/planning/flutter-rebuild/phase-map.json').read_text()
        )
        self.assertEqual(current['old_phase_count'], 19)
        self.assertEqual(current['current_phase_count'], 12)
        self.assertEqual(
            {g['phase'] for g in current['groups']},
            {f'{i:02}' for i in range(12)},
        )
        mapping = {}
        for group in current['groups']:
            for old in group['former_phases']:
                self.assertNotIn(old, mapping, 'Original phase assigned twice')
                mapping[old] = group['phase']
        self.assertEqual(set(mapping), {f'{i:02}' for i in range(19)})
        self.assertEqual(mapping, current['old_to_new'])

    def test_completion_overlay_retains_required_work_packages(self):
        current = json.loads(
            (ROOT / 'docs/planning/flutter-rebuild/phase-map.json').read_text()
        )
        grouping = current['execution_grouping']
        self.assertEqual(grouping['phase'], 'Completion')
        self.assertEqual(
            grouping['included_work_packages'],
            ['00-residual', '02-residual'] + [f'{i:02}' for i in range(3, 12)],
        )
        self.assertEqual(grouping['reused_completed_work_packages'], ['01'])
        self.assertTrue(grouping['preserve_original_capture_mapping'])
        scope = ROOT / 'docs/planning/flutter-rebuild' / grouping['scope_record']
        self.assertTrue(scope.is_file(), 'Completion scope record must remain available')
