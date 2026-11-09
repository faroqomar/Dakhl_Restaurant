# Nonvisual Sales ViewModel composition

Engine implementation/API/Design: N/A. App composes reviewed public quote/stock contracts and its existing TicketWorkspaceController at runtime pin d316fd6076375daa3f412889f73eaebfeeb5d4d4. No UI or account posting. Parent owns aggregate audit/prevention/memory.

## Attempts

2026-11-07T22:01:07.277390+00:00 — Ownership files absent. Hindsight searched and separate daftar/madar recall succeeded; current controller/catalog/quote source governs. Baseline free111888712KiB; app Git18423680KiB/engine Git41284KiB, build621656KiB/dart tool204860KiB. No subagents. First combined intake/prevention search exceeded output budget; bounded source slices restored decisive context. A guessed account_preferences.dart path was absent; subsequent work uses actual AccountDocument.preferences.

## Delivered API and boundaries

`SalesViewModel(repository)` privately constructs the existing typed workspace controller and binds the current StorageFence. `load`, `addProduct`, `setQuantity`, `removeProduct`, `updateDetails`, `hold`, `resume`, `deleteHeld` and `reconcile` expose observable immutable ticket state, errors and busy/readback status. `catalog`, `groups`, filters and80-row pages delegate to CatalogReadModel; `quote` delegates exact calculation to public Madar APIs and checks current dated stock/catalog eligibility. Editing incomplete discounts can persist an ineligible draft for recovery; quote eligibility never grants checkout permission. No manual price override, final-sale write, receipt allocation or UI widget is present.

Construct a fresh model after account generation replacement. A stale/disposed model hides its state and discards late results. Filter edits do not persist; draft edits preserve unrelated form data through the controller. The first product addition captures its current price; further quantity changes retain it.

## Executed verification and attempts

- Retained specification tests first produced a missing-file compilation RED, then13initial behavior tests passed. Added numeric/date boundaries made16cases; one expected `invalid_decimal` assertion was wrong for extra fractional precision. Public ExactDecimal reports `invalid_precision`; corrected the assertion. No production defect for that case.
- Source model.js96 quantity parsing accepts Arabic decimal separators and rejects exponents. A retained new regression failed against the initial ViewModel. Enabled the public parser's Arabic-decimal option; final17new cases and45sales-suite cases pass. The first repair script assumed obsolete formatter indentation, raised ValueError without mutation, then its shell still ran unchanged tests. Corrected the exact anchor and moved fail-fast before the edit. Both failed attempts remain explicit; no failed test is counted passed.
- Removed unused dart:async import after analyzer reported one unnecessary-import info. Final two-file analyzer reports no issues. Required unchanged frozen-reference `npm --prefix electron-reference test` passes140cases.
- Kept one private controller owner instead of an optional shared-controller injection seam, preventing external controller state from bypassing the ViewModel's observed snapshot.
- Covered80pagination/search/group reset, immutable fields and capture prices, exact fractional/zero/overflow quotes, source quantity syntax, missing/archived/dated-stock eligibility,40-held limit and swap/delete, definite failure and recovery, uncertain acknowledgement without repeat write, stale workspace revision, reentrant busy calls, listener disposal, late acknowledgement and account generation replacement.

## Evidence and remaining gates

Canonical manifest and receipt: `outputs/completion-review/sales-view-model/verified-inputs.json` and `receipt.json`. Retained logs record the meaningful red cases, final sales regression, analyzer and frozen-reference suite. No new disposable probe source or native/device store was created. Existing lower-level sales tests cover real-adapter reopen; the new ViewModel tests exercise composition with existing deterministic store fixtures.

Independent review belongs to the parent. C2 UI approval, route integration, checkout/receipt persistence, native acceptance and per-operation benchmarks remain pending. Runtime schema11, isolated journal candidates, engine source/pins and Git delivery remain unchanged. This does not close checklist rows. Parent owns aggregate tracker/prevention updates.

Closeout recorded 2026-11-07T22:09:33.218781+00:00: free110687204KiB; component sizes{".git": 18428044, "../Madar_Engine/.git": 41744, "build": 623664, ".dart_tool": 204860, "outputs/completion-review/sales-view-model": 96}; temporary Git stores{".git/objects": 0, "../Madar_Engine/.git/objects": 0}. Retain task outputs for independent review. No cleanup candidate was obsolete; reclaimed0B. Shared-volume/Git changes during concurrent work have no verified producer.


## Root repair and independent recheck

2026-11-07T22:36:00.843166+00:00: Initial independent review found one source-parity defect in default plus with fractional stock. Root's three regressions first required a mutable JSON fixture copy, then failed for the intended behavior. The fix preserves explicit quantity rejection, captured price and exhausted-state identity.20focused/48sales tests pass with clean analyzer; fresh focused reviewer checks7hashes and five actual frozen expression cases and passes. Source/API guide: docs/reference/sales-view-model.md. Canonical successor evidence: outputs/completion-review/sales-view-model/repaired-1/. Original manifest/receipt remain historical. No route/UI/checkout/schema or native activation.
