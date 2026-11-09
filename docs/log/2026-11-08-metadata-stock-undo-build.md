# Metadata and stock session undo adapters — 2026-11-08

Status: metadata3/3 and stock2/2 focused checks pass; targeted analysis clean. Root owns observer wiring and overall undo completion.

## Scope and contract

Owner build-first direction keeps full tests, benchmarks, visual qualification and independent review deferred. This app-owned source mapping consumes existing Madar exact values, inventory invariants and store/CAS contracts; Madar implementation/revision changes are N/A. No engine copies, synthetic durable receipts, schema bootstrap, live migration/cutover, real-account access or Git mutation.

`MetadataSessionUndoAdapter(repository:, bridge:, label:)` implements the `FinancialUndoAdapter` contract. `MetadataUndoPlan.prepare(before:, after:, current:)` validates source-only transitions and creates a current-state compensation. It restores changed product/category/supplier/material fields, preference leaves and chicken counts. It preserves unrelated fields/records, financial source, journals, receipts, provenance, dirty workspace and current lineage/fence authority. A changed target field, opening-debt mutation, financial transition, stock movement mutation or collection reorder fails closed. Arrays such as shortcuts are atomic fields; a later conflicting list edit is protected. Source validation still runs over the complete candidate.

`captureMetadataUndoAttempt` captures the existing repository/bridge authority and delegates commit to existing repository or inventory command ownership. Unknown saves retain exact repository token/payload evidence and use repository reconciliation; no workspace refresh/write occurs. The shared session undo controller receives an acknowledged complete snapshot through its metadata result path, without inventing a financial receipt.

`StockMovementSessionUndoAdapter(repository:, bridge:, reason:, label:)` handles one standalone newly appended movement. It delegates the compensation to existing `InventoryCommands.reverseMovement`, retaining the original row and appending a reasoned original-date inverse. It refuses source changes, already reversed targets, reversal-of-reversal and coupled product/stock creation. Existing inventory validation blocks negative historical stock. Coupled product creation plus opening stock still needs a true atomic compensation API; no sequential partial rollback or erased movement history is claimed.

## Focused evidence and attempts

Metadata tests: `flutter test --no-pub test/accounts/metadata_session_undo_test.dart` → 3/3 passed. They cover restoration over later unrelated product-price and financial-expense changes, exact unknown compensation readback without a second revision, dirty workspace preservation, and conflicting/financial transition refusal. Targeted analyzer over metadata adapter, stock adapter and metadata test: no issues.

Initial analyzer found a missing explicit fence argument in the workspace fixture and two brace infos; corrected only owned files. Initial metadata run passed2/3: the observer was initialized after the metadata commit, so its duplicate-after registration path returned success without adding an entry. Corrected the fixture to initialize before the event, matching actual session composition. No product fix addressed this observer mistake. Compiler released to root then sales; stock checks queued after sales.

Baseline available96,156,848KiB. Source/helper/test/log files are canonical integration and regression evidence. No exports, native builds or duplicate task scratch outputs created.

Root must suppress undo registration for its own in-flight compensation and include this compact log in coordinated Markdown memory synchronization. No overall undo or phase completion claim follows from these bounded adapters.

## Stock check completion

`flutter test --no-pub test/inventory/stock_session_undo_test.dart` → 2/2 passed. Checks retained original-date history/inverse, unchanged financial envelope, refusal of reversal-of-reversal, and no-write refusal when undoing a restock would leave later negative stock. Initial1/2 result expected insufficient_stock, but the canonical account codec rejects that candidate earlier with invalid_payload; corrected the observer assertion to actual established error boundary, preserving no-write/source assertions. No product fix changed negative-stock behavior. Final targeted stock adapter/test analysis reports no issues. Compiler released to settings/date owner.

Storage closeout: available96,116,132KiB (40,716KiB below baseline across concurrent workers). .git18,439,356KiB and outputs7,398,508KiB unchanged; build2,142,684KiB. Canonical new sources/tests/log retained; no owned obsolete or duplicate artifacts, reclaimed0bytes. Global disk delta has no exclusive attribution; threshold not approached. Root will coordinate memory sync/check.

Account-only reuse follow-up: MetadataUndoPlan.prepareAccounts(before:AccountDocument, after:, current:) now owns the original whitelist/patch implementation; portable prepare adds lineage/envelope guards and delegates to it. Existing3metadata cases passed after that refactor. Root owns normal schema11 observer composition; no fabricated portable state or durable receipt was introduced.
