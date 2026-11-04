#!/usr/bin/env python3
"""Dakhl consumer for Madar's source-bound development campaign ledger.

Coordinates evidence, not installation, device input, publication or approval.
"""
import argparse
import fcntl
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

REVISION = re.compile(r'[0-9a-f]{40}')
DIGEST = re.compile(r'[0-9a-f]{64}')
SOURCE_DIRS = ('lib', 'test', 'integration_test', 'assets', 'android', 'ios',
               'macos', 'linux', 'windows', 'web', 'scripts', 'tool/dev_dashboard')
SOURCE_FILES = ('.fvmrc', 'pubspec.yaml', 'pubspec.lock', 'engine-dependency.json',
                'dev-tooling-dependency.json')
REQUIRED = ('engine-dependency.json', 'scripts/android_install_guard.py',
            'scripts/phase_preflight.py', 'scripts/phase_workflow.py',
            'integration_test/support/native_picker_wait.dart',
            'integration_test/support/native_app_readiness.dart')


class WorkflowError(ValueError):
    """Safe bounded consumer failure code."""


def read_bytes(path, limit=4 * 1024 * 1024):
    path = Path(path)
    if path.is_symlink() or not path.is_file() or path.stat().st_size > limit:
        raise WorkflowError('unsafe-input')
    return path.read_bytes()


def read_json(path):
    try:
        return json.loads(read_bytes(path))
    except (OSError, ValueError, TypeError):
        raise WorkflowError('invalid-json-input') from None


def git(root, *args):
    try:
        result = subprocess.run(['git', '-C', str(root), *args], capture_output=True,
                                timeout=10, check=False)
    except (OSError, subprocess.TimeoutExpired):
        raise WorkflowError('git-unavailable') from None
    if result.returncode:
        raise WorkflowError('git-query-failed')
    return result.stdout


def load_tools(root, tools_root):
    """Load only bytes matching the committed, hash-pinned tool revision."""
    root, tools_root = Path(root), Path(tools_root).resolve()
    pin = read_json(root / 'dev-tooling-dependency.json')
    revision, digest = pin.get('git_commit'), pin.get('workflow_sha256')
    if (not isinstance(revision, str) or not REVISION.fullmatch(revision)
            or not isinstance(digest, str) or not DIGEST.fullmatch(digest)):
        raise WorkflowError('invalid-tool-pin')
    relative = 'tool/dev_workflow/workflow.py'
    path = tools_root / relative
    data = read_bytes(path)
    committed = git(tools_root, 'show', f'{revision}:{relative}')
    if data != committed or hashlib.sha256(data).hexdigest() != digest:
        raise WorkflowError('tool-source-mismatch')
    # Compile the checked bytes, avoiding a second file read/import race.
    import types
    module = types.ModuleType('madar_dev_workflow')
    module.__file__ = str(path)
    sys.modules[module.__name__] = module
    exec(compile(data, str(path), 'exec'), module.__dict__)
    if getattr(module, 'API_VERSION', None) != 1:
        raise WorkflowError('unsupported-tool-api')
    return module, revision


def source_inputs(root):
    root = Path(root).resolve()
    for relative in REQUIRED:
        if not (root / relative).is_file():
            raise WorkflowError('missing-required-input')
    names = git(root, 'ls-files', '--cached', '--others', '--exclude-standard', '-z',
                '--', *SOURCE_DIRS, *SOURCE_FILES).decode().split('\0')
    paths = {name for name in names if name
             and '__pycache__' not in Path(name).parts
             and Path(name).suffix not in ('.pyc', '.pyo')}
    paths.update(p for p in SOURCE_FILES if (root / p).exists())
    for name in paths:
        cursor = root
        for part in Path(name).parts:
            cursor = cursor / part
            if cursor.is_symlink():
                raise WorkflowError('unsafe-input')
    return {name: hashlib.sha256(read_bytes(root / name, 64 * 1024 * 1024)).hexdigest()
            for name in sorted(paths)}


def prepare_plan(root, tools_root, spec):
    root = Path(root).resolve()
    module, tool_revision = load_tools(root, tools_root)
    runtime = read_json(root / 'engine-dependency.json').get('git_commit')
    if not isinstance(runtime, str) or not REVISION.fullmatch(runtime):
        raise WorkflowError('invalid-runtime-pin')
    plan = {
        'schemaVersion': 1, 'campaignId': spec['campaignId'],
        'consumerId': 'Dakhl_Restaurant',
        'sourceRevision': git(root, 'rev-parse', 'HEAD').decode().strip(),
        'engineRevision': runtime, 'toolRevision': tool_revision,
        'targetId': spec['targetId'], 'fixtureId': spec['fixtureId'],
        'context': spec.get('context', {'platform': spec.get('platform', 'host')}),
        'inputs': source_inputs(root), 'stages': spec['stages'],
    }
    if plan['context'] not in ({'platform': p} for p in ('host', 'android', 'ios', 'macos')):
        raise WorkflowError('invalid-platform')
    module.validate_plan(plan)
    return plan


def validate_consumer_plan(root, tools_root, plan):
    current = prepare_plan(root, tools_root, plan)
    if current != plan:
        raise WorkflowError('consumer-context-mismatch')
    return load_tools(root, tools_root)[0]


def write_json(path, value, *, exclusive=False):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    data = (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()
    if path.is_symlink():
        raise WorkflowError('unsafe-output')
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
            temporary = Path(stream.name)
            os.fchmod(stream.fileno(), 0o600)
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        if exclusive:
            os.link(temporary, path)
        else:
            os.replace(temporary, path)
            temporary = None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('init', 'preflight', 'record', 'next', 'summary'))
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--engine-tools-root', type=Path, required=True)
    parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--state', type=Path, required=True)
    parser.add_argument('--spec', type=Path)
    parser.add_argument('--receipt', type=Path)
    parser.add_argument('--retry', type=Path)
    parser.add_argument('--evidence-output', type=Path)
    args = parser.parse_args(argv)
    lock = None
    module = None
    preflight = None
    try:
        root = args.root.resolve()
        args.state.parent.mkdir(parents=True, exist_ok=True)
        lock_path = args.state.with_name(args.state.name + '.lock')
        lock = os.open(lock_path, os.O_WRONLY | os.O_CREAT | os.O_NOFOLLOW, 0o600)
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise WorkflowError('campaign-busy') from None
        if args.action == 'init':
            if not args.spec or args.plan.exists() or args.state.exists():
                raise WorkflowError('fresh-plan-and-state-required')
            plan = prepare_plan(root, args.engine_tools_root, read_json(args.spec))
            module = validate_consumer_plan(root, args.engine_tools_root, plan)
            state = module.create_campaign(plan, root)
            write_json(args.plan, plan, exclusive=True)
            write_json(args.state, state, exclusive=True)
            result = module.summarize(state, plan, root)
        else:
            plan, state = read_json(args.plan), read_json(args.state)
            module = validate_consumer_plan(root, args.engine_tools_root, plan)
            if args.action == 'record':
                receipt = read_json(args.receipt) if args.receipt else None
                if receipt is None:
                    raise WorkflowError('receipt-required')
                # A preflight PASS must come from the composed preflight path.
                stage = next((s for s in plan['stages'] if s['id'] == receipt.get('stageId')), None)
                if stage and stage['kind'] == 'preflight':
                    raise WorkflowError('use-preflight-action')
                state = module.record_attempt(state, plan, root, receipt,
                                              retry=read_json(args.retry) if args.retry else None)
                write_json(args.state, state)
                result = module.summarize(state, plan, root)
            elif args.action == 'preflight':
                if not args.spec or not args.evidence_output:
                    raise WorkflowError('preflight-spec-and-output-required')
                pending_id = module.summarize(state, plan, root)['nextStage']
                stage = next((item for item in plan['stages'] if item['id'] == pending_id), None)
                if not stage or stage['kind'] != 'preflight':
                    raise WorkflowError('preflight-not-next')
                preflight_spec = importlib.util.spec_from_file_location('phase_preflight', root / 'scripts/phase_preflight.py')
                preflight = importlib.util.module_from_spec(preflight_spec)
                sys.modules[preflight_spec.name] = preflight
                preflight_spec.loader.exec_module(preflight)
                spec = read_json(args.spec)
                expected = {'appRevision': plan['sourceRevision'],
                            'runtimeRevision': plan['engineRevision'],
                            'targetId': plan['targetId'], 'fixtureId': plan['fixtureId'],
                            'platform': plan['context']['platform']}
                if any(key in spec and spec[key] != value for key, value in expected.items()):
                    raise WorkflowError('preflight-context-mismatch')
                spec.update(expected)
                retry = read_json(args.retry) if args.retry else None
                module.validate_attempt(state, plan, root, stage['id'], retry=retry)
                failure = None
                try:
                    evidence = preflight.run_preflight(spec, root)
                except preflight.PreflightError as error:
                    failure = error.code
                    evidence = dict(expected, status='preflight-failed', failureCode=failure)
                if failure is None and (evidence.get('status') != 'preflight-passed' or any(
                        evidence.get(key) != value for key, value in expected.items())):
                    raise WorkflowError('preflight-context-mismatch')
                # Record only after hashing the current complete source set again.
                validate_consumer_plan(root, args.engine_tools_root, plan)
                write_json(args.evidence_output, evidence, exclusive=True)
                relative = args.evidence_output.resolve().relative_to(root).as_posix()
                receipt = {'stageId': stage['id'], 'status': 'failed' if failure else 'passed',
                           'cleanupConfirmed': True, 'identity': state['identity'],
                           'evidence': [{'path': relative, 'sha256': hashlib.sha256(read_bytes(args.evidence_output)).hexdigest()}]}
                state = module.record_attempt(state, plan, root, receipt, retry=retry)
                write_json(args.state, state)
                result = module.summarize(state, plan, root)
                if failure:
                    print(json.dumps(result, sort_keys=True))
                    return 1
            elif args.action == 'next':
                result = {'next': module.next_stage(state, plan, root)}
            else:
                result = module.summarize(state, plan, root)
        print(json.dumps(result, sort_keys=True))
        return 0
    except Exception as error:
        safe_types = (WorkflowError,)
        for owner in (module, preflight):
            if owner is not None:
                candidate = getattr(owner, 'WorkflowError', getattr(owner, 'PreflightError', None))
                if isinstance(candidate, type):
                    safe_types += (candidate,)
        code = str(error) if isinstance(error, safe_types) else 'workflow-refused'
        if not re.fullmatch(r'[a-z][a-z0-9-]{0,63}', code):
            code = 'workflow-refused'
        print(json.dumps({'status': 'refused', 'code': code}))
        return 2
    finally:
        if lock is not None:
            os.close(lock)


if __name__ == '__main__':
    raise SystemExit(main())
