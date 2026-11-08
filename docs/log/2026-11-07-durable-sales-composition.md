# Isolated Durable Sales Composition Record

Date: 2026-11-07.
Author: Implementation Sub-Agent.
Status: Implemented and Verified Conformance. Candidate command layer under ADR 0021 and `docs/phases/completion-durable-sales-contract.md`.

## Context & Scope

This work implements the bounded isolated durable sales composition in `Dakhl_Restaurant` under ADR 0021 and `docs/phases/completion-durable-sales-contract.md`.
It provides single-store atomic persistence for:
1. Completed sales (`CompleteSaleCommand`)
2. Partial and full customer returns (`SaleReturnCommand`)
3. Eligible original-date sale voids (`SaleVoidCommand`)

All operations atomically update the source candidate records (`AccountDocument` within `PortableJournalState`), record immutable double-entry restaurant journals (`PortableJournalEntry` in `journals`), and persist durable command receipts/outcomes via Madar's `DurableCommandCoordinator`.

### Ownership Boundaries

As instructed, this sub-agent owned **strictly and only** the four new paths:
- `lib/accounting/restaurant_journal_sale_commands.dart`
- `test/accounting/restaurant_journal_sale_commands_test.dart`
- `test/accounting/restaurant_journal_sale_conformance_test.dart`
- `docs/log/2026-11-07-durable-sales-composition.md`

All existing dirty and untracked work across the repository was strictly preserved untouched. Existing `SaleProposal`, `ReturnProposal`, `RestaurantJournalMapper`, `PortableJournalCodec`, `PortableJournalState`, UI components, repository bootstraps, and engine files were reused through their public APIs without modification.

No commits, branches, PRs, worktrees, or build exports were initiated.

## Storage & Environment Measurements

| Metric | Last Root Measurement | Post-Implementation Measurement | Delta |
| --- | --- | --- | --- |
| Available Disk Space | 115,612,716 KiB | 115,472,040 KiB | -140,676 KiB (plenty > 10 GiB free) |
| App Git Size (`.git`) | 18,418,820 KiB | 18,419,048 KiB | +228 KiB (stable, << 2 GiB limit) |
| Engine Git Size (`../Madar_Engine/.git`) | 36,612 KiB | 36,612 KiB | 0 KiB (untouched) |
| Temporary Stores (`/tmp`) | 0 | 0 | 0 |
| Engine Git Commit | `d316fd6076375daa3f412889f73eaebfeeb5d4d4` | `d316fd6076375daa3f412889f73eaebfeeb5d4d4` | verified identical |
| App Git HEAD | `cc91fae438101fce7ff4729e12bf3c2b64dacd70` | `cc91fae438101fce7ff4729e12bf3c2b64dacd70` | verified identical |

## Implementation Architecture

### 1. Frozen Inputs & Command Immutability
- Commands deep-freeze caller maps and lists recursively upon construction into `Map.unmodifiable` and `List.unmodifiable`.
- External caller mutation after command instantiation has zero effect on command execution. Direct mutation attempts throw `UnsupportedError`.

### 2. Complete Versioned Canonical Payload Identity
- Bounded, deterministic, sorted JSON payload identity derived from all command intent, financial fields, version, lineage, and fence parameters.
- Any change to financial amounts (discount, quantity, price, scale), intent (order type, note, date, reason), or `payloadVersion` results in an identity mismatch on replay, causing `DurableCommandCoordinator` to reject replay with `changed_payload_rejected` without writing to disk.

### 3. Lineage Validation Across All Paths
- `RestaurantJournalSaleCommandCoordinator` verifies `currentState.accountLineage == command.accountLineage` directly against the stored snapshot **before** delegating to the coordinator, guaranteeing that account lineage mismatches fail closed without replaying.
- Lineage is re-checked inside `proposal(state, fence)`.
- Lineage is re-checked on the final snapshot returned after writes or re-reads.

### 4. Storage Fence Isolation
- Commands capture caller-owned `StorageFence? expectedFence`.
- If fence generation or storeId has changed (e.g. after database restore/replacement), commands reject with `stale_authority_fence`.

### 5. Cutover Gating & Cross-Cutover Integrity
- Gated cutover state (`cutoverState.isGated == true` or `hasActivePosting == false`) refuses posting (`cutover_gated`).
- Operations dated prior to the established cutover date fail closed (`pre_cutover_operation_rejected`).
- Returns and voids against sales that have no eligible post-cutover journal fail closed under the cross-cutover gate (`cross_cutover_source_has_no_post_cutover_journal`).

### 6. BigInt Metadata Snapshot Composition
- Proposals' `BigInt` metadata values (`'gross'`, `'discount'`, `'net'`, `'amount'`) are converted to explicit exact decimal strings without altering mapper/domain values.
- Persists source version (`'sourceVersion'`), receipt number (`'receiptNumber'`), operation ID (`'operationId'`), and record IDs in `PortableJournalEntry.metadata`.
- Guarantees valid JSON serialization and prevents precision loss.

### 7. Zero-Value Source Compatibility
- Commands accept optional `JournalPolicy? policy`.
- Zero-net sales or zero returns fail under standard policy (`allowZeroLines: false`), but succeed cleanly with balanced zero lines when passed `RestaurantJournalPolicies.allowZero`.

### 8. Negative Cash & Financial Policies
- Permitted negative daily cash is preserved.
- Customer returns (refunds) debit sales-return contra-revenue and credit daily cash on the return date.
- Sale voids reject any sale with partial/full returns in source or journals (`void_ineligible_sale_has_returns`), reject already voided sales (`sale_already_void`), and strictly reverse on the original sale date.

## Verification & Conformance Evidence

1. **Unit Test Suite (`test/accounting/restaurant_journal_sale_commands_test.dart`)**:
   - 12 test cases covering input freezing, canonical payload identity determinism and sensitivity, BigInt decimal string composition, zero-net policy handling, pre-cutover date rejection, cumulative return calculations, cross-cutover journal gates, over-return rejection, original-date void reversal invariants, return-blocked voids, and outcome roundtripping.
   - Result: 12/12 passed (100%).

2. **Store Conformance Test Suite (`test/accounting/restaurant_journal_sale_conformance_test.dart`)**:
   - 11 real-store integration tests using `PowerSyncLocalDocumentWorkspaceStore` and `DurableCommandCoordinator`.
   - Tested scenarios:
     - Atomic persistence across source records, immutable journals, and receipts.
     - Idempotent replay without store revision increments or state mutation.
     - Tampered command replay rejection with `changed_payload_rejected` leaving disk state untouched.
     - Changed payload version rejection.
     - Lineage mismatch rejection before replay.
     - Stale generation storage fence rejection.
     - Rejection paths (gated cutover, over-return, ineligible void) leaving revision and payload 100% untouched.
     - Full sale -> partial return -> full return lifecycle with exact daily cash impact.
     - Eligible void lifecycle reversing on original date and preventing subsequent returns or duplicate voids.
     - Real store close and reopen from disk preserving complete state, journals, and receipts.
     - Uncertain acknowledgement resolution via `UnknownAckStore`, testing `resolvePendingWrite()` and re-read recovery.
   - Result: 11/11 passed (100%).

3. **Static Analysis & Formatting**:
   - `dart analyze lib/accounting/restaurant_journal_sale_commands.dart test/accounting/restaurant_journal_sale_commands_test.dart test/accounting/restaurant_journal_sale_conformance_test.dart` -> No issues found (0 warnings, 0 infos, 0 errors).
   - `dart format` -> applied cleanly.

## Non-Goals & Scope Limits

- This command slice is an isolated candidate layer under ADR 0021.
- All established cutovers in tests are synthetic and confer no live activation permission.
- Does not activate schema 12 in the running app, run migrations, alter runtime repository bootstrap, or make live UI postings.


## Root repairs after independent review 3f201e33

The first passing 23-case suite missed nine failure classes. Root added requirement-driven regressions: 11 of the first 12 new safety cases failed against the candidate; two extra reconciliation cases and one bounded-iterator case also failed before their remedies. The initial safety harness guessed a mapper method name; root corrected it against the actual method before the failing baseline.

Execution now requires a caller-captured expected fence before any store read. Pure proposal values can remain unbound for unit evaluation, but executing an unbound value returns missing_authority_fence. All real-store tests now capture authority before constructing commands. The optional injected coordinator must reference the identical store owner; otherwise construction fails before I/O.

The app no longer performs its own redundant pre-read/recovery loop. It delegates reads, cancellation, exceptions, pending-write resolution, CAS and unknown acknowledgements to the reviewed Madar coordinator. A per-command codec wrapper checks app lineage at every decode, extraction, attachment and encode, including replay/rereads. No final callback turns a durable success into a false failure.

Command drafts and return iterables materialize once before canonical identity generation. JSON snapshots reject cycles, depth >=100, unsupported types, malformed Unicode, unsafe integers and payloads above the 20 MiB store bound; return iteration stops at the canonical source sales limit of 200 lines. Typed policy/quantity BigInt fields serialize as explicit decimal strings. Raw BigInt values in untyped draft maps fail rather than colliding with string values. Outcome metadata uses detached recursive snapshots; equality/hash include the canonical metadata content and toString redacts financial details.

Receipt overrides must match the actual generated source number. Return/void evaluation verifies a unique original posting against source receipt, date, recording timestamp, mapped journal lines and exact gross/discount/net snapshots. Returns also reject reversed postings. Replay validates the matching receipt outcome against its saved journal and source before receipt matching. Root first attempted rejection by throwing in replayedOutcomeMapper; the generic engine intentionally isolates that presentation callback, so it returned a replay without a mapped outcome. Root moved validation into codec receipt extraction, the actual rejection boundary. No engine behavior was weakened or duplicated.

The original review's suggestion that mutating outcome metadata also mutates PortableJournalEntry metadata overstates the alias defect: PortableJournalEntry already deep-copies it. The returned outcome was mutable and its equality omitted metadata; those real defects are fixed. The review found no admissible gross-aggregation arithmetic discrepancy. Root nevertheless routes source quote recomputation through existing CommerceCalculations rather than an app-owned addition loop.

Verification: all 856 Flutter tests pass on the repaired revision, including 40 sales command/unit/real-store/safety cases. Full static analysis and exact engine source/pin guard pass. A real-store test injects acknowledgement loss after a durable write, resolves and reopens with exactly one sale, one sale journal and one receipt; this is not an OS crash or power-loss proof. A completed sale still replays its original outcome after a later valid void. The earlier initial-read-unknown test remains a separate scenario.

Root repair overhead: a scripted constructor edit left two extra opening braces; formatting caught it before compilation. One existing const outcome fixture needed a runtime constructor after snapshots became validating. A brittle insertion marker failed once and caused one unnecessary unchanged-source test run; root used a stable final block afterward. Analysis caught one redundant assertion and eight brace hints, all corrected. Existing reviewed portable codec, mapper and C1 source hashes remain unchanged.

Limits: this isolated command layer still has no runtime repository/bootstrap/UI activation. Opening values, cutover date, migration/rollback, broader F-09 reconciliation, expense/purchase commands, C3 UI, native acceptance, benchmarks, CI and release remain separate obligations. Existing C1/portable verification is reused by unchanged hashes.

Storage closeout: 115434740 KiB available, app Git18419316 KiB (+184 from intake), engine Git36612 KiB unchanged, build639572 KiB (+47680), dart_tool204852 KiB unchanged, review outputs1868 KiB (+4). Volume free variation−41112 KiB is unattributed. Retain source/tests, current caches and compact receipts; preserve unique recovery/design evidence. No bulk build/export or unsafe cleanup occurred. Temporary root test logs are disposable after compact result extraction.

Final identity follow-up: a new failing case showed return/void canonical payloads trimmed the submitted reason before identity calculation. The source still uses its established trimmed reason, but canonical identity now retains the exact submitted string so changed intent text cannot reuse a payload identity. Final source-bound full suite: 857 Flutter tests pass, including 41 focused sales cases. This supersedes the immediately prior 856/40 intermediate count. Recheck input hashes were regenerated before delegation; no previously dispatched review was invalidated.

API/setup/example/error/limit reference: docs/reference/durable-sales-commands.md. No runtime caller or shared engine source changed with this documentation.

Removed seven completed root-owned /tmp test logs after extracting compact results; reclaimed 206935 bytes. Retained canonical source/tests/manifests, active compiler caches and unique recovery/design evidence. No active fixture or uncertain data removed.

Independent recheck c237c174 matched all nine inputs, passed 41 focused cases and six removed disposable probes, and found no new blockers in this isolated slice. It confirmed all nine original repairs plus source/outcome and post-void replay behavior. Runtime activation and the listed downstream obligations remain open. The next spending slice may factor the app command host; any such source change needs its own compatibility verification/review and does not retroactively alter this receipt.
