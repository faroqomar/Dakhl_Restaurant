# C1-04 Implementation Evidence: Catalog Product-Photo Selection, Validation, Draft & Controller

## Current parent-corrected candidate

The initial worker narrative below is historical and **does not describe the current API**. Independent review found scope/persistence, acknowledged-baseline, opening-stock, ID, mutable-byte, busy and authority defects. Parent removed custom native-file input, magic-header/5MiB policy, preview bytes and photo-source enum. Current scope matches the frozen eight-key reference selector; Madar file/image adapter change is N/A. Bundled asset bytes match the preserved Electron files in the current tests.

Caller supplies the product ID and any already-constructed exact InventoryMovement. This controller performs no opening quantity arithmetic or hidden clock/ID generation. Photo selection/removal reject while busy; unsaved choices do not replace the acknowledged baseline. Save binds to the form's captured document/snapshot, so passing a fresh session after account replacement cannot retarget an old draft. Success acknowledges only the submitted photo and keeps newer metadata edits; lifecycle guards prevent dispatch after listener disposal and suppress late notifications after dispatch.

Parent wrote four requirement regressions before fixing code: all four failed against the initial implementation (baseline corruption, busy mutation, fresh-session retarget and disposal-before-dispatch). After correction, all four pass. Replacement tests now cover the eight bundled files, codec/export/reopen, acknowledged replacement/removal, failed/unknown save retention, caller-owned exact opening metadata and disposal outcomes. Current focused run: **24 passing tests** across both photo suites plus existing catalog VM/read-model suites. Initial targeted analysis found three style issues; the first style fix then exposed Dart public named-argument spelling for private initializing formals (three compile errors and one unused-parameter warning). Parent corrected the call sites, reran analysis clean and reran all24targeted tests successfully. Independent focused recheck, approved UI mounting and native acceptance remain pending. This evidence closes no full checklist row.

The current draft constructor is library-private; callers create account-bound forms through the controller factories. Public metadata fields remain editable; photo mutation uses controller actions to keep preview and persisted key consistent. No real accounts, native dialogs, application routes, engine pin or existing inventory/codec implementation changed.

## Historical worker handoff (superseded API and limits)

**Objective:** Nonvisual implementation of C1-04 (source-compatible photo selection, preview model, replacement/removal, accepted photo representation, and durable acknowledged product save using existing guarded edit session).
**Date:** 2026-11-07
**Component Ownership:** NEW app catalog product-photo selection/validation/draft/controller module (`lib/catalog/product_photo_draft_controller.dart`), dedicated test suite (`test/catalog/product_photo_draft_controller_test.dart`), and owned evidence log (`docs/phases/c1-04-product-photo-evidence.md`).

---

## 1. Scope and Boundaries

- **Preserved Existing Components:**
  - Existing `lib/catalog/catalog_view_model.dart`, `lib/inventory/inventory_commands.dart`, `lib/accounts/legacy_account_codec.dart`, and application routing were **not edited**.
  - Composed exclusively through their public APIs (`CatalogViewModel.createProduct`, `CatalogViewModel.editProduct`, `CatalogViewModel.beginEdit`, `CatalogEditSession`, and `AccountsRepository`).
- **Single-Restaurant & Offline Guarantees:**
  - Zero cloud/auth dependencies; purely local, offline-first.
  - Arabic RTL localized labels ('كباب لحم', 'دجاج مشوي', etc.) preserved exactly from frozen Electron reference `app/ui/commerce.js`.
- **Reusable Adapter Boundary & Madar Gap Report:**
  - Composed Madar's `FileTransferCapability` and `NativeFileTransfer` from `madar_application` and `madar_flutter_adapters`.
  - **Identified Reusable Adapter Gap:** Madar's `FileTransferCapability.open()` transfers raw bounded `Uint8List` bytes only; it does not surface file names, MIME types, or image dimensions. The consumer module inspects magic bytes (WebP: `RIFF...WEBP`, PNG: `\x89PNG\r\n\x1a\n`) to validate format and bounded size (5 MiB limit), and maps selections to the frozen schema's canonical keys without embedding engine I/O inside the app.

---

## 2. Implemented Architecture

### A. Accepted Photo Representation & Schema Conformance (`ProductPhotoReference`)
- Strict parity with `LegacyAccountCodec._photos` and Electron reference `M.productPhotos`:
  - 8 canonical keys: `beef-kebab`, `chicken-kebab`, `grilled-chicken`, `dulaimiya`, `red-rice`, `appetizers`, `water`, `cola`.
  - Arabic localized labels:
    - `beef-kebab`: `كباب لحم`
    - `chicken-kebab`: `كباب دجاج`
    - `grilled-chicken`: `دجاج مشوي`
    - `dulaimiya`: `دليمية`
    - `red-rice`: `تمن أحمر`
    - `appetizers`: `مقبلات`
    - `water`: `ماء`
    - `cola`: `مشروب غازي`
    - `null` / empty: `بدون صورة`
  - Asset paths: `assets/ui/${key}-480.webp` (matching frozen 480px WebP runtime assets).
  - Validation: size limit bounded at 5 MiB (`maxPhotoBytes = 5 * 1024 * 1024`). Corrupt, empty, or unapproved keys (`../../private`, etc.) fail with clear diagnostic codes (`empty_input`, `photo_oversized`, `corrupt_photo`, `invalid_photo`).

### B. Preview Model (`ProductPhotoPreview`)
- Exposes:
  - `key`: Canonical photo key or null.
  - `label`: Arabic RTL label or `بدون صورة`.
  - `assetPath`: Local asset path or null.
  - `bytes`: Raw preview bytes (when selected via native transfer) or null.
  - `hasPhoto`: Boolean indicating active photo.
  - `source`: `PhotoSelectionSource` (`reference`, `nativeFile`, `none`).

### C. Draft Model (`ProductDraft`)
- Encapsulates product form fields (`id`, `name`, `code`, `unit`, `group`, `price`, `photo`, `trackStock`, `minStock`, `archived`, `openingQuantity`, `stockDate`).
- Implements `toImmutableSnapshot()` returning an unmodifiable map matching `LegacyAccountCodec` serialization.
- Prevents mutation during active save dispatches.

### D. Controller (`ProductPhotoDraftController`)
- Factory constructors:
  - `forNew(...)`: Drafts a new product with optional opening quantity/movement.
  - `forExisting(...)`: Drafts updates against an existing product loaded from `viewModel.repository`.
- Methods:
  - `selectReferencePhoto(String? key)`: Sets/updates canonical reference photo; preserves previous photo on invalid key.
  - `removePhoto()`: Clears photo to `بدون صورة`; updates draft.
  - `selectNativePhoto(...)`: Consumes Madar's `FileTransferCapability`. Preserves previous photo on cancellation, permission denial, corrupt bytes, or oversized payloads.
  - `saveProduct({required CatalogEditSession session})`: Performs guarded dispatch via `viewModel.createProduct` or `viewModel.editProduct`. Captures immutable submitted snapshot, guards against re-entrancy and busy state, handles stale revision rejections, preserves draft on failure, and avoids duplicate writes.
- Safe lifecycle & re-entrancy:
  - `_notificationDepth` tracking protects against recursive listener loops.
  - Suppresses notifications after disposal; safely completes delayed in-flight operations.

---

## 3. Verification & Test Evidence

### Test Suite: `test/catalog/product_photo_draft_controller_test.dart`
All 16 focused tests executed and passed:
1. `ProductPhotoReference schema conformance accepted canonical reference photos match frozen schema and Arabic RTL labels` (PASS)
2. `ProductPhotoReference schema conformance validates image header signatures and byte limits` (PASS)
3. `ProductPhotoDraftController photo selection and preview model initial state without photo has empty preview and valid draft map` (PASS)
4. `ProductPhotoDraftController photo selection and preview model selectReferencePhoto updates preview, notifies listeners, and rejects invalid key` (PASS)
5. `ProductPhotoDraftController photo selection and preview model replacement and removal of product photo` (PASS)
6. `ProductPhotoDraftController photo selection and preview model native file selection: cancelled preserves previous photo and product` (PASS)
7. `ProductPhotoDraftController photo selection and preview model native file selection: denial/failure preserves previous photo and product` (PASS)
8. `ProductPhotoDraftController photo selection and preview model native file selection: corrupt/unsupported bytes preserves previous photo and product` (PASS)
9. `ProductPhotoDraftController photo selection and preview model native file selection: oversized bytes preserves previous photo and product` (PASS)
10. `ProductPhotoDraftController photo selection and preview model native file selection: valid photo bytes with mapped reference key updates preview` (PASS)
11. `ProductPhotoDraftController durable acknowledged save creates new product with photo through guarded session and round-trips via codec` (PASS)
12. `ProductPhotoDraftController durable acknowledged save edits existing product to replace and then remove photo round-tripping durably` (PASS)
13. `ProductPhotoDraftController durable acknowledged save stale session rejection preserves draft input and previous photo without writing` (PASS)
14. `ProductPhotoDraftController durable acknowledged save busy rejection prevents duplicate save and preserves active draft` (PASS)
15. `ProductPhotoDraftController durable acknowledged save listener mutation cannot change submitted product and delayed save handles disposal` (PASS)
16. `ProductPhotoDraftController durable acknowledged save account replacement prevents save across authority changes` (PASS)

### Existing Regression Suite
- `flutter test test/catalog/catalog_view_model_test.dart test/catalog/catalog_read_model_test.dart`: 12/12 passed with zero regressions.

### Analyzer Receipt
- `flutter analyze lib/catalog/product_photo_draft_controller.dart test/catalog/product_photo_draft_controller_test.dart`:
  `Analyzing 2 items... No issues found! (ran in 3.1s)`

---

## 4. Storage Containment Delta

- Free disk space before: 118,115,844 KiB
- Free disk space after: 117,956,456 KiB (free disk remains ~112.5 GiB, well above the 10 GiB minimum threshold)
- Git directory size before: 18,414,524 KiB
- Git directory size after: 18,414,980 KiB (delta: +456 KiB, well below the 2 GiB growth ceiling)
- Tmpstores created: 0

---

## 5. Open Limits & Remaining Checklist Items

- **Nonvisual slice delivered:** The controller, draft model, preview model, and validation logic are fully verified nonvisually.
- **UI & Native Evidence Open:** Per plan rules and prompt constraints, UI widgets and native device invocation remain pending named design approval under Penpot and independent integration review. Checklist row C1-04 is **not** marked entirely complete until UI/native evidence and independent review are completed.
