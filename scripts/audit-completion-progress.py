#!/usr/bin/env python3
"""Audit the fixed Completion checklist; --write refreshes aggregates only.

Checked canonical IDs define closure, including rows whose progress status has
descriptive closure wording. Unchecked rows with non-open status or evidence are
partial. This app-specific audit grants no approval and reports no percentage.
Exit 0: current/written aggregates; 1: valid inputs but missing/stale aggregates;
2: refused invalid inputs or I/O failure. Writes require explicit --write.
"""
import argparse
import copy
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import re
import stat
import tempfile


CHECKLIST = Path('docs/phases/completion-unfinished-checklist.md')
PROGRESS = Path('docs/phases/completion-progress/implementation-progress.json')
OUTPUT = Path('docs/phases/completion-progress/progress-audit-latest.json')
BASELINE = {'M': 28, 'I': 70, 'V': 99, 'G': 16}
# Frozen original 213 IDs/types. Status and requirement text remain in Markdown.
EXPECTED_BY_TYPE = {
    'M': '''C1-04 F-05 F-06 F-07 C4-01 C4-02 C4-03 C4-04 C4-05 C4-08
        C4-09 C4-10 C4-12 C4-14 C4-16 C6-01 C6-02 C6-09 C7-02 C8-01
        C8-02 C8-04 C8-05 C8-10 C8-11 C8-14 C8-15 C8-16'''.split(),
    'I': '''C1-01 C1-02 C1-03 C1-05 C1-06 C1-07 C1-08 C1-09 C1-10 C1-16
        C1-17 C2-01 C2-02 C2-03 C2-04 C2-05 C2-06 C2-07 C2-08 C2-09
        C2-10 C2-11 C2-12 C2-17 C2-18 C2-19 C2-20 C3-01 C3-02 C3-03
        C3-04 C3-05 C3-06 C3-10 C3-11 C4-06 C4-07 C4-13 C4-15 C5-01
        C5-02 C5-03 C5-05 C5-06 C5-07 C5-08 C5-11 C5-12 C6-03 C6-04
        C6-05 C6-06 C6-07 C6-08 C6-10 C6-11 C6-16 C6-17 C7-01 C7-03
        C7-04 C7-06 C7-07 C7-09 C7-14 C8-07 C8-09 C8-12 C8-13 C8-18'''.split(),
    'V': '''C0-01 C0-02 C0-03 C0-04 C0-05 C0-06 C0-07 C0-08 C0-09 C0-10
        C0-11 C0-12 C0-13 D-09 C1-11 C1-12 C1-13 C1-14 C1-15 F-08 F-09
        F-10 C2-13 C2-14 C2-15 C2-16 C3-07 C3-08 C3-09 C3-12 C3-13 C3-14
        C4-11 C4-17 C4-18 C4-19 C4-20 C5-04 C5-09 C5-10 C5-13 C6-12
        C6-13 C6-14 C6-15 C6-18 C7-05 C7-08 C7-10 C7-11 C7-12 C7-13
        C7-15 C8-03 C8-06 C8-08 C8-17 C8-19 C8-20 C8-21 C9-01 C9-02
        C9-03 C9-04 C9-05 C9-06 C9-07 C9-08 C9-11 C9-12 C9-13 C9-14
        C9-15 C9-17 C9-18 C9-19 C9-20 C9-21 C9-22 C9-23 C9-24 Q-01 Q-02
        Q-03 Q-04 Q-05 Q-06 Q-07 Q-09 Q-10 Q-11 Q-12 Q-13 Q-14 Q-15 Q-16
        Q-17 Q-18 Q-19'''.split(),
    'G': '''D-01 D-02 D-03 D-04 D-05 D-06 D-07 D-08 F-01 F-02 F-03 F-04
        C9-09 C9-10 C9-16 Q-08'''.split(),
}
EXPECTED_TYPES = {identity: kind for kind, ids in EXPECTED_BY_TYPE.items()
                  for identity in ids}
ROW = re.compile(r'^- \[([ xX])\] \*\*([A-Z][A-Z0-9]*-\d+) \[([MIVG])\]\*\* (.+)$')
CLOSED_STATUS = re.compile(r'^closed(?:$|[\W_])', re.IGNORECASE)


class AuditError(Exception):
    def __init__(self, code):
        super().__init__(code)
        self.code = code


def require(condition, code):
    if not condition:
        raise AuditError(code)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'duplicate_json_key')
        result[key] = value
    return result


def decode_json(data):
    def reject_constant(_):
        raise AuditError('invalid_json')

    def finite_float(text):
        value = float(text)
        require(math.isfinite(value), 'invalid_json')
        return value

    try:
        return json.loads(data.decode('utf-8'), object_pairs_hook=unique_object,
                          parse_constant=reject_constant, parse_float=finite_float)
    except (UnicodeError, ValueError, RecursionError):
        raise AuditError('invalid_json') from None


def read_input(path):
    require(not path.is_symlink() and path.is_file(), 'unsafe_or_missing_input')
    require(path.stat().st_size <= 2 * 1024 * 1024, 'input_too_large')
    return path.read_bytes()


def parse_checklist(data):
    try:
        lines = data.decode('utf-8').splitlines()
    except UnicodeError:
        raise AuditError('invalid_checklist_encoding') from None
    rows = {}
    for line in lines:
        # A malformed checkbox/ID row must not disappear from the audit.
        if not re.match(r'^\s*-\s*\[', line):
            continue
        match = ROW.fullmatch(line)
        require(match is not None, 'malformed_checklist_row')
        checked, identity, kind, requirement = match.groups()
        require(bool(requirement.strip()), 'malformed_checklist_row')
        require(identity not in rows, 'duplicate_checklist_id')
        rows[identity] = (kind, checked.lower() == 'x')
    require(set(rows) == set(EXPECTED_TYPES), 'checklist_id_set')
    require(all(kind == EXPECTED_TYPES[identity] for identity, (kind, _) in rows.items()),
            'checklist_type_mismatch')
    return rows


def parse_progress(value):
    require(isinstance(value, dict) and isinstance(value.get('items'), list), 'progress_schema')
    items = {}
    for item in value['items']:
        require(isinstance(item, dict) and isinstance(item.get('id'), str), 'progress_item')
        identity = item['id']
        require(identity not in items, 'duplicate_progress_id')
        require(isinstance(item.get('status'), str) and bool(item['status'].strip()),
                'progress_status')
        require(isinstance(item.get('evidence'), list) and all(
            isinstance(x, str) and bool(x.strip()) for x in item['evidence']), 'progress_evidence')
        items[identity] = item
    require(set(items) == set(EXPECTED_TYPES), 'progress_id_set')
    require(all(item.get('type') == EXPECTED_TYPES[identity] for identity, item in items.items()),
            'progress_type_mismatch')
    return items


def aggregates(rows, items):
    counts = {kind: dict(total=total, closed=0, partialProgress=0, noProgressRecorded=0,
                         progressRecorded=0) for kind, total in BASELINE.items()}
    closed = []
    for identity, (kind, checked) in rows.items():
        item = items[identity]
        require(checked or not CLOSED_STATUS.match(item['status'].strip()),
                'unchecked_closed_status')
        if checked:
            closed.append(identity)
            category = 'closed'
        elif item['status'].strip().casefold() != 'open' or item['evidence']:
            category = 'partialProgress'
        else:
            category = 'noProgressRecorded'
        counts[kind][category] += 1
        if category != 'noProgressRecorded':
            counts[kind]['progressRecorded'] += 1
    partial = sum(v['partialProgress'] for v in counts.values())
    no_progress = sum(v['noProgressRecorded'] for v in counts.values())
    recorded = len(closed) + partial
    require(len(closed) + partial + no_progress == 213, 'aggregate_partition')
    return dict(total=213, counts=counts, formalChecked=len(closed), closedRows=closed,
                formallyRemaining=213 - len(closed), partialProgress=partial,
                noProgressRecorded=no_progress, progressRecorded=recorded, statusOpen=no_progress,
                limit=f'{recorded} rows have recorded progress: {len(closed)} closed and '
                      f'{partial} partial; {no_progress} without recorded progress; '
                      f'{213 - len(closed)} formal obligations remain.')


def validate_audit(value):
    require(isinstance(value, dict), 'audit_schema')
    numeric = ('total', 'formalChecked', 'formallyRemaining', 'partialProgress',
               'noProgressRecorded', 'progressRecorded', 'statusOpen')
    require(all(key not in value or (type(value[key]) is int and value[key] >= 0)
                for key in numeric), 'audit_aggregate_type')
    if 'counts' in value:
        require(isinstance(value['counts'], dict) and not (set(value['counts']) - set(BASELINE))
                and all(isinstance(v, dict) for v in value['counts'].values()), 'audit_counts')
        require(all(key not in values or (type(values[key]) is int and values[key] >= 0)
                    for values in value['counts'].values()
                    for key in ('total', 'closed', 'partialProgress', 'noProgressRecorded',
                                'progressRecorded')), 'audit_aggregate_type')
    if 'closedRows' in value:
        rows = value['closedRows']
        require(isinstance(rows, list) and all(isinstance(x, str) for x in rows)
                and len(rows) == len(set(rows)) and not (set(rows) - set(EXPECTED_TYPES)),
                'audit_closed_rows')


def verify_unchanged(inputs):
    require(all(read_input(path) == data for path, data in inputs.items()), 'inputs_changed')


def atomic_refresh(output, value, inputs):
    # Serialize/validate everything before creating an output or replacing anything.
    data = (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode('utf-8')
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(prefix='.completion-audit-', dir=output.parent,
                                         delete=False) as stream:
            temporary = Path(stream.name)
            os.fchmod(stream.fileno(), stat.S_IMODE(output.stat().st_mode))
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        verify_unchanged(inputs)
        os.replace(temporary, output)
        temporary = None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def run(root, write=False):
    require(len(EXPECTED_TYPES) == 213 and all(len(EXPECTED_BY_TYPE[k]) == n
                                             for k, n in BASELINE.items()), 'invalid_frozen_baseline')
    root = Path(root).resolve()
    paths = [root / relative for relative in (CHECKLIST, PROGRESS, OUTPUT)]
    inputs = {path: read_input(path) for path in paths}
    rows = parse_checklist(inputs[paths[0]])
    items = parse_progress(decode_json(inputs[paths[1]]))
    previous = decode_json(inputs[paths[2]])
    validate_audit(previous)
    derived = aggregates(rows, items)
    refreshed = copy.deepcopy(previous)
    for key, value in derived.items():
        if key == 'counts':
            for kind, values in value.items():
                refreshed.setdefault('counts', {}).setdefault(kind, {}).update(values)
        else:
            refreshed[key] = value
    differences = [key for key, value in derived.items()
                   if key != 'counts' and previous.get(key) != value]
    differences += [f'counts.{kind}.{field}' for kind, values in derived['counts'].items()
                    for field, value in values.items()
                    if previous.get('counts', {}).get(kind, {}).get(field) != value]
    matches = not differences
    missing = [key for key in differences if key.startswith('counts.') and
               key.split('.')[2] not in previous.get('counts', {}).get(key.split('.')[1], {})
               or not key.startswith('counts.') and key not in previous]
    if write:
        refreshed['recordedUtc'] = datetime.now(timezone.utc).isoformat()
        atomic_refresh(paths[2], refreshed, inputs)
    else:
        verify_unchanged(inputs)
    return dict(status='valid', written=bool(write), auditMatches=bool(write) or matches,
                previousAggregateDifferences=differences,
                missingAggregateFields=missing,
                mismatchedAggregateFields=[key for key in differences if key not in missing],
                **derived, inputSha256={str(path.relative_to(root)): hashlib.sha256(data).hexdigest()
                                       for path, data in inputs.items()})


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1],
                        help='Project root; also supports isolated test fixtures')
    parser.add_argument('--write', action='store_true',
                        help='Atomically refresh only progress-audit-latest.json aggregates')
    args = parser.parse_args(argv)
    try:
        result = run(args.root, write=args.write)
    except (AuditError, OSError) as error:
        print(json.dumps(dict(status='refused', code=error.code if isinstance(error, AuditError)
                              else 'io_error', written=False), separators=(',', ':')))
        return 2
    print(json.dumps(result, separators=(',', ':')))
    return 0 if args.write or result['auditMatches'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
