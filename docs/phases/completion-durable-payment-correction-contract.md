# Isolated durable standalone supplier-payment corrections

Date: 2026-11-08. Status: authorized nonvisual Completion foundation under accepted [B/F correction examples](completion-remaining-correction-approval.md), ADR0021 and the existing durable spending contract. Section E stays blocked. This slice supports eligible standalone CreateSupplierPaymentCommand roots only. Invoice-immediate-payment correction, invoice correction, day/range shift, undo and UI remain separate.

## Ownership and existing contract

Dakhl_Restaurant owns payment source projection, captured allocation intent, immutable correction snapshots/history and family reconciliation. Madar owns balanced journals, allocation arithmetic, durable coordinator and one-store storage. New engine runtime/API: N/A; consume reviewed ac8b4edc2c915ed22c0991685c33967b3360e7fa. Reuse public engine contracts and existing PurchaseProposals; do not copy arithmetic or persistence. Runtime schema11 stays unchanged; schema12 commands remain synthetic/isolated.

Current source already supports selected invoice due plus eligible verified opening debt. The existing positive test named “selected invoice is settled first then eligible verified debt” verifies250=200+50. Thus no additive create API is needed for accepted B. Preserve existing CreateSupplierPaymentCommand canonical identity exactly. The historical packet’s no-silent-spillover wording does not prohibit the already verified selected-invoice/verified-opening split; other invoices, unverified manual debt and future-created debt remain ineligible. Future saved payments reserve capacity under the frozen allocator; do not replace this with an as-of-date policy.

## Required behavior

Edit/delete only the exact expected current eligible post-cutover standalone payment source and active posting. Capture lineage/fence, source ID/version/full snapshot, active posting, caller operation/correction/inverse/replacement IDs, reason/recorded timestamp, mapper profile/policy and replacement supplier/invoice/category/date/amount/funding/note plus explicit invoiceAmount/debtAmount intent. Freeze/bound all intent and reject changed canonical payloads.

For edit, use the frozen PurchaseProposals.payment editing path, preserving ID/createdAt and excluding the old allocation during recalculation. Require recalculated splits to equal captured intent and independently recognized liabilities. Original-date inverse restores the old liability/cash split; replacement posts the validated new settlement. Delete removes only current source and appends its inverse. One complete candidate persists source, journals, immutable snapshots/history, outcome and receipt in one revision through the existing host. Payment never creates another purchase expense.

Require recognized unique active invoice posting with matching supplier/amount/lines, verified opening debt capacity, valid category/funding/date/reference and full legacy candidate/timeline validation. No blanket later-payment deletion ban: enforce actual source candidate restrictions. Reject missing/ambiguous/reversed/unrecognized originals, pre-cutover corrections, invalid invoice/debt/funding allocation and stale source/fence/lineage. Invoice-immediate-payment roots fail closed until parent invoice/history integration exists.

Family history must preserve create/edit/delete replay after later corrections or deletion and after a fresh-owner restore/fence change. Reconstruct historical roots from exact retained recognized source/journal/receipt/outcome snapshots, not by rerunning old allocations against current state. Receipt sequence orders operations; revision monotonicity is per storage fence. Narrowly extend existing payment eligibility and standalone create replay to recognize valid correction chains. Preserve invoice/sales/expense behavior and old canonical identities.

## Acceptance

Meaningful tests cover accepted B exact20000/12500/7500 original,18000/12500/5500 replacement and delete, mixed funding/category/note/date, repeated edits, retained historical outcomes, later payments, future reservations, invalid timeline/invoice/opening and equal-total tampering. Use exact frozen supplier edit/delete source bodies for differential complete-source parity. Assert complete source maps, exact journal sides/amounts, paid-spending effects, receipts and preserved observations.

Real PowerSync conformance covers single-revision atomicity, precommit rollback, genuinely committed lost acknowledgment resolution/reopen/replay, changed intent/version rejection, lineage/fence/stale targets and same-account restore to a new storage fence. Tests precede behavior changes where practical; preserve failed attempts and distinguish fixture errors from product RED. Avoid duplicate full suites; run focused payment plus affected spending/expense history regressions. Independent review is mandatory; worker cannot close rows.

Deliver source/API/error/setup/examples/limits docs, exact hashes/results and storage closeout. Per-operation benchmarks remain pending and cannot use test elapsed as a substitute. No UI/Penpot/sign-in, real accounts, live opening/date/migration, schema12 activation, pin/version/Git delivery or phase/release approval follows.
