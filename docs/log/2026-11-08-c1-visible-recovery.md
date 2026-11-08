# C1 visible unknown-save and readback acceptance

Status: implementation and host verification complete for independent review; native execution and C1-14 closure pending. Local date: 2026-11-08. Task intake UTC start and active effort are unknown; the parent Completion execution journal owns the campaign timer. Runtime public pin remains `d316fd6076375daa3f412889f73eaebfeeb5d4d4`.

## Objective and ownership

Advance C1-14 with visible product-form save, uncertainty, retained input, duplicate-save refusal, and existing account readback controls. [C1 design approval](../phases/c1-design-approval.md) covers the 15 named pairs and five pattern reuses. This task introduces no recovery policy, financial production change, shared foundation, schema activation or native acceptance claim.

Madar implementation/API/design: N/A. Existing Madar PowerSync/SQLite storage, pending-write resolution and public document/workspace contracts remain authoritative. Dakhl owns presentation, modal guards and shell composition. The worker owns the new acceptance test and native harness stage only; root owns `lib/app/app.dart` and any shell-status repair. No source changes to catalog form/controller/ViewModel have been necessary.

Task-relevant project-daftar and project-madar Hindsight recalls succeeded separately. Current rules, trackers, C1 approval and source controlled the decisions. The worker reviewed the applicable project-local Flutter testing/accessibility guidance; live screen-reader verification remains owner-excluded.

## Implemented acceptance coverage

[test/catalog/c1_visible_recovery_workflow_test.dart](../../test/catalog/c1_visible_recovery_workflow_test.dart) mounts the actual app shell and catalog modal against a new temporary SQLite-backed PowerSync document/workspace store per test. Only shell preferences use a memory fixture. The test-only transport wrapper injects outcomes at the store boundary; it delegates successful storage and reconciliation to the actual store. No normal application entry point, real account path, file import/export, network service or native target runs.

The host cases exercise committed acknowledgement loss and uncertain precommit failure through the existing settings readback control, plus the existing shell retry control after the root-owned repair. They assert retained name/photo, unchanged acknowledged document/snapshot, unknown-write fencing, no second dispatch/token, dirty cancel/continue/discard, actual resolve/read calls, no recovery write, exact submitted product/opening identity, rendered inventory result and close/reopen payload/fence/revision/token. A genuinely failed precommit operation retains its draft and retries through the visible form button. Unknown precommit readback must report stale authority and leave the acknowledged empty catalog intact.

[integration_test/c1_catalog_native_test.dart](../../integration_test/c1_catalog_native_test.dart) now contains visible product edit/save/error/duplicate-save/dirty-discard/settings/readback/return controls where its former stage called catalog/repository methods directly. The historical dates, stock kinds, cutoff assertions, isolated setup and cleanup remain intact. Analyzer success establishes source validity only; native execution remains pending.

## Attempts and evidence

Canonical outputs: [c1-visible-recovery](../../outputs/completion-review/c1-visible-recovery/).

- Attempt01: reached the filled form and stalled when a host fake-async tap dispatched real SQLite I/O. The worker terminated its own process. Partial output retained; no passing claim.
- Attempt02: stage diagnostics confirmed successful actual-store setup, shell mount and field entry. A configured 40-second test timeout did not resolve the stalled host async boundary. The worker terminated its own process. Partial output retained.
- Attempt03: dispatching the visible gesture through `tester.runAsync` allowed store completion and the whole visible recovery path. The fresh-owner assertion then failed because `DocumentSnapshot` uses instance identity; the test now compares payload, fence, revision and write token.
- Attempt04: all three initial visible workflow cases passed (7 seconds reported by test runner). This version preceded the requested shell-status regression and additional shell-button case.
- Attempt05-shell-red: reproduced a product integration gap. After an unknown catalog write and guarded modal discard, `AccountsViewModel.state` remained saved and the shell omitted the pending-confirmation status. `repository.hasUnknownWrite` remained true. The new visible status assertion failed at the missing Arabic pending-confirmation message. Root owns the bounded shell change; existing settings readback remains the correct mechanism.
- Attempt06-scoped: all 29 scoped tests passed, including four new real-store visible cases and the existing photo authority/controller, product dialog and catalog ViewModel suites (10 seconds reported by runner). Both shell and settings readback paths execute existing reconciliation.
- Analyze02: both changed test sources and root-owned app composition passed `flutter analyze --no-pub`, no issues (6.4 seconds).
- Analyze01: `flutter analyze --no-pub` on both changed test sources passed, no issues (5.8 seconds reported by analyzer).

No native discovery/build/execution occurred; parent preflight/device evidence limitations remain open. The worker ran no benchmarks or Git/pin/version mutations. Tests do not prove OS crash/power-loss behavior, native controls, fresh-process restart or design/release approval.

## Storage review

Baseline observed available: 113,867,368 KiB; `.git`: 18,422,716 KiB; `build`: 623,604 KiB. Interim available: 111,155,640 KiB; `.git`: 18,423,252 KiB; `build`: 623,708 KiB; this task's evidence: 24 KiB. The host free-space decrease exceeded 2 GiB while these project areas grew about 640 KiB. The worker paused further test-producing batches and reported the unaccounted concurrent/host growth to the parent; producer remains unverified at this checkpoint.

Two synthetic SQLite roots from terminated attempts occupied 260 KiB each. `lsof +D` showed no open files and no owned Flutter tester remained. The worker deleted only those exact task-owned temporary paths and verified absence, reclaiming 520 KiB. Successful/failing completed tests unmount the app, dispose account owners, close SQLite and remove their own temporary root. Retain failed-attempt logs and new regression source. Preserve existing Git recovery stores and concurrent artifacts.

## Prevention handoff

The root-owned repeated-problems record should include: host widget gestures that initiate real SQLite I/O need `tester.runAsync`; fake-async gesture dispatch can stall after valid setup and bypass the practical configured timeout. Bound the first case, retain attempts, inspect progress, terminate only the owned tester, and remove only closed task-owned fixtures. Snapshot reopen assertions must compare public snapshot fields rather than object identity. Combined large authority reads exceeded tool output limits; prefer bounded relevant source slices and never count truncated output as full review.

## Final storage and review handoff

Final observed available: 109,453,556 KiB; `.git`: 18,423,252 KiB; `build`: 623,704 KiB; evidence allocation before final receipt/log edits: 32 KiB. No active `.git/objects/tmp_objdir-*` stores and no remaining task fixture directories. `.git` grew 536 KiB, build grew 100 KiB. Two deleted closed synthetic fixtures reclaimed 520 KiB; retained logs remain small and serve independent review.

The parent measured the app below its earlier size, expected engine growth of about 80 MiB, zero Git temporary stores and over 104 GiB free. The parent authorized bounded continuation after the worker confirmed old writers exited and removed its known fixture roots. The wider volume decrease remains unattributed; no causal claim or unsafe cleanup follows from it.

Root repaired the existing shell status/error/retry conditions using `needsWriteReadback` and the existing `reconcile` action. The red status regression, four visible acceptance cases and affected regressions now pass. [Receipt](../../outputs/completion-review/c1-visible-recovery/receipt.json) freezes source hashes, commands, attempts, actual outcomes and storage evidence. The parent must synchronize the sanitized milestone alongside its current Completion documentation batch; this worker makes no completed-memory-delivery claim.

Independent review, native execution, and C1-14 closure remain open. This worker cannot approve or close the row. No required account safeguards, catalog authority/controller behavior, historical movement expectations or public engine contracts changed.
