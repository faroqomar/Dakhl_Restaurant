# Review-stage feature benchmark scenarios

Date: 2026-11-08. Scope: app-owned scenario/fixture/producer and registry routing.
Madar runtime/API N/A: the existing reviewed host sampler, protocol and result
contract remain unchanged. The root separately owns the new PDF raster contract
and its exact engine adoption. No benchmark/native build or measurement ran in
this worker lane.

Implemented twelve separate operations in
`lib/platform/review_performance_scenarios.dart` and an opt-in profile producer:
checkout/refund, expense/transfer/register, invoice/payment, complete-envelope
export/import/previous recovery, cash PDF bytes and expense compensation undo.
The fixture uses an exclusively allocated temporary real adapter,20products,
200pre-cutover cash rows, one supplier/material, and explicit synthetic verified
cutover. Source-only historical rows are not fabricated journal postings.

Preparation, command capture where available, verification, native reopen and
cleanup stay outside elapsed samples. The register public command captures its
intent inside elapsed. Export ends at canonical bytes; import/recovery starts
with a validated prepared candidate; PDF generation includes the bundled-font
read. CPU/RAM include between-sample fixture work in the existing broad marker
window and cannot be described as per-command isolated resources. No UI, frame,
input dispatch, file chooser or native PDF raster is measured here.

## Verification

-37Python runner/registry checks passed, including two new routing/registration
specifications and the updated explicit ready-operation roster.
-12fixture/option cases passed in `review-benchmark-fixtures-successor2.log`;
PDF case then passed in `review-benchmark-report-successor.log` after initializing
the Flutter test binding so the real bundled font could load. Root's final full
suite must consume the final combined source; no aggregate suite pass is inferred.
-Targeted analyzer: no issues.
-The first fixture compilation omitted the required invoice-query comparator;
a null attempt also failed because its public port is nonnullable. The final
verification supplies an explicit ASCII-fixture-only comparator. No production
collation fallback changed.
-The first Python run failed only its stale hardcoded ready-case roster; the
successor preserves the existing assertions and adds the twelve real scenarios.

Canonical logs: `outputs/completion-review/review-stage-001/` with prefix
`review-benchmark-`. Formatting/analyze and tests ran only after root granted
the compiler window. Native profile build, pilot, matrix, source identity and
independent review remain root-owned and pending. Registry/source-ready does not
mean measured or release-approved. No Git mutations, dependency changes, copied
engine sampler, real account access or parallel compiler run occurred here.

## Storage and handoff

Baseline free94,055,124KiB; `.git`18,441,260KiB, `build`2,215,664KiB,
`outputs`7,399,056KiB. Final free94,033,888KiB; `.git`18,441,260KiB, `build`2,183,068KiB, `outputs`7,399,152KiB. Global free decreased21,236KiB, app build decreased32,596KiB and outputs grew96KiB across concurrent work; no exclusive producer attribution is made. No retained test fixture roots remain and0bytes needed cleanup beyond the task-owned recall scratch JSON. The lane retains
only new source/tests/docs and compact compiler logs; no temporary fixture
folders remain after successful checks. No duplicate build or disposable export
was created. Root synchronizes this sanitized receipt with project-daftar and
performs the final campaign storage/memory closeout.

## Independent review payload successor

The reviewer found that previous/current/import fixture payloads were identical,
so selecting the wrong payload could pass. The corrected import fixture has
distinct Current and Incoming identities; recovery writes distinct Previous and
Current identities. Preparation captures and checks the complete selected
candidate payload separately. Verification requires that exact payload and a
fresh generation, then compares the exact reopened native payload. Two negative
regressions publish the wrong old/current payload under a further fresh generation
and require verification failure. Import/recovery now use scenarioVersion2; the
other ten scenarios retain version1. Timing and host protocol did not change.

Final combined fixture successor:15/15passed, targeted analyzer0issues. Evidence:
`outputs/completion-review/review-stage-001/review-benchmark-payload-successor.log`.
No benchmark build or measurement ran in this lane. Compiler released for the
root's source-frozen full checks, native pilot and matrix. The reviewed engine
pin supplied by root remained untouched.

Storage at successor closeout:
```text
/dev/disk3s1   482797652 351883680  93644412    79% 3814590 936444120    0%   /System/Volumes/Data
18441260	.git
2183448	build
7399184	outputs
```
No retained review fixture roots remain. Only source/tests/registry and compact evidence changed;0bytes reclaimed. Global concurrent changes are not attributed to this lane.

## Restart-resumed Q03–Q06 expansion

The T3 restart cancelled the expansion before its result. The resumed lane inspected existing source before changing it: the case declarations and command branches survived, but report/history fixture helpers, added postconditions and registry entries were incomplete. It completed those existing paths rather than replacing the original twelve cases.

There are now32review cases: eligible void, expense correction, bounded one-day date correction, supplier-ledger query, invoice with immediate payment and purchase analysis supplement the original twelve; each of seven report kinds has a separate short and larger valid fixture. Ledger/analysis use200historical invoices and measure nonvisual queries. Report short fixtures use one row; larger naturally tabular reports use150rows and150distinct catalog products. Sale source forbids repeated product IDs within a ticket, so large sale receipts use distinct products. Payment.max uses a valid500-character note; it is a bounded receipt, not a claimed multipage document. No PDF page count/raster/layout claim follows from PDF byte generation alone. Root owns native verification and actual measurement.

Actual validation:35/35fixture checks pass, including original wrong-replacement-payload negatives;37Python runner checks pass. Source analyzer clean. Initial expansion attempts failed on missing helper/verification branches, then duplicate synthetic sale product IDs, then integer copied sale numbers. Source correctly refused those invalid fixtures; successors use unique product IDs and source string sale numbers. An attempted textual number repair missed an inline expression, causing one avoidable repeated run; the final exact replacement passed. No product validation was relaxed. Stale legacy registry reasons now distinguish implemented checkout/cart behavior from still-unimplemented visible-to-raster benchmark series.

Evidence: `outputs/completion-review/review-stage-001/resumed-benchmark-fixtures-successor-final.log`, `resumed-benchmark-python-successor.log`, `resumed-benchmark-analysis.log`; earlier failed attempts remain alongside. No native build or benchmark measurement ran. Compiler released and source frozen. Storage latest sample: free93,877,988KiB; .git18,442,132/build2,184,048/outputs7,399,600KiB. Lane retained source/tests/registry and compact logs only; no fixture roots remain. Two task-owned read scratch files removed; no uncertain shared data cleaned. Concurrent disk changes remain unattributed.
