# C1 isolated native acceptance harness

Date: 2026-11-07. Actor: Codex C1 worker. Status: harness implemented and analyzed; native execution blocked. Independent review and checklist closure remain with the Lead.

The Lead assigned a bounded C1 catalog/inventory pilot against synthetic persistence. C1's 15 pairs and five pattern proposals have [owner approval](../phases/c1-design-approval.md). This task does not cover C4, financial activation, merge or release. Live screen-reader verification remains owner-excluded, without a passed label.

## Ownership and current authority

- App: acceptance composition, UI interactions, synthetic fixture lifecycle and receipts. New source: [c1_catalog_native_test.dart](../../integration_test/c1_catalog_native_test.dart).
- Madar implementation/API/design: N/A. The harness consumes the existing document/workspace and preferences adapters at reviewed runtime `d316fd6076375daa3f412889f73eaebfeeb5d4d4`; it delegates shared persistence and stock validation. No package, pin or runtime source changed.
- Development ledger: reviewed `f7f68988561d25cc93eb28c0ec989847526b2df9`, workflow SHA-256 `3ccabda58f24cac7fb0f3c915870af62d77785fc4e95459fd5938e2a3d26b808`. [Madar contract](../../../Madar_Engine/tool/dev_workflow/README.md).
- Both projects' standing workflow, plans, trackers and prompts informed scope. Current source, C1 approval and the explicit Lead assignment override older tracker snapshots. Current-turn project-daftar recall returned the C1 approval and incomplete-native boundaries; separate project-madar recall confirmed campaign provenance and consumer ownership. [Scoped Madar recall receipt](../../outputs/completion-review/c1-native/madar-recall.json).

## Harness behavior

The retained integration test mounts the actual app on its inventory route. It reuses `integration_test/support/native_app_readiness.dart` after inspecting `lib/platform/ui_qa_main.dart`; both compositions allocate temporary storage and omit file-import/export capability. The new test needs access to its repository for assertions and fault injection, so it owns a fresh temporary root rather than invoking the interactive QA main. It never invokes normal main or default/native account-location factories.

The test drives visible product creation, reference-photo selection, opening stock, product editing, photo removal, history locks, dated restock and signed adjustment. It asserts rejection of an earlier reversal that would produce a later negative balance, input retention and an unchanged durable snapshot. It then records a valid inverse, preserves the original entry, checks the reference/date/delta and verifies chronological history. Further assertions cover a stale visible edit and a synthetic lost acknowledgement after a real durable commit, duplicate-write blocking and authoritative readback. The final fresh-owner SQLite reopen checks the exact persisted payload in the same process.

Lost acknowledgement is a test transport injection, not an observed OS crash. Same-process close/reopen does not establish process-restart acceptance. The test keeps actual target viewport metrics. It has bounded UI waits and deletes only its allocated root after unmounting and closing its owners.

## Executed checks and blocks

Final `dart analyze integration_test/c1_catalog_native_test.dart` exited 0 with `No issues found!`; final formatter reported no changes. [Verification receipt](../../outputs/completion-review/c1-native/verification.json) binds the source hash. No native test, build, launch, screenshot, matrix or benchmark ran. Existing independently reviewed widget/source evidence remains unchanged.

One current-runtime T3 `device_list({})` call returned no output during the bounded observation. Tool waits exposed at least 32 seconds pending; total discovery duration includes intervening independent work and remains unknown. The worker terminated the waiting exec cell. No tool error or recovery advice arrived, and no device IDs, `device_open`, bound agent-device command or `device_screenshot` became available. The worker stopped dependent device work.

The original ledger initialized, then its preflight returned `workflow-refused`. Read-only diagnosis found shell `python3` resolves to micromamba Python 3.9.23; importing the native guard fails on `Path | None`. The tool requires Python 3.10+. [Exact diagnostic](../../outputs/completion-review/c1-native/python39-preflight-diagnosis.json). The worker retained the original ledger and used the existing Python 3.13 interpreter for a distinct corrected campaign. A later check found the original source fingerprint stale only for the concurrent F09 test; the worker preserved that history.

The [corrected consumer preflight](../../outputs/completion-review/c1-native/corrected-preflight/preflight-attempt-1.json) records `device-evidence-required`, exit 1. Its immutable attempt chain contains one failed preflight and no pilot attempt. `unselected-ios-candidate` explicitly denotes an unselected candidate, not an observed target. [Plan](../../outputs/completion-review/c1-native/corrected-preflight/plan.json), [state](../../outputs/completion-review/c1-native/corrected-preflight/state.json) and command receipts preserve exact app, engine, tool, fixture and input identity. The worker cleaned the two tiny preflight fixture directories after their checks and retained one canonical descriptor plus cleanup receipts. A future native campaign needs fresh live device evidence and fixture state; this blocked campaign grants no authority to launch.

The separate [engine pin checker](../../outputs/completion-review/c1-native/engine-pin-check.json) exited 1: `Engine source differs from its committed pin; commit/review the engine first.` Current uncommitted collation tooling remains a global source hold despite the unchanged reviewed runtime packages. The worker did not bypass the checker, change a pin or infer that the device failure was the only remaining preflight obligation.

## Attempts, timing and prevention

Initial skills/authority/memory/storage reads preceded timer startup; that interval remains unknown. Several combined document/source reads exceeded output budgets and required focused slices. One source lookup guessed an absent `dated_stock.dart`; bounded discovery corrected it without mutation. Initial analyzer output identified two unused imports and a brace lint; the worker fixed them and reran the narrow analyzer. These are agent-caused overhead, not product failures.

The [persistent timer](../../outputs/completion-review/c1-native/timing.json) covers its recorded segment only. Parallel worker time, tool latency, non-wait wall time and active effort are different; no token/cost or whole-task effort figure is available. The Lead received the Python interpreter and non-returning device findings for the shared prevention catalog. Future automation should validate the interpreter version before ledger initialization and expose a bounded Device discovery timeout. Required source checks and native observations remain separate from harness analysis.

## Storage closeout

Initial free disk: 112,059,852 KiB. Initial app `.git`: 18,422,536 KiB; build: 639,928 KiB. Final measured free disk: 112,007,856 KiB; app: 27,085,808 KiB; `.git`: 18,422,716 KiB; build: 623,536 KiB; `.dart_tool`: 204,860 KiB; this task's output folder: 156 KiB before writing the closeout receipt. Both projects had zero `tmp_objdir-*` stores at final inspection. Disk remained above 10 GiB. The worker did not attribute concurrent free-space/cache changes to this task.

The worker retained the new acceptance source, compact ledger/diagnostic receipts and timer as canonical evidence. It created no native binary, export, archive or screenshot. It removed only its two preflight fixture directories after no process held them. Required shared caches, source, account data, designs and recovery evidence remain intact. The [storage receipt](../../outputs/completion-review/c1-native/storage-closeout.json) records measured values and retention reasons. No unexplained task-owned growth exceeded 2 GiB.

Next: independent source review; then a fresh representative Device pilot after discovery and source delivery/preflight holds clear. The Lead owns aggregate journal, checklist and separate project-memory synchronization. No checklist row or phase closes through this worker report.
