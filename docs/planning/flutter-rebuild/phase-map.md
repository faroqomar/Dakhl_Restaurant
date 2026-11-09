> Execution update, 2026-11-05: the owner grouped all remaining work into one **Completion phase**. Original IDs below remain requirement/work-package references. Preserve prior DONE evidence and unfinished checks. [Current scope and readiness](../../phases/completion-scope-readiness.md) · [Current planning view](completion.html). This historical pack does not grant implementation approval.

# Phase consolidation — 19 to 12

Status: current sequence, revised at the owner’s request on 2026-10-27. No Flutter implementation or feature scope changed.

The original phase numbers are historical identifiers. Use the new numbers in the [current plan](README.md), phase files and gallery. A label such as old 06 or old 17 refers only to the archived version or capture manifest.

## New workstreams and reasons

| Current phase | Former phase IDs | Why grouped or kept separate |
| --- | --- | --- |
| [00 — Baseline and delivery setup](phases/00.md) | 00 | Keep platform/toolchain and distribution proof separate from feature implementation. |
| [01 — Design system, navigation and interaction shell](phases/01.md) | 01, 03 | The shell uses the same components, focus behavior, dialogs and responsive rules; build and review them together. |
| [02 — Local accounts, validation and safe persistence](phases/02.md) | 02 | Keep storage and compatibility as an early gate; settings will expose its file operations in phase 09. |
| [03 — Sellable products and inventory](phases/03.md) | 05 | Keep stock history, reversals and historical quantity checks together as one complete inventory feature. |
| [04 — Cash sales, saved receipt, drafts and held orders](phases/04.md) | 06, 07 | Draft recovery and hold/resume are part of the same ticket lifecycle as checkout; separating them created a partially finished sales flow. |
| [05 — Sales history, returns and voids](phases/05.md) | 08 | Keep return/void accounting and historical stock checks as a distinct verification gate after checkout. |
| [06 — Daily accounting, expense categories and cashbox](phases/06.md) | 04, 09, 15 | Categories feed expense entry, and daily/cash funding and transfers change both ledgers; implement and verify them together. |
| [07 — Suppliers, debts, materials and prices](phases/07.md) | 11, 12 | Supplier and material setup are the reference data used by the same purchase workflow. |
| [08 — Purchase invoices, analysis and supplier payments](phases/08.md) | 13, 14 | Immediate payment already belongs to invoice entry; combining them removes a later-phase dependency from a core purchase action. |
| [09 — Settings, backups, import and recovery](phases/09.md) | 16 | Keep the complete settings and user-facing recovery review after operational records are available; reuse phase 02 storage services. |
| [10 — Statements, day review, PDF reports and printing](phases/10.md) | 10, 17 | Statements/day review and their reports share filters, financial meanings and export actions; verify screen-to-document parity together. |
| [11 — Complete MVP verification, migration rehearsal and release](phases/11.md) | 18 | Keep independent end-to-end, installed-device and cutover verification as the final gate. |

## Every original phase has an owner

| Historical phase | Current phase |
| --- | --- |
| 00 — Baseline and delivery setup | [00 — Baseline and delivery setup](phases/00.md) |
| 01 — Design system and responsive components | [01 — Design system, navigation and interaction shell](phases/01.md) |
| 02 — Local accounts, validation and safe persistence | [02 — Local accounts, validation and safe persistence](phases/02.md) |
| 03 — Navigation, shortcuts and interaction shell | [01 — Design system, navigation and interaction shell](phases/01.md) |
| 04 — Expense categories | [06 — Daily accounting, expense categories and cashbox](phases/06.md) |
| 05 — Sellable products and inventory | [03 — Sellable products and inventory](phases/03.md) |
| 06 — Cash sale and saved receipt | [04 — Cash sales, saved receipt, drafts and held orders](phases/04.md) |
| 07 — Active draft and held orders | [04 — Cash sales, saved receipt, drafts and held orders](phases/04.md) |
| 08 — Sales history, returns and voids | [05 — Sales history, returns and voids](phases/05.md) |
| 09 — Daily expenses, remaining cash and chicken counts | [06 — Daily accounting, expense categories and cashbox](phases/06.md) |
| 10 — Account statement and day review | [10 — Statements, day review, PDF reports and printing](phases/10.md) |
| 11 — Suppliers, opening balances and debts | [07 — Suppliers, debts, materials and prices](phases/07.md) |
| 12 — Shared supplier materials and default prices | [07 — Suppliers, debts, materials and prices](phases/07.md) |
| 13 — Purchase invoices and purchase analysis | [08 — Purchase invoices, analysis and supplier payments](phases/08.md) |
| 14 — Supplier payments and allocation | [08 — Purchase invoices, analysis and supplier payments](phases/08.md) |
| 15 — Cashbox and daily transfers | [06 — Daily accounting, expense categories and cashbox](phases/06.md) |
| 16 — Settings, backups, import and recovery | [09 — Settings, backups, import and recovery](phases/09.md) |
| 17 — Arabic PDF reports, sharing and system printing | [10 — Statements, day review, PDF reports and printing](phases/10.md) |
| 18 — Complete MVP verification, migration rehearsal and release | [11 — Complete MVP verification, migration rehearsal and release](phases/11.md) |

## Preservation and dependency rules

Every original implementation item and feature-specific acceptance check is retained in the merged phase. Workstreams have named subsections rather than losing detail in a shorter summary. All 179 original image files and the immutable capture manifest are retained; current screenshot filters translate capture IDs using [phase-map.json](phase-map.json).

The dependency graph has only earlier-phase dependencies. In particular, the daily/cashbox phase 06 uses synthetic saved payments to verify derived source effects; purchase/payment phase 08 must prove live end-to-end integration with those ledgers. Invoices and immediate settlement now finish in the same phase. Phase 10 reporting follows operational data and settings, and phase 11 remains the independent final acceptance gate.

The [preservation audit](merge-audit.json) lists each original work/check item with its new owner and updated phase references. All platforms, accounting rules, error/recovery cases and final MVP acceptance remain required. Phase status remains planned/not started.

The [archived original plan](archive/v1-19-phases/plan.html) is retained for comparison, explicitly marked superseded and excluded from project-memory indexing. Do not implement from its obsolete numbering. Earlier logs remain historical evidence.
