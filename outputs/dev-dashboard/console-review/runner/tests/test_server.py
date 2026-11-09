import http.client
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

MODULE = Path(__file__).parents[1] / 'server.py'
spec = importlib.util.spec_from_file_location('dakhl_runner', MODULE)
server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)


def wait_until(predicate, timeout=3):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(.01)
    raise AssertionError('bounded readiness failed')


class RunnerFixture:
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = dict(os.environ, GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull)
        self.engine = self.repo('engine', {'packages/core/lib/a.dart': 'engine', 'tool/check.py': 'tool'})
        self.tools = self.repo('tools', {'tool/dev_benchmarks/benchmark.py': 'tools'})
        self.engine_commit = server.git(self.engine, 'rev-parse', 'HEAD')
        self.app = self.repo('app', {'pubspec.yaml': 'version: 0.0.0+1\n', 'pubspec.lock': 'locked',
            'engine-dependency.json': json.dumps({'git_commit': self.engine_commit}),
            'lib/main.dart': 'app', 'test/a.dart': 'test', 'scripts/check.py': 'script', 'macos/Runner/a.swift': 'native',
            'tool/dev_dashboard/runner.py': 'runner', 'tool/dev_dashboard/operations.json': json.dumps({'operations': [
                {'id': 'app.startup', 'status': 'ready'}, {'id': 'orders.process', 'status': 'planned'}]}),
            'PHASES.md': '| 01 | Shell | BLOCKED |\n| 02 | Accounts | TODO |\n'})
        self.runner = server.Runner(dict(app_root=str(self.app), engine_root=str(self.engine), engine_tools_root=str(self.tools),
            data_dir=str(self.root / 'data'), site_url='https://dashboard.example', port=0))
        self.addCleanup(self.runner.shutdown)

    def repo(self, name, files):
        root = self.root / name
        root.mkdir()
        for relative, text in files.items():
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        subprocess.run(['git', 'init', '-q', str(root)], env=self.env, check=True)
        subprocess.run(['git', '-C', str(root), 'add', '.'], env=self.env, check=True)
        subprocess.run(['git', '-C', str(root), '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                        '-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgsign=false', 'commit', '-qm', 'fixture'], env=self.env, check=True)
        return root

    def job(self):
        return dict(id='run-' + 'a' * 16, status='queued', source=server.source_info(self.app, self.engine, self.tools),
                    commands=[], results=[], startedAt=server.now(), kind='tests', request={'suite': 'app'})



class RunnerTests(RunnerFixture, unittest.TestCase):
    def test_provenance_covers_actual_engine_tools_and_app_tests_scripts_native(self):
        source = server.source_info(self.app, self.engine, self.tools)
        self.assertEqual(source['engineCommit'], self.engine_commit)
        self.assertEqual(source['runtimeEngine']['commit'], self.engine_commit)
        self.assertEqual(source['benchmarkTools']['commit'], server.git(self.tools, 'rev-parse', 'HEAD'))
        for root, relative in ((self.app, 'test/a.dart'), (self.app, 'scripts/check.py'), (self.app, 'macos/Runner/a.swift'),
                               (self.app, 'tool/dev_dashboard/runner.py'), (self.engine, 'packages/core/lib/a.dart'),
                               (self.tools, 'tool/dev_benchmarks/benchmark.py')):
            with self.subTest(relative=relative):
                before = server.source_key(server.source_info(self.app, self.engine, self.tools))
                path = root / relative
                path.write_text(path.read_text() + 'changed')
                self.assertNotEqual(server.source_key(server.source_info(self.app, self.engine, self.tools)), before)
        dependency = self.app / 'engine-dependency.json'
        dependency.write_text(json.dumps({'git_commit': '0' * 40}))
        actual = server.source_info(self.app, self.engine, self.tools)
        self.assertEqual(actual['engineCommit'], self.engine_commit)
        self.assertEqual(actual['declaredEngineCommit'], '0' * 40)

    def test_command_rejects_source_change_after_execution(self):
        job = self.job()
        argv = [sys.executable, '-c', "from pathlib import Path;Path('test/a.dart').write_text('changed during command')"]
        with self.assertRaisesRegex(RuntimeError, 'Source changed'):
            self.runner.command(job, 'mutate own fixture', argv, self.app)
        self.assertEqual(job['commands'], [])

    def test_command_timeout_stops_only_owned_child(self):
        job = self.job()
        with self.assertRaisesRegex(RuntimeError, 'timed out'):
            self.runner.command(job, 'bounded sleep', [sys.executable, '-c', 'import time;time.sleep(30)'], self.app, timeout=.05)
        self.assertEqual(self.runner.processes, {})
        self.assertIsNone(self.runner.active)

    def test_shutdown_joins_non_daemon_job_and_reaps_owned_child(self):
        def execute(job):
            try:
                self.runner.command(job, 'owned sleep', [sys.executable, '-c', 'import time;time.sleep(30)'], self.app)
            except RuntimeError:
                pass
            finally:
                with self.runner.lock:
                    self.runner.active = None
                    self.runner.workers.discard(threading.current_thread())
        with patch.object(self.runner, 'execute', execute):
            self.runner.start({'kind': 'tests', 'suite': 'app'})
        wait_until(lambda: bool(self.runner.processes))
        owned = list(self.runner.processes.values())
        workers = list(self.runner.workers)
        self.assertTrue(all(not worker.daemon for worker in workers))
        self.runner.shutdown()
        self.assertTrue(all(not worker.is_alive() for worker in workers))
        self.assertTrue(all(process.poll() is not None for process in owned))
        with self.assertRaisesRegex(RuntimeError, 'stopping'):
            self.runner.start({'kind': 'tests'})

    def test_shutdown_allows_cooperative_host_to_reap_detached_child(self):
        pid_file = self.root / 'nested.pid'
        helper = self.root / 'cooperative.py'
        helper.write_text("""import os,signal,subprocess,sys,time
child=subprocess.Popen([sys.executable,'-c','import time;time.sleep(30)'],start_new_session=True)
def stop(*_):
    raise SystemExit(143)
signal.signal(signal.SIGTERM,stop)
open(sys.argv[1],'w').write(str(child.pid))
try:
    time.sleep(30)
finally:
    child.terminate()
    child.wait(timeout=3)
""")
        job = self.job()
        errors = []
        def execute():
            try:
                self.runner.command(job, 'cooperative host', [sys.executable, str(helper), str(pid_file)], self.app)
            except RuntimeError as error:
                errors.append(str(error))
        thread = threading.Thread(target=execute, daemon=False)
        self.runner.workers.add(thread)
        thread.start()
        wait_until(pid_file.exists)
        child_pid = int(pid_file.read_text())
        self.runner.shutdown()
        self.assertFalse(thread.is_alive())
        with self.assertRaises(ProcessLookupError):
            os.kill(child_pid, 0)
        self.assertTrue(errors)

    def test_single_flight_and_fixed_app_python_suite(self):
        block = threading.Event()
        with patch.object(self.runner, 'execute', lambda job: block.wait(2)):
            self.runner.start({'kind': 'tests', 'suite': 'app'})
            with self.assertRaisesRegex(RuntimeError, 'already active'):
                self.runner.start({'kind': 'tests', 'suite': 'engine'})
            block.set()
            for worker in list(self.runner.workers):
                worker.join()
        self.runner.active = None
        job = self.job()
        calls = []
        def command(job, label, argv, cwd, **_):
            calls.append((label, argv, cwd))
            job['commands'].append({'passed': 3})
        with patch.object(self.runner, 'command', command):
            self.runner.execute(job)
        self.assertEqual(job['status'], 'passed')
        self.assertTrue(any(argv[-1] == 'tool/dev_dashboard/tests' and cwd == self.app.resolve() for _, argv, cwd in calls))
        with self.assertRaises(ValueError):
            self.runner.start({'kind': 'benchmarks', 'caseIds': ['orders.process']})

    def test_phase_status_sidecar_and_tracker_have_no_permanent_blockers(self):
        snapshot = self.runner.snapshot()
        self.assertEqual(snapshot['phase']['status'], 'blocked')
        self.assertEqual(snapshot['phase']['blockers'], [])
        self.assertEqual(snapshot['lastChecks']['status'], 'not_run')
        server.atomic_json(self.runner.status_file, {'phase': {'id': '02', 'name': 'Accounts', 'status': 'in progress', 'blockers': []},
                                                     'lastChecks': {'status': 'passed', 'passed': 151, 'source': 'dated sidecar'}})
        snapshot = self.runner.snapshot()
        self.assertEqual(snapshot['phase']['id'], '02')
        self.assertEqual(snapshot['lastChecks']['passed'], 151)


class HTTPTests(RunnerFixture, unittest.TestCase):
    def setUp(self):
        super().setUp()
        self.web = self.root / 'web'
        (self.web / 'dist').mkdir(parents=True)
        (self.web / 'dist/index.html').write_text('dashboard')
        (self.web / 'secret.txt').write_text('private')
        (self.web / 'dist/leak.txt').symlink_to(self.web / 'secret.txt')
        self.root_patch = patch.object(server, 'ROOT', self.web)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)
        self.http = server.ThreadingHTTPServer(('127.0.0.1', 0), server.Handler)
        self.http.runner = self.runner
        self.port = self.http.server_address[1]
        self.runner.port = self.port
        self.thread = threading.Thread(target=self.http.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.close_http)

    def close_http(self):
        self.http.shutdown()
        self.http.server_close()
        self.thread.join()

    def request(self, method, path, body=None, headers=None):
        conn = http.client.HTTPConnection('127.0.0.1', self.port, timeout=2)
        values = {'Host': f'127.0.0.1:{self.port}'}
        if headers:
            values.update(headers)
        if body is not None:
            body = json.dumps(body)
            values['Content-Type'] = 'application/json'
        conn.request(method, path, body=body, headers=values)
        response = conn.getresponse()
        payload = response.read()
        status = response.status
        conn.close()
        return status, payload

    def token(self):
        return self.runner.pair(self.runner.pair_code(), self.runner.site_origin)

    def test_http_auth_host_origin_and_preflight(self):
        self.assertEqual(self.request('GET', '/health')[0], 200)
        self.assertEqual(self.request('GET', '/api/status')[0], 401)
        self.assertEqual(self.request('GET', '/health', headers={'Host': 'evil.example'})[0], 403)
        self.assertEqual(self.request('GET', '/health', headers={'Origin': 'https://evil.example'})[0], 403)
        token = self.token()
        valid = {'Origin': self.runner.site_origin, 'Authorization': 'Bearer ' + token}
        self.assertEqual(self.request('GET', '/api/status', headers=valid)[0], 200)
        self.assertEqual(self.request('OPTIONS', '/api/status', headers={'Origin': self.runner.site_origin})[0], 204)
        self.assertEqual(self.request('POST', '/api/runs', {'kind': 'tests'}, {'Authorization': 'Bearer invalid'})[0], 401)

    def test_pairing_is_single_use_origin_bound_and_expiring(self):
        code = self.runner.pair_code()
        headers = {'Origin': self.runner.site_origin}
        status, payload = self.request('POST', '/api/pair', {'code': code}, headers)
        self.assertEqual(status, 200)
        token = json.loads(payload)['token']
        self.assertTrue(self.runner.authorized('Bearer ' + token, self.runner.site_origin))
        self.assertFalse(self.runner.authorized('Bearer ' + token, 'http://localhost:0'))
        self.assertEqual(self.request('POST', '/api/pair', {'code': code}, headers)[0], 401)
        expired = self.runner.pair_code()
        self.runner.pairs[expired] = time.monotonic() - 1
        self.assertEqual(self.request('POST', '/api/pair', {'code': expired}, headers)[0], 401)

    def test_http_single_flight_and_request_allowlist(self):
        token = self.token()
        headers = {'Origin': self.runner.site_origin, 'Authorization': 'Bearer ' + token}
        self.assertEqual(self.request('POST', '/api/runs', {'kind': 'tests', 'command': 'anything'}, headers)[0], 400)
        block = threading.Event()
        try:
            with patch.object(self.runner, 'execute', lambda job: block.wait(2)):
                self.assertEqual(self.request('POST', '/api/runs', {'kind': 'tests', 'suite': 'app'}, headers)[0], 202)
                self.assertEqual(self.request('POST', '/api/runs', {'kind': 'tests', 'suite': 'app'}, headers)[0], 409)
        finally:
            block.set()
            for worker in list(self.runner.workers):
                worker.join()
            self.runner.active = None

    def test_static_paths_cannot_escape_dist(self):
        self.assertEqual(self.request('GET', '/')[1], b'dashboard')
        for path in ('/../secret.txt', '/%2e%2e/secret.txt', '/leak.txt'):
            with self.subTest(path=path):
                status, body = self.request('GET', path)
                self.assertEqual(status, 404)
                self.assertNotIn(b'private', body)


if __name__ == '__main__':
    unittest.main()
