# Phase 01 / development dashboard — approved source integration, 2026-10-29

Status: DONE for the owner-approved development-preview scope and source integration. Completion documentation is local, with its publication boundary below. Historical records retain their original status; this is the dated superseding outcome.

Ownership: the app owns approved Arabic RTL UI/ViewModels, route/six-shortcut semantics, guarded isolated preferences location, builds and realistic scenario fixtures. Madar solely owns shared contracts/storage adapters and generic host measurement. App consumes exact 6d4ae39; full-restart restoration and existing safeguards remain in the approved scope.

## Approval and source integration

The owner explicitly answered “Approve these revisions with independent review” for these four exact heads, conditional on configured GitHub checks passing. All 15 configured premerge jobs passed at those heads. Cubic could not rerun because the organization subscription was inactive; Copilot had no review quota. They remain unavailable, not passed. The owner explicitly accepted the completed independent review as the review basis. Live TalkBack/screen-reader verification is owner-excluded, not tested; existing keyboard/focus/semantics remain. Earlier approval waits are superseded.

| Repository / PR | Owner-approved head | Actual merge commit |
| --- | --- | --- |
| Madar #4 | ffb89bcb719a7d980260740962196c5ce7d9b702 | 79c19276c249c91c343c98c3a7674cbed7ea599f |
| Dakhl #7 | 5260eec2f8d0320160fea2349a5e09abd6397b2e | 14a563ef97a6a891274aa2b68b16a6f2a2cfb143 |
| Madar #5 | b0c96ac89de650f05ae27db4308bccbe73fdee83 | 06e69f2da330bcce2250e22e743391fbdabb39bf |
| Dakhl #8 | 3fbf8ad581f87c0eb08d9d9f782f758d54f9f58d | 00b5bbae8be5ebb1bd2f98471b006dec8778f258 |

Normal merges completed in dependency order #4 → #7 → #5 → #8. The stacked tooling PRs were retargeted only after proving their patches identical and their new base trees identical to the approved parent trees. Exact-head guards were used; no force/admin/squash merge or branch deletion. Final engine main tree equals approved b0c96ac; app main tree equals approved 3fbf8ad. The actual consumed engine 6d4ae39 remains in merged engine ancestry, and the actual source checker passed after integration. No runtime repin or copied engine implementation.

## Evidence and limits

Independent read-only review found no remaining code blocker after genuine red/green repairs. All 46 original automatic comments have dispositions; raw historical evidence and earlier source-hash receipts retain capture-time scope. Engine verification includes 5 named application tests, 17 data tests, 4 final process checks, and 19 independent generic benchmark tests (plus 12 portable child contracts under Linux emulation). App guard verification passes 14 focused/154 full tests; dashboard verification passes analysis, 158 Flutter tests, 28 script tests and 7 profile-cache tests. Earlier native keyboard/device/build observations remain tied to their recorded source and scope; they are not claimed rerun.

Actual corrected profile conformance at app e385ce6/tools 75c12fb/runtime 6d4ae39 passed startup, route switch and shortcut save (5/20/20 samples). Median ms: 561.583/14.231/13.648; p95: 1188.382/22.978/18.600; sampled peak RAM MB: 186.483/197.329/193.298; average CPU %: 59.645/29.583/28.114. One logical core = 100%; direct-child sampled RSS, fresh processes and uncontrolled OS caches. Compilation/native input are outside the timing scope; protocol waits affect resource windows. Full results/identities/cleanup are in the app review-corrections evidence. This is a new tooling baseline, not an optimization claim. Order/item scenarios remain planned until real features/fixtures exist.

App candidate remains 0.0.0+1, unreleased. Engine package previews remain application 0.1.0-dev.2/data and native adapter 0.1.0-dev.1. No installed production update, tag, supported engine release, deployment, production migration or next phase. Release/install validation is N/A to this source-integration delivery; broader MVP and both-domain engine release gates remain separate. Seventeen existing frozen-reference dependency alerts (9 high, 8 moderate) remain disclosed and unresolved by this change.

## Recovery and preservation

No production restaurant records were used by the merge or benchmarks. Disposable fixtures remain the verification basis. If a source rollback is explicitly authorized, revert normal merge commits with mainline 1 in reverse dependency order: app #8, engine #5, app #7, engine #4, then verify consumer/source compatibility. These rollback actions are documented, not executed or falsely rehearsed. Before integration engine main was 07d2bb1 and app main f73b14b; preserve history rather than reset/force.

All 636 pre-existing dirty files were retained in 11 local Git preservation commits without changing original checkout/index/HEAD. Superseded docs, raw memory snapshots, browser captures and backup archives stay local and are not published or restored over reviewed source. Older checkouts can still show dirty files; no fully-clean-workspace claim.

## Completion record publication boundary

This postmerge record and tracker updates are committed locally on codex/phase01-completion-record. They do not change the four owner-approved merged revisions and are not silently pushed to main. Live merged-PR metadata also records completion; any later publication of these additional documentation commits needs its own explicit revision approval. No extra PR or phase is started. Separate project-scoped memory delivery must be verified against this local source snapshot.
