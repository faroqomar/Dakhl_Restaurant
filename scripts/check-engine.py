#!/usr/bin/env python3
"""Verify the independent engine source matches this consumer's explicit pin."""
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urljoin, urlsplit


def require(condition, message):
    if not condition:
        raise ValueError(message)


def scalar(value):
    """Read the simple scalars used by pub's lockfile/path declarations."""
    if value.startswith('"'):
        return json.loads(value)
    if value.startswith("'") and value.endswith("'"):
        return value[1:-1].replace("''", "'")
    require(not value.startswith(('{', '[', '*', '&', '!', '|', '>')),
            'Use explicit block mappings for engine dependency declarations.')
    return re.sub(r'\s+#.*$', '', value).rstrip()


def mapping_section(path, section):
    """Fail closed on unsupported YAML rather than misread a source override.

    Only dependency/lock mapping sections are needed; Flutter asset lists and
    other unrelated pubspec fields are deliberately outside this reader.
    """
    result = {}
    stack = [(-1, result)]
    active = False
    seen = False
    saw_top_level = False
    for line in path.read_text().splitlines():
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        if not line[0].isspace():
            match = re.fullmatch(r'''("(?:[^"\\]|\\.)*"|'(?:[^']|'')*'|[A-Za-z0-9_-]+):(?:\s+(.*))?''', line)
            require(match is not None, f'Unsupported top-level YAML mapping in {path.name}: {line}')
            key, value = match.groups()
            key = scalar(key)
            saw_top_level = True
            active = key == section
            if active:
                require(not seen, f'Duplicate {section} in {path.name}')
                seen = True
                require(not scalar((value or '').strip()),
                        f'Use an explicit {section} block mapping in {path.name}.')
            continue
        require(saw_top_level, f'Unsupported indented top-level YAML mapping in {path.name}')
        if not active:
            continue
        require('\t' not in line, f'Unsupported indentation in {path.name}')
        indent = len(line) - len(line.lstrip())
        match = re.fullmatch(r'\s*([A-Za-z0-9_-]+):(?:\s+(.*))?', line)
        require(match is not None, f'Unsupported {section} mapping in {path.name}: {line.strip()}')
        key, value = match.groups()
        while stack[-1][0] >= indent:
            stack.pop()
        parent = stack[-1][1]
        require(key not in parent, f'Duplicate {key} in {path.name}')
        value = scalar((value or '').strip())
        parent[key] = value if value else {}
        if isinstance(parent[key], dict):
            stack.append((indent, parent[key]))
    return result if seen else None


def local_uri(value, base, label):
    require(isinstance(value, str), f'{label} must be a local URI.')
    uri = urlsplit(urljoin(base, value))
    require(uri.scheme == 'file' and not uri.netloc and not uri.query and not uri.fragment,
            f'{label} must resolve to a local file URI.')
    return Path(unquote(uri.path)).resolve()


def verify_resolution(app, engine, pin):
    remedy = 'Run flutter pub get --enforce-lockfile, then rerun scripts/check-engine.py.'
    config_file = app / '.dart_tool/package_config.json'
    require(config_file.is_file(), f'Missing package resolution. {remedy}')
    config = json.loads(config_file.read_text())
    require(config.get('configVersion') == 2 and isinstance(config.get('packages'), list),
            f'Unsupported package resolution. {remedy}')
    require(isinstance(pin.get('packages'), dict) and pin['packages'],
            'At least one explicit engine package pin is required.')
    require(all(isinstance(entry, dict) for entry in config['packages']),
            f'Malformed package resolution. {remedy}')
    resolved_madar = {entry.get('name') for entry in config['packages']
                      if isinstance(entry.get('name'), str) and entry['name'].startswith('madar_')}
    require(resolved_madar == set(pin['packages']),
            f'Resolved Madar packages must match the explicit engine pins. {remedy}')
    require((app / 'pubspec.lock').is_file(), f'Missing pubspec.lock. {remedy}')
    locked = mapping_section(app / 'pubspec.lock', 'packages')
    declared = mapping_section(app / 'pubspec.yaml', 'dependencies') or {}
    development = mapping_section(app / 'pubspec.yaml', 'dev_dependencies') or {}
    overrides = mapping_section(app / 'pubspec.yaml', 'dependency_overrides') or {}
    overrides_file = app / 'pubspec_overrides.yaml'
    if overrides_file.is_file():
        # Pubspec overrides replace the manifest's entire overrides section.
        file_overrides = mapping_section(overrides_file, 'dependency_overrides')
        if file_overrides is not None:
            overrides = file_overrides
    for name, package in pin['packages'].items():
        directory = (app / package['path']).resolve()
        require(directory.is_relative_to(engine.resolve()),
                f'{name} pin points outside the checked Madar_Engine source.')
        tracked = subprocess.run(['git', '-C', str(engine), 'ls-files', '--error-unmatch', '--',
                                  str(directory.relative_to(engine.resolve()) / 'pubspec.yaml')],
                                 capture_output=True, text=True)
        require(tracked.returncode == 0, f'{name} is not tracked in the pinned engine checkout.')
        entries = [entry for entry in config['packages'] if entry.get('name') == name]
        require(len(entries) == 1, f'{name} must occur once in package resolution. {remedy}')
        entry = entries[0]
        root = local_uri(entry.get('rootUri'), config_file.as_uri(), f'{name} rootUri')
        require(root == directory, f'{name} resolved to {root}, expected {directory}. {remedy}')
        library = local_uri(entry.get('packageUri'), root.as_uri() + '/', f'{name} packageUri')
        require(library == (directory / 'lib').resolve(),
                f'{name} packageUri redirects imports away from its pinned lib directory. {remedy}')
        require(directory.is_dir() and library.is_dir(), f'{name} resolved source is missing. {remedy}')
        declaration = overrides.get(name, declared.get(name))
        require(name not in development, f'{name} must have one production dependency declaration. {remedy}')
        require(isinstance(declaration, dict) and set(declaration) == {'path'} and
                isinstance(declaration['path'], str) and
                (app / declaration['path']).resolve() == directory,
                f'{name} current dependency/override differs from its pinned source. {remedy}')
        lock = (locked or {}).get(name, {})
        description = lock.get('description', {})
        require(lock.get('source') == 'path' and lock.get('version') == package['version'] and
                isinstance(description, dict) and isinstance(description.get('path'), str) and
                description.get('relative') == ('false' if Path(description['path']).is_absolute() else 'true') and
                (app / description['path']).resolve() == directory,
                f'{name} pubspec.lock differs from its pinned source/version. {remedy}')

app = Path(__file__).resolve().parent.parent
pin = json.loads((app / 'engine-dependency.json').read_text())
engine = app.parent / 'Madar_Engine'
require(engine.is_dir(), 'Check out Madar_Engine beside the app; engine source is not copied here.')
expected = pin['git_commit']
require(re.fullmatch(r'[0-9a-f]{40}', expected), 'Full engine commit SHA required')
actual = subprocess.check_output(['git', '-C', str(engine), 'rev-parse', 'HEAD'], text=True).strip()
require(actual == expected, 'Review the engine upgrade and update engine-dependency.json deliberately.')
status = subprocess.check_output(['git', '-C', str(engine), 'status', '--porcelain', '--',
                                  'packages', 'tool'], text=True)
require(not status, 'Engine source differs from its committed pin; commit/review the engine first.')
try:
    verify_resolution(app, engine, pin)
except (ValueError, OSError, KeyError, TypeError) as error:
    sys.exit(f'Engine resolution check failed: {error}')
for name, package in pin['packages'].items():
    directory = app / package['path']
    manifest = (directory / 'pubspec.yaml').read_text()
    require(re.search(r'^name:\s*' + re.escape(name) + r'\s*$', manifest, re.M),
            f'{name} manifest name differs from its pin.')
    require(re.search(r'^version:\s*' + re.escape(package['version']) + r'\s*$', manifest, re.M),
            f'{name} manifest version differs from its pin.')
subprocess.run(['dart', 'run', 'tool/verify_boundaries.dart', str(app)], cwd=engine, check=True)
print('Consumer engine commit, resolved sources, versions and source boundaries match.')
