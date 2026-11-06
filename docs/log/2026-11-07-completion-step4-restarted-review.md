# Restarted Step4 independent review

Date: 2026-11-07. Status: independent review completed with unresolved gates; **whole Completion is BLOCKED, not ready for approval**. The Lead implemented parts of Step3 and does not self-approve. Three fresh reviewers separately inspect engine correctness, app integrity and evidence/readiness. Original checkouts and existing unrelated work remain preserved.

## Baseline under review

App3cb3e201029ecdb05b4a8fbeabae65f9d3076094; engine7b1866fb8c9a40345c9d67b455c40053178fcb44. At review entry, Step4 fixes were later working-tree source awaiting verification; final committed identities and rechecks appear below. Existing Step3 results retain their original source/fingerprint limits.

## Findings and disposition

| Finding | Independent evidence | Current disposition |
| --- | --- | --- |
| P2 ticket dates below year1000 | Constructor accepted dates rejected by frozen model/account codec | Fixed with account-compatible bounds; failing regression preceded fix; independent pure-Dart checks pass |
| P2 settings/held-label whitespace | Dart trim removed NEL while source JS preserves it | Reused shared LegacyText.trimJavaScript; all3settings fields and persisted/reopened held labels independently checked |
| P2 report reversed/unsupported dates | Rendering-only oracle bypassed source validRange | Guard fixed; oracle includes actual ux.validRange; independent checks pass. Report still incomplete/untracked |
| P2 Unicode catalog matching | Acceptedİ misses queryi+combiningdot; Greek/context and newer Unicode mappings also differ | Resolved: complete shared Unicode17 profile independently reviewed; all15consumer cases independently match frozen Electron44.5.1/Unicode17.0 |
| P2 native binary provenance incomplete | Android receipt lacks dirty-source fingerprint; macOS debug receipt lacks source/engine/toolchain identity | Compilation and binary hashes verified, but exact final-candidate binary association remains pending controlled rebuild. No retrospective observations invented |
| P2 stale active engine tracker | Active row said no implementation/no PR | Row corrected to Step4 blocked and actual older draft PR9 |
| P3 benchmark header stale | Header said pending despite measured section | Corrected to historical independently reviewed baseline; later Step4 changes are not certified by it |

Root's focused regression run passed28tests after4expected failures. Independent Flutter rerun failed during settings-loader compiler copy with ENOSPC and ended22passed/1failed after its owner stopped it; this is not a passing run. A separate independent pure-Dart probe passed21targeted checks for the first3fixes. Native builds are not repeated under unchanged low-storage conditions.

## Verified baseline evidence

- Engine reviewer reran45domain tests, analysis, architecture boundaries and exact consumer source/pin checks; regenerated5stock source cases byte-for-byte.
- Evidence reviewer verified29compressed log archives against original-content and archive hashes; logs establish637working-tree tests (including5untracked report tests),45domain tests,109Python checks and5goldens.
- Benchmark receipt hashes/attempt chain and all7x20raw sample medians/p95 match. This is a fixed-workload local baseline, not a numeric budget/speedup/UI pass. RAM/CPU include inter-iteration preparation, verification and cleanup.
- Android APK and macOS executable hashes match recorded artifacts. iOS log confirmsNoSpace. Compilation is distinct from installed/update/recovery acceptance.

## Hosted state and remaining gates

Read-only GitHub observations: app PR11 is open/non-draft at7067ea72 with7successful checks; engine PR9 is open/draft at4b146e3 with2successful checks. Neither certifies current local heads: both exact-current-SHA check endpoints returnedHTTP422/No commit found. No PR state, push or merge changed during review.

Whole Completion still lacks approved new UI, accepted financial account/opening/correction/migration mappings and integrated durable source/journal/effect workflows; full-day/cross-target portability, installed updates, recovery/rollback, signing and system-service evidence remain pending. Untracked reports retain collation and unsupported-aggregate gaps. Missing/failed checks remain blocked. This review does not authorize new policy, delivery or merge.

## Final fix verification

Engine `bc4e8fc63a18fd9c985cf475110d3624c8c8a97f`, domain `0.1.0-dev.3`, contains the independently reviewed Unicode module, public export, version and documentation. Engine reviewer passed49domain tests, analysis and boundaries; regenerated tables/oracle byte-identically and independently verified all3official source hashes. Scalar coverage is exhaustive; contextual coverage is representative. Minor provenance URL errors were corrected and independently rechecked.

App pin/lock adoption passed exact source/version/boundary checks and targeted Dart analysis. App reviewer independently matched all15catalog cases and regenerated frozen-source oracle. The prior failed independent Flutter attempt remains preserved; later focused verification is recorded separately. Existing native binaries and benchmarks predate these fixes and do not certify final source.

Timing: persistent restart timer exited output-write-failed during this review; preserved heartbeat ends2026-11-06T22:59:01Z after528.584observed seconds. Final interval is unknown, not measured total. No billing/token totals are available. Archive manifests preserve raw logs losslessly. Scope remains blocked; no push, merge, publication or next-step authorization is inferred.

Prevention priorities: (1) capture exact dirty-source fingerprint and toolchain with each native artifact; acceptance is a receipt matching final source and binary hash; (2) preflight storage before compiler/native campaigns and preserve failed receipts; (3) detect timer-write failure immediately and retain an explicit unknown tail; (4) pin reference Unicode profile and regenerate source oracle before compatibility changes.

Final focused Flutter retry:28tests passed (catalog/settings/ticket/report candidate), exit0, after storage recovered to1.3GiB. This supersedes the failed attempt for those focused checks only; full final-source suite, native rebuilds and hosted CI remain pending. Independent app reviewer confirmed exact engine pin, dev.3 manifest/lock and resolved original package paths; lock changed only domain version.

Final app code checkpoint: `f24bc12934ccec6307049803b6b9a6be7bc8e596`. Only reviewed catalog/date/whitespace fixes and exact dependency adoption were committed. Incomplete report source/oracle/tests remain untracked; their successful targeted checks are working-tree evidence, not a committed report implementation. Review evidence and trackers remain local alongside preserved preexisting documentation changes.

Memory delivery checkpoint: both project APIs healthy, zero failed sources; app3pending and engine1pending at first final check. Queued synchronization does not establish delivery; any remaining pending entries stay disclosed.
