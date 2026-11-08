# Build first daily register snapshot controller log

Recorded UTC: 2026-11-08T13:20:00Z (Local: 2026-11-08T16:20:00+03:00).
Status: implementation complete; 5 focused tests passing; clean static analysis (0 issues).
Advances isolated version 12 complete-envelope daily register snapshot capability.

## Context and assignment

- Authorized implementation sub-agent continuing source-authorized Completion build-first.
- Owned scope:
  - `lib/accounting/daily_register_snapshot_controller.dart`
  - `test/accounting/daily_register_snapshot_controller_test.dart`
  - Narrow session/host integration in `lib/app/restaurant_operations_session.dart` and `lib/app/portable_restaurant_host.dart`
  - Compact operational log `docs/log/2026-11-08-build-first-daily-register.md`
- Ownership boundaries:
  - Root owns `lib/app/app.dart` and `lib/accounting/daily_cash_surface.dart` and will build UI on top of this API.
  - No Git mutations, branches, worktrees, subagents, browser, native execution, independent code reviews, full-suite runs, or benchmarks.
  - Source-reference visual qualification is explicitly deferred in `docs/phases/source-reference-build-approval.md`.

## Semantics & frozen authority verification

1. **Frozen source authority**:
   - `electron-reference/app/ui/renderer.js` submit branch (`remaining`, `balance`, `total`, `clear-balance`).
   - `electron-reference/app/ui/model.js` (`recordRemaining`, `balanceFromRemaining`, `remaining`, `total`, `validDate`, `numeric`).
   - `electron-reference/app/ui/ux.js` (`recordCorrection`).
2. **Display/register snapshot semantics**:
   - These are register/display snapshots, NOT profit, new cash flows, or authority to fabricate opening or journal postings.
   - Recording remaining stores `d.remaining = { amount, dailySpent, transferred, salesTotal }` and updates `d.balance = sum = total + amount + transferred`.
   - Recording remaining does NOT create correction records.
   - Manual balance (`recordBalance`) updates `d.balance` (or clears it with `null`) and appends a correction entry (`field: 'balance'`) with required non-empty trimmed `reason` (<= 500 chars), before/after values, and ISO timestamp.
   - Total override (`recordTotal`) sets `d.totalOverride` (or restores automatic calculation with `null`) and appends a correction entry (`field: 'total'`) with required non-empty trimmed `reason`, before/after values, and ISO timestamp.
   - Historical corrections in `d.corrections` are strictly preserved and accumulated.
   - Reuses `DailyCashQueries` for `total`, `dailySpent`, `transferred`, `netSales`, and live `remaining` calculation taking subsequent differences into account.
   - Bound constraints: money bounds <= 1e12 IQD, JavaScript max safe integer (9007199254740991), non-negative remaining and total, signed allowed for balance.
3. **Storage & idempotency**:
   - Reuses existing single Madar store (`LocalDocumentWorkspaceStore`) via `DurableCommandCoordinator`.
   - Attaches `DurableCommandReceipt` for idempotency and replay without duplicating storage or inventing secondary mechanisms.
   - Preserves all journals, receipts, accountLineage, cutoverState, and sourceProvenance.
   - Explicitly initialized portable account only; no schema11 bootstrap, live migration, cutover activation, or new counteraccount.

## Implementation details

1. **Controller (`lib/accounting/daily_register_snapshot_controller.dart`)**:
   - Implemented `DailyRegisterSnapshotController`, `DailyRegisterCommand` (`RecordRemainingCommand`, `RecordBalanceCommand`, `RecordTotalCommand`), and `DailyRegisterSnapshotOutcome`.
   - Methods:
     - `recordRemaining({required String date, required BigInt amount, String? operationId, String? recordedAt})`
     - `recordBalance({required String date, BigInt? amount, required String reason, String? operationId, String? recordedAt})`
     - `recordTotal({required String date, BigInt? amount, required String reason, String? operationId, String? recordedAt})`
     - `acceptSnapshot(DocumentSnapshot snapshot)`
     - `retry()`
   - Properties:
     - `DocumentSnapshot get snapshot`
     - `AccountDocument get account`
     - `DailyCashSnapshot daySnapshot(String date)`
     - `bool get busy`
     - `bool get needsReadback` / `bool get pending`
     - `DailyRegisterCommand? get pendingCommand`
     - `String? get error` / `String? get errorCode`
     - `List<Map<String, Object?>> corrections(String date)`
   - Non-blocking self-retry: when an uncertain write (`commit_unknown`) occurs, `_pending` retains the command. Retrying executes the identical command without triggering self-block.
2. **Session integration (`lib/app/restaurant_operations_session.dart`)**:
   - Exposed `session.dailyRegister`.
   - Connected mutual write-exclusion guards: peer writers check `register.busy || register.needsReadback`; `dailyRegister` checks peer busy and unknown states.
   - Integrated into `synchronize()` (busy check, unknown check, snapshots list, reader refresh via `acceptSnapshot`).
   - Integrated into `_changed()` and `dispose()`.
3. **Host integration (`lib/app/portable_restaurant_host.dart`)**:
   - Added `s.dailyRegister.needsReadback` to `_isSessionWritingOrPending()`.

## Verification

- Focused unit and integration checks:
  - Command: `flutter test test/accounting/daily_register_snapshot_controller_test.dart`
  - Result: 5 targeted real checks passed in 4.0s:
    1. `recordRemaining computes total + amount + transferred, preserves journals, and replays idempotently`
    2. `recordBalance and recordTotal update overrides/balance, require reason, and append retained corrections`
    3. `rejection on invalid bounds, out-of-range amounts, and invalid date`
    4. `commit_unknown write captures pending command, blocks other commands, and resolves via retry without self-block`
    5. `session integration coordinates dailyRegister with peer synchronization and mutual exclusion`
- Regression checks on peer sessions:
  - `flutter test test/app/restaurant_operations_session_test.dart`: 6 tests passed in 4.0s.
  - `flutter test test/app/portable_restaurant_host_test.dart`: 7 tests passed in 9.0s.
- Static analysis:
  - Command: `flutter analyze lib/accounting/daily_register_snapshot_controller.dart lib/app/restaurant_operations_session.dart lib/app/portable_restaurant_host.dart test/accounting/daily_register_snapshot_controller_test.dart`
  - Result: 0 issues found.

## Implemented vs Unsupported in this task

- **Implemented**:
  - Concrete source-defined recorded remaining, recorded balance, manual/automatic total snapshots.
  - Retained source correction history (`d.corrections`) with required reason, before/after values, and timestamps.
  - Durable command execution, replay idempotency, CAS retry, and unknown-write readback without self-block.
  - Mutual write exclusion and snapshot synchronization across `RestaurantOperationsSession` and `PortableRestaurantHost`.
  - Stable `session.dailyRegister` API for UI binding.
- **Unsupported / Explicitly Deferred**:
  - No date-range financial migration in this task (root owns separately).
  - No UI widgets (root owns `app.dart` and `daily_cash_surface.dart` and will build UI from this API).
  - No Penpot / native visual qualification (deferred per `docs/phases/source-reference-build-approval.md`).
  - No schema 11 live migration or cutover activation.

## Storage closeout

- Available disk space: 96,094,476 KiB.
- No temporary worktrees, build artifacts, or duplicate stores created.
