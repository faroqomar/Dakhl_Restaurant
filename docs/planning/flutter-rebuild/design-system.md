# Design reproduction contract

Status: extracted reference plus planned acceptance rules, 2026-10-27. No Flutter implementation yet.

[Visual board](design-system.md) · [Board image](screenshots/design-system.png) · [Computed tokens](design-tokens.json) · [All screenshots](gallery.html)

## Frozen token inventory

| Role | Current value |
| --- | --- |
| Background / paper | #f6f7f2 / #fefefa |
| Ink / muted | #17382d / #4c6051 |
| Main green / lime / soft | #245b42 / #d6e7b8 / #eaf0e4 |
| Border / danger / keyboard focus | #e2e8dd / #9a493e / #28633f |
| Page gutters | 24 logical px desktop; 14 narrow |
| Shared panel padding / radius | 20 / 10 logical px |
| Base input height | 42 logical px |
| Standard / wide dialog | 620 / 1060 logical px maximum, constrained by window |
| Current body font | Geeza Pro, Tahoma, sans-serif; 15px |
| Typical page heading | 28px, 42px line height |
| Typical button | 15px type, 24px line height, 10px 12px padding, 9px radius |

These shared values are not every component’s final value: sales-specific CSS and media queries override some styles. The actual screenshot and frozen CSS govern each component. For example, the sale confirmation and category tabs use their current brighter accent; do not recolor everything with one global green.

## Components to port

- Navigation popover with grouped routes, scrim, active state and focus return; shortcut row and persistent save/error status.
- Page heading/actions, wrapping filters, date controls, compact totals and inline help.
- Product photo card, plus/count overlay, group tabs, search, dense display and bill/ticket lines.
- Ledger tables, horizontal overflow where required, row actions, running balances, status badges, pagination and short empty states.
- Money/quantity/date/text/select controls, optional notes, shared-funding inputs, previews and inline validation.
- Standard/wide centered dialogs with separate scrollable fields and accessible actions; dirty-form guard and delete/discard confirmation.
- Toast with export actions, loading/saving/error/retry, receipt, refund rows, held-order rows, settings tabs and unified savebar.

## Layout and interaction rules

Retain Arabic RTL, current labels, left-side desktop catalog and right-side bill, full-width workspace with aligned gutters, short grouped totals and current compact density. Do not insert a persistent sidebar or center pages inside an unnecessary narrow container. Keep images and controls legible when shrinking the layout.

Match narrow references before proposing changes. Test 390×844 and 320 logical width, a medium 1024×768 window, desktop 1440×1000 and wide 1920×1080; establish native golden references per target in phase 01. The existing narrow layout can show awkward fields; record any adaptation needed for usable native controls as a specific owner-reviewed difference rather than copying an unreachable action.

Use tabular Latin numerals for financial values and retain Arabic/Persian digit input normalization. Keep screen-reader labels, semantic table/field order, keyboard traversal, Escape/back behavior, focus trapping and return, contrast and visible focus. Test large text, reduced motion and screen reader access. Platform touch targets may need invisible hit padding while preserving visual dimensions.

## Font and asset boundary

The current macOS screenshot uses the host’s font fallback. This pack does not redistribute Geeza Pro/Tahoma font files or establish Android glyph identity. Select an appropriately licensed bundled Arabic font, compare it with the owner in phase 01 and store target-specific goldens. Preserve text shaping and financial readability; do not call a fallback rendering “pixel exact” without measurement.

Frozen CSS (including report styles), product thumbnails and extracted icons.json are under reference-assets/; assets-manifest.json records their hashes. Images are references from the existing app; repeated sample product photos are not approved menu/product additions. Icons originate from renderer.js / paths. Record source and license before redistribution.

## Visual acceptance procedure

1. Restore the same synthetic state, route, date, filter, open dialog and scroll position.
2. Render at the same logical dimensions and recorded scale factor; disable transient animations and mask only documented volatile timestamps/status.
3. Compare side-by-side and with an overlay: Arabic copy, edge alignment, color, spacing, radius, wrapping, number formatting, visible actions and scrolling.
4. Maintain Flutter goldens per renderer/platform. Do not use a single aggregate similarity score to accept a missing button or incorrect amount.
5. Link before/reference/after captures and every intentional difference in the phase log. Never replace the baseline automatically just to make tests pass.
