# Completion category metadata ViewModel & test evidence (C4-01, C4-02, C4-03)

Date: 2026-11-07.
Scope: Objective nonvisual foundations for C4-01 and C4-02, plus selector-ready C4-03 presentation contract.
Sole owned implementation:
- `lib/accounting/categories_view_model.dart`
- `test/accounting/categories_view_model_test.dart`
- `docs/log/2026-11-07-completion-category-view-model.md`

## Implemented architecture & semantics

1. **Presentation & classification contract (C4-01)**:
   - Exposes strongly-typed `CategoryRecord` and `CategoryType` (`primary` / `additional`).
   - Categorizes account-scoped categories into `allCategories`, `activeCategories`, `primaryCategories`, `additionalCategories`, and `archivedCategories`.
   - Preserves frozen source ordering and Arabic names for the 4 core built-in categories (`samoon` -> 'الصمون', `bread` -> 'الخبز', `falafel` -> 'الفلافل', `market` -> 'الأسواق').
   - Implements automatic type saving via `setCategoryType(id, type)`. Switching classification directly commits through `repository.save`, advancing account snapshot and fence authority. Setting an existing type is a no-op that produces zero storage writes.

2. **Built-in restrictions & custom archive/restore (C4-02)**:
   - Enforces built-in identity immutability: built-in categories cannot be deleted, cannot be renamed, and cannot be archived (`isArchived == false` strictly preserved).
   - Allows custom categories to be archived via `archiveCategory(id)` and restored via `restoreCategory(id)`.
   - Prevents creation of custom categories using reserved built-in identifiers.
   - Archive and restore operations preserve existing historical references in days, daily expenses, supplier defaults, and payments without rewriting history.

3. **Validation & normalization (C4-02)**:
   - Normalizes category names via whitespace trimming.
   - Validates that names are non-empty and bounded to 80 characters.
   - Prevents duplicate category names (both exact and case-insensitive) across active and archived categories.
   - Enforces the codec maximum bound of 500 categories.
   - Draft retaining: validation and persistence failures retain all user draft inputs and set `lastErrorCode`/`lastErrorMessage` rather than clearing user input.

4. **Active selectors & inline creation (C4-03)**:
   - Exposes `selectorChoices({String? currentCategoryId})`: returns all active unarchived categories for new entries, but includes the referenced archived category if `currentCategoryId` matches an archived record, ensuring historical expense and payment selections remain valid and visible.
   - Provides `createInlineCategory({required String name, CategoryType type, String? id})` to support immediate inline creation from expense entry forms, returning the committed `CategoryRecord` with its stable ID.
   - Preserves historical references across all existing days, payments, and supplier links.

5. **Concurrency, fencing & disposal safeguards**:
   - `_busy` lock prevents overlapping conflicting writes.
   - Authority fencing ensures drafts check `repository.document` and `repository.snapshot` before and during persistence. Stale drafts fail cleanly with `conflict`.
   - Rejects writes when `repository.hasUnknownWrite` or `hasUnknownWorkspaceWrite` is active with `commit_unknown`.
   - Disposed ViewModel safe guards: `_disposed` and `_notificationDepth` prevent late callbacks or notifications after controller teardown.

## Test execution & verification

All 17 dedicated unit tests pass with zero failures:
Command: `flutter test --no-pub test/accounting/categories_view_model_test.dart`
Results:
- `CategoriesViewModel presentation contract (C4-01 / C4-03) initializes with 4 built-in categories in order with Arabic names`: PASS
- `CategoriesViewModel presentation contract (C4-01 / C4-03) selectorChoices includes active categories and includes current archived category if referenced`: PASS
- `Classification & automatic type save (C4-01) switching category type triggers automatic save and survives repository reopen`: PASS
- `Classification & automatic type save (C4-01) setting the same type is a no-op that writes zero bytes`: PASS
- `Category create, edit & inline creation (C4-01 / C4-02 / C4-03) creates custom category with stable ID and survives restart without altering history`: PASS
- `Category create, edit & inline creation (C4-01 / C4-02 / C4-03) createInlineCategory creates category immediately and is selector-ready`: PASS
- `Category create, edit & inline creation (C4-01 / C4-02 / C4-03) edits custom category and preserves stable identity for historical references`: PASS
- `Built-in category restrictions (C4-02) built-in categories cannot be renamed`: PASS
- `Built-in category restrictions (C4-02) built-in categories cannot be archived`: PASS
- `Duplicate validation & normalization (C4-02) rejects duplicate name matching existing category exactly or with whitespace trimming`: PASS
- `Duplicate validation & normalization (C4-02) rejects empty or whitespace-only name`: PASS
- `Duplicate validation & normalization (C4-02) rejects name exceeding 80 characters`: PASS
- `Archive & restore lifecycle (C4-02) custom category can be archived and restored without losing historical records`: PASS
- `Fencing, stale draft, overlapping saves & unknown writes stale draft cannot overwrite intervening category changes and retains draft fields on failure`: PASS
- `Fencing, stale draft, overlapping saves & unknown writes concurrent overlapping save is rejected with busy code`: PASS
- `Fencing, stale draft, overlapping saves & unknown writes reconciliation required if repository has unknown write`: PASS
- `Fencing, stale draft, overlapping saves & unknown writes disposed ViewModel rejects operations safely without calling listeners`: PASS

Static analysis:
Command: `flutter analyze --no-pub lib/accounting/categories_view_model.dart test/accounting/categories_view_model_test.dart`
Result: `No issues found! (ran in 0.7s)`

Regression verification:
Command: `flutter test --no-pub test/accounting/daily_cash_queries_test.dart test/accounts/codec_test.dart test/parties/parties_view_model_test.dart test/catalog/catalog_view_model_test.dart`
Result: `All 348 tests passed!`

## Storage delta & containment

- Pre-work available space: 114,042,732 KiB
- Post-work available space: 115,059,940 KiB
- Pre-work Git directory size: 18,415,304 KiB
- Post-work Git directory size: 18,415,376 KiB
- Git delta: +72 KiB (untracked code, tests, and evidence log only; well below the 2 GiB threshold)
- Temporary stores created: 0

## Limits & boundary statement

- This delivery covers nonvisual ViewModel and controller logic for C4-01 and C4-02, and the presentation/selector contract for C4-03.
- Checklist rows C4-01, C4-02, and C4-03 are NOT marked complete in `completion-unfinished-checklist.md` because UI widget mounting, Flutter dialog rendering, supplier/payment integration, and independent review remain pending.
- Existing worker files (`PartiesViewModel`, `CatalogViewModel`, `AccountsRepository`, `LegacyAccountCodec`, routes, and financial commands) were strictly preserved without edits.


## Root review fixes — 2026-11-07T14:23:29.324040+00:00

Independent review found four source/controller defects despite17passing worker tests. Four new regressions in test/accounting/categories_source_parity_test.dart all failed before fixes. Root now captures all submitted fields before listener notification, uses frozen case-sensitive name equality, notifies validation errors/records write failures/clears errors on success, and preserves document order when including an archived referenced selector choice.21categorytests pass; the full accounting directory42tests and targeted5fileanalysis also pass. Snapshot/authority and no-write busy safeguards remain intact. UI, named category designs, native verification and fresh independent recheck remain pending.

Engine change: N/A for this category correction; account metadata/workflow belongs to Dakhl_Restaurant and uses the existing reviewed store contract. Current shared coordinator work is separately owned in Madar. Source hashes: outputs/completion-review/review-fix-inputs.json.


Independent review73dfce71 on 2026-11-07T14:55:29.501229+00:00 verified matching source hashes and closed all four category findings with21focused category tests. This clears the nonvisual controller slice only. Category UI/design discrepancies and native integration remain open.
