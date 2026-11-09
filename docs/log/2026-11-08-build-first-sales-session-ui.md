# Build-first sales session and approved core UI

Date: 2026-11-08. Status: implementation candidate with small checks; full tests, benchmarks, independent review and native acceptance deferred by owner request.

## App/engine contract

App owns new `SalesWorkflowSession`, the private portable-account read projection, `SalesSurface` and focused tests. Engine implementation/API change: N/A. Both the schema-11 draft controller and durable portable commands use the same underlying borrowed Madar store; the projection delegates workspace operations and refuses account writes/recovery. No storage engine algorithm, new native owner, engine pin, runtime schema activation, opening values or cutover date changed.

The existing final schema-11 repository cannot decode portable envelopes. The sales-owned projection exposes validated embedded source accounts only to the existing draft ViewModel; financial commands retain the complete portable snapshot. The public session exposes guarded draft actions rather than allowing mutation through its private draft model during checkout. It blocks conflicting external metadata work through `isWriteBlocked`; `refreshAccount(fresh: ...)` refreshes projections after another acknowledged complete-state commit. Reports can subscribe to `session.operations` and read its immutable `account`.

Checkout captures one sale operation and empty successor draft. On success/replay, workspace cleanup replaces only an active finalized identity, retaining unrelated held tickets and form values. A cleanup failure keeps the confirmed sale and pending cleanup; retry does not generate another operation or repost a known successful sale. Restart reads saved sale authority before replacing a finalized active draft. An unrelated finalized held identity fails closed for explicit recovery. Account posting and workspace cleanup remain separate commits; no atomicity claim spans both.

## Approved UI

The owner approved the C2 packet during this task; [exact approval](../phases/c2-c4-owner-approval.md) supersedes the earlier sales task's UI-hold statement for this bounded core only. Inspected the approved desktop-cart native image and current shared components/source. Used the project responsive-layout skill for parent-width layout and shared RTL controls.

`SalesSurface(model: ...)` supports operational schema-11 catalog/search/group/pagination, image/compact cards, captured cart quantities/prices, removal, date/discount/note, order type, optional-name hold and populated held resume. It stages raw field edits and flushes them before other workflow actions; invalid input remains visible. `onPendingInputChanged` lets the shell protect route navigation while raw input awaits acknowledgement. Compact mode retains product photos. Root owns app mounting and shell workspace coordination.

Schema-11 checkout stays disabled with a visible explanation. `SalesSurface(session: ...)` permits durable checkout only through the explicit portable session; a successful command and reconciled workspace precede paid confirmation. It exposes retry for unresolved checkout. No sample sale toast or demo success represents a real operation. Detailed C3 receipts/return/void UI, held-empty/delete-confirmation and excluded layouts remain outside this approval.

## Actual small checks and failures

- Session smoke passes checkout, lost workspace acknowledgement, retry without a second account write, preserved held/form values and reopened fresh active draft.
- Two mounted widget checks pass: real schema-11 product addition with disabled checkout/no saved sale; populated held-list resume.
- Targeted analyzer over session, surface, their tests and root-owned `app.dart` passed with no issues at the checked revision.
- Agent-caused setup rework: initial session model construction preceded repository opening; corrected before smoke execution. UI source first had one missing closing parenthesis, fixed before formatting. Widget fixture initially called nonexistent `tester.view.setPhysicalSize`; corrected to the actual property setter, then both widget checks passed. Braces lint infos were fixed through exact-file `dart fix`. One mixed test invocation contained the fixture compilation failure; its session scenario still passed, and the corrected invocation passed all three checks.
- Later optional dirty-input navigation callback and compact-photo retention are small source additions after the three-check run; final targeted analysis is recorded by the controller when available. No broad test suite/review/benchmark/native launch ran.

Compiler windows were handed between workers; no repeated native builds. Precise total task effort/token cost is unknown. Tool-reported compile/test batches took roughly 2–10 seconds; one errored test process required a completion read. Failed paths above remain documented instead of being called behavioral failures.

## Storage review

Continuation baseline available disk: 95,488,044 KiB; final at 10:40:42 UTC: 95,499,284 KiB (11,240 KiB more free). Sales folder 72 to 104 KiB. Shared Git objects 4,638,244 to 4,638,548 KiB; shared build directory 2,163,128 to 2,144,920 KiB. Concurrent workers prevent attributing those shared changes to this task. Four new canonical source/test artifacts total 50,437 bytes. Retain source/tests/logs; no screenshots, exported designs, archives, temporary stores or duplicate outputs were created by this continuation. Cleanup reclaimed 0 bytes; active shared compiler caches remain for other workers. Disk stayed above the stop threshold; no unexplained multi-GiB growth occurred in these measurements.

## Remaining integration

Root must finish shell navigation protection using the pending-input callback and preserve typed active/held workspace fields during shell saves. Schema-11 runtime now has approved draft UI, but real financial posting remains gated until portable activation and verified openings/cutover. Explicit portable-session demo/composition can proceed without touching real accounts. C3 and excluded C2 layouts still need their own approval. Later full tests must cover checkout unknown-command outcomes, cross-controller changes, restart boundaries, late callbacks and native acceptance. Parent coordinates phase-journal reconciliation and project-scoped memory delivery; this log does not claim synchronized delivery.

Final bounded check after pending-input callback and compact-photo retention: `dart analyze` over both new source files and their tests passed with no issues. Earlier three Flutter smoke passes remain the runtime evidence; no redundant full-suite run occurred.
