"""Build the repository planning pack from its frozen screenshot manifest."""
from pathlib import Path
import json, html

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/planning/flutter-rebuild'
BASELINE_PHASES = [
('00','Baseline and delivery setup','None',
 'A runnable, isolated Flutter app on macOS, Android and iPhone, with a frozen specification.',
 ['Create the Flutter workspace in a separate flutter/ directory, retaining the working Electron app. Use separate development app identifiers and data locations until the final migration rehearsal.',
  'Pin the verified Flutter/Dart toolchain and dependency versions; record minimum supported OS versions and actual test devices. Build and launch a blank Arabic RTL shell on all three targets.',
  'Freeze these screenshots, source hashes, illustrative fixtures and feature inventory. Review the current plan with the owner; changes can be decided at the start of each later phase.',
  'Choose iPhone installation/distribution route, Apple signing identity, Android signing custody and macOS distribution route. Keep credentials outside the repository.',
  'Prove Arabic font availability/licensing, file picker import/export, local writes, PDF generation/share and system print entry points on all targets before depending on plugins. Select dependencies by this evidence, not by another project’s stack.'],
 ['Three launch records show device/OS/build versions and screenshots. A simulator build alone does not establish iPhone installation.', 'Every current screen and behavior has an owner phase. No current accounts have been opened, modified or migrated by this planning work.'],
 ['desktop-sales','desktop-expenses','desktop-settings-data']),
('01','Design system and responsive components','00',
 'A Flutter component gallery matching the current visual language.',
 ['Implement extracted colors, radii, spacing, page gutters, typography roles, Latin tabular financial values, Arabic labels and RTL reading order.',
  'Build the actual shared components: toolbar and shortcuts, buttons and icons, inputs, money/quantity/date fields, selects, tables, pagination, filters, badges, empty states, toast/status, standard and wide dialogs.',
  'Retain fluid full-width pages, catalog on the left and bill on the right, modest gutters, compact related totals, popover navigation and centered dialogs. Reuse the frozen product thumbnails and icon paths.',
  'Reproduce the current narrow reference at 390×844, then verify safe areas, keyboard open, scrollable form content, visible save/cancel, back gesture and large text on Android and iPhone.',
  'Choose a licensed Arabic font and establish a golden baseline per platform. Record glyph/rendering differences explicitly; do not claim raw macOS pixels can be identical on every platform.'],
 ['Component gallery screenshots cover default, focused, disabled, loading, validation and error states.', 'Side-by-side comparison at the same logical size shows no unexplained layout or copy differences. 320-wide and 200% text tests leave essential actions reachable.'],
 ['design-system','desktop-navigation','desktop-invoice-new','phone-invoice-new']),
('02','Local accounts, validation and safe persistence','00, 01',
 'Accounts can be saved, reopened and recovered safely while offline.',
 ['Define typed Dart models, codecs, IDs, date-only values, integer IQD money, scaled quantities up to three decimals, exact rounding and shared validation limits. Preserve source semantics and IDs, not just visible totals.',
  'Implement repository and local file service boundaries. Proposed first storage is versioned JSON with atomic replacement, validated writes, previous-copy backup and an explicit single-writer policy. Record any alternative in an ADR before changing it.',
  'Implement non-destructive legacy migrations for supported Electron schema versions 1–11. Preserve workers/savingsEntries and correction history as compatibility data with no worker UI.',
  'Add a separate durable workspace for active/held orders and device-only display preferences. File/account replacement clears old drafts only after a successful replacement.',
  'Handle loading, unreadable file, unsupported version, invalid import, full disk/write failure, interrupted write, backup recovery, save retry and app lifecycle interruption. Failed writes never show saved success or clear the user’s form.',
  'Create a deterministic parity corpus from synthetic JavaScript inputs/outputs. As each later feature is implemented, run the same cases through Dart; compare records and derived outputs.'],
 ['Restart round-trip preserves every supported record and setting. Unknown future schema is rejected without overwriting it.', 'Fault injection at each write boundary recovers either the last valid state or the complete new state. Import size limit and validation match the current 20 MiB boundary unless explicitly changed.', 'All money/date/quantity parsing and migration cases pass in Dart and in the frozen JavaScript reference.'],
 ['desktop-save-error','desktop-settings-data','empty-sales']),
('03','Navigation, shortcuts and interaction shell','01, 02',
 'All 12 screens are reachable through the same navigation model.',
 ['Rebuild the grouped popover menu and dismiss/scrim behavior, six configurable shortcuts, active state and current save/error status.',
  'Wire route restoration and unknown destinations back to Sales. Preserve the historic savings shortcut cleanup without exposing a retired screen.',
  'Implement keyboard traversal, Escape, focus trapping/restoration, menu shortcuts, session undo dispatch and dirty-form protection. Map mobile back/navigation onto the same rules.',
  'Provide compact loading, empty and failure shells without changing domain records. Keep every page aligned to the same gutters.'],
 ['Every route opens, closes and restores focus; hidden navigation cannot receive interaction.', 'Unsaved dialogs/settings require a discard decision; canceling it retains content. Navigation does not erase an active ticket.'],
 ['desktop-navigation','desktop-sales','phone-sales']),
('04','Expense categories','02, 03',
 'Expense categories can be managed without losing historical references.',
 ['Rebuild the category grid, add/edit dialog, primary/additional classification and automatic type save.',
  'Preserve built-in category identities and restrictions. Validate names and duplicate handling; allow custom category archive/restore behavior as supported by the source.',
  'Expose active categories to new expenses and supplier-payment defaults while historical entries keep their category identity. Support creating a category within the expense form.'],
 ['Add/edit/type/archive/reopen work offline and survive restart.', 'Existing expenses and supplier references retain their identity and financial values; invalid names do not save.'],
 ['desktop-categories','desktop-category-new','desktop-category-edit','phone-categories']),
('05','Sellable products and inventory','02, 03',
 'The sellable catalog and quantity ledger work end to end.',
 ['Rebuild catalog table, search, group/status/low-stock filters, pagination, add/edit product, code/barcode text, group, unit, price, reference photo and archive state.',
  'Implement tracked/untracked products, opening quantities, restock and signed adjustment/loss, effective dates, low-stock threshold and current-date availability.',
  'Rebuild stock history including sale/return links, future movement labels, reversal with reason and trace to the original entry. Corrections preserve history and cannot create negative historical stock.',
  'Lock unit/tracking changes once history exists; preserve prices and product details in saved sale lines. Keep supplier ingredients/materials separate: no recipe or automatic purchase-to-product conversion.',
  'Barcode is a searchable text/code field here. Camera scanning or new scanner hardware is outside this reproduction unless later requested.'],
 ['Opening, sale, return, restock, loss and reversal quantities reconcile for current and historical dates.', 'Archived, unavailable and low-stock states match the reference; filters keep keyboard focus. Changing a current price never rewrites a saved sale.'],
 ['desktop-inventory','desktop-product-new','desktop-product-edit','desktop-stock','desktop-stock-history','desktop-stock-reverse','phone-inventory']),
('06','Cash sale and saved receipt','02, 03, 05',
 'A sale can be completed once and safely, with stock and daily proceeds updated.',
 ['Reproduce photo cards, corner plus/count, group tabs/counts, search, compact display toggle and catalog pagination/scrolling.',
  'Build the right-hand ticket with quantity increment/decrement/direct entry, remove line, fixed discount, note, date, order type, subtotal and total; retain the price captured when adding an item.',
  'Exact-value checkout means confirming receipt of the net total. Do not add a tendered-cash input, taxes, fees, credit customers or automatic delivery charges.',
  'Persist before presenting the paid receipt. Protect duplicate taps, retries and stale workspace writes using durable operation/sale identity. Keep the ticket on any failed validation or save.',
  'After a successful save open the paid receipt with close/new-order, details, PDF and system-print actions. Connect file/print services incrementally; their final cross-platform completion is phase 17.'],
 ['Subtotal minus discount equals stored net; stock and daily sales change once. Retrying after restart cannot duplicate a saved sale or reuse a sale number.', 'Empty ticket, insufficient stock, archived product, invalid discount and changed date have explicit states. Failed saves retain the ticket.'],
 ['desktop-sales','desktop-sales-cart','desktop-sales-compact','desktop-sales-catalog-bottom','desktop-sales-no-results','desktop-sale-paid','phone-sales']),
('07','Active draft and held orders','02, 06',
 'Unpaid work survives closing and restarting the app.',
 ['Rebuild hold-name dialog, held list, resume/swap and deletion confirmation, including empty list.',
  'Persist active ticket and up to the source limit of 40 held orders in device/account-scoped storage; keep lines, price snapshots, date, discount, note and order type.',
  'A held order creates neither sale nor stock reservation nor cash effect. Resume checks current product availability at checkout.',
  'Switching to another held ticket atomically preserves the current one; handle storage failure and stale second-window state without losing either ticket.',
  'Keep these drafts outside the transferable accounts backup, matching current behavior. Explain their device-only boundary in the UI and manual.'],
 ['Force-close/reopen recovers active and held orders, scoped to the correct account.', 'Hold/resume failures preserve both sides; checkout conflicts cannot duplicate sales. Importing replacement accounts cannot resurrect unrelated drafts.'],
 ['desktop-hold-order','desktop-held-orders','desktop-sales-cart']),
('08','Sales history, returns and voids','02, 05, 06',
 'Saved sales can be found, inspected, refunded or corrected with faithful accounting.',
 ['Rebuild date/query/status/order-type filters, presets, pagination, totals, saved/void receipts and refund history.',
  'Implement partial and full returns with quantity, date, reason, explicit cash-refund confirmation and per-line optional restock. Display the calculated refund before saving.',
  'Use original price snapshots and cumulative discount allocation/rounding. Full successive refunds must equal the original net exactly, including fractional quantities.',
  'Refund affects daily net proceeds on its return date, never an expense or automatic cashbox withdrawal. Restock affects only the return date when selected.',
  'Void a sale without returns only, with reason and original-date reversal. Preserve its number and original record. A sale with returns uses further returns rather than void.'],
 ['Over-return, duplicate return and invalid dates are rejected. Full returns reconcile exactly and cannot double-deduct a fresh remaining snapshot.', 'History totals use sale dates and refund dates correctly, including a negative net return-only period. Saved receipt details persist after price changes.'],
 ['desktop-sale-history','desktop-receipt','desktop-sale-return','desktop-sale-void','desktop-void-receipt','phone-sale-return']),
('09','Daily expenses, remaining cash and chicken counts','02, 04, 08',
 'The daily ledger and its balances match the existing accounting rules.',
 ['Reproduce the daily table plus compact secondary cash-expense/remaining/chicken column; date selection, previous/next/today, expense add/edit/delete and notes.',
  'Implement daily/cash/shared funding with both shares validated. A shared expense appears in both source views, with no duplication in daily totals.',
  'Port remaining-cash snapshots and total-balance recording, automatic/manual expense totals, correction reasons/history, clear balance and session undo preserving inverse correction records.',
  'Port daily date correction and optional shift of following recorded days with preview/collision protection. Respect the independent dates of supplier invoices/debts, sales and inventory.',
  'Chicken used/left are counts only. Keep daily sales/refunds integrated with remaining snapshots without treating balances as profit.'],
 ['The numerical examples in accounting-parity.md pass for edits/deletes, shared funding, snapshots, later sales/refunds and transfers.', 'Correction/undo/date-shift tests preserve linked records and reject overlaps; chicken changes affect no monetary result.'],
 ['desktop-expenses','desktop-expense-new','desktop-expense-edit','desktop-validation','desktop-remaining','desktop-total','desktop-balance','desktop-day-date','desktop-chicken','phone-expenses']),
('10','Account statement and day review','03, 09',
 'Paid spending can be reviewed for a period and a day can be checked without closing it.',
 ['Reproduce from/to, category and source filters, date presets, summary amounts, descending category ranking, transaction detail and pagination.',
  'Use paid expenses and supplier payments, not unpaid invoice totals. Source-filtered shares remain correctly classified.',
  'Rebuild the short day-review dialog, temporary checkboxes, sales/refund/spending facts, record-remaining link, optional transfer and daily PDF link.',
  'Keep day review informational. It does not create an immutable closing record, lock a date or calculate profit.'],
 ['Cash-source filtering shows zero daily share, matching the reference. Ranked totals reconcile to visible rows.', 'Review checkboxes change no account data and no financial amount; links return to the correct daily context.'],
 ['desktop-statement','full-statement','desktop-day-review','phone-statement']),
('11','Suppliers, opening balances and debts','02, 03, 04, 09',
 'Supplier liabilities and ledger history can be managed.',
 ['Rebuild supplier picker/search, supplier add/edit, optional contact and note, category default, opening debt and supported archive behavior.',
  'Reproduce supplier summary, invoices/debts/ledger tabs, additional debt add/edit/delete and chronological before/after balances.',
  'Preserve IDs and relationships and enforce restrictions on debt reductions/deletions once allocated payments exist.',
  'Opening debt, added debt and invoice liability do not themselves create paid expense or cashbox movements. Payment actions link to phase 14.'],
 ['Opening debt + added debt + invoices − payments equals the supplier summary and ledger closing balance.', 'Backdated debt/invoice changes and payment allocations preserve history and reject underfunded edits.'],
 ['desktop-suppliers','desktop-supplier-picker','desktop-supplier-new','desktop-supplier-edit','desktop-supplier-debts','desktop-supplier-ledger','desktop-debt','phone-suppliers']),
('12','Shared supplier materials and default prices','02, 03, 11',
 'One materials catalog provides reusable invoice defaults.',
 ['Reproduce material search/status filters, add/edit/archive, name, unit and independent carton/piece defaults.',
  'Keep one shared catalog across suppliers. Selecting a material fills defaults in a new invoice but saves a snapshot on that invoice.',
  'Preserve legacy material identity/migration and duplicate-name handling. Do not infer a carton-to-piece conversion.'],
 ['Editing or archiving a material never rewrites an earlier invoice or debt total.', 'New invoice selection uses current defaults, while legacy single-unit lines remain readable and retain totals.'],
 ['desktop-materials','desktop-material-new','desktop-material-edit','phone-materials']),
('13','Purchase invoices and purchase analysis','02, 11, 12',
 'Dated supplier invoices and their quantity/price analysis work offline.',
 ['Rebuild separate purchase-invoice page, supplier/material/date filters, purchase groups/details and quantity/price history comparisons.',
  'Reproduce the wide invoice dialog with visible supplier/date/number context, scrollable lines and total/save actions. Support adding/selecting materials inline.',
  'Enter carton and piece quantities/prices independently; save snapshots and notes. Permit historical invoices with unique invoice number per supplier.',
  'Create liability only for an unpaid invoice. Invoice-with-payment must commit the invoice and payment together, following phase 14 allocation/funding rules; that path cannot be called finished before phase 14.',
  'Restrict edit/delete when payments exist. Preserve legacy quantity × unit-price lines and unit-aware analysis.'],
 ['Carton/piece calculations match rounding and range limits; quantities aggregate by unit without fabricated conversion.', 'Paid invoices cannot be deleted or reduced below their allocation. Inline material creation plus invoice save is atomic.'],
 ['desktop-invoices','desktop-invoice-new','desktop-invoice-new-bottom','desktop-invoice-edit','phone-invoice-new']),
('14','Supplier payments and allocation','02, 09, 11, 13',
 'Partial/full supplier settlement affects expenses and its funding source exactly once.',
 ['Rebuild payments list/filter/pagination and new/edit/delete payment dialog, supplier/invoice/debt choice, amount/date/category/note and funding split.',
  'Implement available amount and preview: pay the selected invoice first, then eligible supplier debt; store invoiceAmount and debtAmount.',
  'Never spill excess into another invoice or future debt. Prevent orphan references, wrong supplier, invalid payment date and overpayment.',
  'Connect purchase-with-immediate-payment atomically. A payment contributes one paid expense and one source effect; editing/deleting reverses prior effects appropriately.',
  'Provide payment receipt PDF entry; complete platform sharing in phase 17.'],
 ['The invoice/debt split and daily/cash split reconcile through restart/import/edit/delete and backdated operations.', 'Invoice + immediate payment either both save or neither saves. No path double-counts expense or deducts the source twice.'],
 ['desktop-payments','desktop-payment-new','desktop-payment-edit','desktop-invoice-new-bottom','phone-payment-new']),
('15','Cashbox and daily transfers','02, 09, 14',
 'Cash movements and transfers reconcile with the daily ledger.',
 ['Rebuild cash card, movement ledger/running balance, filters, external deposit/withdrawal, edit/delete and cash context popover.',
  'Include derived cash-funded expense/payment movements without permitting a second independent edit of a derived movement; route to its source.',
  'Transfer part/all of available remaining daily cash to cashbox once. Editing/deleting restores both sides correctly and preserves the saved total-balance meaning.',
  'Keep existing negative-balance indications where the source allows them; do not introduce unapproved blocking rules or label cashbox balance as profit.'],
 ['External deposits, withdrawals, shared expenses, payments and transfers reconcile to the model and filtered running balances.', 'A transfer above available daily cash is blocked. Editing or deleting a transfer adjusts daily and cashbox once, with no expense created.'],
 ['desktop-cash','desktop-cash-popout','desktop-cash-deposit','desktop-cash-withdrawal','desktop-cash-edit','desktop-daily-transfer','phone-cash']),
('16','Settings, backups, import and recovery','02, 03, 06, 07, 14, 15',
 'A user can configure the app and safely move or restore all finalized records.',
 ['Reproduce restaurant identity/live receipt preview, workflow, data/backup and about sections, a shared save/discard bar and dirty-state protection.',
  'Implement shortcut ordering and order-type add/rename/enable/disable/delete/default rules. At least one enabled type; unique names across both lists; maximum 20. Existing sales retain their original type.',
  'Export the complete validated account schema. Import is replacement, not merge: inspect counts/coverage/version, confirm replacement and create a pre-import backup before committing.',
  'Show backup status and previous-copy recovery, invalid/unreadable/oversized file states and explicit cancel paths. Mobile uses system file/share surfaces instead of a desktop folder path.',
  'Preserve retired worker data and account preferences. Keep active/held tickets and compact-display preference device-only. Explain that copying a backup is a manual handoff, not synchronization.'],
 ['Export on macOS → import on Android → export → import on iPhone → reimport in a separate test account preserves finalized records, IDs, totals and supported legacy data.', 'Rejected/canceled import and failed recovery preserve current data. Successful replacement clears stale workspace safely; no account or draft silently mixes with another.'],
 ['desktop-settings','desktop-settings-workflow','desktop-settings-data','desktop-settings-about','phone-settings-data']),
('17','Arabic PDF reports, sharing and system printing','06, 08, 10, 13, 14, 15, 16',
 'Every current operational report can be exported/shared and printed through the system.',
 ['Reproduce daily expenses, supplier invoice, sale receipt, period sales/refunds, account statement, cashbox and supplier-payment receipt. Retired worker reports remain compatibility code only, with no new visible workflow.',
  'Generate from validated saved records and stable IDs/filters, never user-provided HTML or editable display totals. Match Arabic shaping, RTL order, Latin numbers, A4 layout, table wrapping, page breaks, repeated headings and page numbering.',
  'Provide save/share/open actions on each target and normal system print dialogs. Cancel, denied file access, no printer and service failure leave the saved transaction intact.',
  'Use report HTML screenshots as content/style references, then render actual Flutter PDFs and inspect every page. HTML screenshots are not evidence of PDF output fidelity.',
  'No thermal printer/Bluetooth/ESC-POS work is included. Store signing, sharing and print integration evidence per platform.'],
 ['Seven report kinds export from all three platforms; amounts and date/filter boundaries match on screen and in the file.', 'Open/print/share is tested with native surfaces on physical devices; system print cancellation creates no new sale or payment. Arabic text is intact in short and multipage outputs.'],
 ['report-daily','report-invoice','report-sale','report-sales','report-statement','report-cash','report-payment']),
('18','Complete MVP verification, migration rehearsal and release','00–17',
 'Installable MVP builds on all three platforms, with end-to-end evidence and rollback instructions.',
 ['Run the full synthetic restaurant-day scenario in release/profile builds: import, products/opening stock, invoice, partial shared payment, sales, hold/resume, return, expenses, remaining snapshot, transfer, day review, reports, export, restart and restore.',
  'Run the complete parity suite, widget tests and integration tests. Compare macOS/Android/iPhone captures to the frozen references and approved per-platform goldens. Record deliberate differences and owner decisions.',
  'Test app kill/resume, device offline/restart, duplicate tap, disk full, bad file, unknown schema, long Arabic names, large datasets, small screens, landscape, safe area, keyboard open, large text and accessibility semantics.',
  'Build signed installable artifacts for macOS/Android/iPhone through the chosen distribution route. Validate installation, launch, native import/export/share/print and update persistence on physical target devices.',
  'Rehearse migration using synthetic legacy copies first. Before any later live cutover, make a private verified backup and keep Electron available for rollback. Never point both implementations at the same writable accounts file.',
  'Deliver app builds, source, release notes, backup/import/restore manual, known issues and rollback procedure. Public store publishing is a separate explicit action if requested.'],
 ['All checks in mvp-acceptance.md pass with attached evidence. No data-loss, duplicate-posting or incorrect-financial-total defect is open.', 'Each target has a real install/run record, migration round-trip and native service results. Any missing signing/device/printer requirement is reported as a remaining blocker, not marked passed.'],
 ['desktop-sales-cart','desktop-expenses','desktop-invoice-new','phone-sales','phone-expenses','report-daily'])
]

# Current owner-requested consolidation. Baseline work/check items remain intact.
PHASE_GROUPS = [
('00', 'Baseline and delivery setup', 'None', ['00'],
 'A runnable, isolated Flutter app on macOS, Android and iPhone, with a frozen specification.',
 'Keep platform/toolchain and distribution proof separate from feature implementation.'),
('01', 'Design system, navigation and interaction shell', '00', ['01','03'],
 'A responsive Arabic component system and complete navigation shell with shortcuts and safe form interactions.',
 'The shell uses the same components, focus behavior, dialogs and responsive rules; build and review them together.'),
('02', 'Local accounts, validation and safe persistence', '00, 01', ['02'],
 'Accounts can be saved, reopened and recovered safely while offline.',
 'Keep storage and compatibility as an early gate; settings will expose its file operations in phase 09.'),
('03', 'Sellable products and inventory', '01, 02', ['05'],
 'The sellable catalog and quantity ledger work end to end.',
 'Keep stock history, reversals and historical quantity checks together as one complete inventory feature.'),
('04', 'Cash sales, saved receipt, drafts and held orders', '01, 02, 03', ['06','07'],
 'A cashier can build, suspend, recover and complete a ticket safely, with a saved receipt and one stock/cash effect.',
 'Draft recovery and hold/resume are part of the same ticket lifecycle as checkout; separating them created a partially finished sales flow.'),
('05', 'Sales history, returns and voids', '02, 03, 04', ['08'],
 'Saved sales can be found, inspected, refunded or corrected with faithful accounting.',
 'Keep return/void accounting and historical stock checks as a distinct verification gate after checkout.'),
('06', 'Daily accounting, expense categories and cashbox', '01, 02, 05', ['04','09','15'],
 'Categories, source-funded expenses, daily balances, chicken counts, cash movements and daily-to-cashbox transfers reconcile as one workflow.',
 'Categories feed expense entry, and daily/cash funding and transfers change both ledgers; implement and verify them together.'),
('07', 'Suppliers, debts, materials and prices', '01, 02, 06', ['11','12'],
 'Supplier liabilities and a shared materials/default-price catalog are ready for purchasing.',
 'Supplier and material setup are the reference data used by the same purchase workflow.'),
('08', 'Purchase invoices, analysis and supplier payments', '02, 06, 07', ['13','14'],
 'Invoices, quantity/price analysis and partial/full settlement work together, including atomic invoice-with-payment.',
 'Immediate payment already belongs to invoice entry; combining them removes a later-phase dependency from a core purchase action.'),
('09', 'Settings, backups, import and recovery', '01, 02, 04, 06, 08', ['16'],
 'A user can configure the app and safely move or restore all finalized records.',
 'Keep the complete settings and user-facing recovery review after operational records are available; reuse phase 02 storage services.'),
('10', 'Statements, day review, PDF reports and printing', '03, 04, 05, 06, 07, 08, 09', ['10','17'],
 'The owner can review paid spending and the restaurant day, then export/share/print every operational report.',
 'Statements/day review and their reports share filters, financial meanings and export actions; verify screen-to-document parity together.'),
('11', 'Complete MVP verification, migration rehearsal and release', '00–10', ['18'],
 'Installable MVP builds on all three platforms, with end-to-end evidence and rollback instructions.',
 'Keep independent end-to-end, installed-device and cutover verification as the final gate.')
]
OLD_TO_NEW = {old:group[0] for group in PHASE_GROUPS for old in group[3]}
assert set(OLD_TO_NEW)=={p[0] for p in BASELINE_PHASES}
assert sum(len(g[3]) for g in PHASE_GROUPS)==len(BASELINE_PHASES)
BASELINE = {p[0]:p for p in BASELINE_PHASES}

def update_phase_references(text):
    import re
    text=re.sub(r'\bphase (\d{2})\b',lambda m:'phase '+OLD_TO_NEW[m[1]],text)
    text=text.replace('following phase 08 allocation/funding rules; that path cannot be called finished before phase 08',
                      'using this phase’s allocation/funding rules; both invoice and immediate payment must work before this phase is complete')
    text=text.replace('Create the Flutter workspace in a separate flutter/ directory, retaining the working Electron app.',
                      'Create the Flutter workspace at this project root, retaining the unchanged Electron reference in electron-reference/.')
    return text

PHASES=[]
for number,title,deps,old_ids,outcome,reason in PHASE_GROUPS:
    scope=[update_phase_references(item) for old in old_ids for item in BASELINE[old][4]]
    checks=[update_phase_references(item) for old in old_ids for item in BASELINE[old][5]]
    featured=list(dict.fromkeys(item for old in old_ids for item in BASELINE[old][6]))
    if number=='06':
        scope.append('Validate payment-derived expense/cash effects with synthetic saved payment records here; phase 08 must also prove the live invoice/payment UI updates these same ledgers once.')
    PHASES.append((number,title,deps,outcome,scope,checks,featured))

def remap_owners(raw):
    import re
    if raw=='03; visible features 04–16':return '01; visible features 03–10'
    found=[]
    for first,last in re.findall(r'(\d{2})(?:–(\d{2}))?',raw):
        found.extend(f'{n:02}' for n in range(int(first),int(last or first)+1))
    mapped=','.join(sorted({OLD_TO_NEW[n] for n in found}))
    if 'and feature phase' in raw:return mapped+' and feature phase'
    if 'and every visual phase' in raw:return mapped+' and every visual phase'
    if 'and each owning feature' in raw:return mapped+' and each owning feature'
    return mapped or raw

def write(name,text):
    if name=='feature-coverage.md':
        lines=[]
        for line in text.splitlines():
            cells=line.split('|')
            if line.startswith('|') and len(cells)>3 and cells[-2].strip()[:2].isdigit():
                cells[-2]=' '+remap_owners(cells[-2].strip())+' '
                line='|'.join(cells)
            lines.append(line)
        text='\n'.join(lines).replace('phases 00/16/17/18','phases 00/09/10/11')
        text=text.replace('| app/', '| electron-reference/app/').replace('; app/', '; electron-reference/app/')
    p=OUT/name; p.parent.mkdir(parents=True,exist_ok=True); p.write_text(text.strip()+'\n')

manifest=json.loads((OUT/'screenshot-manifest.json').read_text())
shots=[{**s, 'capturePhase':s.get('phase'), 'phase':OLD_TO_NEW.get(s.get('phase'),s.get('phase'))} for s in manifest['screenshots']]
lookup={s['id']:s for s in shots}
assert not manifest['errors'],manifest['errors']
phase_links=[]
# Remove superseded active phase pages; their historical copies are in archive/.
active_ids={p[0] for p in PHASES}
for suffix in ['.md','.html']:
    for page in (OUT/'phases').glob('*'+suffix):
        if page.stem not in active_ids:page.unlink()
for number,title,deps,outcome,scope,checks,featured in PHASES:
    filename=f'phases/{number}.md'
    phase_links.append(f'| {number} | [{title}]({filename}) | {deps} | Not started |')
    refs=list(dict.fromkeys(featured+[s['id'] for s in shots if s.get('phase')==number]))
    missing=[s for s in refs if s not in lookup]; assert not missing,(number,missing)
    text=f'''# Phase {number} — {title}

Status: planned, not implemented. Date: 2026-10-27. Depends on: {deps}.

Outcome: {outcome}

Includes former phase(s): {', '.join(next(g[3] for g in PHASE_GROUPS if g[0]==number))}. [Merge rationale and old-to-new map](../phase-map.md).

[Master plan](../README.md) · [Screenshot gallery](../gallery.html?phase={number}) · [Design contract](../design-system.md) · [Accounting contract](../accounting-parity.md)

Execution rules: [AGENTS.md](../../../../AGENTS.md) · scope index: [PLANS.md](../../../../PLANS.md) · authoritative status/evidence: [PHASES.md](../../../../PHASES.md). This published scope file does not establish phase completion.

## Work to deliver

'''
    group=next(g for g in PHASE_GROUPS if g[0]==number)
    for old in group[3]:
        text+=f'### {BASELINE[old][1]}\n\n'
        text+='\n'.join(f'- [ ] {update_phase_references(x)}' for x in BASELINE[old][4])+'\n\n'
    if number=='06':text+='- [ ] '+scope[-1]+'\n'
    text+='''

## Acceptance for this feature

'''+ '\n'.join(f'- [ ] {x}' for x in checks) + '''

- [ ] Run this phase’s behavior tests with isolated synthetic records; save command/result evidence.
- [ ] Capture the implemented Flutter screen and dialogs on macOS, Android and iPhone; compare the same state and logical size against the references below.
- [ ] Verify empty, populated, invalid, loading, failed-save and retry/cancel states where applicable; test restart persistence for every changed record.
- [ ] Review with the owner at this phase. Preserve the current design unless an explicit change is recorded; an undecided edit does not authorize a redesign.
- [ ] Update feature coverage, decisions and the project log; synchronize project documentation and verify no pending/failed memory work.
- [ ] Satisfy the adopted workflow: dedicated phase branch/worktree and PR, applicable Figma validation and user design approval (or Design: N/A), read-only planning, meaningful tests before behavior changes, independent review/re-verification and required CI/benchmark evidence.
- [ ] Record user approval, merged PR and applicable release/rollback validation in PHASES.md before marking DONE. Never merge without user approval or automatically start the next phase.

## Screenshot references

These are current Electron screenshots with synthetic data, except the explicitly labelled design board and report HTML. They specify composition and current behavior; they do not prove a Flutter implementation. Phone captures are narrow current-UI references, not native Android/iPhone captures. See the capture contract before comparing pixels.

'''
    primary=list(dict.fromkeys(BASELINE[old][6][0] for old in group[3]))
    for id in primary if len(primary)>1 else featured[:2]:
        text+=f'![{lookup[id]["title"]}](../screenshots/{lookup[id]["file"]})\n\n'
    text+='| Reference | Kind |\n| --- | --- |\n'
    for id in refs:
        s=lookup[id]; kind='Full document' if s.get('fullDocument') else 'Narrow viewport' if s.get('mobile') else 'Full viewport'
        text+=f'| [{id}](../screenshots/{s["file"]}) | {kind} |\n'
    text+=f'''
## Handoff for implementation

Read AGENTS.md, PLANS.md, PHASES.md, the master plan, this phase, its screenshot set and source evidence. Implement phase {number} only when the owner has started it and its dependencies are complete. First report source/reference mismatches, establish dedicated Git isolation and apply the design/approval gate where relevant. The Lead coordinates a read-only Planner, appropriate UX/Workers and an independent Reviewer. Preserve the current design and scope. End with working results, actual tests/captures, review and PR evidence in PHASES.md. Do not mark DONE before approved merge and applicable release validation; do not automatically start the next phase.
'''
    write(filename,text)

write('README.md',f'''# Daftar — Flutter/Dart rebuild to a complete MVP

Status: revised 12-phase planning baseline, superseding the original 19-phase sequence; Flutter implementation has not started. Date: 27 October 2026 (Asia/Baghdad). Owner: restaurant/project owner. Reference: current working tree, Electron {manifest['appVersion']}, account schema {manifest['schema']}.

## Confirmed scope

- One restaurant; Arabic RTL and IQD. Rebuild in Flutter and Dart for **macOS, Android and iPhone**.
- Fully offline, one device’s local account at a time. Each installation holds its own data. Backups/import provide deliberate manual handoff; no merge or automatic device synchronization.
- Reproduce the **same current features and design**. The owner will decide any edits when the relevant phase begins. Until then, exact current-design reproduction is the baseline.
- PDF export/share and normal system printing. Thermal-printer integration is outside this MVP.
- Preserve existing finalized records, schema migrations, financial meanings, IDs, history and backup recovery. Retired worker data survives import/export; its removed screen stays removed.
- This task delivers the plan and reference pack. It does not install a replacement application, migrate real records or publish to stores.

## Start here

1. Browse the [visual reference gallery](gallery.html) — **{len(shots)} captured images** with desktop, narrow, dialog, full-document, empty-state, design-system and report references.
2. Follow the [{len(PHASES)} phase files](#phase-sequence), in dependency order. Every phase names a working feature/outcome, implementation checklist, screenshots and testable exit criteria.
3. Keep the [design contract](design-system.md), [accounting parity contract](accounting-parity.md), [feature/source inventory](feature-coverage.md) and [MVP acceptance checklist](mvp-acceptance.md) beside the work.
4. At the start of a phase, ask for any edits to that feature. Record accepted changes and replace only the affected reference baseline; retain the previous one. Do not pause unrelated agreed work waiting for speculative changes.
5. Finish each phase with working code, tests and Flutter captures. A visual mockup or a passing build alone does not finish a feature.

Read the adopted [AGENTS.md](../../../AGENTS.md), [PLANS.md](../../../PLANS.md) and [PHASES.md](../../../PHASES.md) before execution. PHASES.md is authoritative for status and evidence; all phases are initially TODO. The published table below is a scope overview and does not waive the workflow gates.

## Phase sequence

| Phase | Feature | Dependencies | Execution state |
| --- | --- | --- | --- |
{chr(10).join(phase_links)}

Phases 00–02 establish the runnable foundation; 03–05 deliver inventory and the complete sales lifecycle; 06–08 deliver accounting and purchasing; 09–11 finish settings/data portability, reporting and verified delivery. Some domain infrastructure is shared, but no screen is declared complete until its full workflow and failure cases work.

## Consolidation from 19 to 12 phases

The owner requested fewer, more coherent phases. The revision combines design with navigation, sales with draft/held-ticket recovery, daily accounting with categories and cashbox, suppliers with materials, invoices with settlement, and statements/day review with reports/printing. Storage safety, inventory, return accounting and final release remain distinct gates.

All original work items, feature-specific acceptance checks and {len(shots)} screenshot files are retained. Dependencies and screenshot filters use the new numbering. The [phase map](phase-map.md) records every old-to-new assignment and why it was merged; the [historical 19-phase version](archive/v1-19-phases/plan.html) remains available for comparison and is superseded. A merged phase includes several workstreams and is complete only when all of them pass.

## Proposed implementation boundaries

These are implementation recommendations to validate in phase 00/02, not additional owner-approved product features:

- The Flutter rebuild will use this project root. The old application, dependencies and tests now live in `electron-reference/`; plans and screenshots remain in `docs/planning/flutter-rebuild/`. Do not overwrite the reference or use the production storage path during development. [Folder-layout decision](../../decisions/0013-electron-reference-folder.md).
- Flutter views and view models render/coordinate; pure Dart domain code validates and computes; repositories are the single write boundary; platform services provide files, storage, sharing, print and lifecycle. Widgets do not calculate money or write account files.
- Begin with compatible, versioned local JSON and a reliable single-writer, validated atomic save/backup service. It matches the current offline product and minimizes migration risk. A database is not required by this request; any storage change needs a separate documented decision and proof of lossless compatibility.
- Keep finalized account data, recoverable ticket workspace and device-only preferences separate. Use stable operation identity and durable validation for duplicate prevention; no server is required.
- Choose and pin state-management, file, font, PDF and print packages after three-platform capability checks. No AlDakhl/Madar/PowerSync/Supabase dependency is implied.

These boundaries follow the separation of views, view models, repositories and services described in the [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide). They remain tailored to this local single-restaurant app.

## What “follow exactly” means

Use the frozen screenshots for Arabic wording, composition, alignment, density, colors, pictures, spacing, controls and visible state. Compare equivalent synthetic data at the same logical size. Preserve desktop full-width alignment and catalog/bill placement. Preserve function while fitting phone safe areas and keyboards.

The current narrow screenshots were rendered by Electron on macOS, **not** by Android or iOS. They cannot establish native fonts, safe areas, keyboard behavior, file dialogs or printing. Phase 01 must capture actual Flutter phone references and record unavoidable platform differences; no silent redesign is permitted. Cross-platform glyph/pixel identity is not promised before the font decision.

## Completion rule for every phase

All behavior tests and screenshot comparisons relevant to that phase pass; macOS/Android/iPhone paths are exercised; failed save/cancel/restart behavior is covered; no real restaurant records were used as test fixtures; the owner’s accepted edits are documented; actual evidence is linked. Each implementation phase has dedicated Git isolation, a read-only plan, meaningful tests before behavior changes, independent review/re-verification, applicable numeric benchmarks and required CI. UI work requires its suitable reference validated in Figma and user design approval before implementation; non-UI work records Design: N/A. Existing screenshot intent does not establish that new Figma gate as passed.

Only PHASES.md records execution completion. DONE requires all applicable requirements, user approval, merged PR and applicable release/rollback validation. Never merge without user approval and never automatically start the next phase. Missing dependency, design, signing/device or access evidence remains pending/blocked and cannot be relabelled passed.

## Decisions to resolve when needed

| Decision | Resolve by | Default until then |
| --- | --- | --- |
| Screen/behavior edits | Start of each feature phase | Exact current source and design |
| Arabic font and asset licensing | 00–01 | Current macOS look is reference; no unlicensed font redistribution |
| Minimum OS/device matrix; macOS architectures | 00 | All three requested platforms remain required |
| iPhone delivery and Apple signing; Android signing; Mac installation route | 00, proved in 11 | Private/test delivery first; no automatic store publishing |
| JSON implementation and platform packages | 00–02 | Preserve compatibility and validate capability before adopting |
| Physical test devices/system printer access | 00 and 10 | Record unavailable hardware honestly; simulator-only checks do not finish native paths |

No additional product questions are required to start this plan. Login, multi-restaurant/multiuser support, cloud sync, recipes, kitchen tickets, tables, modifiers, tax engine, loyalty, camera scanning, thermal hardware, campaign publishing and profit reporting are not silently added. A held-order label such as “table 3” is not a table-management feature.

## Evidence and reference maintenance

The capture harness uses only synthetic in-memory accounts and an isolated Electron profile. [Manifest](screenshot-manifest.json) records capture metadata, image dimensions/checksums and current UI source hashes. Its phase labels are the original capture numbers; [phase-map.json](phase-map.json) translates them for the current plan without altering the capture record. [Capture guide](capture-guide.md) explains regeneration and limits. The existing JavaScript baseline passed **140/140 tests** when the original pack was created; this revision changes documentation only and claims no new app or Flutter test/build/run.

Authoritative behavior is documented in [accounting rules](../../reference/accounting-rules.md), [application reference](../../reference/application.md), [scope](../../reference/project-scope.md) and decisions 0002–0010. [Decision 0011](../../decisions/0011-flutter-rebuild-baseline.md) records the rebuild boundary; [decision 0012](../../decisions/0012-merge-flutter-rebuild-phases.md) records this phase consolidation. Changes to this plan require evidence and an updated log, not a rewritten history.
''')

write('design-system.md','''# Design reproduction contract

Status: extracted reference plus planned acceptance rules, 2026-10-27. No Flutter implementation yet.

[Visual board](design-system.html) · [Board image](screenshots/design-system.png) · [Computed tokens](design-tokens.json) · [All screenshots](gallery.html)

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
''')

write('accounting-parity.md','''# Financial and data parity contract

Status: current-source behavior to preserve, 2026-10-27. This is not a new accounting policy or a claim of Flutter implementation.

Sources: model.js symbols in feature-coverage.md, current accounting-rules.md, decisions 0002, 0003, 0004 and 0010. Use exact arithmetic and the source’s bounds/rounding; do not substitute visually plausible totals.

## Rules and reference examples

| Case | Required behavior / deterministic example |
| --- | --- |
| Money and input | Whole IQD amounts; Arabic/Persian digits normalize; reject invalid sign, fraction, exponent and out-of-range values according to the source. Current money validator bounds magnitude at 10^12. Quantities allow up to three decimal places. |
| Shared expense | Expense 30,000 split daily 20,000 + cash 10,000: daily spending rises 20,000, cashbox falls 10,000, combined expense remains 30,000. |
| Remaining snapshot | Start with daily spending 20,000, transferred 5,000 and net sales 30,000. Record physical remaining 100,000. After another daily expense 3,000, transfer 2,000, sale 8,000 and refund 1,000, remaining becomes 102,000. Earlier movements are not applied again. |
| Remaining formula | snapshot.amount − (current dailySpent − snapshot.dailySpent) − (current transferred − snapshot.transferred) + (current net sales − snapshot.salesTotal, default 0 in legacy snapshots). |
| Recorded total balance | On recording remaining: total(daily, including manual override if set) + recorded physical remaining + transfers already made from that day. Future transfer does not rewrite that recorded balance. Cashbox-funded expense is excluded. |
| Daily transfer | From remaining 100,000, transfer 20,000: daily remaining 80,000; cashbox +20,000; no expense; saved total balance unchanged. Edit/delete reverses the prior effect once. |
| Supplier invoice | 2 cartons ×40,000 +3 pieces ×2,500 =87,500 liability. No paid expense until settlement. No carton-to-piece conversion. |
| Supplier payment | Invoice due 12,500 + eligible debt 50,000; payment 20,000 splits invoice 12,500 and debt 7,500. If funding daily 15,000/cash 5,000, expenses get that single 20,000 payment and each source only its share. |
| Supplier excess | Excess cannot pay a different invoice, unavailable future debt or a nonexistent liability. Invoice number uniqueness is per supplier. |
| Snapshot preservation | Changing catalog material price or current product price does not rewrite old invoice/sale lines or totals. |
| Sale | Subtotal minus fixed discount = net. New quick sale records exact net received; old tendered/change values remain as recorded. Type has no automatic fee. |
| Returns | Original sale remains. Refund on return date reduces daily net sales, not expenses/cashbox. Optional restock on return date only. Cumulative discounted partial refunds equal original net at full return. |
| Void | Only eligible sale without returns; reason required; reverse at original sale date while preserving number/history. |
| Inventory | Opening + restocks + signed adjustments − completed sale quantities + selected restocked returns, with dated reversals. Prevent negative historical stock. Supplier materials never silently add sellable stock. |
| Worker history | Preserve workers and savingsEntries with legacy validation and no operational worker screen; these do not affect expenses, supplier balances or cashbox. |
| Chicken | Quantities only; no monetary effect. |
| Statement | Paid expenses/payments, filtered by actual funding share. Cash-only filter gives daily share zero. Unpaid purchase liability is not paid spending. |
| Day review | Temporary checkboxes and facts; no new close-day ledger or immutable audit claim. |
| Undo/corrections | Preserve current session undo and financial correction trails, including inverse corrections; do not invent a permanent universal audit log. |

The labels remaining, daily total balance and cashbox balance are never aliases for profit. Sales net is after discount/void/refund, not business net profit.

## Compatibility and failure corpus

Use synthetic fixtures for schema 1–11 covering empty accounts and every entity: categories, days/expenses/chicken/balances/snapshots/corrections, transactions, transfers, suppliers, materials, invoices, payments/allocations, debts, workers, savingsEntries, products, stockEntries, sales, saleReturns and preferences. Check missing optional fields and historic order types/disabled types/retired shortcuts.

For each domain command, retain input, stable IDs/date/timestamp, expected validated output, derived totals, rejection reason and unchanged-state expectation. Run JavaScript and Dart on the same corpus. Compare per-record identity and allocations as well as totals; canceling errors can hide record corruption.

Cover boundaries: fractional quantity rounding; full discount/zero-value line; cumulative partial returns; earlier/later dates and midnight; negative refund-only net; manual total overrides; backdated stock and payments; duplicate IDs/numbers; orphan relationships; oversized/unknown-version files; malformed amounts; interrupted save; stale second window; duplicate taps/retries; lossless export/import and recovery.

Maintain separate suites for pure Dart domain tests, repository fault injection, widget/golden checks and real platform integration. The existing JavaScript suite passed 140 tests for this planning baseline. No Dart parity results exist yet.
''')

evidence=[
('12 routes; worker route removed','app/ui/index.html','top-level navigation','25–37','03; visible features 04–16'),
('Daily expenses, statement, cash and category pages','app/ui/renderer.js','expensesPage / statementPage / cashPage / categoriesPage','44–70','04,09,10,15'),
('Dialogs and mutation dispatch','app/ui/renderer.js','openDrawer / submitForm / commit','86–98;124–180;199–235','02 and feature phase'),
('Sales catalog, cart and checkout','app/ui/commerce.js','salesPage / renderProducts / renderCart / commerceAction','14–38;87–115','06'),
('Products and sale history','app/ui/commerce.js','inventoryPage / renderInventory / salesHistoryPage / commerceDrawer','39–71','05,08'),
('Return and held workflows','app/ui/commerce.js','saleReturnFields / refreshReturnQuote / heldOrdersDialog / holdCurrentOrder / resumeHeldOrder','156–215','07,08'),
('Durable drafts, focus, dirty guards and lists','app/ui/ux.js','allowLeave / restoreSaleDraft / writeSaleWorkspace / pageItems / enhanceDialog','49–76;120–129','02,03,07'),
('Day review and stock event history','app/ui/ux.js','stockHistory / dayReview','152–153','05,10'),
('Settings and order manager','app/ui/ux.js','organizedSettingsPage / initializeSettings / activateSettingsSection / orderTypeManager','209–300','16'),
('Supplier tabs, materials, invoice analysis and payments','app/ui/suppliers.js','suppliersPage / invoicesPage / supplierDetail / materialsPage / supplierDrawer / supplierSubmit','10–87;150–183','11–14'),
('Daily, funding, balances, dates, supplier calculations','app/ui/model.js','dailySpent / remaining / recordRemaining / transferRemaining / correctDayDates / splitPayment / supplierBalance','16–150','09–15'),
('Integer money, quantities and compatibility','app/ui/model.js','numeric / quantity / money / validate / validateSavings','9–14;95–109;226–263;265;416–451','02'),
('Sales/return/inventory arithmetic and validation','app/ui/model.js','returnQuote / returnSale / stock / validateCommerce / completeSale / voidSale','294–414','05–08'),
('Validated atomic writes and backups','app/storage.cjs','Storage','4–32: constructor / load / atomic / save','02,16'),
('Native file, import, print and report boundary','app/main.cjs','IPC handlers; app.whenReady','43–103: handle and accounts:* registrations','16,17,18'),
('Seven active report kinds','app/reports/pdf.cjs','daily / invoice / sale / periodReport / paymentReceipt / createReport','28–100','17'),
('Visual controls and responsive rules','app/ui/styles.css; app/ui/commerce.css; app/ui/ux.css','.button / .drawer / .product-grid / :root / media queries','frozen files in reference-assets; source hashes in manifest','01 and every visual phase')
]
write('feature-coverage.md','''# Feature and source coverage

Status: current-source observations, checked 2026-10-27. Source identity: working tree, not a claim about the installed app. This inventory is newer than the historic 13-screen memory: index.html contains 12 visible routes and worker savings UI is retired by decision 0007.

Each observation includes file, enclosing symbol and proof location. Read the current source before implementation; the manifest fingerprints this capture baseline. Numeric ranges below are proof locations, not a promise that later source line numbers remain stable.

| Observation | File | Symbol | Proof | Owning phase |
| --- | --- | --- | --- | --- |
'''+ '\n'.join(f'| {obs} | {f} | {sym} | {proof} | {phase} |' for obs,f,sym,proof,phase in evidence)+'''

## User-facing scope mapping

| Current screen/workflow | Planned phase |
| --- | --- |
| Sales, compact catalog, ticket and paid receipt | 06 |
| Active ticket recovery and held orders | 02,07 |
| Sales history, receipt detail, returns and voids | 08 |
| Inventory/product editor/stock history/reversal | 05 |
| Daily expenses, funding, balances, chicken and date correction | 09 |
| Account statement and quick day review | 10 |
| Suppliers, opening/additional debts and ledger | 11 |
| Materials and prices | 12 |
| Purchase invoices, carton/piece lines and analysis | 13 |
| Supplier payments and allocation | 14 |
| Cashbox, external movements and daily transfer | 15 |
| Categories | 04 |
| Restaurant/workflow/data/about settings | 16 |
| File replacement, backup recovery and legacy records | 02,16 |
| PDFs, native share/open and system print | 17 |
| Dirty forms, keyboard focus, filters, pagination, undo, failures | 01–03 and each owning feature |
| Signed installs, physical devices and migration/cutover evidence | 00,18 |

## Explicit limitations and unknowns

No Flutter code, native phone screenshot, real account migration, signed release or physical printer verification was performed by this plan. Report captures show HTML reference output rather than actual Flutter PDFs. Native file/print dialogs are platform-owned and cannot be specified by these Electron screenshots; reproduce their operation and test them in phases 00/16/17/18.

Campaign/idea documentation is not an app feature. Workers/savingsEntries and historical report support are retained for compatibility; the removed worker screen is not in the rebuild. No cloud backend, multi-restaurant model, recipe conversion, camera scanner, thermal printer or profit dashboard is implied.
''')

write('mvp-acceptance.md','''# MVP acceptance and cutover checklist

Status: all Flutter checks pending. These checkboxes describe future evidence, not results from the Electron baseline.

The adopted [AGENTS.md](../../../AGENTS.md), [PLANS.md](../../../PLANS.md) and [PHASES.md](../../../PHASES.md) govern execution. Each phase requires dedicated Git isolation and PR traceability, applicable Figma validation/user design approval, meaningful tests before behavior changes and independent review. Record benchmarks as numeric evidence or justified N/A. DONE also requires the approved merged PR and applicable release/rollback checks; never automatically start the next phase.

## Functional completion

- [ ] Phases 00–10 meet their individual acceptance criteria; all 12 current screens and related dialogs work on macOS, Android and iPhone.
- [ ] A complete synthetic day covers purchase invoice → partial/shared settlement → stock → cash sales → hold/resume → refund → expense → record remaining → transfer → review → reports.
- [ ] Original/changed/void/refunded sales, dated stock, supplier balances, payments, daily shares, remaining snapshots and cashbox reconcile with the JavaScript corpus.
- [ ] Every supported old schema imports with the same IDs, snapshots and historical values; worker compatibility data is retained without a worker screen.
- [ ] Every mutation has validation, save status, cancel, failure/retry and restart evidence. No duplicate posting from retry/double tap/restart.

## Visual and interaction completion

- [ ] Actual macOS/Android/iPhone captures are attached for every phase; owner-reviewed changes have decision records and before/after references.
- [ ] Typography, RTL, financial digits, photo assets, colors, alignment, density, dialogs, table overflow, empty and error states match their approved baseline.
- [ ] Small/medium/large screens, phone safe areas, soft keyboard, landscape, large text and reduced motion are covered; primary actions remain reachable.
- [ ] Keyboard, screen reader semantics, focus visibility/trapping/restoration and mobile back/gesture behavior are verified.

## Offline and portable-data completion

- [ ] Core work succeeds with connectivity disabled; no login/network dependency is introduced.
- [ ] Force-close/reopen restores the last committed accounts and the active/held workspace correctly.
- [ ] macOS → Android → iPhone → isolated macOS backup round-trip retains all finalized records and supported settings; drafts remain device-only.
- [ ] Import preview, pre-import backup, replacement confirmation, cancellation, malformed/oversized/future-version file rejection and previous-copy restore are exercised.
- [ ] Disk/write failure and interrupted writes preserve recoverable valid state. Concurrent/stale writer conflicts cannot overwrite a newer account/workspace.

## Reports and native services

- [ ] Seven report types export on all targets; actual PDFs are rendered and all pages inspected for Arabic shaping, pagination, long text and exact totals.
- [ ] System share/save/open works on Android and iPhone, and save/open/reveal works on macOS where appropriate.
- [ ] Native system print dialogs are tested, including no printer/cancel/failure; no accounting mutation occurs during printing. Physical successful printing is recorded when a compatible printer is available; do not claim it without evidence.
- [ ] Native file pickers and permission-denial paths are tested outside widget tests.

## Installed delivery and rollback

- [ ] Signed macOS, Android and iPhone artifacts use the agreed delivery channels and preserve data after an update.
- [ ] Each platform has a physical-device installation/launch/native-service record with app build, OS and device model.
- [ ] A synthetic migration rehearsal succeeds before live cutover. Any later live import uses a private verified backup, amount/record-count comparison and an untouched rollback copy.
- [ ] Electron and Flutter never write the same production file concurrently. A rollback restores the correct backup/version rather than trusting an incompatible newer export.
- [ ] The owner receives builds, source, release notes, known limitations, backup/recovery instructions and rollback instructions.
- [ ] No unresolved incorrect-total, lost-record, duplicate-posting or failed-recovery defect remains. Missing credentials, hardware or native test evidence are listed as blockers.

## Evidence record per target

| Evidence | macOS | Android | iPhone |
| --- | --- | --- | --- |
| Signed installed build + OS/device | Pending | Pending | Pending |
| Complete day flow offline | Pending | Pending | Pending |
| Domain/data parity corpus | Pending | Pending | Pending |
| Native file import/export/recovery | Pending | Pending | Pending |
| Draft/held restart recovery | Pending | Pending | Pending |
| Visual/keyboard/large text | Pending | Pending | Pending |
| Seven actual PDFs inspected | Pending | Pending | Pending |
| Share/open/print native behavior | Pending | Pending | Pending |
| Update persistence + rollback | Pending | Pending | Pending |

Flutter’s official integration_test does not interact with native platform UI; combine domain/widget/integration checks with native device verification for file pickers, share sheets and print dialogs. Source: [Flutter integration testing](https://docs.flutter.dev/cookbook/testing/integration/introduction).

Delivery references, to recheck during implementation: [iOS/TestFlight/signing](https://docs.flutter.dev/deployment/ios), [Android release/signing](https://docs.flutter.dev/deployment/android), [macOS release/signing](https://docs.flutter.dev/deployment/macos).
''')

write('capture-guide.md',f'''# Frozen screenshot reference pack

Status: captured and catalogued 2026-10-27. {len(shots)} images; {len(manifest['errors'])} capture errors in the final run.

The captures are unchanged by the 19-to-12 phase consolidation. The original manifest/harness retain capture-time phase IDs; phase-map.json maps those IDs to the current plan. The builder applies the map to the gallery and phase reference tables; do not renumber the capture provenance or recapture images just to change grouping.

## Provenance

The harness loads electron-reference/app/ui/index.html with the original preload and an isolated profile at dist/flutter-reference-profile. Its IPC handlers supply only fabricated in-memory restaurant records. It never creates Storage against the installed app directory or reads real accounts. Sample supplier names, receipts, debt and balances are illustrative; menu images and synthetic expanded catalog do not authorize real product additions. The 2026-10-28 folder move did not change any captured image or capture manifest; sourceHashes now resolve inside electron-reference/app/ui/.

The manifest records the current UI file hashes, logical viewport and physical PNG dimensions. A capture can have 2× physical pixels on Retina despite its logical layout size. Compare matching logical size and scale, not image width alone. The final capture uses desktop 1440×1000 and narrow 390×844; report HTML uses 794×1123, and the extracted design board uses 1440×1200.

## Naming

- desktop-*: entire app content viewport at its original layout; dialogs include background and all visible controls.
- phone-*: entire narrow Electron viewport. These are references for responsive fitting, not screenshots from iOS/Android devices.
- full-*: Chromium full natural document capture without CSS changes. Internal independently scrollable regions are not magically expanded; use paired bottom/scroll references.
- *-bottom: same viewport after scrolling the document or form to its lower content; a duplicate can be intentional when content already fits.
- empty-*: actual current screen rendered from an empty synthetic account.
- report-*: rendered current report HTML, including full-document copies. These do not assert PDF rendering or print pagination fidelity.
- design-system: board assembled from extracted current tokens/components; not a screen shipped in the app.
- desktop-validation and desktop-save-error: deliberately presented failure/validation states for visual reference. The save-error capture is a simulated presentation, not a claim that a disk failure occurred.

## Regeneration

Do not regenerate the baseline merely because implementation differs. When the owner changes a design, archive the existing manifest/images first, then capture a new revision and record the change.

From the project root, run the local Electron capture harness, then the Python planning-pack builder:

```sh
./electron-reference/node_modules/.bin/electron scripts/capture-flutter-reference.cjs
python3 scripts/build-flutter-plan.py
```

The design board and frozen assets are already present. Review differences against sourceHashes; update reference-assets only for an intentional new baseline. Capture profiles, generated report HTML and logs under dist/ are disposable, whereas docs/planning/flutter-rebuild is the durable handoff pack.

## What remains for implementation

Capture actual native Flutter screenshots, soft-keyboard/safe-area states, native import/share/print dialogs, crash recovery and fault-injection behavior on the requested devices. Add middle scroll positions for unusually long lists/forms where neither endpoint shows all fields. Phase acceptance requires these tests; the planning screenshots alone do not establish them.
''')

mapping_rows=[]
for old,p in BASELINE.items():
    new=OLD_TO_NEW[old]
    title=next(g[1] for g in PHASE_GROUPS if g[0]==new)
    mapping_rows.append(f'| {old} — {p[1]} | [{new} — {title}](phases/{new}.md) |')
reason_rows=[f'| [{n} — {title}](phases/{n}.md) | {", ".join(old)} | {reason} |' for n,title,deps,old,outcome,reason in PHASE_GROUPS]
write('phase-map.md',f'''# Phase consolidation — 19 to 12

Status: current sequence, revised at the owner’s request on 2026-10-27. No Flutter implementation or feature scope changed.

The original phase numbers are historical identifiers. Use the new numbers in the [current plan](README.md), phase files and gallery. A label such as old 06 or old 17 refers only to the archived version or capture manifest.

## New workstreams and reasons

| Current phase | Former phase IDs | Why grouped or kept separate |
| --- | --- | --- |
{chr(10).join(reason_rows)}

## Every original phase has an owner

| Historical phase | Current phase |
| --- | --- |
{chr(10).join(mapping_rows)}

## Preservation and dependency rules

Every original implementation item and feature-specific acceptance check is retained in the merged phase. Workstreams have named subsections rather than losing detail in a shorter summary. All {len(shots)} original image files and the immutable capture manifest are retained; current screenshot filters translate capture IDs using [phase-map.json](phase-map.json).

The dependency graph has only earlier-phase dependencies. In particular, the daily/cashbox phase 06 uses synthetic saved payments to verify derived source effects; purchase/payment phase 08 must prove live end-to-end integration with those ledgers. Invoices and immediate settlement now finish in the same phase. Phase 10 reporting follows operational data and settings, and phase 11 remains the independent final acceptance gate.

The [preservation audit](merge-audit.json) lists each original work/check item with its new owner and updated phase references. All platforms, accounting rules, error/recovery cases and final MVP acceptance remain required. Phase status remains planned/not started.

The [archived original plan](archive/v1-19-phases/plan.html) is retained for comparison, explicitly marked superseded and excluded from project-memory indexing. Do not implement from its obsolete numbering. Earlier logs remain historical evidence.
''')
write('phase-map.json',json.dumps({'revision':'2026-10-27-12-phases','old_phase_count':len(BASELINE_PHASES),'current_phase_count':len(PHASES),'old_to_new':OLD_TO_NEW,'groups':[{'phase':n,'title':title,'dependencies':deps,'former_phases':old,'reason':reason} for n,title,deps,old,outcome,reason in PHASE_GROUPS]},indent=2))
items=[]
for old,p in BASELINE.items():
    for kind,index in [('work',4),('acceptance',5)]:
        for i,item in enumerate(p[index],1):
            items.append({'id':f'old-{old}-{kind}-{i:02}','old_phase':old,'new_phase':OLD_TO_NEW[old],'kind':kind,'original':item,'current':update_phase_references(item)})
write('merge-audit.json',json.dumps({'original_work_items':sum(len(p[4]) for p in BASELINE_PHASES),'original_acceptance_items':sum(len(p[5]) for p in BASELINE_PHASES),'preserved_items':items,'additional_integration_check_phase':'06','screenshots_retained':len(shots)},indent=2,ensure_ascii=False))

# Static local gallery: no backend or dependency, with phase/kind/text filters.
cards=[]
references={s['id']:{s.get('phase','')} for s in shots}
for number,title,deps,outcome,scope,checks,featured in PHASES:
    for id in featured:references[id].add(number)
for s in shots:
    tags=' '.join([s['id'],s.get('title',''),s.get('phase','')])
    kind='report' if s['id'].startswith('report-') else 'phone' if s.get('mobile') else 'full' if s.get('fullDocument') else 'empty' if s['id'].startswith('empty-') else 'desktop'
    cards.append(f'''<article data-phase="{' '.join(sorted(references[s['id']]))}" data-kind="{kind}" data-search="{html.escape(tags.lower(),quote=True)}"><a href="screenshots/{s['file']}" target="_blank"><img loading="lazy" src="screenshots/{s['file']}" alt="{html.escape(s.get('title',s['id']),quote=True)}"></a><div><small>PHASE {' / '.join(sorted(references[s['id']]))} · {kind.upper()}</small><h3>{html.escape(s['id'])}</h3><p>{html.escape(s.get('title',''))}</p><p>{s.get('width','?')} × {s.get('height','?')} logical · {s.get('pixelWidth','?')} × {s.get('pixelHeight','?')} PNG</p><a href="screenshots/{s['file']}" target="_blank">Open full screenshot ↗</a></div></article>''')
options=''.join(f'<option value="{n}">{n} · {html.escape(t)}</option>' for n,t,*_ in PHASES)
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Daftar · Flutter rebuild reference library</title><style>
*{box-sizing:border-box}body{margin:0;background:#f6f7f2;color:#17382d;font:15px/1.5 -apple-system,BlinkMacSystemFont,sans-serif}header{padding:38px max(24px,4vw) 20px;background:#17382d;color:#fefefa}header p{color:#d6e7b8;max-width:940px}h1{font-size:34px;margin:0 0 8px}header a{color:#d6e7b8}nav{display:flex;gap:20px;flex-wrap:wrap;margin:20px 0}.filters{position:sticky;top:0;z-index:1;background:#f6f7f2ef;backdrop-filter:blur(8px);display:flex;gap:12px;flex-wrap:wrap;padding:18px max(24px,4vw);border-bottom:1px solid #e2e8dd}input,select{min-height:44px;border:1px solid #ccd8c8;border-radius:8px;padding:10px 12px;color:#17382d;background:#fefefa;font:inherit}input{flex:1;min-width:200px}main{padding:24px max(24px,4vw);display:grid;grid-template-columns:repeat(auto-fill,minmax(330px,1fr));gap:24px}article{border:1px solid #e2e8dd;border-radius:12px;background:#fefefa;overflow:hidden}article img{width:100%;height:245px;object-fit:contain;object-position:top;background:#eaf0e4}article>div{padding:18px}h3{font-size:16px;margin:6px 0;overflow-wrap:anywhere}small{font-size:11px;color:#4c6051;letter-spacing:1px}article p{font-size:12px;color:#4c6051;margin:6px 0}a{color:#245b42}[hidden]{display:none!important}#count{align-self:center;font-size:13px}footer{padding:24px 4vw;color:#4c6051;font-size:12px}
</style><header><small style="color:#d6e7b8">DAFTAR / FLUTTER REBUILD / 27 OCTOBER 2026</small><h1>Current app. Every phase. A visual reference.</h1><p>COUNT screenshots from the current Electron UI with synthetic accounts. Desktop 1440×1000 and narrow 390×844 references, dialogs, empty states and report HTML. Native Flutter work has not started. Use the plan alongside these pictures to preserve both design and behavior.</p><nav><a href="README.md">Master plan</a><a href="design-system.html">Design board</a><a href="design-system.md">Design contract</a><a href="accounting-parity.md">Accounting rules</a><a href="mvp-acceptance.md">MVP checklist</a><a href="screenshot-manifest.json">Capture manifest</a></nav><p style="font-size:12px">Phone references are narrow Electron screenshots, not Android/iPhone captures. Full-document images retain the actual CSS; independently scrolling regions also have viewport references.</p></header><div class="filters"><input id="query" placeholder="Search screens, dialogs, reports…" aria-label="Search reference screenshots"><select id="phase" aria-label="Phase"><option value="">All phases</option>OPTIONS</select><select id="kind" aria-label="Reference type"><option value="">All reference types</option><option>desktop</option><option>phone</option><option>full</option><option>empty</option><option>report</option></select><span id="count"></span></div><main>CARDS</main><footer>Reference captures only · exact current-design baseline until the owner changes a phase · no real restaurant data · local files with no external dependencies.</footer><script>
const q=document.querySelector('#query'),p=document.querySelector('#phase'),k=document.querySelector('#kind');p.value=new URLSearchParams(location.search).get('phase')||'';function filter(){let n=0;for(const el of document.querySelectorAll('article')){const ok=(!p.value||el.dataset.phase.split(' ').includes(p.value))&&(!k.value||el.dataset.kind===k.value)&&(!q.value||el.dataset.search.includes(q.value.toLowerCase()));el.hidden=!ok;if(ok)n++;}document.querySelector('#count').textContent=n+' references';}q.addEventListener('input',filter);p.addEventListener('change',filter);k.addEventListener('change',filter);filter();</script></html>'''.replace('COUNT',str(len(shots))).replace('OPTIONS',options).replace('CARDS',''.join(cards))
write('gallery.html',page)

# Readable offline HTML editions of the plan and every phase, alongside Markdown.
import re, posixpath
md_files=[p for p in OUT.rglob('*.md') if 'archive' not in p.relative_to(OUT).parts]
def html_name(md):
    if md==OUT/'README.md':return 'plan.html'
    if md==OUT/'design-system.md':return 'design-system-contract.html'
    return str(md.relative_to(OUT).with_suffix('.html'))
editions={str(md.relative_to(OUT)):html_name(md) for md in md_files}
def inline(raw,origin):
    raw=html.escape(raw)
    def rewrite(url):
        plain=html.unescape(url)
        if not plain.startswith(('https:','http:','#')):
            file,sep,frag=plain.partition('#')
            key=posixpath.normpath(posixpath.join(str(origin.relative_to(OUT).parent),file))
            if key in editions:
                relative=posixpath.relpath(editions[key],str(Path(html_name(origin)).parent))
                return html.escape(relative+('#'+frag if sep else ''),quote=True)
        return url
    raw=re.sub(r'!\[([^\]]*)\]\(([^)]+)\)',lambda m:f'<a class="figure" href="{rewrite(m[2])}"><img loading="lazy" src="{rewrite(m[2])}" alt="{m[1]}"></a>',raw)
    raw=re.sub(r'(?<!!)\[([^\]]*)\]\(([^)]+)\)',lambda m:f'<a href="{rewrite(m[2])}">{m[1]}</a>',raw)
    raw=re.sub(r'`([^`]+)`',r'<code>\1</code>',raw)
    raw=re.sub(r'\*\*([^*]+)\*\*',r'<strong>\1</strong>',raw)
    return raw
def render(md):
    lines=md.read_text().splitlines();parts=[];i=0;slugs={}
    while i<len(lines):
        s=lines[i]
        if not s.strip():i+=1;continue
        if s.startswith('```'):
            block=[];i+=1
            while i<len(lines) and not lines[i].startswith('```'):block.append(lines[i]);i+=1
            parts.append('<pre><code>'+html.escape('\n'.join(block))+'</code></pre>');i+=1;continue
        heading=re.match(r'^(#{1,6}) (.*)',s)
        if heading:
            level=len(heading[1]);slug=re.sub(r'[^\w -]','',heading[2].lower()).replace(' ','-')
            parts.append(f'<h{level} id="{slug}">{inline(heading[2],md)}</h{level}>');i+=1;continue
        if s.startswith('|'):
            rows=[]
            while i<len(lines) and lines[i].startswith('|'):
                cells=[c.strip() for c in lines[i].strip('|').split('|')]
                if not all(re.fullmatch(r':?-+:?',c.replace(' ','')) for c in cells):rows.append(cells)
                i+=1
            parts.append('<div class="table-wrap"><table>')
            for n,row in enumerate(rows):
                tag='th' if n==0 else 'td';parts.append('<tr>'+''.join(f'<{tag}>{inline(c,md)}</{tag}>' for c in row)+'</tr>')
            parts.append('</table></div>');continue
        if re.match(r'^(?:- |\d+\. )',s):
            ordered=bool(re.match(r'^\d+\. ',s));tag='ol' if ordered else 'ul';parts.append('<'+tag+'>')
            while i<len(lines) and re.match(r'^(?:- |\d+\. )',lines[i]):
                item=re.sub(r'^(?:- |\d+\. )','',lines[i]);checkbox=''
                if item.startswith('[ ] '):checkbox='<input type="checkbox" disabled aria-label="Pending"> ';item=item[4:]
                parts.append('<li>'+checkbox+inline(item,md)+'</li>');i+=1
            parts.append('</'+tag+'>');continue
        para=[s];i+=1
        while i<len(lines) and lines[i].strip() and not re.match(r'^(?:#|\||```|- |\d+\. )',lines[i]):para.append(lines[i]);i+=1
        parts.append('<p>'+inline(' '.join(para),md)+'</p>')
    return '\n'.join(parts)
style='''*{box-sizing:border-box}body{margin:0;background:#f6f7f2;color:#17382d;font:16px/1.75 -apple-system,BlinkMacSystemFont,sans-serif}nav{position:sticky;top:0;z-index:2;padding:14px 5vw;background:#17382df5;display:flex;gap:22px;flex-wrap:wrap;backdrop-filter:blur(8px)}nav a{color:#d6e7b8;font-size:14px}main{max-width:1160px;margin:35px auto 90px;padding:0 28px}h1{font-size:36px;line-height:1.25;margin:36px 0 18px}h2{font-size:25px;margin:40px 0 16px;border-top:1px solid #d4dfcf;padding-top:20px}h3{font-size:20px}p{margin:12px 0}a{color:#245b42;text-underline-offset:3px}li{margin:10px 0}code{font-size:13px;background:#eaf0e4;padding:2px 5px;border-radius:4px}pre{padding:20px;border-radius:10px;background:#eaf0e4;overflow:auto}.table-wrap{overflow:auto;margin:18px 0}table{border-collapse:collapse;width:100%;background:#fefefa;font-size:14px}th,td{padding:12px 14px;border:1px solid #e2e8dd;text-align:left;vertical-align:top}th{background:#eaf0e4}.figure{display:block;margin:22px 0;background:#eaf0e4;border:1px solid #d4dfcf;border-radius:10px;overflow:hidden}.figure img{display:block;max-width:100%;width:auto;max-height:640px;margin:auto;object-fit:contain}input[type=checkbox]{accent-color:#245b42;margin-right:6px}footer{color:#4c6051;font-size:12px;margin-top:45px;border-top:1px solid #d4dfcf;padding-top:15px}@media(max-width:600px){main{padding:0 18px}h1{font-size:29px}nav{gap:14px}body{font-size:15px}}'''
for md in md_files:
    file=html_name(md);depth=len(Path(file).parts)-1;prefix='../'*depth
    title=md.read_text().splitlines()[0].lstrip('# ')
    edition=f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(title)}</title><style>{style}</style><nav><a href="{prefix}plan.html">Master plan</a><a href="{prefix}gallery.html">{len(shots)} screenshot references</a><a href="{prefix}design-system.html">Design board</a><a href="{prefix}accounting-parity.html">Accounting contract</a><a href="{prefix}mvp-acceptance.html">MVP checklist</a></nav><main>{render(md)}<footer>Daftar · 27 October 2026 · Planning/reference only · Flutter implementation not started · <a href="{md.name}">Markdown source</a></footer></main></html>'''
    write(file,edition)
gallery=(OUT/'gallery.html').read_text()
for key,value in editions.items():gallery=gallery.replace('href="'+key+'"','href="'+value+'"')
write('gallery.html',gallery)
print(json.dumps({'phases':len(PHASES),'screenshots':len(shots),'captureErrors':len(manifest['errors'])}))
