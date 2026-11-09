# Mixed journal reconciliation verification

Status: execution in progress; independent aggregate review remains pending.

Scope: F-09 acceptance tests over existing public durable sales/spending commands and the real single-owner Madar document store. App ownership: synthetic restaurant envelope, expected examples and read-query reconciliation. Madar source change: N/A, existing reviewed contracts suffice. Reviewed engine: `d316fd6076375daa3f412889f73eaebfeeb5d4d4`; app base: `cc91fae438101fce7ff4729e12bf3c2b64dacd70`, with concurrent uncommitted work preserved. Runtime schema11 and production cutover remain unchanged. No real account, native UI, build, Git mutation or live migration access.

## Execution record

- Intake through 2026-11-07T20:43:19Z: read task rules, both project rule/plan/tracker/prompt and engine responsibility sources, ADR0021 and durable sales/spending/portable contracts, local testing skills and existing public test/source seams. Focused Hindsight recall succeeded separately for daftar and madar. Start timestamp unavailable; no timing invented. Raw first discovery output exposed excessive tool metadata, and several combined reads exceeded output bounds. Corrective action: focused source paths and bounded reads. One guessed test path did not exist; read the actual restaurant-prefixed paths. Two zsh glob reads failed on absent query names; replace with rg file discovery. No writes resulted from those reads.
- Storage baseline: `df -k .` available112032436KiB; `.git`18422536KiB, outputs7305660KiB, `.dart_tool`204860KiB, build639928KiB, Madar `.git`41076KiB. No storage-producing campaign; only bounded host tests and compact receipts. Shared baseline may include other workers' activity.
- 2026-11-07T20:43:19Z onward: implement retained acceptance test `test/accounting/journal_mixed_reconciliation_test.dart`. Independent expected IQD fixtures: sale2900 refunded967+1933, original-date2000 void, surviving2000 sale,3000 shared expense,9500 unpaid invoice,2000 second invoice with1500 immediate cashbox payment,11000 selected invoice/opening-debt payment,3500 opening settlement. Expected paid spending19000, daily12500/cash6500, supplier liability500. No property generator: a bounded, independently calculated mixed example provides the oracle without another ledger implementation.

Token use, cost and active effort: unknown. Execution audit overhead includes repeated bounded source intake; automation candidate: a compact named contract/API intake manifest with source hashes and no repeated aggregate dumping. Parent owns phase journal/tracker integration and independent review.

## Verified outcome

On2026-11-07T20:49:02.526313Z the retained mixed real-store acceptance test passed. Final targeted analysis passed with no issues in2.6seconds. `final-test.log` reports1test passed in the expanded reporter's1second elapsed bucket; this is test-runner time, not a feature benchmark. Test source SHA256: `c75eab45d28219fce922ea6e1a9520ee03d2ef742a9e05ba9bab00d04dcf3562`.

The synthetic history commits11commands,13journals including opening and11ordered receipts. It verifies each journal's exact account/side/IQD/date/source, each receipt's operation/journal/net identity and persisted equality, atomic invoice/payment linkage, and fixed source ticket/refund/invoice/payment/funding fields. Reopen preserves the complete serialized payload. Settlement replay returns the same recorded receipt without changing payload or revision. Invalid void-with-returns and501IQD settlement against500IQD due both reject without changing accepted history.

The correct frozen cumulative-floor refund examples are **966+1934=2900IQD**. The initial967/1933expectation above was a test-author arithmetic assumption, corrected after checking frozen `electron-reference/app/ui/model.js:309` and Madar's cumulative-floor contract. No production defect arose from it. Final expected totals:19000IQD paid spending,12500daily share,6500cashbox share,89500synthetic physical daily cash,43500cashbox,500supplier liability and16sellable units. The9500unpaid invoice adds internal purchase expense/liability and no paid row; settlements add no second purchase expense. Carton/piece inputs remain purchase units. The final non-restocked refund affects return-date cash and preserves the selected stock reduction. The void restores stock and financial effects on the original sale date despite later recording.

All supplier assertions use public unordered invoice/debt/balance queries with a throwing text comparator. This test establishes no ordered locale/ICU qualification. Statement filters use validated ISO dates and supported funding projections.

## Attempts and author-caused corrections

- Initial analysis: unused JSON import and four nonexistent receipt `toJson` calls. The public receipt contract provides equality; fix test assertions to use it. The first scripted replacement missed two formatter-indented calls; `attempt-01.log` preserves that compile failure. This was avoidable fixture/API work, not a product regression.
- `attempt-02.log`: all11commands and reopen reached replay; the test incorrectly expected success subtype instead of `DurableCommandReplayed`. Corrected against the public result API.
- `attempt-03.log`: fixed expected outcomes exposed the966first-refund value. Corrected the independently written fixture from source semantics as described above. Do not treat this as a product failure.
- `attempt-04.log`: per-journal and receipt assertions passed, then test read ticket `receiptNumber`; canonical source uses `number`. Corrected that fixture key.
- `attempt-05.log`: mixed acceptance passed. Added funding/date projections, immediate-payment linkage and filtered spending assertions before the final pass. Final test and affected analysis pass; no further product-source changes.

The first two shell test batches ended with `cat`, which masked the failed runner's process status in the outer command. Their retained test logs explicitly report failure. Later commands preserve and return the runner status. Prevention: inspect public types/keys before writing fixture assertions; validate replacement counts after formatting and preserve runner exit status. Parent owns any central repeated-problems entry because this worker's write scope excludes that catalog.

## Storage review and retained evidence

Baseline free112032436KiB; final observed free112031944KiB, a492KiB decrease across concurrent workers. App `.git` increased180KiB to18422716KiB; outputs increased172KiB to7305832KiB; `.dart_tool` stayed204860KiB; build decreased16392KiB to623536KiB. No `.git/objects/tmp_objdir-*` directories remained. This worker did not attribute shared growth/cleanup to another task.

Canonical new test remains under `test/accounting`; the English digest remains here. Compact logs and the exact-source/toolchain/expected-values receipt remain under `outputs/completion-review/journal-reconciliation/` (28KiB at measurement). These unique attempt/final receipts support independent review and need retention. Test teardown closed the sole real store and removed its task-owned `dakhl-f09-mixed-*` directory; final inspection found none. No duplicate export, build, screenshot, archive or account copy arose. No uncertain Git object, unrelated cache or unique recovery artifact was removed. Reclaimed task bytes:0; runtime fixture cleanup is ephemeral and its deleted byte count is unknown.

## Limits and handoff

This verifies one rich bounded synthetic post-cutover history and two rejection paths. It does not establish global reconciliation for arbitrary migrated histories, complete financial edit/delete/correction coverage, cross-cutover policy, process crash/fault coverage, real opening values, live activation, UI/native/platform acceptance, operation performance, hosted CI, merge or release. The independent F-08 worker owns crash/fault evidence; root owns aggregate review, paired tracker integration and final project-scoped memory sync/check. Madar implementation/document changes remain N/A because no missing reusable capability or source defect appeared. Feature benchmark N/A for this tests-only change; existing feature campaign obligations remain open.
