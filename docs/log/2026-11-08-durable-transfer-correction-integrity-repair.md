# Transfer correction integrity repair

Recorded 2026-11-08. Status: implementation and local verification complete; fresh independent recheck pending. Design: N/A for isolated nonvisual composition. No checklist closure or live activation.

## Scope and authority

This repair addresses the independent transfer-correction review's five finding groups under `docs/phases/completion-durable-transfer-correction-contract.md` and ADR0021 3A. Dakhl_Restaurant owns source/journal/receipt reconciliation and command composition. Madar's balanced-journal, storage and coordinator implementations remain unchanged. The app still consumes d316fd6076375daa3f412889f73eaebfeeb5d4d4. Concurrent root work committed the reviewed engine collation candidate at 783e29cf8ae5c829cbb09bdb5b7a547aa92bc8d6; this worker did not adopt it or change engine source/pins/configuration.

## Repair

- Reconstruct recognized create and every edit/delete envelope from committed canonical command intent under the caller's mapper/profile/policy. Compare full portable entries and complete historical outcomes rather than comparing mutually matching stored metadata.
- Require all prior committed chain receipts, increasing receipt sequence and journal encounter order, exact source snapshots, one linear correction chain and matching terminal source projection. Reject missing receipts and extra transfer-linked branches.
- Validate an active target's complete recognized history before a new correction. Preserve immutable prior journals/receipts and historical replay after later edits/deletion.
- Reuse existing bounded `CommandSnapshot` canonicalization and metadata freezing. Keep raw submitted reason in durable identity and trimmed reason in the journal.
- Update synthetic proposal fixtures to include explicitly captured seed command receipts. A source row and a posting alone are not evidence of an eligible durable history. Pure proposals still omit their current receipt until coordinator attachment.
- Add actual before-commit store-checkpoint exception tests for edit and delete. Existing proposal-rejection tests remain labeled as proposal rejection.
- Produce a successor oracle invoking the actual frozen renderer confirm-delete body with synthetic commit/close callbacks. Existing oracle/generator remain unchanged.

## Verification and corrected historical claims

- The independent original review reproduced the financial-history defects before this repair. Permanent regression tests cover those reproduced paths.
- 26 new integrity tests plus the retained 33 correction and 38 create tests give 97 focused cases.
- Full accounting suite: 297/297 passed (`flutter test --no-pub --reporter expanded test/accounting/`). Targeted analysis: no issues. Pure contract/adapter/consumer boundary check: passed.
- Correct previous accounting arithmetic: the original 271 count was 233 baseline + 33 corrections + 5 concurrent F08 cases. The 38 create cases were already inside the 233 baseline, not additional. This repair adds 26 cases to 271.
- The original precommit claim was proposal rejection before writing. New tests throw only after reaching actual `transaction.before_commit`; they assert exact old complete bytes/revision, clean reopen, one successful retry and stable replay. No SIGKILL or general power-loss claim follows from these two tests.
- Original delete oracle cases mirrored the renderer filter. The successor executes the extracted actual handler and retains renderer/handler/model/generator/runtime provenance; source fixtures and final summaries remain compatible.

## Attempts and avoidable overhead

The existing adversarial review supplied red defect evidence before implementation. The first implementation regression run exposed four unit fixtures and one safety fixture without durable seed receipts; those fixtures now describe recognized committed history. The new regression helper initially inferred a nullable async generic as FutureOr, repeating a known trap, then assumed a nested `journal` JSON shape instead of reading the portable entry serializer; explicit generic typing and the actual flat serializer fixed these test harness mistakes. One multiline policy-shape replacement missed two cases, which failed before any assertions and then passed after a bounded correction. The first full accounting attempt omitted required `JournalPolicy.allowZeroLines` in two new policy cases; it caused two compilation/load failures. The retained failed attempt and successful successor are separate logs. Broad intake output also truncated; bounded follow-up reads supplied the needed evidence. No production failure or test pass is inferred from these failed harness attempts.

No Flutter pub, clean or cache deletion ran. The worker held the parent's exclusive Flutter window throughout; it will release that window with the frozen successor manifest. Parent owns aggregate prevention/audit and independent acceptance.

## Limits and closeout

UI, transfer date shifts, legacy/unposted correction, operation performance, native acceptance, live cutover and runtime schema migration remain outside this repair. Root trackers, source-pin adoption and delivery approval remain parent-owned. `repaired-1/storage-closeout.json` records before/after usage, canonical artifact retention and task scratch cleanup. No real account records, Git mutations or temporary Git stores were created by this worker.

Final formatting check found the original conformance file's formatting drift. `--output=none` did not change it; a targeted format changed only that file's layout after the 297-test pass. No semantic code changed, so the existing results are reused. The final successor manifest preserves the earlier repair manifest as an immutable preparation snapshot and binds the formatted file and this note.
