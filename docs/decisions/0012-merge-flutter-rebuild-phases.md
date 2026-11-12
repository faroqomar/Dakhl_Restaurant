# 0012 — Consolidate the Flutter rebuild from 19 phases to 12

Status: owner-requested plan reorganization; implementation has not started. Date: 2026-10-27. Source: the owner's request to identify and merge phases that can be combined.

## Decision and rationale

Combine phases completing one workflow rather than delivering closely related features separately:

| New phase | Earlier phases | Rationale |
| --- | --- | --- |
| 01 — Design, navigation and interaction | 01, 03 | Share components and form/focus rules |
| 04 — Sales, receipts, drafts and holds | 06, 07 | All belong to the same cash-order lifecycle |
| 06 — Daily account, categories and cashbox | 04, 09, 15 | Expense funding and transfers connect both accounts; categories are part of entry |
| 07 — Suppliers, debts, materials and prices | 11, 12 | Setup data required by purchases |
| 08 — Purchases, analysis and settlement | 13, 14 | Recording an invoice and its payment requires one atomic operation |
| 10 — Statements, day review, reporting and printing | 10, 17 | Align views/filters with the resulting document and verify their agreement |

Setup 00, persistence 02, inventory 03, returns/history 05, settings/backups 09 and acceptance/release 11 remain distinct gates. [Complete old/new numbering map](../planning/flutter-rebuild/phase-map.md).

## Preserved boundaries

No feature, verification scenario or screenshot is removed. All 179 images and the requirements for macOS, Android, iPhone, local operation, backup/import, ordinary printing and the current design remain. Original work and acceptance items are preserved with new owners in the [consolidation audit](../planning/flutter-rebuild/merge-audit.json).

Dependencies use the new phase numbers without cycles: phase 06 tests settlement effects on the cashbox with isolated data, then phase 08 proves the direct settlement-UI workflow. Combining daily/cashbox or supplier/material phases does not merge their financial meanings or ingredient inventory with sellable products.

## Supersession and documentation

This supersedes the **phase breakdown** in [0011](0011-flutter-rebuild-baseline.md), not its approved rebuild scope. The [current plan](../planning/flutter-rebuild/README.md) runs from 00 to 11. The [previous version](../planning/flutter-rebuild/archive/v1-19-phases/README.md) is preserved, labelled historical and excluded from memory indexing.

Application source, accounts and screenshots were unchanged by this task. Actual verification and limits are in the [consolidation log](../log/2026-10-27-flutter-phase-consolidation.md).
