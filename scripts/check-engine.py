#!/usr/bin/env python3
"""Verify the independent engine source matches this consumer's explicit pin."""
import json
from pathlib import Path
import re
import subprocess

app = Path(__file__).resolve().parent.parent
pin = json.loads((app / 'engine-dependency.json').read_text())
engine = app.parent / 'Madar_Engine'
assert engine.is_dir(), 'Check out Madar_Engine beside the app; engine source is not copied here.'
expected = pin['git_commit']
assert re.fullmatch(r'[0-9a-f]{40}', expected), 'Full engine commit SHA required'
actual = subprocess.check_output(['git', '-C', str(engine), 'rev-parse', 'HEAD'], text=True).strip()
assert actual == expected, 'Review the engine upgrade and update engine-dependency.json deliberately.'
status = subprocess.check_output(['git', '-C', str(engine), 'status', '--porcelain', '--',
                                  'packages/application', 'packages/flutter_adapters', 'tool'], text=True)
assert not status, 'Engine source differs from its committed pin; commit/review the engine first.'
for name, package in pin['packages'].items():
    directory = app / package['path']
    manifest = (directory / 'pubspec.yaml').read_text()
    assert re.search(r'^name:\s*' + re.escape(name) + r'\s*$', manifest, re.M)
    assert re.search(r'^version:\s*' + re.escape(package['version']) + r'\s*$', manifest, re.M)
subprocess.run(['dart', 'run', 'tool/verify_boundaries.dart', str(app)], cwd=engine, check=True)
print('Consumer engine commit, versions and source boundaries match.')
