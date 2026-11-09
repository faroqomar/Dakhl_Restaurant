# C1 Catalog, Product Photo & Inventory UI Integration Log

**Date:** 2026-11-07  
**Author:** Implementation Sub-Agent (Antigravity harness / T3 Code)  
**Status:** Completed & Verified  

---

## 1. Engine Pin & Runtime Environment

- **Engine Repository:** `Madar_Engine` (sibling checkout at `../Madar_Engine`)
- **Engine Git Commit:** `d316fd6076375daa3f412889f73eaebfeeb5d4d4`
- **Application Package:** `madar_application: 0.1.0-dev.4` (`../Madar_Engine/packages/application`)
- **Domain Package:** `madar_domain: 0.1.0-dev.5` (`../Madar_Engine/packages/domain`)
- **Data Package:** `madar_data: 0.1.0-dev.2` (`../Madar_Engine/packages/data`)
- **Flutter Adapters Package:** `madar_flutter_adapters: 0.1.0-dev.1` (`../Madar_Engine/packages/flutter_adapters`)
- **Pin / Lockfile Ownership:** Untouched by sub-agent; maintained by root owner.
- **Source Guard / Enforced Offline Pub Resolution:** Passed without modification.

---

## 2. Design Approval & Scope

Implementation conforms to approved design specifications documented in:
- `docs/phases/c1-design-approval.md`
- `outputs/completion-review/c1-design-approval.json`
- 15 C1 design/wireframe pairs and 5 Phase02 pattern-reuse proposals approved on 2026-11-07.
- UX Guidelines: `.impeccable.md` (single-restaurant offline Arabic RTL, IQD currency, exact quantities scale 3, responsive 320px–1440px with 200% font scale, accessibility semantics).

---

## 3. Implemented Presentation Components

All UI presentation code was developed strictly under `lib/catalog` and integrated into the shell in `lib/app/app.dart`:

1. **`lib/catalog/catalog_formatters.dart`**:
   - Money and quantity formatters with comma thousands grouping and trailing zero stripping.
   - Quantity parser enforcing thousandths (scale 3) and max absolute units $10^{12}$ via `ExactDecimal`.
   - Date parsing using `DateOnly.parse(text, minimumYear: 1000, maximumYear: 9999)`.
   - Caller-owned ID generator and Arabic domain error code mapping.

2. **`lib/catalog/product_form_dialog.dart`**:
   - Product create (`showProductCreateDialog`) and edit (`showProductEditDialog`).
   - Integrated `ProductPhotoDraftController` with reference photo selector (8 canonical keys: `beef-kebab`, `chicken-kebab`, `tikka`, `quarter-chicken`, `half-chicken`, `rice-plate`, `tea`, `water`).
   - Clean removal of photos updating draft to null.
   - Unit, minStock, price, trackStock toggle, opening stock movement for new products.
   - History locks for existing products with prior stock movements or sales.
   - Dirty form shell protection with confirmation dialog on cancellation.

3. **`lib/catalog/stock_movement_dialog.dart`**:
   - Restock, signed adjustment, and loss/waste movements (`showStockMovementDialog`).
   - Maps loss to `StockEntryKind.adjustment` with negative units and note prefixed with `تالف: `.
   - Enforces required notes for adjustment and loss.
   - Effective date parsing and validation.

4. **`lib/catalog/stock_reversal_dialog.dart`**:
   - Reasoned reversal workflow (`showStockReversalDialog`).
   - Retains original movement trace, links via `reversesId`, preserves effective date.
   - Rejects reversal if it would cause negative historical balances.

5. **`lib/catalog/stock_history_dialog.dart`**:
   - Stock history movement ledger (`showStockHistoryDialog`).
   - Chronological composition of `stockEntries`, completed `sales`, and `saleReturns`.
   - Running balance computation and future dated movement badge.
   - Downstream link stubs for sales and returns (C1-16, dependent on C3 sale history).

6. **`lib/catalog/inventory_surface.dart`**:
   - Root `/inventory` route surface.
   - Low-stock attention banner with quick filter button.
   - Filter bar supporting search query, stock status, and category group dropdowns.
   - Responsive presentation: wide `DataTable` vs narrow card list.
   - 50-item pagination with next/previous controls.
   - Empty inventory placeholder (`empty-inventory`).

7. **`lib/app/app.dart`**:
   - Composed `/inventory` route mounting `InventorySurface(model: _catalogViewModel, accounts: accounts, shell: _model)`.
   - Controlled lifecycle: `_catalogViewModel = CatalogViewModel(accounts.repository)` and clean disposal.

---

## 4. Verification Receipts

### 4.1 Analyzer Status
```
$ flutter analyze lib/catalog/ lib/app/app.dart test/catalog/
Analyzing 3 items...
No issues found! (ran in 8.7s)
```

### 4.2 Test Suite Execution
All new and existing catalog/app tests passed (61 total passing tests across suites):
```
$ flutter test test/catalog/ test/app/app_test.dart
...
00:07 +61: All tests passed!
```

Breakdown of new C1 test suites:
- `test/catalog/inventory_surface_test.dart`: 7 tests passing (loading state, empty inventory, responsive layout at 320px/200% font scale, pagination with 120 items, status filtering, table headers/badges).
- `test/catalog/product_dialog_workflow_test.dart`: 5 tests passing (product create with reference photo and opening movement, history lock on unit/trackStock, validation failure retaining input, archive/restore toggle, photo removal).
- `test/catalog/stock_movement_workflow_test.dart`: 5 tests passing (restock movement, adjustment movement, loss movement with required reason, reasoned reversal with `reversesId`, stock history ledger with running balance and future badges).
- `test/catalog/shell_inventory_integration_test.dart`: 3 tests passing (navigation to `/inventory`, dirty form shell protection with discard dialog, null accounts graceful handling).

---

## 5. Storage Baseline & Growth Closeout

- **Baseline Available Space:** ~111 GiB
- **Closeout Available Space:** 108 GiB (comfortably exceeds the $\ge 10\text{ GiB}$ threshold; growth $< 2\text{ GiB}$)
- **File Integrity:** Preserved all dirty and untracked files from other agents; no blanket cleanup; no commits, branches, or tags created.


## Root repairs after independent code and UX reviews

The initial 61-test pass missed connected workflow defects. Five of six new regression cases failed before repair; the UUID loop also reproduced duplicate timestamp identities. Root replaced timestamp IDs with UUIDv4 values, captured stock/reversal/archive edit sessions at form opening, guarded busy submissions and stale completion effects, and rebuilt the mounted inventory from account notifications after replacing its disposed ViewModel. Numeric price/minimum-stock inputs now use exact validation; malformed values retain input instead of becoming zero. Opening zero quantities remain optional without generating a movement.

The inventory reads one complete projection per build. Its warning count covers all active tracked products across pages and excludes untracked products; inventory group options retain archived-only groups. Stock history composition moved into app read data/ViewModel, calls Madar exact binary64 summation, includes raw-ID tie-breaking and caches by immutable account snapshot. Presentation pages contain 50 newest-first rows while preserving original running balances. Tests verify 120-event paging, same-timestamp ID ordering, future/current date isolation and actual negative-result reversal rejection without writes. Existing pagination tests now tap the rendered controls; the misleading reversal test name and duplicate assertions were corrected.

Root found an additional dismissal defect missed by both independent reviews: top-level modal helpers passed no canDismiss callback, so header/Escape/barrier dismissal bypassed form state and native back had competing nested guards. Four composed dismissal regressions failed before repair. All modal dismissal paths now call the same captured form guard; cancellation keeps input and dirty state. Acknowledged archive operations refresh only their own form authority and preserve pending photo selection.

Verification on the repaired revision: 94 catalog/all-app tests, 816 full Flutter tests and 140 frozen Electron reference tests pass. Affected analysis and engine source/pin checks pass. An initial test compilation attempt omitted a required productId and used guessed labels; root corrected the harness against the actual widget contract before the failing baseline. One scripted modal-helper replacement touched the preceding enum delimiter; formatting caught it, root repaired it, and the composed regressions pass. The first numeric validation repair changed an existing negative-price message; root retained that error while rejecting malformed values.

The original 11 widget capture PNGs and their manifest are canonical evidence for their recorded initial source hashes. Root inspected desktop inventory and phone create captures; the repaired revision needs focused independent verification. These are widget renders with synthetic fixtures, not native-device proof. Live screen-reader execution stays owner-excluded. No continuous input formatter is added: exact submission parsing handles Arabic digits/grouping without an unapproved typing policy.

Open limits: C3 receipt/return navigation is still pending. Lexical raw-ID comparison covers current UUID examples but does not prove arbitrary legacy localeCompare ordering; a shared reviewed collation capability remains an integration obligation. Device operation measurements, native acceptance, hosted CI, merge/release and broader design approval stay separate. No C1 row closes from the root pass. Shared engine implementation N/A for this repair: existing reviewed exact arithmetic and stock contracts suffice.

Storage repair closeout: 115775040 KiB available; app Git 18418552 KiB (+484 from codec closeout), engine Git 36612 KiB (−52), build 639584 KiB (+47844), dart_tool 204852 KiB (unchanged), review outputs 1852 KiB (+1632), including 1628 KiB canonical initial C1 widget captures. Zero temporary Git stores in both repositories. Volume free space increased 1214256 KiB; cause unattributed. Retain source, reviewed recovery objects, current compiler caches and the single canonical visual set. Removed six completed root-owned /tmp test logs after compact result extraction, reclaiming 212343 bytes. No uncertain/active or unique recovery/design data deleted.
