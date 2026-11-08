"""Build-only receipt producer; never launches or installs the normal app."""
from pathlib import Path
import datetime as dt
import hashlib
import importlib.util
import json
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(name, value):
    (OUT / name).write_text(json.dumps(value, indent=2) + '\n')


def main():
    matrix = json.loads((OUT / 'benchmark-matrix-004.json').read_text())['results']
    expected = {v['id'] for v in json.loads((ROOT / 'tool/dev_dashboard/operations.json').read_text())['operations'] if v['status'] == 'ready'}
    assert len(matrix) == len(expected) == 65
    assert {r['operationId'] for r in matrix} == expected
    assert all(r['status'] == 'passed' and r['iterations'] == 20 for r in matrix)
    spec = importlib.util.spec_from_file_location('normal_build_source', ROOT / 'scripts/phase_workflow.py')
    workflow = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(workflow)
    before = workflow.source_inputs(ROOT)
    write('normal-build-source-inputs.json', before)
    receipt = {'startedAt': dt.datetime.now(dt.timezone.utc).isoformat(),
               'engine': json.loads((ROOT / 'engine-dependency.json').read_text()),
               'sourceManifest': 'normal-build-source-inputs.json', 'builds': []}
    commands = [
        ('macos', ['flutter', 'build', 'macos', '--debug', '--no-pub']),
        ('ios-device-unsigned', ['flutter', 'build', 'ios', '--debug', '--no-codesign', '--no-pub']),
        ('android-arm64', ['flutter', 'build', 'apk', '--debug', '--target-platform', 'android-arm64', '--no-pub']),
    ]
    for target, argv in commands:
        log = OUT / ('normal-' + target + '-build-001.log')
        assert not log.exists(), 'Never silently repeat a build attempt.'
        started = time.monotonic()
        with log.open('x') as stream:
            result = subprocess.run(argv, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
        row = {'target': target, 'command': argv, 'exitCode': result.returncode,
               'elapsedSeconds': time.monotonic() - started, 'log': log.name}
        receipt['builds'].append(row)
        write('normal-builds-final.json', receipt)
        print(json.dumps(row), flush=True)
        if result.returncode:
            raise SystemExit(result.returncode)
    after = workflow.source_inputs(ROOT)
    receipt['sourceUnchanged'] = before == after
    receipt['sourceChangedPaths'] = sorted(k for k in before.keys() | after.keys() if before.get(k) != after.get(k))
    receipt['finishedAt'] = dt.datetime.now(dt.timezone.utc).isoformat()
    write('normal-builds-final.json', receipt)
    assert before == after, 'Build mutated a selected source input.'


if __name__ == '__main__':
    main()
