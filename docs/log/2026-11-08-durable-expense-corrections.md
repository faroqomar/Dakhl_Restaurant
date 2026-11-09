# Isolated durable operating-expense correction foundation

Date: 2026-11-08. Status: local targeted verification passed; independent aggregate review pending. Runtime/UI activation and Completion row closure remain separate.

The owner accepted correction examples A-D/F under ADR0021. This slice follows [the isolated contract](../phases/completion-durable-expense-correction-contract.md). Section E financial changes without an eligible original remain blocked.

## Ownership and scope

Dakhl_Restaurant owns operating-expense commands, source projection and receipt-backed history reconciliation. Madar owns balanced journals, durable coordination and the one-store persistence contract. Engine runtime/API changes: N/A. The app consumes reviewed `ac8b4edc2c915ed22c0991685c33967b3360e7fa` / application `0.1.0-dev.5`; no engine, dependency or pin edits belong to this worker.

The new source remains unimported by the active native target. No UI, live account, schema activation, migration, tracker, merge, remote delivery or release change follows.

## Preparation and attempts

- Read current rules/plans/trackers/prompts and relevant ownership/financial documents in both projects. Separate current-turn `project-daftar` and `project-madar` Hindsight recalls succeeded. No raw source data or private account records entered memory.
- Confirmed new command/history/test/output paths absent, then retained the storage baseline in `outputs/completion-review/durable-expense-corrections/preflight.json`. Free disk: 96,930,232 KiB. Hidden `.git`: 18,430,636 KiB. Native campaign retains the sole Flutter/build/device window.
- Wrote specification/unit tests before the command/history implementation. Deferred the red runner because the active native campaign owns shared Flutter artifacts. Source order alone did not establish a red executed test; actual failed attempts and repairs follow below.
- Added immutable raw canonical command identity using the public bounded snapshot helper. Added original-date inverse/replacement/source before/after envelopes and complete root/correction receipt reconstruction. The narrow create-expense matcher delegates historical replay to that verified chain; invoice/payment/sales matchers retain their behavior.
- First specific Dart analysis failed: five test-only API assumptions (`isAccepted` and receipt `toJson`) and two unused imports, three redundant null assertions and required brace lints. Read the actual public API, corrected tests/imports/assertions and applied scoped brace fixes. Follow-up specific analysis passed. This was agent-caused avoidable preparation overhead; inspect shared API signatures before drafting tests.
- Prepared a synthetic Node oracle that extracts and executes actual frozen renderer expense edit and confirm-delete bodies, plus the actual source helper bodies. The harness substitutes only UI/save boundaries and calls the actual source model. Exact model/renderer/body hashes and spans accompany each oracle result. The later PowerSync differential test executed these bodies and compared complete source maps.
- Prepared real PowerSync precommit rollback, genuine committed lost-acknowledgement/reopen, stale authority, changed intent, foreign-store, complete-map parity and historical replay tests. The later targeted conformance run verified these scenarios in real isolated PowerSync stores.

Start/end per preparation batch, token/cost accounting and clock gaps are unknown for this worker. Tool reports retain measured command durations; no invented benchmark or hidden reasoning record is included. Parent owns the campaign timer and shared execution journal.

## Verification and limits

Final specific Dart analysis passed for commands/history, the narrow create matcher and all three new test files. The renderer differential covers cash, shared and explicit zero daily funding, category/note/date changes, then delete. No Flutter/test/build/pub command ran before the native owner released its window.

Required next work: independent aggregate review against the exact source/result manifest; parent memory sync/check. Per-operation performance remains PENDING; unit-test elapsed is not a benchmark. Memory sync/check belongs to the parent batch.

## Storage

Preparation recheck: free 95,529,368 KiB, task output directory 8 KiB. Host free space decreased by 1,400,864 KiB while native/other work continued; producer attribution remains unknown. This is below the 2 GiB unexpected-growth threshold and free space exceeds 10 GiB. No cleanup target was confirmed. Final closeout follows below.

## Executed runner window

The native owner released the shared compiler at 07:48:20 UTC and the controller authorized the six-file targeted host run. The worker used `flutter test --no-pub` and retained expanded logs. No pub, build, native or full-accounting run occurred.

1. Attempt 1: 73 passed / 31 failed. All 72 existing spending command/conformance/safety cases passed. The new shared fixture tried mutating the immutable root from `AccountDocument.toJson`; the worker retained its exact failing source and copied the root with `Map.from` before editing fixture data. This was an avoidable test-author mistake.
2. Attempt 2, three new files only: 28 passed / 4 failed. All six real PowerSync conformance cases passed, including the actual renderer differential, edit/delete precommit faults, committed lost ACK/reopen, competing corrections and authority/changed-intent/foreign-host rejection. Four adversarial tests expected family-level rejection after constructing states that the existing portable constructor already rejects. The worker retained the two exact pre-fix test files, asserted typed earlier rejection for forbidden forks/inverse-of-inverse, renumbered the missing-root receipt fixture to reach the family reconciler, and checked a foreign root before its inverse exists. No guard or production code was relaxed.
3. Attempt 3, repaired unit/safety files only: all 26 passed. All 32 new cases and 72 existing spending regressions therefore pass across the retained bounded runs: **104 unique relevant cases**. Runtime command/history/create-matcher hashes stayed unchanged across all three runs. The worker released the shared runner window before documentation and storage closeout.

The three new test files form the specification/regression suite. The first source helper mistake and the earlier API signature mistakes belong in the controller-owned repeated-problem catalog. Avoidability: inspect immutable/public APIs before drafting fixtures; account for earlier validation layers in adversarial tests. Acceptance checks for an automation candidate: a fixture helper must return a mutable detached root, and negative-state helpers must identify whether portable decoding or family reconciliation rejects the case.

The actual precommit seam throws at `transaction.before_commit` inside the PowerSync adapter. These tests establish exact byte/revision rollback for that seam, retry/replay and fresh owner reopening. They do not establish SIGKILL or arbitrary physical power-loss behavior. The lost-ACK wrapper first obtains success from the actual store, then returns commit-unknown and blocks reads until resolution; one write, one revision and replay/reopen assertions prevent a false pending-read-only claim.

## Final source and storage receipts

Canonical current evidence: `outputs/completion-review/durable-expense-corrections/review-inputs.json`, `focused-result.json`, `final-analysis.log` and `storage-closeout.json`. Earlier attempt logs and exact pre-fix test snapshots remain unique failure evidence. The prepared manifest preserves the pre-execution state.

Final storage sample: free 92,924,424 KiB; `.git` unchanged at 18,430,636 KiB; no Git temporary object store and no remaining task temporary directory. New accounting source/tests total delta is 84 KiB; task evidence measured 136 KiB before final small receipts. Reclaimed: 0 bytes. No confirmed obsolete task artifact remained. Shared `.dart_tool` 810,892 KiB and `build` 1,973,988 KiB remain under the active controller's ownership; prior native/restart evidence remains retained.

Host free space decreased 4,005,808 KiB during concurrent work. Exact per-producer delta is unknown because this worker did not capture shared-cache baselines. A bounded inspection located current shared macOS/iOS builds, compiler/hook caches and CoreSimulator data; it does not prove their growth caused the full delta. The worker stopped sustained storage-producing work and informed the controller when the difference exceeded 2 GiB. Free space remains above 10 GiB. No uncertain cleanup, Git pruning or account deletion occurred. Parent should reconcile host-level campaign baselines before the next large batch.

No design/UI/live activation/row closure/merge/release approval follows from these results. Independent review and per-operation benchmark acceptance remain pending.
