# Build-first durable invoice corrections

Date: 2026-11-08. Status: isolated implementation candidate; three focused smoke cases passed and targeted analysis clean. Full tests/fault campaigns, benchmarks and independent review remain deferred under the owner build-first instruction. No phase/merge/release or live financial activation claim.

## Request and boundary

Root assigned safe durable invoice edit and source-supported unpaid deletion under accepted ADR0021 1A-P/3A/4A. Worker read the current correction contract/examples, invoice proposals/mapper/host and actual frozen `suppliers.js` invoice submission/deletion branches. Source preserves invoice creation identity, refuses supplier changes, validates paid totals/timelines and blocks deletion while payments reference an invoice. Existing `PurchaseProposals` retain those rules. Madar implementation/API/pin changes: N/A; app mapping/history consumes existing balanced-journal/coordinator/store contracts. No portable codec change was required.

Root granted narrow existing spending-command history hooks after worker identified the original-create replay and subsequent-payment eligibility dependency. Root did not edit that file concurrently. Sales UI owner retained exclusive form/controller-adapter ownership and received exact method/argument signatures; it reported connecting the edit adapter and owner-approved user-entered correction reason. This worker does not claim its later widget result.

## Changes

- New `lib/accounting/restaurant_journal_invoice_correction_commands.dart`: frozen expected-source/authority commands, original-date inverse plus replacement or deletion, atomic complete-state outcome, retained source snapshots and receipt-backed invoice history. Missing/ambiguous/originally unposted/pre-cutover source families fail closed. Existing shared command host owns persistence and uncertainty recovery.
- Narrow `restaurant_journal_spending_commands.dart` hooks: reuse original create matcher against the retained invoice snapshot for historical replay; recognize a corrected active liability posting for later payments. Uncorrected paths retain existing behavior. No lexical comparator or alternate allocation is added.
- `PartiesOperationsViewModel`: active posting lookup, edit/delete intents, pure preview, submit and exact pending-command retry integration. `PurchaseOperationsController`: edit/delete delegation. Existing cross-workflow pending guards remain.
- Contract: `docs/phases/completion-durable-invoice-correction-contract.md` records setup/API example, semantics/errors/limits, actual evidence and pending acceptance.

## Actual verification

`flutter test --no-pub test/accounting/restaurant_journal_invoice_correction_commands_test.dart`: 3 passed. Cases cover original-date inverse/edited-date replacement, original create replay after correction, payment against corrected invoice, repeated edits/old correction replay, unpaid deletion and create/edit/delete replay after a fresh ViewModel owner, changed source and missing-posting refusal, and a replacement below paid allocation leaving stored payload/write count unchanged. Fixtures use the existing in-memory store; no native/SQLite fault acceptance follows.

Final `dart analyze` across the new correction file, changed spending/parties/controller files and focused test: no issues. Initial analysis produced brace/null-assertion/null-aware-element style diagnostics and three unused test imports; worker corrected them. No behavior smoke failed in this task. The compiler window transferred to sales_build after the passing backend smoke; no additional Flutter build/native/benchmark/review ran here.

The earlier broad source read truncated; worker used bounded relevant methods/branches afterward. Wall time, token cost and active engineering time are unknown. These checks do not prove immediate-payment-root variants, restored-fence behavior, every historical/tampering case, concurrency/process faults, full source-oracle differential coverage or UI/native acceptance. Those remain in the deferred verification stage; no row closure or independent approval is inferred.

## Storage completion

Initial task free space: 96,259,580 KiB. Final at 2026-11-08T11:55:13Z: 96,252,476 KiB (-7,104 KiB shared-volume change), `.git` 18,437,064 KiB. Canonical new correction source 32 KiB, focused test 12 KiB, contract 8 KiB; this compact log is retained source evidence. No `.git/objects/tmp_objdir-*` directory appeared. No task-owned screenshot, archive, exported PDF, build duplicate or scratch file was created. Other agents used the shared volume concurrently; no unsupported producer attribution is made. No low-disk or unexplained 2 GiB growth threshold occurred. No unsafe/shared-cache or Git-object cleanup was needed. Root owns final campaign build cleanup and batched Markdown memory delivery.
