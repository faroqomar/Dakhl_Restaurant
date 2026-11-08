### Independent Review: Supplier-Opening Amendment & Completion Claims

**Scope:** Independent read-only verification of [supplier-opening-amendment-proposal.md](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/docs/phases/supplier-opening-amendment-proposal.md), [supplier_opening_commands.dart](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/lib/parties/supplier_opening_commands.dart), [supplier_opening_controller.dart](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/lib/parties/supplier_opening_controller.dart), [portable_journal_state.dart](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/lib/accounts/portable_journal_state.dart), and [2026-11-08-remaining-completion-closeout.md](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/docs/log/2026-11-08-remaining-completion-closeout.md).

---

### Verification Findings: Clear (No Blocking Defects)

The implementation strictly satisfies [ADR 0021](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/docs/decisions/0021-completion-financial-policy.md) and approved amendment boundaries without architectural spillover:

1. **Immutable Opening & Delta at Established Cutover:**
   - [`SupplierOpeningHistory.baseOpening`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/lib/parties/supplier_opening_commands.dart#L149-L167) verifies the base opening journal identity, hash, cutover date, and unreversed status fail-closed.
   - [`SupplierOpeningHistory.entries`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/lib/parties/supplier_opening_commands.dart#L175-L215) posts linked differences (`delta = after - before`) on `c.cutoverDate` with balanced liability/equity lines. No base journals are rewritten or reversed.

2. **Explicitly Accepted Equity:**
   - Enforced by both [`SupplierOpeningCoordinator.execute`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/lib/parties/supplier_opening_commands.dart#L330-L336) and [`SupplierOpeningController.canWrite`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/lib/parties/supplier_opening_controller.dart#L37-L40).
   - Rejects missing or mismatched equity counterparts with `unmapped_supplier_opening_equity`. No silent default chart accounts are inferred.

3. **Settlement Capacity:**
   - [`SupplierOpeningHistory.preservesSettlements`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/lib/parties/supplier_opening_commands.dart#L282-L323) evaluates post-cutover settled payments against cumulative recognized opening and validated additional debts. Decreases underfunding retained settlements or leaving opening balances negative are rejected with `supplier_opening_underfunds_settlement`.

4. **Atomicity:**
   - Evaluated in [`SupplierOpeningCoordinator.evaluate`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/lib/parties/supplier_opening_commands.dart#L366-L417). New or updated supplier metadata, opening amendment journals, durable receipts, and required-feature flags transition together in a single fenced snapshot write.

5. **Old-Reader Refusal & Required Features:**
   - Envelopes with opening amendments require [`supplierOpeningFeature`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/lib/accounts/portable_journal_state.dart#L360-L373) (`supplierOpeningAmendments-v1`).
   - Prior schema-12 readers strictly reject unrecognised keys via `_keys()` in [`PortableJournalState.fromJson`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/lib/accounts/portable_journal_state.dart#L560-L570). Readers lacking this feature fail with `missing_required_feature` or `unsupported_required_feature`.

6. **Honest Live-Activation Gate:**
   - Production entrypoint [`lib/main.dart`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/lib/main.dart#L13-L37) retains standard native accounts repository wiring. Portable financial journal states remain behind explicit envelope imports. Real restaurant live migration remains non-activated and gated.

---

### Prior Evidence Acknowledged (Not Duplicated)
- Financial recheck: 16 focused + 68 regression checks clear (`outputs/completion-review/remaining-completion-001/opening-*.log`).
- Test suite & analysis: 1,432 Flutter tests pass, 16 UI rechecks pass, analysis 0 issues.
- Native conformance: macOS, iOS Simulator, and Android Emulator pilots pass 1,506 corpus pairs and 20 edge checks.

---

### Genuine Remaining Gates
The completion claims in [2026-11-08-remaining-completion-closeout.md](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/docs/log/2026-11-08-remaining-completion-closeout.md) accurately state what remains incomplete:
- **`PARENT_PENDING_MEASUREMENTS`:** New 65-case numeric benchmark matrix and runtime metrics are in progress; not passed.
- **`PARENT_PENDING_SHARE_AB`:** macOS share anchor picker visibility/delivery remains unproven.
- **`PARENT_PENDING_NORMAL_BUILDS`:** Fresh normal-entrypoint build seals and packaging checks pending.
- **`PARENT_PENDING_STORAGE_MEMORY`:** Storage cleanup and memory sync remain unfinalized.
- **Physical Devices & Live Activation:** Physical devices are unavailable; live cutover and accounting activation remain gated.