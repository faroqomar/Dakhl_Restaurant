# 0004 — Popouts, work protection and corrections

Status: approved by the owner's "fix them all" direction after the audit report and request to convert side panels to popouts; implemented in source 1.12.0 and schema 10. Date: 2026-10-26.

## Decision and rationale

- Navigation is a popout over the workspace and forms are centered dialogs. The purchase dialog is larger and includes supplier/date context, save actions and the total. This replaces the collapsible sidebar; it does not open separate operating-system windows.
- Preserve the requested sales layout: products left, ticket right. Large screens use internal scrolling; short or zoomed screens allow scrolling to reach actions. Discount and date are expandable details, with an optional compact-product mode.
- Save the sales draft locally per account path. Each line's price is fixed when added to the draft. A draft number/ID prevents recovery as a new sale after saving completes. A draft is not a financial movement and is not included in the account backup.
- A completed sale is not erased by general undo; it requires a reasoned void. An inventory correction is a reversal linked to its original movement and must satisfy historical-balance validation. Balance/total corrections retain the reason and before/after values; undo adds a reversing effect.
- Schema 10 adds receipt identity, supplier deactivation, custom fields, correction history and inventory reversal links. Migration does not redefine the daily account, cashbox or worker savings.
- Import and restore display summaries of the incoming and current data and save a copy of the current file before replacement. A backup on the same device does not protect against device loss.

## Verification and limits

[64-item resolution and verification matrix](../planning/2026-10-26-ux-audit-resolution.md) and [implementation log](../log/2026-10-26-ux-audit-fixes.md). Implementation and packaging are separate from installing the application against restaurant data; no physical printer, barcode reader or comprehensive VoiceOver session was tested.

This supersedes the permanent sidebar-hiding and restricted-scrolling behavior in [0003](0003-sales-layout-review.md), preserving the approved reference images, exact-value payment and order types.

Update, 2026-10-27: the worker UI and its details are no longer available screens; the owner's request in [decision 0007](0007-retire-worker-savings.md) supersedes that portion. The rest of this decision remains in force.

Update, 2026-10-27: the owner requested automatically opening the receipt after payment; [decision 0010](0010-mvp-returns-and-held-orders.md) supersedes showing only a success notification, without changing the rest of this decision.
