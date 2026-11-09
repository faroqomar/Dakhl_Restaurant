# Financial independent-review fixes

Date: 2026-11-08. Scope: two independently reported P2 defects; app-owned financial composition only. Engine implementation/API/pin: N/A, unchanged; existing Madar complete-state CAS/receipt contract remains the public boundary. No live cutover, account access, policy choice or Git mutation.

## Changes

- Sale replay validates the stored posting with the same injected `RestaurantJournalMapper` that created it. A reopened coordinator with custom cash/revenue accounts replays the exact receipt without writes; a default-profile coordinator still refuses mismatched proof.
- Payment correction keeps complete current state for invoice and payment history verification. The pure eligibility evaluator derives an allocation-only account excluding the verified payment being replaced. History validation no longer loses the original inline-payment source after an invoice correction; overpayment and absent authority still fail before writing.
- Updated an obsolete safety assertion that expected all immediate invoice payment corrections to fail. The successor proves receipt-backed inline correction succeeds while the same source without its invoice receipt fails. Legacy unposted source refusal remains.

## Verification

- The initial focused batch passed 30 existing sale/invoice/payment/safety cases, but the new regression module failed compilation because its test omitted the `madar_domain` import for `FundingSource`. Added the import; the successor passed both new regressions. No pre-fix red execution is claimed. Root retains independent review evidence of the original defects.
- Two new cases: custom-profile create → coordinator reopen → replay with no writes; invoice1000 + inline200 → invoice correction1200 → inline correction100 → exact replay → overpayment refusal with no writes. Seven journals and three real durable receipts remain.
- Targeted analysis: no issues. Logs: `outputs/completion-review/review-stage-001/financial-fixes-focused.log`, `financial-fixes-regressions-successor.log`, `financial-fixes-analysis.log`.
- Independent fix recheck and aggregate/native/benchmark validation remain root-owned.

## Storage and efficiency

Initial free space 96,275,140 KiB; final 93,090,284 KiB. Final app sizes: `.git`18,440,772 KiB, `build`2,181,136 KiB, `outputs`7,398,916 KiB. Relative to the inherited review baseline `.git`18,440,260/build2,181,600/outputs7,398,572 KiB, project growth is small (+512/-464/+344 KiB); global free-space movement is concurrent and unattributed by this worker. Root notified for campaign-level attribution. No Git temporary object directories found. Zero cleanup: only canonical source/tests and three compact diagnostic logs created; no duplicate build/export or task temp files. Raw failure log retained as evidence.

Avoidable overhead: omitted test import caused one focused compile failure. Prevention: inspect test enum ownership/imports before compiler handoff; retain narrowly scoped successor evidence. Total task duration/token/cost across inherited context is unknown. Root owns final project memory synchronization after integrating this compact digest.
