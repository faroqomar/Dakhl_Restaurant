import ast
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]

class PlanGroupingTest(unittest.TestCase):
    def test_builder_emits_retained_completion_scope(self):
        tree = ast.parse((ROOT / 'scripts/build-flutter-plan.py').read_text())
        current = json.loads((ROOT / 'docs/planning/flutter-rebuild/phase-map.json').read_text())
        assignment = next(n for n in tree.body if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'EXECUTION_GROUPING' for t in n.targets))
        grouping = ast.literal_eval(assignment.value)
        call = next(n.value for n in tree.body if isinstance(n, ast.Expr) and isinstance(n.value, ast.Call) and isinstance(n.value.func, ast.Name) and n.value.func.id == 'write' and n.value.args and isinstance(n.value.args[0], ast.Constant) and n.value.args[0].value == 'phase-map.json')
        captured = {}
        groups = [(g['phase'], g['title'], g['dependencies'], g['former_phases'], '', g['reason']) for g in current['groups']]
        env = dict(json=json, write=lambda name, data: captured.update(json.loads(data)), EXECUTION_GROUPING=grouping, BASELINE_PHASES=[None]*current['old_phase_count'], PHASES=[None]*current['current_phase_count'], OLD_TO_NEW=current['old_to_new'], PHASE_GROUPS=groups)
        exec(compile(ast.fix_missing_locations(ast.Module(body=[ast.Expr(call)], type_ignores=[])), '<phase-map-writer>', 'exec'), env)
        self.assertEqual(captured['execution_grouping'], current['execution_grouping'])
        self.assertEqual(captured['old_to_new'], current['old_to_new'])
