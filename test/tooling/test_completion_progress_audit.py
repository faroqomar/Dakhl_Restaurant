"""Regression coverage for the app's fixed 213-obligation count audit."""
import copy
from contextlib import redirect_stdout
import io
import importlib.util
import json
from pathlib import Path
import tempfile
import subprocess
import sys
import unittest
from unittest import mock


SOURCE = Path(__file__).resolve().parents[2] / 'scripts/audit-completion-progress.py'
SPEC = importlib.util.spec_from_file_location('completion_progress_audit', SOURCE)
audit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit)


class CompletionProgressAuditTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.checklist = self.root / audit.CHECKLIST
        self.progress = self.root / audit.PROGRESS
        self.output = self.root / audit.OUTPUT
        self.checklist.parent.mkdir(parents=True)
        self.progress.parent.mkdir(parents=True)
        self.rows = [
            f'- [{"x" if identity == "F-01" else " "}] '
            f'**{identity} [{kind}]** Original requirement; approval remains separate.'
            for identity, kind in sorted(audit.EXPECTED_TYPES.items())
        ]
        self.items = [dict(id=identity, type=kind, status='open', evidence=[])
                      for identity, kind in sorted(audit.EXPECTED_TYPES.items())]
        self.item('F-01')['status'] = 'Closed: accepted policy; implementation gates separate'
        self.original_audit = dict(previousSnapshot={'total': 213, 'closed': 0},
                                   approvalState='owner-pending', extension={'keep': [1, 2]},
                                   counts={'M': {'customMetric': 'preserved'}})
        self.save()

    def item(self, identity):
        return next(item for item in self.items if item['id'] == identity)

    def save(self):
        self.checklist.write_text('# Canonical requirements\n' + '\n'.join(self.rows) + '\n')
        self.progress.write_text(json.dumps({'items': self.items,
                                            'approvalState': 'unchanged'}))
        self.output.write_text(json.dumps(self.original_audit))

    def assert_refused_without_mutation(self, code):
        before = {p: p.read_bytes() for p in [self.checklist, self.progress, self.output]}
        with self.assertRaises(audit.AuditError) as error:
            audit.run(self.root, write=True)
        self.assertEqual(error.exception.code, code)
        self.assertEqual(before, {p: p.read_bytes() for p in before})
        self.assertEqual(list(self.output.parent.glob('.completion-audit-*')), [])

    def test_descriptive_closed_status_uses_canonical_checkbox(self):
        self.item('C1-04').update(status='reviewed foundation; UI pending', evidence=['receipt.json'])
        self.save()
        before = self.output.read_bytes()
        result = audit.run(self.root)
        self.assertEqual(result['total'], 213)
        self.assertEqual(result['formalChecked'], 1)
        self.assertEqual(result['partialProgress'], 1)
        self.assertEqual(result['noProgressRecorded'], 211)
        self.assertEqual(result['counts']['G']['closed'], 1)
        self.assertEqual(result['counts']['M']['partialProgress'], 1)
        self.assertEqual(self.output.read_bytes(), before)

    def test_checked_row_is_closed_even_when_progress_text_says_open(self):
        self.item('F-01')['status'] = 'open'
        self.save()
        self.assertEqual(audit.run(self.root)['formalChecked'], 1)

    def test_open_status_with_evidence_is_partial(self):
        self.item('C0-02')['evidence'] = ['independent-review.json']
        self.save()
        self.assertEqual(audit.run(self.root)['partialProgress'], 1)

    def test_unchecked_closed_and_descriptive_closed_are_rejected(self):
        for status in ['closed', 'CLOSED after independent review', 'closed_reviewed']:
            with self.subTest(status=status):
                self.item('C0-02')['status'] = status
                self.save()
                self.assert_refused_without_mutation('unchecked_closed_status')

    def test_duplicate_checklist_id_is_rejected(self):
        self.rows.append(self.rows[0])
        self.save()
        self.assert_refused_without_mutation('duplicate_checklist_id')

    def test_duplicate_progress_id_is_rejected(self):
        self.items.append(copy.deepcopy(self.items[0]))
        self.save()
        self.assert_refused_without_mutation('duplicate_progress_id')

    def test_unknown_id_in_both_inputs_cannot_pass_matching_sets(self):
        identity = self.items[0]['id']
        self.rows = [row.replace(identity, 'C99-99') for row in self.rows]
        self.items[0]['id'] = 'C99-99'
        self.save()
        self.assert_refused_without_mutation('checklist_id_set')

    def test_missing_progress_id_is_rejected(self):
        self.items.pop()
        self.save()
        self.assert_refused_without_mutation('progress_id_set')

    def test_type_drift_preserving_bucket_totals_is_rejected(self):
        self.item('C1-04')['type'], self.item('C1-01')['type'] = 'I', 'M'
        self.save()
        self.assert_refused_without_mutation('progress_type_mismatch')

    def test_checklist_type_drift_is_rejected(self):
        self.rows = [row.replace('**F-01 [G]**', '**F-01 [M]**') for row in self.rows]
        self.save()
        self.assert_refused_without_mutation('checklist_type_mismatch')

    def test_write_preserves_unrelated_fields_and_all_source_bytes(self):
        before = {p: p.read_bytes() for p in [self.checklist, self.progress]}
        result = audit.run(self.root, write=True)
        written = json.loads(self.output.read_text())
        self.assertTrue(result['written'])
        self.assertEqual(written['previousSnapshot'], self.original_audit['previousSnapshot'])
        self.assertEqual(written['approvalState'], 'owner-pending')
        self.assertEqual(written['extension'], {'keep': [1, 2]})
        self.assertEqual(written['counts']['M']['customMetric'], 'preserved')
        self.assertEqual(written['closedRows'], ['F-01'])
        self.assertEqual(written['formalChecked'], 1)
        self.assertEqual(before, {p: p.read_bytes() for p in before})
        self.assertEqual(list(self.output.parent.glob('.completion-audit-*')), [])
        self.assertTrue(audit.run(self.root)['auditMatches'])

    def test_unknown_audit_id_is_rejected_before_write(self):
        self.original_audit['closedRows'] = ['C99-99']
        self.save()
        self.assert_refused_without_mutation('audit_closed_rows')

    def test_invalid_aggregate_types_are_not_repaired_by_write(self):
        for value in [True, -1, '32']:
            with self.subTest(value=value):
                self.original_audit['formalChecked'] = value
                self.save()
                self.assert_refused_without_mutation('audit_aggregate_type')

    def test_missing_fields_and_wrong_closure_totals_are_distinct(self):
        audit.run(self.root, write=True)
        existing = json.loads(self.output.read_text())
        del existing['counts']['M']['noProgressRecorded']
        existing['formalChecked'] = 0
        self.output.write_text(json.dumps(existing))
        result = audit.run(self.root)
        self.assertEqual(result['missingAggregateFields'], ['counts.M.noProgressRecorded'])
        self.assertEqual(result['mismatchedAggregateFields'], ['formalChecked'])

    def test_duplicate_json_keys_are_rejected(self):
        self.progress.write_text('{"items":[],"items":[]}')
        self.assert_refused_without_mutation('duplicate_json_key')

    def test_nonfinite_json_metadata_is_rejected_before_write(self):
        for number in ['NaN', 'Infinity', '1e999']:
            with self.subTest(number=number):
                self.save()
                self.output.write_text('{"unrelated":' + number + '}')
                self.assert_refused_without_mutation('invalid_json')

    def test_cli_deep_json_refuses_without_traceback_or_input_mutation(self):
        self.output.write_text('{"extra":' + '[' * 1200 + '0' + ']' * 1200 + '}')
        before = {p: p.read_bytes() for p in [self.checklist, self.progress, self.output]}
        result = subprocess.run(
            [sys.executable, '-B', str(SOURCE), '--root', str(self.root), '--write'],
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stderr, '')
        self.assertEqual(json.loads(result.stdout),
                         dict(status='refused', code='invalid_json', written=False))
        self.assertEqual(before, {p: p.read_bytes() for p in before})
        self.assertEqual(list(self.output.parent.glob('.completion-audit-*')), [])

    def test_input_change_refuses_atomic_replacement(self):
        original = self.output.read_bytes()
        with mock.patch.object(audit, 'verify_unchanged', side_effect=audit.AuditError('inputs_changed')):
            with self.assertRaises(audit.AuditError):
                audit.run(self.root, write=True)
        self.assertEqual(self.output.read_bytes(), original)
        self.assertEqual(list(self.output.parent.glob('.completion-audit-*')), [])

    def test_malformed_checklist_marker_is_not_silently_ignored(self):
        self.rows[0] = self.rows[0].replace('- [ ]', '- [?]')
        self.save()
        self.assert_refused_without_mutation('malformed_checklist_row')

    def test_failed_atomic_replace_preserves_original_and_removes_scratch(self):
        before = self.output.read_bytes()
        with mock.patch.object(audit.os, 'replace', side_effect=OSError('synthetic failure')):
            with self.assertRaises(OSError):
                audit.run(self.root, write=True)
        self.assertEqual(self.output.read_bytes(), before)
        self.assertEqual(list(self.output.parent.glob('.completion-audit-*')), [])

    def test_cli_dry_run_then_explicit_write_and_invalid_write(self):
        before = self.output.read_bytes()
        stream = io.StringIO()
        with redirect_stdout(stream):
            self.assertEqual(audit.main(['--root', str(self.root)]), 1)
        self.assertFalse(json.loads(stream.getvalue())['written'])
        self.assertEqual(self.output.read_bytes(), before)
        stream = io.StringIO()
        with redirect_stdout(stream):
            self.assertEqual(audit.main(['--root', str(self.root), '--write']), 0)
        self.assertTrue(json.loads(stream.getvalue())['auditMatches'])
        self.item('C0-02')['status'] = 'closed'
        self.save()
        before = self.output.read_bytes()
        stream = io.StringIO()
        with redirect_stdout(stream):
            self.assertEqual(audit.main(['--root', str(self.root), '--write']), 2)
        self.assertEqual(json.loads(stream.getvalue())['code'], 'unchecked_closed_status')
        self.assertEqual(self.output.read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
