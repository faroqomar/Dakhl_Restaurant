"""Loopback-only, capability-authenticated Dakhl development runner."""
from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import secrets
import signal
import subprocess
import sys
import threading
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]


def now():
    return datetime.now(timezone.utc).isoformat()


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n")
    temporary.replace(path)


def git(root, *args):
    result = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, timeout=10)
    return result.stdout.strip() if result.returncode == 0 else "unavailable"


def repository_info(root):
    """Fingerprint allowlisted source, tests and build/tool configuration only."""
    root = Path(root).resolve()
    prefixes = {"lib", "assets", "test", "tests", "integration_test", "scripts",
                "tool", "packages", "macos", "ios", "android", "windows", "linux", ".github"}
    names = {"pubspec.yaml", "pubspec.lock", "engine-dependency.json", "analysis_options.yaml",
             "melos.yaml", "package.json", "package-lock.json", "pyproject.toml", "pubspec_overrides.yaml"}
    listing = subprocess.run(["git", "-C", str(root), "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                             capture_output=True, timeout=10, check=True).stdout
    digest = hashlib.sha256()
    for relative in sorted(set(os.fsdecode(value) for value in listing.split(b"\0") if value) | {name for name in names if (root / name).is_file()}):
        parts = Path(relative).parts
        if not parts or (parts[0] not in prefixes and relative not in names):
            continue
        if any(part in {"Pods", "ephemeral", "xcuserdata", "__pycache__", ".symlinks", "build", ".dart_tool"} for part in parts):
            continue
        path = root / relative
        if path.is_file():
            digest.update(relative.encode() + b"\0" + path.read_bytes() + b"\0")
        else:
            digest.update(relative.encode() + b"\0missing\0")
    return {"commit": git(root, "rev-parse", "HEAD"),
            "dirty": bool(git(root, "status", "--porcelain")), "sourceFingerprint": digest.hexdigest()}


def source_info(app, engine=None, engine_tools=None):
    app = Path(app)
    pubspec = (app / "pubspec.yaml").read_text()
    version = re.search(r"^version:\s*(\S+)", pubspec, re.M).group(1)
    dependency = json.loads((app / "engine-dependency.json").read_text())
    actual_engine = repository_info(engine or app.parent / "Madar_Engine")
    tools = repository_info(engine_tools or engine or app.parent / "Madar_Engine")
    return dict(repository_info(app), name="Dakhl_Restaurant", version=version,
                engineCommit=actual_engine["commit"], declaredEngineCommit=dependency["git_commit"],
                runtimeEngine=actual_engine, benchmarkTools=tools)


def source_key(source):
    # Dirty flags include unrelated documentation/output; source bytes and exact
    # revisions determine whether an execution still describes its start source.
    return tuple((source[key]["commit"], source[key]["sourceFingerprint"])
                 for key in ("runtimeEngine", "benchmarkTools")) + ((source["commit"], source["sourceFingerprint"]),)


class Runner:
    def __init__(self, config):
        self.config = config
        self.app = Path(config["app_root"]).resolve()
        self.engine = Path(config["engine_root"]).resolve()
        self.engine_tools = Path(config["engine_tools_root"]).resolve()
        self.data = Path(config.get("data_dir", ROOT / "var")).resolve()
        self.data.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.site_origin = config["site_url"].rstrip("/")
        parsed = urlsplit(self.site_origin)
        if parsed.scheme != "https" or parsed.path or parsed.query or parsed.fragment:
            raise ValueError("site_url must be the exact HTTPS Site origin")
        self.port = int(config.get("port", 18763))
        self.origins = {self.site_origin, f"http://127.0.0.1:{self.port}", f"http://localhost:{self.port}"}
        self.lock = threading.Lock()
        self.tokens = {}
        self.pairs = {}
        self.active = None
        self.stopping = threading.Event()
        self.processes = {}
        self.workers = set()
        self.jobs = {}
        self._source_cache = (0, None)
        self.status_file = Path(config.get("status_file", self.data / "status.json"))
        for path in sorted((self.data / "runs").glob("run-*.json")):
            try:
                job = json.loads(path.read_text())
                if job["status"] in {"queued", "running"}:
                    job.update(status="interrupted", finishedAt=now(), error="Runner restarted before completion.")
                    atomic_json(path, job)
                self.jobs[job["id"]] = job
            except (ValueError, KeyError):
                continue

    def pair_code(self):
        code = secrets.token_urlsafe(24)
        with self.lock:
            self.pairs = {k: v for k, v in self.pairs.items() if v > time.monotonic()}
            self.pairs[code] = time.monotonic() + 180
        return code

    def pair(self, code, origin):
        if not isinstance(code, str) or len(code) > 128:
            return None
        with self.lock:
            candidate = next((key for key in self.pairs if hmac.compare_digest(code, key)), None)
            if not candidate or self.pairs.pop(candidate) <= time.monotonic():
                return None
            token = secrets.token_urlsafe(32)
            self.tokens[token] = (time.monotonic() + 8 * 3600, origin)
            return token

    def authorized(self, authorization, origin):
        if not authorization.startswith("Bearer "):
            return False
        token = authorization[7:]
        with self.lock:
            record = self.tokens.get(token)
        return bool(record and record[0] > time.monotonic() and (not origin or record[1] == origin))

    def operations(self):
        path = self.app / "tool/dev_dashboard/operations.json"
        if not path.exists():
            return []
        parsed = json.loads(path.read_text())
        values = parsed if isinstance(parsed, list) else parsed.get("operations", parsed.get("cases", []))
        output = []
        for value in values:
            item = dict(value)
            item["id"] = item.get("id", item.get("operationId"))
            item["label"] = item.get("label", item["id"])
            item.setdefault("status", "planned")
            output.append(item)
        return output

    def snapshot(self):
        if time.monotonic() - self._source_cache[0] > 8:
            self._source_cache = (time.monotonic(), source_info(self.app, self.engine, self.engine_tools))
        project = self._source_cache[1]
        phases = []
        for line in (self.app / "PHASES.md").read_text().splitlines():
            if re.match(r"\| \d{2} \|", line):
                cells = [v.strip() for v in line.split("|")[1:-1]]
                name = re.sub(r"\[([^]]+)\]\([^)]*\)", r"\1", cells[1])
                phases.append({"id": cells[0], "name": name, "status": cells[2].split(" — ")[0].lower()})
        active_phases = [value for value in phases if value["status"] not in {"todo", "done"}]
        phase = dict((active_phases or phases or [{"id": None, "name": "Not recorded", "status": "unknown"}])[-1], blockers=[])
        checks = {"status": "not_run", "passed": None, "source": "No current local execution recorded"}
        if self.status_file.is_file():
            scoped = json.loads(self.status_file.read_text())
            if isinstance(scoped.get("phase"), dict):
                phase.update(scoped["phase"])
            if isinstance(scoped.get("lastChecks"), dict):
                checks = scoped["lastChecks"]
        with self.lock:
            runs = sorted(self.jobs.values(), key=lambda v: v["startedAt"], reverse=True)
            runs = json.loads(json.dumps(runs))
            active = self.active
        latest_tests = next((v for v in runs if v["kind"] == "tests" and v["status"] in {"passed", "failed"}), None)
        if latest_tests:
            checks = {"status": latest_tests["status"], "passed": latest_tests.get("counts", {}).get("passed"), "recordedAt": latest_tests.get("finishedAt"), "sourceCommit": latest_tests["source"]["commit"], "source": "Local runner", "runId": latest_tests["id"]}
        baseline_path = self.data / "baselines.json"
        baselines = json.loads(baseline_path.read_text()) if baseline_path.exists() else {}
        operations = self.operations()
        for operation in operations:
            results = [(run, result) for run in runs if run.get("status") == "passed" for result in run.get("results", []) if result.get("operationId") == operation["id"] and result.get("status") == "passed"]
            if results:
                run, result = results[0]
                operation["latest"] = dict(result, runId=run["id"])
                chosen = baselines.get(operation["id"])
                comparable = result.get("comparabilityKey")
                baseline = next(((rr, v) for rr, v in results if (not chosen or rr["id"] == chosen) and v.get("comparabilityKey") == comparable), None) if chosen else next(((rr, v) for rr, v in reversed(results) if v.get("comparabilityKey") == comparable), None)
                if baseline:
                    operation["baseline"] = dict(baseline[1], runId=baseline[0]["id"])
        versions = [{"version": project["version"], "commit": project["commit"], "status": "working tree" if project["dirty"] else "unreleased", "date": None}]
        for run in runs:
            version = run.get("source", {})
            if version and not any(v["version"] == version["version"] and v["commit"] == version["commit"] for v in versions):
                versions.append({"version": version["version"], "commit": version["commit"], "status": "measured source", "date": run["startedAt"]})
        return {"schemaVersion": 1, "project": project, "phase": phase, "phases": phases, "lastChecks": checks,
                "operations": operations, "runs": runs[:30], "versions": versions, "runner": {"online": True, "busy": bool(active), "activeRunId": active}, "generatedAt": now()}

    def start(self, request):
        kind = request.get("kind")
        if kind == "tests":
            if set(request) - {"kind", "suite"} or request.get("suite", "all") not in {"all", "app", "engine"}:
                raise ValueError("Choose App, Engine or All tests.")
        elif kind == "benchmarks":
            if set(request) - {"kind", "caseIds"}:
                raise ValueError("Unsupported benchmark request.")
            ready = {v["id"] for v in self.operations() if v.get("status") == "ready"}
            chosen = request.get("caseIds") or sorted(ready)
            if not isinstance(chosen, list) or not chosen or any(not isinstance(v, str) or v not in ready for v in chosen) or len(set(chosen)) != len(chosen):
                raise ValueError("Only implemented benchmark operations can run.")
            request = dict(request, caseIds=chosen)
        else:
            raise ValueError("Only tests and benchmarks are supported.")
        with self.lock:
            if self.stopping.is_set():
                raise RuntimeError("The runner is stopping.")
            if self.active:
                raise RuntimeError("A run is already active. Wait for it to finish.")
            run_id = "run-" + secrets.token_hex(8)
            job = {"id": run_id, "kind": kind, "status": "queued", "startedAt": now(), "finishedAt": None,
                   "request": request, "source": source_info(self.app, self.engine, self.engine_tools), "results": [], "summary": "Waiting to start", "counts": {}, "commands": []}
            self.jobs[run_id] = job
            self.active = run_id
            self.save(job)
            worker = threading.Thread(target=self.execute, args=(job,), daemon=False)
            self.workers.add(worker)
            worker.start()
        return run_id

    def save(self, job):
        atomic_json(self.data / "runs" / (job["id"] + ".json"), job)

    def verify_source(self, job):
        if source_key(source_info(self.app, self.engine, self.engine_tools)) != source_key(job["source"]):
            raise RuntimeError("Source changed during this run; results cannot be claimed for its starting revision.")

    @staticmethod
    def stop_process(process):
        # Cooperative SIGTERM lets the generic benchmark host clean its own
        # separately sessioned native children before this CLI is forced down.
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=8)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)
        # Reap a command that exited before its own same-group descendants.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass

    def shutdown(self):
        self.stopping.set()
        with self.lock:
            processes = list(self.processes.values())
        for process in processes:
            self.stop_process(process)
        with self.lock:
            workers = list(self.workers)
        for worker in workers:
            if worker is not threading.current_thread():
                worker.join(timeout=15)
        if any(worker.is_alive() for worker in workers):
            raise RuntimeError("Owned job did not stop cleanly.")

    def command(self, job, label, argv, cwd, timeout=1200):
        self.verify_source(job)
        if self.stopping.is_set():
            raise RuntimeError("Runner stopped before command execution.")
        directory = self.data / "logs" / job["id"]
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / (str(len(job["commands"])) + ".log")
        job.update(status="running", summary=label)
        self.save(job)
        started = time.monotonic()
        with path.open("w") as log:
            with self.lock:
                if self.stopping.is_set():
                    raise RuntimeError("Runner stopped before process creation.")
                process = subprocess.Popen(argv, cwd=cwd, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                self.processes[process.pid] = process
            try:
                code = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                self.stop_process(process)
                raise RuntimeError(label + " timed out; only its owned processes were stopped.")
            finally:
                if process.poll() is None:
                    self.stop_process(process)
                with self.lock:
                    self.processes.pop(process.pid, None)
        if self.stopping.is_set():
            raise RuntimeError("Runner stopped; owned command interrupted.")
        self.verify_source(job)
        text = path.read_text(errors="replace")
        count = re.findall(r"\+(\d+): All tests passed", text)
        python_count = re.findall(r"Ran (\d+) tests?", text)
        passed = int(count[-1]) if count and code == 0 else (int(python_count[-1]) if python_count and code == 0 else None)
        item = {"label": label, "exitCode": code, "elapsedSeconds": round(time.monotonic() - started, 2), "passed": passed}
        job["commands"].append(item)
        self.save(job)
        if code:
            raise RuntimeError(label + " failed. Its local evidence is retained.")
        return passed

    def execute(self, job):
        try:
            if job["kind"] == "tests":
                suite = job["request"].get("suite", "all")
                commands = []
                if suite in {"all", "app"}:
                    commands += [("Verify engine source", [sys.executable, "scripts/check-engine.py"], self.app),
                                 ("App source and version regressions", [sys.executable, "-m", "unittest", "discover", "-s", "scripts/tests"], self.app),
                                 ("Validate app version", [sys.executable, "scripts/release_version.py", "check"], self.app),
                                 ("App regression tests", ["flutter", "test", "--no-pub"], self.app),
                                 ("App benchmark runner tests", [sys.executable, "-m", "unittest", "discover", "-s", "tool/dev_dashboard/tests"], self.app)]
                if suite in {"all", "engine"}:
                    commands += [("Engine application tests", ["dart", "test"], self.engine / "packages/application"),
                                 ("Engine storage tests", ["dart", "test"], self.engine / "packages/data"),
                                 ("Engine native adapter tests", ["flutter", "test", "--no-pub"], self.engine / "packages/flutter_adapters"),
                                 ("Benchmark foundation tests", [sys.executable, "-m", "unittest", "discover", "-s", "tool/dev_benchmarks/tests"], self.engine_tools)]
                for label, argv, cwd in commands:
                    self.command(job, label, argv, cwd)
                counts = [v["passed"] for v in job["commands"] if v["passed"] is not None]
                job["counts"] = {"passed": sum(counts) if counts else None, "failed": 0}
            else:
                for case_id in job["request"]["caseIds"]:
                    output = self.data / "results" / (job["id"] + "-" + case_id + ".json")
                    output.parent.mkdir(parents=True, exist_ok=True)
                    argv = [sys.executable, "tool/dev_dashboard/run_benchmarks.py", "--engine-tools-root", str(self.engine_tools), "--case", case_id, "--output", str(output)]
                    self.command(job, "Measure " + case_id, argv, self.app, timeout=1800)
                    value = json.loads(output.read_text())
                    values = value if isinstance(value, list) else value.get("results", [value])
                    if not values or any(v.get("status") != "passed" or v.get("operationId") != case_id for v in values):
                        raise RuntimeError("Benchmark did not return a successful matching operation result.")
                    job["results"].extend(values)
                    self.save(job)
            self.verify_source(job)
            if self.stopping.is_set():
                raise RuntimeError("Runner stopped before completion.")
            job.update(status="passed", summary="All selected checks passed" if job["kind"] == "tests" else "Measurements complete")
        except Exception as error:
            job.update(status="interrupted" if self.stopping.is_set() else "failed", error=str(error)[:300], summary="Run did not complete")
        finally:
            job["finishedAt"] = now()
            self.save(job)
            with self.lock:
                self.active = None
                self.workers.discard(threading.current_thread())

    def baseline(self, request):
        if set(request) != {"operationId", "runId"}:
            raise ValueError("Choose a successful measured result.")
        job = self.jobs.get(request["runId"])
        if not job or job["status"] != "passed" or not any(v.get("operationId") == request["operationId"] and v.get("status") == "passed" for v in job.get("results", [])):
            raise ValueError("Only successful measured results can become baselines.")
        path = self.data / "baselines.json"
        with self.lock:
            values = json.loads(path.read_text()) if path.exists() else {}
            values[request["operationId"]] = request["runId"]
            atomic_json(path, values)


class Handler(BaseHTTPRequestHandler):
    server_version = "DakhlRunner/1"

    @property
    def runner(self):
        return self.server.runner

    def log_message(self, *_):
        # Request paths, pairing codes and authorization headers never enter logs.
        return

    def safe_request(self):
        expected = {f"127.0.0.1:{self.runner.port}", f"localhost:{self.runner.port}"}
        return self.headers.get("Host") in expected and (not self.headers.get("Origin") or self.headers["Origin"] in self.runner.origins)

    def reply(self, status, value, content_type="application/json"):
        body = json.dumps(value).encode() if content_type == "application/json" else value
        self.send_response(status)
        origin = self.headers.get("Origin")
        if origin in self.runner.origins:
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Security-Policy", "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self' http://127.0.0.1:* http://localhost:*; frame-ancestors 'none'")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        if not self.safe_request():
            return self.reply(403, {"error": "Origin or host rejected."})
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", self.headers.get("Origin", ""))
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type")
        self.send_header("Access-Control-Allow-Private-Network", "true")
        self.send_header("Vary", "Origin")
        self.end_headers()

    def do_GET(self):
        if not self.safe_request():
            return self.reply(403, {"error": "Origin or host rejected."})
        path = urlsplit(self.path).path
        if path == "/health":
            return self.reply(200, {"ok": True, "service": "Dakhl local runner", "schemaVersion": 1})
        if path == "/connect":
            code = self.runner.pair_code()
            bridge = f"http://127.0.0.1:{self.runner.port}"
            template = (ROOT / "runner/connect.html").read_text()
            values = {"site": self.runner.site_origin, "bridge": bridge, "code": code}
            return self.reply(200, template.replace("/*CONNECTION*/{}", json.dumps(values)).encode(), "text/html; charset=utf-8")
        if path.startswith("/api/"):
            if not self.runner.authorized(self.headers.get("Authorization", ""), self.headers.get("Origin")):
                return self.reply(401, {"error": "Connect this Mac before running or reading checks."})
            if path == "/api/status":
                return self.reply(200, self.runner.snapshot())
            match = re.fullmatch(r"/api/runs/(run-[0-9a-f]{16})", path)
            if match and match[1] in self.runner.jobs:
                return self.reply(200, self.runner.jobs[match[1]])
            return self.reply(404, {"error": "Unknown operation."})
        relative = unquote(path).lstrip("/") or "index.html"
        candidate = (ROOT / "dist" / relative).resolve()
        if not candidate.is_relative_to((ROOT / "dist").resolve()) or not candidate.is_file():
            return self.reply(404, {"error": "Not found."})
        import mimetypes
        return self.reply(200, candidate.read_bytes(), mimetypes.guess_type(candidate.name)[0] or "application/octet-stream")

    def do_POST(self):
        if not self.safe_request():
            return self.reply(403, {"error": "Origin or host rejected."})
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > 4096 or self.headers.get("Content-Type", "").split(";")[0] != "application/json":
                return self.reply(415, {"error": "A small JSON request is required."})
            body = json.loads(self.rfile.read(length))
            if not isinstance(body, dict):
                raise ValueError("Request must be an object.")
            path = urlsplit(self.path).path
            if path == "/api/pair":
                token = self.runner.pair(body.get("code"), self.headers.get("Origin"))
                return self.reply(200, {"token": token}) if token else self.reply(401, {"error": "Connection code expired. Open Connect this Mac again."})
            if not self.runner.authorized(self.headers.get("Authorization", ""), self.headers.get("Origin")):
                return self.reply(401, {"error": "Connect this Mac first."})
            if path == "/api/runs":
                return self.reply(202, {"runId": self.runner.start(body)})
            if path == "/api/baseline":
                self.runner.baseline(body)
                return self.reply(200, {"ok": True})
            return self.reply(404, {"error": "Unknown operation."})
        except (ValueError, TypeError, KeyError):
            return self.reply(400, {"error": "Invalid request or unavailable measured result."})
        except RuntimeError as error:
            return self.reply(409, {"error": str(error)})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default=str(ROOT / "runner-config.json"))
    args = parser.parse_args()
    runner = Runner(json.loads(Path(args.config).read_text()))
    server = ThreadingHTTPServer(("127.0.0.1", runner.port), Handler)
    server.runner = runner
    print(f"Dakhl local runner: http://127.0.0.1:{runner.port}/connect", flush=True)
    print("Bound to this Mac only. Commands are allowlisted; project data requires pairing.", flush=True)
    def stop(_signum, _frame):
        if runner.stopping.is_set():
            return
        runner.stopping.set()
        # serve_forever must be interrupted from its owning main thread, while
        # finally performs cooperative child cleanup and joins non-daemon jobs.
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        try:
            runner.shutdown()
        finally:
            server.server_close()


if __name__ == "__main__":
    main()
