# Completion nonvisual catalog and account settings

Date: 2026-11-07. Status: implemented candidate; independent review and UI/repository integration pending. The catalog read model and settings draft do not write. `AccountSettingsController.save()` persists through `repository.save`; this bounded foundation added no screen design.

## Catalog read model

`CatalogReadModel.fromAccount` takes a validated `AccountDocument` and a caller-supplied stock-balance snapshot in exact thousandths keyed by product ID. The caller must supply the correct business-date snapshot; this class does not compute stock or access storage. Missing balances follow the source's zero fallback. Product and page lists are immutable.

Sales exclude archived products, filter exact group plus case-insensitive name/code substring, preserve source order and page at80. Inventory searches name/code/group, supports active/all/archived/low/out filters and pages at50. Low means tracked quantity at or below the saved threshold; out means tracked zero. Both clamp pages to1..max(1,pageCount). Search text is not trimmed or digit-normalized because the frozen source does neither. Status labels preserve the source Arabic strings. Groups preserve first appearance among active products.

Source: `electron-reference/app/ui/commerce.js` sales/catalog and inventory functions; `ux.js` pageItems and inventoryMatches. `test/catalog/generate_catalog_oracle.cjs` extracts the actual frozen functions/filter statements and evaluates synthetic records under Node. It writes source hashes, input products and expected cases to `test/catalog/oracle.json`. Dart tests compare IDs, counts and clamped pages. No catalog save, stock arithmetic, product-history mutation, images or UI are implemented by this read model.

## Settings draft

`AccountSettingsValues` defensively copies active/disabled order types and shortcuts. `AccountSettingsDraft` tracks a raw editable baseline, supports replace/discard, and builds a validated candidate using the existing `LegacyAccountCodec` against the caller's current account. Restaurant fields are trimmed at save preparation, matching the source. The codec remains the authority for order-type counts/uniqueness, at least one active type, allowed shortcuts and string bounds; no validation backend is copied.

`prepareSave` preserves current non-preference records and leaves dirty state intact. It does not save or clear the draft after a failed write. `acceptSaved` is an explicit acknowledgement hook only: the repository caller must confirm durable success under the correct account/generation/fence before calling it. Account switching, stale drafts, concurrent settings edits and pending acknowledgement need integration safeguards before use in a screen. This class does not claim those safeguards or perform I/O.

Source: `ux.js` saveSettings/readOrderTypeDraft and `model.js` preferences validation. Tests use only synthetic empty/current accounts. Historical saved sale order-type strings remain outside the edited preference lists.

## Actual verification

Tests preceded new libraries: initial Flutter run failed on missing catalog/settings files and symbols. Initial invocation resolved dependencies; tracked pubspec.lock did not change. Subsequent commands used --no-pub. Final focused Flutter suite:7 tests passed, including seven frozen-source catalog oracle cases. Focused Flutter analysis across the four owned source/test directories: no issues. Formatting passed. Logs: /tmp/restart-app-red.log, /tmp/restart-app-final.log, /tmp/restart-app-analysis.log.

No full app/engine compatibility, native, build, hosted CI, benchmark, UI, durability or complete C1/C7 result is claimed. No optimization occurred. Independent review, approved UI composition and actual repository/fence integration remain required. Shared business calculations stay in Madar; consumer presentation and account composition remain here.

## Settings durable editor follow-up

`AccountSettingsController` binds a settings draft to its captured repository revision. It rejects concurrent/stale/unknown writes, validates before persistence, retains edits on failure and preserves newer edits made during an acknowledged save. Reopen a controller after conflict or unknown-write reconciliation; it does not infer a merge. Four test-first scenarios pass and focused analysis passes. Independent review remains pending. UI and native interaction are separate gates.

## Integration checkpoint

The [restarted Step3 build record](../log/2026-11-07-completion-step3-restarted-build.md) supersedes earlier pending integration statements with exact current evidence. The app adopts reviewed engine7b1866fb8c9a40345c9d67b455c40053178fcb44. The independently reviewed [nonvisual baseline](completion-benchmarks.md) exercises real isolated storage for the relevant implemented commands; it does not establish UI, installed-device, financial posting or full phase acceptance.
