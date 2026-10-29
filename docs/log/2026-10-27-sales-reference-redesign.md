# Redesign the Sales screen

Date: 2026-10-27. Status: implemented in source and verified by tests/isolated Electron preview.

- Request: redesign Sales using the owner's attached image as inspiration.
- Change and rationale: scrollable group tabs with product counts, organized photo cards and clear addition, ivory background and a separate ticket with bottom total/confirmation; align the experience with the reference while preserving Arabic/current flows. [Decision](../decisions/0005-sales-reference-redesign.md).
- Files: `app/ui/commerce.js`, `app/ui/commerce.css`; filtering test in `tests/ui.test.cjs`. Accounting/persistence were unchanged.
- Actual verification: `npm test` passed 114 tests. The group test covers filtering, order preservation, search/reset, keyboard focus and no save. An Electron preview using `tests/commerce-fixture.cjs` data is under `dist/sales-redesign-review/`; 1440×1000 and 390×844 captures were reviewed without horizontal overflow. Review images: `outputs/sales-redesign-2026-10-27/`. Restaurant accounts were neither read nor modified.
- Limits and next action: source change only; no packaging or installed-app update. Taxes, customers and held orders were not imported from the reference.
- Memory: ran `./scripts/memory sync` then `./scripts/memory check`. The service was healthy with no pending/failed operations, but the check reported `sources: 0` and sync listed no documents; new-document indexing is therefore not established. Markdown files remain authoritative.
