# Source-reference sales completion build

App-owned C2/C3 implementation under [source-reference approval](../phases/source-reference-build-approval.md). Native/visual qualification, broader tests, benchmarks and independent review remain deferred. Madar changes: N/A; existing exact-decimal, durable commands and report delivery suffice. No package pins, posting policy or normal schema11 activation changed.

Changes: extracted the existing return quote calculation for preview; added quantity/restock/date/reason and explicit customer cash confirmation; exact unknown-return retry preserves captured intent; history distinguishes partial/full refunds. Held dialogs support empty/name/error/readback/delete states. Clear-cart preserves held/form state; source increment/decrement rules and eligibility messages apply. Paid confirmation reads acknowledged saved data and uses existing print/PDF delivery with retained bytes. Root owns `SalesSurface.onOpenReceipt` route wiring.

## Small verification

Eight focused cases passed: new source-sales completion3, existing frozen-return oracle1, history widgets2 and sales widgets2. Checks cover refusal without cash confirmation/no write, unknown refund replay ignoring changed retry inputs, exact cumulative discounted 999 + 2000 refunds, original-sale preservation, typed held-name recovery/delete at390px with280px keyboard inset.

Initial widget run passed6/failed2: offscreen receipt observer needed ensureVisible; held dialog exposed a real controller disposed before reverse-animation unmount. DakhlField now owns the controlled name value until unmount. Successor source3 and combined8 passed. First command output exceeded tool context; successor logs used bounded temporary files. Two guessed frozen reference paths were corrected to commerce.js handlers. First analyzer path lib/app.dart was wrong; corrected lib/app/app.dart analysis found no sales issues and one root-owned app.dart:384 braces info, reported to root. No review/fullsuite/benchmark/native run occurred. Fixture stores only; no real account reads/writes.

## Storage/handoff

Baseline free96,229,224KiB; sales144KiB; build2,142,140KiB; Gitobjects4,640,912KiB. Finish free96,168,460KiB; sales180KiB; tests156KiB; build2,142,748KiB; Gitobjects4,641,820KiB. Shared concurrent activity prevents attributing the60,764KiB free-space difference to one producer; growth is below stop thresholds. No Git temporary object directories appeared. Retain unique source/tests and canonical design paths; no new artwork/exports/copies. Reproducible task-owned temporary observer logs are disposable after this receipt. The first combined log-write/cleanup command was rejected because rm-f style commands are disallowed; no changes from that rejected command were claimed.

Parent owns phase/tracker aggregation and project-memory synchronization; this handoff does not claim memory delivery. Remaining gates: requested later review/tests/benchmarks/native/visual acceptance and existing live portable activation prerequisites. Financial UI requires the authorized durable owner; schema11 retains safe drafts/read-only saved history.
