# Durable operating-expense corrections

Status: isolated implementation candidate under [the accepted contract](../phases/completion-durable-expense-correction-contract.md). Runtime remains schema 11; no live migration, UI binding or row closure follows from this API. Targeted execution passed 32 new cases plus 72 existing spending regressions; independent aggregate review remains pending in the [task record](../log/2026-11-08-durable-expense-corrections.md).

## Public composition

`RestaurantJournalExpenseCorrectionCoordinator` accepts `EditOperatingExpenseCommand` or `DeleteOperatingExpenseCommand`. It delegates to the public `JournalCommandHost`, `PortableJournalCodec` and Madar `DurableCommandCoordinator` / `LocalDocumentWorkspaceStore`. Construct the host/coordinator with the same store owner. A foreign host fails construction.

The app owns restaurant source/history composition. Engine runtime/API changes: N/A. The consumed reviewed source is `ac8b4edc2c915ed22c0991685c33967b3360e7fa`, application `0.1.0-dev.5`. No shared financial or persistence algorithm is copied into the app.

Capture the current account lineage and authority fence before accepting user intent. Allocate fresh operation, inverse and replacement IDs. An edit also captures the exact target active journal ID, chosen date, category, amount, funding source and shares, raw note/reason, timestamp, payload version, account profile, effective policy and mapper default-policy context. Defaults use the accepted standard chart and policy. For a custom mapper, pass its `profile` and `defaultPolicy` as command context; a command's explicit `policy` may override the replacement policy.

```dart
final command = EditOperatingExpenseCommand(
  operationId: operationId,
  accountLineage: capturedLineage,
  expectedFence: capturedFence,
  expenseId: expenseId,
  expectedActiveJournalId: currentJournalId,
  inverseJournalId: freshInverseId,
  replacementJournalId: freshReplacementId,
  date: chosenDate,
  categoryId: existingCategoryId,
  amount: amount,
  fundingSource: FundingSource.shared,
  dailyAmount: dailyShare,
  cashAmount: cashShare,
  note: submittedNote,
  reason: submittedReason,
  recordedAt: recordedAt,
  profile: mapper.profile,
  mapperDefaultPolicy: mapper.defaultPolicy,
);
final result = await RestaurantJournalExpenseCorrectionCoordinator(
  store: owner,
  mapper: mapper,
).execute(command);
```

Delete captures the same authority/target/context, inverse ID, reason and timestamp, without replacement fields. When a caller supplies a delete policy it must equal the recognized target policy. The inverse retains the original journal policy and original effective date.

## State and replay

One successful command produces one complete candidate and one durable receipt in one revision. Edit preserves ID/createdAt, removes the current row, appends the replacement to the chosen day, and retains the immutable original journal. Delete removes the current source row. Both append an original-date inverse. Edit appends a target-date replacement. Before/after source snapshots, lineage links, operation IDs and exact amount strings remain in immutable journal metadata; original receipts and journals retain their bytes.

The family reconciler rebuilds each root and correction from canonical receipt intent and the selected mapper. It compares complete source, journal lines/policy/envelopes and outcomes, checks ordered receipt/journal edges, rejects forks/orphans, and verifies the terminal source projection or tombstone. Historical create/edit/delete replay therefore remains valid after later supported corrections. Changed intent under an old operation ID rejects. Unknown acknowledgement recovery belongs to the existing host/coordinator/store.

Manual total, recorded balance, remaining snapshots and chicken observations remain unchanged. Derived paid-spending and cash queries follow source edits, including negative cash. Existing categories remain available for historical recognition even when their current archive flag changes. This API selects an existing category; inline category creation belongs to a separate category command/UI flow.

## Errors and bounds

- Constructor format errors reject blank identities/reasons, duplicate target/inverse/replacement IDs, invalid funding shares and negative values. Raw note/reason remain in identity; the source note follows JavaScript trimming.
- `missing_authority_fence`, `account_lineage_mismatch`, stale-authority and standard coordinator operation-intent errors prevent unauthorized writes or second effects.
- `cutover_gated`, `pre_cutover_operation_rejected`, `expense_not_found_or_ambiguous` and `expense_history_mismatch` reject unavailable, cross-cutover, changed, reversed, missing-receipt or inconsistent history.
- `expense_profile_mismatch`, `expense_policy_context_mismatch` and `expense_policy_mismatch` reject changed mapper/policy context.
- `duplicate_journal_id`, `missing_category`, mapper validation errors and `invalid_expense_correction_proposal` reject invalid candidates. Zero requires explicit allow-zero mapping policy. Account source amounts retain the codec's integer IQD and `10^12` bounds.
- Canonical identity uses the existing bounded immutable snapshot helper and 20 MiB document bound. The complete encoded state must fit the store/codec bounds, including history and receipts. The implementation does not trim immutable history to fit.

The foundation rejects missing eligible originals rather than backfill journals, alter openings or resolve section E policy. Generic date shifts, supplier corrections, session undo, import compatibility integration and UI remain separate work. Performance acceptance remains PENDING until an isolated per-operation benchmark records p50/p95, sampled RAM/CPU and conditions; unit test timing does not qualify.

## Receipt revisions after authority replacement

Durable receipt sequence orders the complete correction chain across fences. `PortableJournalState` validates committed revisions within each receipt's fence; a restored complete account may retain old-fence receipts while its new authority restarts the revision counter. The family validator does not compare those unrelated counters. This is isolated complete-state conformance, not activation of a version12 import path. Captured commands from the displaced fence remain stale; new commands capture the active fence.
