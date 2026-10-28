# Shared material and price catalog for supplier invoices

Status: implemented and verified by application tests; local update in progress. Date: 2026-10-25. Source: application owner's request.

## Request

Share material names between suppliers, manage carton/piece prices in one settings list, and populate both prices and the unit when selecting a material in any invoice.

## Change and rationale

Added the `materials` root to account schema 7 and a Materials and Prices page. It shows materials, their prices and status, and allows adding/editing materials and disabling them for new invoices. Selecting a material in any invoice fills carton price, piece price and measurement unit. Each invoice keeps an independent name/unit/quantity/price snapshot, so catalog edits do not alter historical records. Legacy-account migration merges supplier material lists by name, uses the old unit price as the default piece price, and starts carton price at zero because prior data did not contain it.

## Verification

`node --check` passed for model/UI files. `npm test` passed: 81 tests, no failures, including migration of supplier materials, preservation of old totals and population of carton/piece prices with a different supplier. Real restaurant data was not used in tests.

## Status and next action

Source version was raised to 1.8.0. Updating the local application requires packaging macOS ARM64, installation and opening it to verify the Materials page. This change does not convert historical prices into current prices; historical analysis always uses invoice snapshots.
