# Dakhl Development

A private, minimal development console: **Progress**, **Checks**, **Performance**.

[Open the private Site](https://dakhl-development-dashboard.eros-6.chatgpt.site). To execute checks, double-click **Start Dashboard.command** on this Mac, then choose **Open private dashboard**. Keep that Terminal window open; closing/stopping it ends the local runner and stops its owned work. If the browser cannot connect from the Site, choose **Open local dashboard** for the same interface on this Mac. No global service is installed.

## Local setup

Requires Python 3.10+, Flutter/Dart from the app's declared SDK, the app dependency setup, and the existing macOS development toolchain for profile benchmarks. There are no frontend dependencies. Copy `runner-config.example.json` to ignored `runner-config.json` and replace the three checkout paths. Runtime engine must match the app's `engine-dependency.json`; generic benchmark tools are maintained separately in Madar. Keep port 18763 and exact Site origin.

Run manually: `python3 runner/server.py --config runner-config.json`. Open `http://127.0.0.1:18763/connect` and choose the dashboard. Pairing uses a single-use three-minute code; the eight-hour bearer stays in this browser session. Re-pair after runner restart/session expiry. Never expose the runner through a public tunnel or reverse proxy.

## How it works

- Progress reads the actual app `PHASES.md`. Optional ignored `var/status.json` adds current scoped blockers and dated historical check evidence; update/remove that sidecar when those gates change. It never changes phase authority.
- Checks launches App, Engine or All allowlisted suites. App includes engine-source validation, source/version regressions, version format, Flutter regression tests and app benchmark-runner regressions. Engine includes application, storage, Flutter-adapter and generic benchmark-tool tests. These are local test suites; a passing run is not hosted CI, signing, release acceptance, or phase approval.
- Performance launches only implemented operations in the app registry. Each result records timing p50/p95, sampled process RAM and CPU, app version/source and dirty fingerprint, actual runtime/tool source identities, hardware, OS, mode and workload. Baselines compare only compatible conditions. CPU may exceed 100% across cores. No performance budget has been invented.
- Results, logs and baseline choices persist in ignored `var/`. A restart preserves completed history and marks unfinished work interrupted. Jobs are single flight. Source mutation during a run fails that run. Closing the runner stops only its owned processes; do not run a second Flutter build in the same checkout.
- The hosted snapshot is sanitized, dated evidence. It cannot execute anything without a paired local runner. Future orders/catalog/sales operations stay planned until real approved workflows exist. Fixtures use temporary app-specific storage, never restaurant records.

## Contract and security

Bind: 127.0.0.1 only. Exact Host/Origin checks; no arbitrary shell, command, path or checkout selection through the API. `/health` is anonymous. `/connect` creates a code; `/api/pair` exchanges it once for an origin-bound session. Authenticated routes: `GET /api/status`, `GET /api/runs/{id}`, `POST /api/runs` (`tests` + allowlisted `suite`, or `benchmarks` + ready `caseIds`), `POST /api/baseline` (`operationId`, successful `runId`). JSON API schema is 1. Requests are bounded; raw logs stay on this Mac and request secrets never enter logs. Local credentials/config/results are ignored by Git and never included in the deployed snapshot.

Madar owns `tool/dev_benchmarks` measurement/protocol/resource collection. Dakhl owns scenario registry, real ViewModel/persistence/render fixtures and build cache. This project owns the console, pairing and allowlisted orchestration. No runtime engine source is copied here.

## Checks and hosting

`node --test site/tests/ui-contract.test.mjs`

`python3 -m unittest discover -s runner/tests -v`

Buildless static output is `dist/`; `.openai/hosting.json` preserves the existing Site identity. Publish through the Sites source workflow, keeping repository credentials in process stdin. Only this standalone developer-console source belongs in that Site repository. Never upload the restaurant app checkout, account files, local runner configuration, logs or pairing credentials.

Future app release/version procedure: `docs/how-to/versioning-and-performance.md` in the app checkout. This dashboard provides no push, tag or merge button. Owner approval and independent review remain separate gates.
