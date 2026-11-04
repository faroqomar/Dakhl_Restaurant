# Development campaign evidence

Use `scripts/phase_workflow.py` for new native/benchmark verification campaigns. It imports the reviewed, committed and SHA-256-pinned tool in Madar through an explicit `--engine-tools-root`. Runtime packages remain at `engine-dependency.json`; `dev-tooling-dependency.json` pins only development tooling. Never copy the engine implementation into this app.

The ledger coordinates external execution and evidence. It does not launch applications, install APKs, control devices, run test commands or publish. Native UI uses Device tools. Existing `scripts/android_install_guard.py` remains the sole guarded Android fixture installation path; preflight invokes it with `execute=False`. Never substitute a mobile `flutter test` installer or rely on `--no-uninstall` for preservation.

## Setup and identity

Python 3.10+ on macOS/Linux, Git, a checkout containing the pinned Madar tool commit and standard library only. Plans bind app HEAD plus hashes of tracked and non-ignored untracked source/build-input files, runtime engine pin, independent tool revision, platform, exact target and synthetic fixture SHA-256. Generated ignored outputs do not change source identity. Source symlinks refuse; changed source requires a new campaign. The wrapper rechecks actual current inputs before recording or resuming.

Keep one writable campaign state per owner, under `outputs/`; state mutations use an exclusive sibling lock. Keep each attempt's evidence at a new path. Summary validates all previous evidence hashes, stage order, complete plan identity and cleanup. Changing a source, target, platform, fixture, tool, stage order or retry bound cannot silently reuse old receipts. These are trusted-local integrity checks, not protection from a hostile user rewriting an entire plan/ledger.

## Campaign

Prepare a small JSON spec with `campaignId`, `platform` (`host`, `android`, `ios`, `macos`), `targetId`, `fixtureId` (the SHA-256 of the synthetic fixture file), and ordered `stages`. At least one preflight and one representative pilot precede cases. Stage fields are `id`, `kind` (`preflight`, `pilot`, `case`) and optional `maxAttempts` (1–5, default2). `context.platform` in generated plans retains the platform identity.

```sh
python3 scripts/phase_workflow.py init --engine-tools-root /path/to/Madar_Engine --spec outputs/campaign-spec.json --plan outputs/plan.json --state outputs/state.json
python3 scripts/phase_workflow.py preflight --engine-tools-root /path/to/Madar_Engine --spec outputs/preflight-spec.json --evidence-output outputs/preflight-attempt1.json --plan outputs/plan.json --state outputs/state.json
python3 scripts/phase_workflow.py next --engine-tools-root /path/to/Madar_Engine --plan outputs/plan.json --state outputs/state.json
```

The preflight spec follows [task-preflight.md](task-preflight.md). The wrapper supplies app/runtime revision, platform, target and fixture identity from the plan; any explicitly supplied conflicting value refuses. Synthetic fixtures require the exact marker, isolated root and bounded regular payload described there. Mobile preflight requires a recent hash-bound observation for the exact Device session; that is operator observation, not automatic proof of live control. Android also requires the existing guard's successful actual preflight. Supply delivery configuration when publication is in campaign scope; observed permissions/scopes cannot prove that a future push will succeed. Read access checks never mutate credentials.

Execute the returned pilot using the authorized platform tools. Store its actual producer result, assertions and cleanup evidence. Prepare an engine-format receipt with `stageId`, `status`, `cleanupConfirmed`, the complete `identity` from state and hashed root-relative `evidence` paths. Status/cleanup are producer attestations checked against evidence integrity; the ledger does not infer native success from a process exit or screenshot.

```sh
python3 scripts/phase_workflow.py record --engine-tools-root /path/to/Madar_Engine --receipt outputs/pilot-attempt1.json --plan outputs/plan.json --state outputs/state.json
python3 scripts/phase_workflow.py summary --engine-tools-root /path/to/Madar_Engine --plan outputs/plan.json --state outputs/state.json
```

Direct preflight receipts refuse; use the composed `preflight` action. A preflight failure writes a safe immutable artifact and records a failed attempt. A failed/unavailable result or unconfirmed cleanup blocks further stages. An explicit retry needs a new artifact path and `--retry outputs/retry.json` containing `priorAttemptId`, an identifier describing the bounded `hypothesis`, and new hashed `changeEvidence`. Retry authorization is validated before preflight runs. Preserve failures. Source changes require a new plan; old successful evidence stays at its original provenance.

Continue existing authorized stages with one campaign owner and no extra approval pause between them. `ready_for_review` means all recorded stages passed their declared checks; it does not approve the design, merge, release or phase completion. Request aggregate independent review, then focused re-review for later source fixes.

## Persistent timing and handoff

Start the engine timer before substantive task work, using a persistent exec session with stdin kept open:

```sh
python3 /path/to/Madar_Engine/tool/dev_workflow/workflow.py timer --output /absolute/task-timing.json --interval 1
```

Send JSON lines `{"action":"pause","category":"service"}`, `{"action":"resume"}` and `{"action":"stop"}` through that same session. Heartbeats, UTC, monotonic measurements, non-wait intervals and categorized waits belong to one process. Missed heartbeats or divergent clocks create unknown intervals. EOF/SIGINT/SIGTERM record interruption. A timer process lost without a final receipt leaves its final heartbeat as incomplete coverage; never infer elapsed active effort. `activeEffortSeconds` stays null.

Use the generated summary as the compact handoff and link evidence rather than duplicate raw logs in both projects. Keep separate bank/source ownership. Preserve unknown lifecycle variance, historical data loss and incomplete native acceptance as explicit limits.

## Verification and errors

```sh
MADAR_WORKFLOW_TOOLS_ROOT=/path/to/Madar_Engine python3 -m unittest discover -s scripts/tests -v
```

The actual engine/consumer composition tests run a marked synthetic host fixture and a fake isolated Git history; no device or production account is used. Existing guard tests remain intact. CLI returns0 for successful evidence operations,1 for a recorded failed preflight,2 for refusal. Fixed safe error codes exclude raw source, fixture payloads, credentials and subprocess output. Local test success is separate from hosted CI or native acceptance.
