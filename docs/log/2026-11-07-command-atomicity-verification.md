# Command atomicity verification, 2026-11-07

Status: worker verification complete; independent review and aggregate integration pending.

App ownership: isolated restaurant command fixtures and real-store conformance tests. Engine changes: N/A; tests consume the public coordinator and existing PowerSync checkpoints at reviewed runtime d316fd6076375daa3f412889f73eaebfeeb5d4d4. Schema 11 runtime, live cutover, UI, account data, pins and Git remain unchanged.

## Audit

- Initial instruction/contract/test inspection and separate project-daftar/project-madar Hindsight recalls succeeded. Required source documents and relevant current contracts were consulted. Initial broad command batches exceeded output caps; focused sections supplied checkpoint and command authority. Read timing before this log is unknown; no token/cost estimates. Prevention: return bounded structured fields and focused sections. Parent owns the phase aggregate and repeated-problems record.
- Actual PowerSync source invokes transaction.before_commit after complete-row SQL update but inside SDK transaction, and transaction.after_commit after the SDK transaction returns and pending intent exists. Throwing at these points exercises rollback and committed-but-unacknowledged resolution. Existing UnknownAckStore fails an initial read; LostCommitAcknowledgementStore wraps a completed success. This suite uses actual store checkpoints and no additional subprocess campaign.
- Baseline: free 112048048 KiB; app Git 18422536 KiB; outputs 7305660 KiB; build 639928 KiB; .dart_tool 204860 KiB. Synthetic test directories will register teardown. Source inputs and start UTC: outputs/completion-review/command-atomicity/inputs.json.

Verification is pending. Clean reopen is not arbitrary process, power-loss, fsync, disk-full or native-device evidence. No F08 whole-row closure or phase/release approval follows.

- Attempt 01 (20:45:19–20:45:24 UTC, 5.686 s) failed to compile because the worker assumed receipt accepted/toJson APIs and an entry-level reversal property. Current public source provides status, value equality and journal.reversesId. Corrected only the owned test; this was avoidable fixture-authoring overhead, not a production defect. Exact compiler output is retained in test-attempt-01.log.

- Attempt 02 (20:45:46–20:45:53 UTC, 6.308 s) reached 13 fixture setups but the generic assertion inferred FutureOr<DocumentSnapshot>? in an async arrow. None reached command fault assertions. Corrected the helper with explicit DocumentSnapshot? type. This was test-only authoring overhead; full failed diagnostics remain in test-attempt-02.log.

- Attempt 03 (20:46:05–20:46:11 UTC, 5.807 s) passed all 13 cases. Added explicit receipt outcome amount/identity links, unchanged source fields, and refund contra-revenue assertions before final verification. No production fix was needed.

## Verified result

Final tests: **13 passed** at 20:46:46–20:46:53 UTC (6.350 s wall clock). Targeted analyzer: **no issues** at 20:46:56–20:47:00 UTC (4.128 s wall clock). Commands used the existing Flutter toolchain with `--no-pub`; no native surface, account launch, extra subprocess campaign, Git change or dependency resolution occurred. The tested production-input hashes match the initial snapshot. Receipt, final source manifest, [test output](../../outputs/completion-review/command-atomicity/final-tests.log), [analysis](../../outputs/completion-review/command-atomicity/analysis.log).

| Accepted composition | Actual precommit checkpoint | Actual postcommit checkpoint |
| --- | --- | --- |
| Tracked sale: 2 units, 2,000 IQD | Full payload/revision/token unchanged before and after reopen; retry/replay exactly once | Resolve, reopen, identical receipt; changed discount rejects without writes; stock 5→3 |
| Restocked return: 1 unit, 1,000 IQD | Same rollback/reopen/retry contract | Refund-date contra revenue and cash, stock 3→4; changed reason rejects |
| Eligible sale void: 2,000 IQD | Same rollback/reopen/retry contract | Original-date inverse linked to sale journal, stock 3→5; changed reason rejects |
| Shared expense: 1,200 IQD | Same rollback/reopen/retry contract | Daily 700/cashbox 500; one source, journal and receipt; changed note rejects |
| Invoice: 4,200 IQD, immediate shared payment 1,500 | Same rollback/reopen/retry contract for inline material, invoice, payment and both journals | Daily 900/cashbox 600, liability 2,700; one receipt and two journals; changed invoice number rejects |
| Separate shared payment: 1,200 IQD | Same rollback/reopen/retry contract; prior invoice/payment retained | Daily 700/cashbox 500, remaining invoice liability 1,500; changed note rejects |

The thirteenth case throws at the actual postcommit checkpoint and makes only the resolution call unavailable. The store reports `commit_unknown` on the pending read. After close/reopen, it contains the entire invoice composition. A later tracked-stock sale appends its source/journal/receipt; replaying both commands and reopening again changes no payload or revision. The test decorator cannot fabricate database writes. Tests preserve prior journals/receipts and unchanged source collections, and compare exact effect deltas and durable outcomes. No production defect emerged.

## Storage closeout and handoff

Storage receipt: free disk 112048048→112025924 KiB; Git 18422536→18422716 KiB; outputs 7305660→7305808 KiB; build 639928→623524 KiB; .dart_tool unchanged at 204860 KiB. Project size at closeout is 27085652 KiB; the parent-provided start baseline was 27101652 KiB. Concurrent workers share these directories; the producer of Git/free-space changes is unknown. No threshold breach or tmp_objdir store appeared.

The framework closed and deleted all task-created synthetic stores; a host scan found none remaining. Reclaimed host-cleanup bytes: 0; no extra delete was needed. Retain the acceptance test, dated log, source hashes, failed attempts and compact final receipts as canonical evidence. Failure logs preserve distinct authoring mistakes, rather than duplicate exports. All initial candidate hashes stayed unchanged. Existing dirty work remains untouched.

Independent review and parent aggregate integration remain pending. The parent owns the shared phase journal/prevention catalog and app-memory sync/check, preventing competing edits or repeated ingestion. No engine document/memory write is needed because runtime/API changes are N/A. This evidence advances F08 and does not close its whole row, runtime activation, UI, migration, arbitrary process/power-loss, multiwriter, device, benchmark, CI or release requirements.

Time/cost review: four test invocations consumed 24.151 measured seconds and one analyzer command 4.128 seconds. Authoring/debugging and document-read intervals lack measured active-time data; token/cost data are unknown. Two avoidable test authoring failures consumed 11.994 test-command seconds. Priorities: (1) inspect public result members before fixture assertions; acceptance is compilation without guessed APIs; (2) give typed async result helpers explicit type arguments; acceptance is representative real-store readback before matrix expansion; (3) return bounded recall/document fields; acceptance is no display truncation. These are fixture/process remedies, with no new production abstraction.
