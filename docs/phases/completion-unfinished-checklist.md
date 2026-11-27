# Completion: unfinished-work checklist

Date: 2026-11-07. **Not complete; not merge-ready.** Owner-requested granular audit of retained phases00–11 and Completion C0–C9. This preserves the original 213-obligation audit baseline and now records exact row closures; it grants no new scope approval and is not a percentage-complete estimate.

Planning companion: [one proposed action/dependency/acceptance plan for each of these 213 items](completion-unfinished-implementation-plan.md). Planning changes no item status and authorizes no implementation.

Current closure update (2026-11-08): **33 rows closed, 180 formally open**. Closed foundation rows: F01/F02/F03/F04/F05/F06/F08/F09/F10; storage cleanup Q-16; documentary reconciliation Q-11/C0-01/C0-11 and C0-09 store race verification; C0-07/C0-13 legacy/history restart/export and C0-10 actual native bootstrap/status acceptance; closed C1 rows: C1-01–15/17 (C1-16 remains open). The [current audit](completion-progress/progress-audit-latest.json) separates partial progress from no recorded progress. [C1 exact closure](../log/2026-11-08-c1-exact-row-closure.md). Category totals/types retain the original baseline; phase/release remain open.

## Evidence and status rules

Historical audit snapshot (2026-11-07): app HEAD `cc91fae438101fce7ff4729e12bf3c2b64dacd70`, engine HEAD `e73b5eebf84f742375eba298a63df8c7bcf70c97`, plus uncommitted catalog fixes and existing local work. At that snapshot, [app routing](../../lib/app/app.dart) mounted `Phase01RouteSurface` outside settings and used demo-only checkout. That dated observation is not the current C1 routing status and does not imply absence of underlying calculations.

- **M — missing:** no complete operational implementation identified in inspected source.
- **I — partial/integration:** foundations exist; the end-to-end feature is not connected or complete.
- **V — verification/delivery pending:** capability may exist, but required final-source evidence or delivery is incomplete. An unchecked item does not assert a proven defect.
- **G — explicit gate:** policy/design/access/approval needed for the dependent item only.

Close an item only with its exact implementation revision and relevant test/native/review/approval receipt. Source links at each section apply to all its rows. Original requirement lists remain binding; no item here waives an unlisted edge case. This audit is documentation/source inspection, not a fresh full runtime audit.

Already evidenced and not labeled missing: approved Phase01 preview shell; account/schema/store foundations; catalog/inventory commands; ticket workspace; settings and parties controllers; pure sale/return/purchase proposals; daily-cash queries; PDF/native service foundations. Historical full suite676passed before latest catalog changes; latest catalog suite8passed with targeted analyzer clean. Those results do not establish full-app acceptance. Existing numeric compatibility fixes remain credited; shared collation is still unresolved.

## Phase reconciliation

| Original phase | Retained slice | Current assessment |
| --- | --- | --- |
| 00 | C0/C9 | Technical baseline exists; overall closeout/delivery residuals remain. |
| 01 | Preserved baseline | Approved preview DONE; only integration regressions need checking. |
| 02 | C0/C7/C9 | Persistence implemented; final native/update/recovery obligations remain. |
| 03 | C1 | Catalog/stock foundations and controller exist; operational UI/photos incomplete. |
| 04 | C2 | Workspace/calculation proposals exist; checkout remains demo. |
| 05 | C3 | Return/history calculations exist; durable refund/void UI incomplete. |
| 06 | C4 | Read queries exist; categories/daily/cash operational workflows incomplete. |
| 07 | C5 | Metadata/ledger foundations exist; supplier/material workflow integration incomplete. |
| 08 | C6 | Pure proposals exist; invoice/payment/analysis workflow incomplete. |
| 09 | C7 | Account surface/settings foundations exist; full settings/portability acceptance incomplete. |
| 10 | C8 | PDF/services and partial queries exist; seven connected report workflows incomplete. |
| 11 | C9 | Full end-to-end verification, approved merge and release delivery incomplete. |

The detailed phase files contain historical planned labels and unchecked templates. [PHASES.md](../../PHASES.md), current source and dated receipts take precedence over those labels for execution status. Consolidation retains requirements; it does not restart Phase01 or complete Madar's separate wider roadmap.

## C0 — 00/02 residual baseline and persistence

Owner: App + Madar; preserve existing store and schema work. Sources: [original phase00](../planning/flutter-rebuild/phases/00.md), [paired implementation plan](completion-implementation-plan.md), [engine obligations](../../../Madar_Engine/docs/reference/consumer-completion-implementation-plan.md).

- [x] **C0-01 [V]** Reconcile Phase00 technical completion with its remaining overall closeout evidence.
- [ ] **C0-02 [V]** Bind current macOS native persistence results to final app, engine, tool and fixture revisions.
- [ ] **C0-03 [V]** Bind current Android native persistence and cancellation results to final revisions.
- [ ] **C0-04 [V]** Bind current iPhone native persistence and cancellation results to final revisions.
- [ ] **C0-05 [V]** Resolve or explicitly disposition historical Android retention/restoration uncertainty without claiming fresh fixtures restore lost history.
- [ ] **C0-06 [V]** Demonstrate installed-update preservation on isolated existing accounts, including backup before update.
- [x] **C0-07 [V]** Demonstrate migration preserves supported schema1–11 records, IDs, preferences and retired compatibility records.
- [ ] **C0-08 [V]** Verify interrupted first creation, corrupt/future/incomplete stores and recovery on final target builds.
- [x] **C0-09 [V]** Verify unknown acknowledgement, stale writers, concurrent processes and reread/recovery before retry on final integration.
- [x] **C0-10 [V]** Verify bootstrap and account-status UI against actual native store states, not only fake stores.
- [x] **C0-11 [V]** Reconcile source/platform access inventory, minimum OS claims and remaining capability limitations.
- [ ] **C0-12 [V]** Exercise the explicit20MiB import boundary, including exact limit and oversized rejection.
- [x] **C0-13 [V]** Verify retained savings/correction history as well as worker records during migration.


## D — Design and approval coverage

Owner: App/UX; owner approves named revisions. Sources: [original phase01](../planning/flutter-rebuild/phases/01.md), [paired implementation plan](completion-implementation-plan.md), [engine obligations](../../../Madar_Engine/docs/reference/consumer-completion-implementation-plan.md).

- [ ] **D-01 [G]** Qualify the remaining reference pairs; reconcile the recorded165pairs/176reference mappings and approved reuse without making duplicates.
- [ ] **D-02 [G]** Finish native transfer repair units and inspect affected exported sides against source.
- [ ] **D-03 [G]** Finish required mobile/native interaction patterns or document exact approved reuse.
- [ ] **D-04 [G]** Cover populated, empty, loading, invalid, failed-save, unknown-save, retry and cancellation designs for each affected workflow.
- [ ] **D-05 [G]** Cover narrow layouts, large text, keyboard visibility, safe areas and dialog scrolling.
- [ ] **D-06 [G]** Reconcile saved native Penpot identities, archive/export hashes, editability and recovery evidence.
- [ ] **D-07 [G]** Obtain independent aggregate design review and resolve its blocking discrepancies.
- [ ] **D-08 [G]** Present exact remaining screen/reference revisions for explicit owner approval; old three-screen approval is not blanket approval.
- [ ] **D-09 [V]** Preserve approved Phase01 shell behavior with regression evidence after operational integration.

## C1 — 03 catalog and inventory

Owner: App UI/controller; Madar stock arithmetic/invariants. Sources: [original phase03](../planning/flutter-rebuild/phases/03.md), [paired implementation plan](completion-implementation-plan.md), [engine obligations](../../../Madar_Engine/docs/reference/consumer-completion-implementation-plan.md).

- [x] **C1-01 [I]** Mount catalog/inventory routes with CatalogViewModel instead of placeholder surfaces.
- [x] **C1-02 [I]** Connect product name/code/group search, active/all/archived/low/out filters and50-row inventory pagination.
- [x] **C1-03 [I]** Connect product creation and editing forms with validation and durable acknowledgement.
- [x] **C1-04 [M]** Complete product photo selection, replacement/removal, persistence and failure handling.
- [x] **C1-05 [I]** Connect tracked/untracked product options, unit and minimum-stock fields.
- [x] **C1-06 [I]** Connect atomic product plus opening-stock entry.
- [x] **C1-07 [I]** Connect dated restock, adjustment and loss forms with reason/history views.
- [x] **C1-08 [I]** Connect movement reversal and reject duplicate reversal without changing history.
- [x] **C1-09 [I]** Connect archive/restore with historical product identity preserved.
- [x] **C1-10 [I]** Show current-business-date stock availability and low/out indications.
- [x] **C1-11 [V]** Verify unit/tracking locks after recorded history through operational forms.
- [x] **C1-12 [V]** Verify backdated movements cannot create historical negative stock through real persistence and UI.
- [x] **C1-13 [V]** Reverify catalog review fixes independently at final integrated source; eight focused tests are local evidence only.
- [x] **C1-14 [V]** Exercise edit-input snapshot, concurrent write, stale account, unknown write and disposal behavior through connected UI.
- [x] **C1-15 [V]** Verify real multi-page boundary navigation and dated stock queries end to end.
- [ ] **C1-16 [I]** Expose stock-history sale/return links, future-entry labels and original-entry trace for reversals.
- [x] **C1-17 [I]** Expose signed adjustment inputs and reasons, preserving source quantity semantics.


## F — Shared financial contracts and unresolved policy

Owner: Madar public contracts/adapters; app restaurant mapping; owner policy. Sources: [original phase04](../planning/flutter-rebuild/phases/04.md), [paired implementation plan](completion-implementation-plan.md), [engine obligations](../../../Madar_Engine/docs/reference/consumer-completion-implementation-plan.md).

- [x] **F-01 [G]** Accept FIN-01 account classifications and worked sale/expense/payment/refund journal mappings.
- [x] **F-02 [G]** Choose and document historical reconstruction versus explicit cutover/opening treatment.
- [x] **F-03 [G]** Accept FIN-02 mapping of legacy edit/delete/date-shift/undo to linked correction semantics.
- [x] **F-04 [G]** Define correction IDs, effective dates, exported history and migration compatibility.
- [x] **F-05 [M]** Complete reusable balanced-journal/posting contract and reject unbalanced results before writes.
- [x] **F-06 [M]** Complete durable operation identity with duplicate retry, changed-payload rejection and restart semantics.
- [ ] **F-07 [M]** Commit source record, journal and stock/cash/liability effects atomically through one persistence owner.
- [x] **F-08 [V]** Inject failures across full command commit; prove no orphan journal, partial effects or duplicate posting.
- [x] **F-09 [V]** Reconcile source records, journals and dated cash/stock effects using independent engine and consumer fixtures.
- [x] **F-10 [V]** Review/version/document public contracts and adopt the exact reviewed engine revision with source checks.

Exact-row closure (2026-11-08): F-01/F-02/F-05/F-06 meet their individual acceptance criteria. See [independent closure evidence](../log/2026-11-08-exact-financial-row-closure.md). Successor [F08/F09 fixture closure](../log/2026-11-08-f08-f09-fixture-closure.md) also closes those two exact representative harness obligations. Live opening values/date, full correction compatibility, later command-specific faults and current source adoption remain separate.

## C2 — 04 sales, receipt and ticket workspace

Owner: App ticket workflows; Madar arithmetic and durable contracts. Sources: [original phase04](../planning/flutter-rebuild/phases/04.md), [paired implementation plan](completion-implementation-plan.md), [engine obligations](../../../Madar_Engine/docs/reference/consumer-completion-implementation-plan.md).

- [ ] **C2-01 [I]** Replace demo checkout toast with an operational sales screen and approved ticket/catalog layout.
- [ ] **C2-02 [I]** Connect80-product sales pagination, name/code search and group filters.
- [ ] **C2-03 [I]** Add product lines and edit quantity, price where source allows, line removal and notes.
- [ ] **C2-04 [I]** Connect order-type selection and saved label snapshots.
- [ ] **C2-05 [I]** Connect source-compatible discount/net calculation and exact-net confirmation.
- [ ] **C2-06 [I]** Persist sale with unique receipt number and saved line/name/unit/price/discount snapshots.
- [ ] **C2-07 [I]** Commit one stock and cash effect with the accepted journal mapping.
- [ ] **C2-08 [I]** Keep ticket and edits on failed or uncertain save; clear only after acknowledged success.
- [ ] **C2-09 [I]** Prevent duplicate checkout from repeated tap, retry, restart or lost acknowledgement.
- [ ] **C2-10 [I]** Show saved receipt and connect subsequent receipt actions to saved record identity.
- [ ] **C2-11 [I]** Connect active ticket autosave and restart recovery in device/account-scoped workspace.
- [ ] **C2-12 [I]** Connect hold/list/label/resume/swap/delete ticket interactions and40-held limit.
- [ ] **C2-13 [V]** Verify hold/swap transitions are atomic and cannot lose the active or held draft.
- [ ] **C2-14 [V]** Verify drafts reserve no stock, move no cash and stay out of portable backups.
- [ ] **C2-15 [V]** Verify account replacement invalidates old drafts and late callbacks.
- [ ] **C2-16 [V]** Verify checkout after product archive/price/stock changes uses the required source-compatible behavior.
- [ ] **C2-17 [I]** Connect photo product cards, plus/count controls, group counts and device-only compact toggle.
- [ ] **C2-18 [I]** Connect direct quantity entry, increment/decrement, ticket business date and add-time price snapshot.
- [ ] **C2-19 [I]** Connect paid-receipt close/new/details/PDF/print actions.
- [ ] **C2-20 [I]** Connect held-ticket empty states and deletion confirmation; preserve every ticket field across hold/resume.


## C3 — 05 sale history, refunds and voids

Owner: App history UI; Madar allocation/reversal invariants. Sources: [original phase05](../planning/flutter-rebuild/phases/05.md), [paired implementation plan](completion-implementation-plan.md), [engine obligations](../../../Madar_Engine/docs/reference/consumer-completion-implementation-plan.md).

- [ ] **C3-01 [I]** Mount sale-history list with date/status/order-type/text filters and pagination.
- [ ] **C3-02 [I]** Show original receipt, line snapshots, lifetime refunds and selected-period totals.
- [ ] **C3-03 [I]** Connect partial and full return selection, quantity validation and cash-refund confirmation.
- [ ] **C3-04 [I]** Persist refund using original saved price/discount and cumulative allocation.
- [ ] **C3-05 [I]** Connect optional restock and apply refund/stock effects on return date.
- [ ] **C3-06 [I]** Connect eligible reasoned void and original-date reversal while preserving receipt number.
- [ ] **C3-07 [V]** Reject over-return, duplicate return/void, invalid dates and ineligible source records without writes.
- [ ] **C3-08 [V]** Reconcile repeated fractional refunds to original net using real durable integration.
- [ ] **C3-09 [V]** Verify history, cash and stock after save failure, unknown acknowledgement and restart.
- [ ] **C3-10 [I]** Use shared source-compatible collation for history ordering; do not substitute parsed time or lexical ordering.
- [ ] **C3-11 [I]** Expose return reason, date, per-line restock choice and refund preview before save.
- [ ] **C3-12 [V]** Enforce void eligibility when prior returns exist.
- [ ] **C3-13 [V]** Verify a fresh remaining-cash baseline prevents double deduction of historical refunds.
- [ ] **C3-14 [V]** Verify return-only periods can show negative net sales movement without being mislabeled profit.


## C4 — 06 daily accounting, categories and cashbox

Owner: App forms/queries; Madar funding/correction contracts. Sources: [original phase06](../planning/flutter-rebuild/phases/06.md), [paired implementation plan](completion-implementation-plan.md), [engine obligations](../../../Madar_Engine/docs/reference/consumer-completion-implementation-plan.md).

- [ ] **C4-01 [M]** Mount category grid and add/edit dialogs with primary/additional classification and automatic type save.
- [ ] **C4-02 [M]** Preserve built-in category restrictions; connect custom archive/restore and duplicate-name validation.
- [ ] **C4-03 [M]** Connect active category selectors, inline expense-category creation and supplier-payment defaults.
- [ ] **C4-04 [M]** Mount daily table, compact cash-expense/remaining/chicken column and previous/next/today selection.
- [ ] **C4-05 [M]** Connect expense add/edit/delete and notes under accepted correction mapping.
- [ ] **C4-06 [I]** Connect daily/cash/shared funding with both shares validated and no duplicated totals.
- [ ] **C4-07 [I]** Connect remaining-cash snapshots and total-balance recording to saved records.
- [ ] **C4-08 [M]** Connect automatic/manual expense totals, correction reason/history and clear-balance flow.
- [ ] **C4-09 [M]** Connect session undo preserving required inverse/correction records.
- [ ] **C4-10 [M]** Implement date-correction preview and optional shift of following recorded days with collision rejection.
- [ ] **C4-11 [V]** Keep supplier invoice/debt, sale and inventory dates independent during date correction.
- [ ] **C4-12 [M]** Connect chicken-used/left count editing without monetary effects.
- [ ] **C4-13 [I]** Mount cash balance card, movement ledger, running balances and filters.
- [ ] **C4-14 [M]** Connect external cash deposit/withdrawal, notes, edit/delete and context actions.
- [ ] **C4-15 [I]** Route derived expense/payment movements back to their source; prohibit second independent edit.
- [ ] **C4-16 [M]** Connect part/all available daily-cash transfer to cashbox.
- [ ] **C4-17 [V]** Verify transfer edit/delete restores both sides and preserves saved-total meaning.
- [ ] **C4-18 [V]** Preserve source negative-balance indications without new blocking or profit labels.
- [ ] **C4-19 [V]** Prove shared expense and live supplier-payment ledgers update once, including failed writes.
- [ ] **C4-20 [V]** Verify the30,000 shared expense and102,000 remaining-snapshot parity examples in integrated UI/storage.

## C5 — 07 suppliers, debts, materials and defaults

Owner: App metadata/ledger; Madar shared references and liabilities. Sources: [original phase07](../planning/flutter-rebuild/phases/07.md), [paired implementation plan](completion-implementation-plan.md), [engine obligations](../../../Madar_Engine/docs/reference/consumer-completion-implementation-plan.md).

- [ ] **C5-01 [I]** Mount supplier picker/list/search and add/edit/archive forms.
- [ ] **C5-02 [I]** Connect supplier contact/note/category fields and preserve stable historical identities.
- [ ] **C5-03 [I]** Connect opening/dated debt records and payment eligibility views.
- [ ] **C5-04 [V]** Enforce paid-debt edit/delete restrictions and historical references in integrated forms.
- [ ] **C5-05 [I]** Mount supplier ledger, date filters, balances and event detail using saved records.
- [ ] **C5-06 [I]** Resolve shared event-ID/timestamp collation before claiming exact ledger ordering.
- [ ] **C5-07 [I]** Mount shared material catalog with search, selection and create/edit/archive.
- [ ] **C5-08 [I]** Connect independent carton/piece units and default prices without conversion.
- [ ] **C5-09 [V]** Verify later supplier/material/default edits leave prior invoice/payment snapshots unchanged.
- [ ] **C5-10 [V]** Verify stale forms, concurrent metadata saves, failed save and account replacement in operational UI.
- [ ] **C5-11 [I]** Connect supplier summary plus invoices/debts/ledger tabs and chronological before/after balances.
- [ ] **C5-12 [I]** Connect additional dated debt create/edit/delete with backdating and allocated-payment restrictions.
- [ ] **C5-13 [V]** Verify duplicate material names and legacy single-unit records retain source-compatible handling.


## C6 — 08 invoices, purchase analysis and payments

Owner: App purchasing workflow; Madar allocation and atomicity. Sources: [original phase08](../planning/flutter-rebuild/phases/08.md), [paired implementation plan](completion-implementation-plan.md), [engine obligations](../../../Madar_Engine/docs/reference/consumer-completion-implementation-plan.md).

- [ ] **C6-01 [M]** Mount purchase invoice page, supplier/material/date filters and grouped details.
- [ ] **C6-02 [M]** Implement quantity/price history comparison and purchase analysis from saved records.
- [ ] **C6-03 [I]** Mount wide/phone invoice forms with supplier/date/number context and scrollable lines.
- [ ] **C6-04 [I]** Connect inline material selection/creation and atomic default/snapshot capture.
- [ ] **C6-05 [I]** Connect independent carton/piece quantities/prices, notes and invoice totals.
- [ ] **C6-06 [I]** Allow valid historical invoices and reject duplicate invoice number within supplier.
- [ ] **C6-07 [I]** Persist unpaid invoice as liability without creating paid expense.
- [ ] **C6-08 [I]** Commit invoice plus optional immediate payment together, including inline material/default changes.
- [ ] **C6-09 [M]** Mount payment list, filters, payment form and receipt entry.
- [ ] **C6-10 [I]** Connect selected-invoice-first then eligible-debt allocation; never spill to another invoice/future debt.
- [ ] **C6-11 [I]** Connect daily/cash/shared funding and exactly one expense/source deduction.
- [ ] **C6-12 [V]** Reject overpayment, wrong/orphan references, paid-record reduction/deletion and invalid allocation.
- [ ] **C6-13 [V]** Inject failure at invoice/material/payment/journal boundaries and preserve the previous complete state.
- [ ] **C6-14 [V]** Verify edit/delete/correction outcomes under FIN-02 after restart.
- [ ] **C6-15 [V]** Prove87,500 invoice and12,500/7,500 payment allocation examples end to end.
- [ ] **C6-16 [I]** Expose payment available amount/allocation preview, category, note, date and list pagination.
- [ ] **C6-17 [I]** Connect payment edit/delete under accepted correction rules and verify import/backdating behavior.
- [ ] **C6-18 [V]** Verify unit-aware purchase analysis never combines carton and piece quantities through invented conversion.


## C7 — 09 settings, backups, import and recovery

Owner: App schema/UI; Madar file/store/fence adapters. Sources: [original phase09](../planning/flutter-rebuild/phases/09.md), [paired implementation plan](completion-implementation-plan.md), [engine obligations](../../../Madar_Engine/docs/reference/consumer-completion-implementation-plan.md).

- [ ] **C7-01 [I]** Mount restaurant identity, workflow, data/backup and about settings sections.
- [ ] **C7-02 [M]** Connect live receipt preview to restaurant settings.
- [ ] **C7-03 [I]** Connect shared save/discard bar and dirty navigation protection to settings controller.
- [ ] **C7-04 [I]** Connect shortcut ordering and order-type add/rename/enable/disable/delete/default controls.
- [ ] **C7-05 [V]** Verify max20unique types, at least one enabled and historical sale labels through UI.
- [ ] **C7-06 [I]** Expose complete validated account export with native save/share outcomes.
- [ ] **C7-07 [I]** Expose replacement-import preview with version/count/coverage inspection.
- [ ] **C7-08 [V]** Require explicit replacement confirmation and successful pre-import backup before commit.
- [ ] **C7-09 [I]** Expose backup status, previous-copy recovery and explicit cancellation.
- [ ] **C7-10 [V]** Verify unreadable, corrupt, oversized and future-version import/recovery leaves records unchanged.
- [ ] **C7-11 [V]** Verify successful replacement invalidates stale account/workspace callbacks and drafts.
- [ ] **C7-12 [V]** Complete macOS→Android→iPhone→separate test-account round trip with finalized operational records.
- [ ] **C7-13 [V]** Preserve retired worker history/account preferences while excluding active/held drafts and compact-device preference.
- [ ] **C7-14 [I]** Explain manual backup handoff rather than synchronization; use mobile native surfaces, not desktop paths.
- [ ] **C7-15 [V]** Test settings edits during save, conflict/recovery, disposal and account switching in connected UI.

## C8 — 10 statements, day review and seven reports

Owner: App composition; Madar reusable queries/collation/native adapters. Sources: [original phase10](../planning/flutter-rebuild/phases/10.md), [paired implementation plan](completion-implementation-plan.md), [engine obligations](../../../Madar_Engine/docs/reference/consumer-completion-implementation-plan.md).

- [ ] **C8-01 [M]** Mount statement from/to/category/source filters and date presets.
- [ ] **C8-02 [M]** Implement paid-spending statement totals, category ranking, transaction detail and pagination.
- [ ] **C8-03 [V]** Exclude unpaid invoice liabilities and reconcile source-filtered shares/ranked rows.
- [ ] **C8-04 [M]** Mount informational day review with temporary checkboxes and sales/refund/spending facts.
- [ ] **C8-05 [M]** Connect remaining-record, optional transfer and daily-PDF links back to correct context.
- [ ] **C8-06 [V]** Prove review checkboxes change no account data and create no closing/locking/profit record.
- [ ] **C8-07 [I]** Complete reusable Electron-compatible ICU/locale comparator with exact code/data provenance.
- [ ] **C8-08 [V]** Run comparator corpus on macOS, Android and iPhone; no lexical fallback or unsupported parity claim.
- [ ] **C8-09 [I]** Complete sales/refunds report integration and source sorting parity.
- [ ] **C8-10 [M]** Compose daily expense PDF from validated saved records.
- [ ] **C8-11 [M]** Compose supplier invoice PDF from validated saved records.
- [ ] **C8-12 [I]** Compose sale receipt PDF from saved receipt identity.
- [ ] **C8-13 [I]** Compose period sales/refunds PDF with stable filters.
- [ ] **C8-14 [M]** Compose account statement PDF with paid-spending semantics.
- [ ] **C8-15 [M]** Compose cashbox PDF with ledger/source context.
- [ ] **C8-16 [M]** Compose supplier-payment receipt PDF with saved allocation/funding.
- [ ] **C8-17 [V]** Inspect actual short and multipage PDFs for Arabic shaping, RTL, Latin numbers, A4, wrapping, repeated headers and page numbering.
- [ ] **C8-18 [I]** Connect save/open/share/system-print actions for all report kinds on each target.
- [ ] **C8-19 [V]** Verify cancellation, denied access, missing printer and service failure preserve saved transaction and never repost.
- [ ] **C8-20 [V]** Verify native physical-device handoffs and screen/PDF amount/date/filter parity.
- [ ] **C8-21 [V]** Verify cash-source statement filtering reports zero daily share, matching the frozen reference.


## C9 — 11 end-to-end acceptance and release

Owner: App delivery + included Madar conformance; owner release authority. Sources: [original phase11](../planning/flutter-rebuild/phases/11.md), [paired implementation plan](completion-implementation-plan.md), [engine obligations](../../../Madar_Engine/docs/reference/consumer-completion-implementation-plan.md).

- [ ] **C9-01 [V]** Run complete isolated restaurant day from setup/catalog through purchases/sales/refunds/expenses/transfers/reports/backup.
- [ ] **C9-02 [V]** Reconcile final stock, cash, liabilities, journals and exported records for that day.
- [ ] **C9-03 [V]** Repeat essential workflow/restart/error acceptance on macOS, Android and iPhone.
- [ ] **C9-04 [V]** Verify operational UI against approved references at matching logical sizes on each target.
- [ ] **C9-05 [V]** Verify large text, focus order, keyboard shortcuts, dialogs, scroll, safe areas and keyboard obstruction.
- [ ] **C9-06 [V]** Verify empty/loading/invalid/failed/unknown/retry/cancel states for each operational screen.
- [ ] **C9-07 [V]** Complete isolated migration rehearsal and export/reimport reconciliation.
- [ ] **C9-08 [V]** Complete installed-upgrade persistence and rollback rehearsal with retained fixture backup.
- [ ] **C9-09 [G]** Confirm target/platform support and obtain required physical-device/printer access.
- [ ] **C9-10 [G]** Resolve signing identity/Android keystore custody and authorized distribution format.
- [ ] **C9-11 [V]** Produce signed installed release candidates on all required targets after authorization.
- [ ] **C9-12 [V]** Finish independent architecture, MVVM, security/privacy and data-integrity review at final source.
- [ ] **C9-13 [V]** Resolve blocking findings and independently reverify affected behavior.
- [ ] **C9-14 [V]** Pass configured exact-head engine/app CI, source-pin checks, format/analyze/tests and applicable builds.
- [ ] **C9-15 [V]** Refresh linked reviewable PR diffs/dependencies and disclose remaining nonblocking risks.
- [ ] **C9-16 [G]** Obtain explicit approval of exact engine/app merge revisions; changed revisions require renewed approval.
- [ ] **C9-17 [V]** Merge only approved revisions in compatible dependency order and verify consumed engine pin.
- [ ] **C9-18 [V]** Deliver version/build/source/tool manifest, release notes, known limits and user backup/recovery/rollback manuals.
- [ ] **C9-19 [V]** Update authoritative trackers and separate project memories with actual final results before DONE.
- [ ] **C9-20 [V]** Run release/profile acceptance offline with kill/resume, restart and repeated taps.
- [ ] **C9-21 [V]** Exercise disk-full, long Arabic text, large datasets and malformed/future files on isolated fixtures.
- [ ] **C9-22 [V]** Verify small/landscape layouts and reduced-motion behavior alongside semantics and large text.
- [ ] **C9-23 [V]** Record deliberate visual differences against approved references rather than treating all screenshot mismatches as accepted.
- [ ] **C9-24 [V]** Confirm zero unresolved incorrect-total, lost-record, duplicate-posting or failed-recovery defects before release readiness.


## Q — Cross-cutting measurements, documentation and storage

Owner: Lead + app scenarios + Madar tooling. Sources: [original phase11](../planning/flutter-rebuild/phases/11.md), [paired implementation plan](completion-implementation-plan.md), [engine obligations](../../../Madar_Engine/docs/reference/consumer-completion-implementation-plan.md).

- [ ] **Q-01 [V]** Register remaining real-operation benchmarks individually; seven nonvisual historical baselines do not cover the full app.
- [ ] **Q-02 [V]** Measure catalog UI/search/photo and inventory workflows with representative fixtures.
- [ ] **Q-03 [V]** Measure durable checkout, held-ticket recovery, refunds and voids independently.
- [ ] **Q-04 [V]** Measure expense/correction/date-shift/transfer operations independently.
- [ ] **Q-05 [V]** Measure supplier ledger, purchase/payment and analysis operations independently.
- [ ] **Q-06 [V]** Measure import/export/recovery and each major report-generation path.
- [ ] **Q-07 [V]** Record elapsed p50/p95, sampled RAM/CPU, failures and exact source/tool/target/fixture conditions.
- [ ] **Q-08 [G]** Resolve documented capacity/performance budgets; avoid inventing acceptable latency.
- [ ] **Q-09 [V]** Record comparable baseline before optimization and validate any claimed improvement.
- [ ] **Q-10 [V]** Map each retained original requirement to an implementation and test/native receipt before closing it.
- [x] **Q-11 [V]** Reconcile stale top-level plan/tracker statements, local revisions and published PR evidence without erasing history.
- [ ] **Q-12 [V]** Complete public engine API/setup/examples/errors/limits/compatibility/recovery documentation with affected code.
- [ ] **Q-13 [V]** Verify safe leveled diagnostics, redaction, protocol stdout and logging-failure isolation where changed.
- [ ] **Q-14 [V]** Synchronize sanitized app and engine documentation separately and verify no pending/failed deliveries.
- [ ] **Q-15 [V]** Diagnose recurring Git tmp_objdir growth and prove containment across representative tool/agent batches.
- [x] **Q-16 [V]** Inspect preserved Git temporary/recovery objects, stop writers and delete only verified duplicates/obsolete outputs.
- [ ] **Q-17 [V]** Identify canonical needed Penpot archives/exports; verify duplicates by hash and retain required source/recovery evidence.
- [ ] **Q-18 [V]** Record free disk and hidden Git/build/cache/export/scratch deltas at every step completion.
- [ ] **Q-19 [V]** Keep storage-producing campaigns held when unexplained growth exceeds2GiB or free space falls below10GiB.

## Explicit exclusions: do not add these as unfinished features

No cloud/auth/multitenancy, Windows, grocery UI, recipe/kitchen/table system, purchase-to-sellable-stock conversion, camera barcode scanning, thermal/Bluetooth/ESC-POS printing, tax, tendered-cash/change input, automatic delivery fees, credit-customer expansion, payroll, invented COGS/profit, immutable day closing or store publication. Live TalkBack/screen-reader verification is owner-excluded, not passed. Retired worker/savings records remain compatibility data, not new operational UI. Broader Madar supported-release gates are outside this app Completion scope.

## Maintenance and audit limits

Keep this file as the detailed checklist; the live gap register provides a summary and links here. Do not duplicate native exports or full logs to update it. A separate read-only GPT-6.1 Sol audit checked original phase00–11 requirements and mvp-acceptance.md; its additional detail is incorporated into the relevant sections above. No runtime code, financial policy, design approval, merge or release is changed by this document.

## Audit receipt — 2026-11-07

Method: compare retained original scope, current paired plans/trackers, current lib source inventory/routing, existing contract/benchmark/design receipts and latest catalog verification. Independent audit supplied overlooked edge cases; no new runtime campaign ran. Planning/phase headers retain historical entries; this checklist and current summary distinguish them. Current-source evidence overrides stale summary text. Reuse existing unchanged-source receipts where applicable.

Storage baseline:104GiB free; .git27,906,164KiB, build622,820KiB, .dart_tool156,456KiB, outputs/penpot7,165,888KiB. This task creates only small Markdown/temporary drafting scripts, no builds or exports. Git recurrence remains open in Q-15; stable earlier short batches did not prove a permanent fix. Existing source, account data, designs and recovery objects retained.

Exact F10 successor closure: [reviewed source/adoption evidence](../log/2026-11-08-f10-reviewed-source-adoption-closure.md). Current consumed engine bb00ccdad8f6710ca1778260d42ed5584f26a86c; no remote or release action.
