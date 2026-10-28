# Daftar — full app, UX and UI audit

Follow-up: the owner subsequently authorized all fixes. See the [implementation and verification record](2026-10-26-ux-audit-resolution.md). This document preserves the original audit baseline.

Status: inspection and proposals only. No application fixes or accounting changes were made by this audit. Date: 26 October 2026. Scope: current source 1.11.0 / schema 9, all 13 sections, using isolated illustrative accounts. The installed 1.10.1 app was not updated or used for transaction tests.

**Verdict:** the calm Arabic RTL design is worth preserving. The largest gaps are transaction clarity, recovery from mistakes, historical context and efficient repeated work. A cosmetic redesign alone would leave the most consequential problems in place.

**Visual anti-pattern verdict: mostly passes.** This is not a generic neon/gradient dashboard. The remaining generic patterns are slogan headings, repeated navigation, too many bordered panels, and uniformly prominent explanatory text. The product grid itself is appropriate to the cashier task and the owner’s sketch.

The list distinguishes **Observed** behavior, **Measured** results, **Source** findings and **Design** recommendations. A source/design finding is not a claim that a user has already suffered a loss. This is a broad inspection, not a guarantee that every possible defect or hardware combination has been discovered.

## Evidence and coverage

- Visited and captured all 13 sections: Sales, Sales history, Inventory, Daily expenses, Statement, Suppliers, Purchase invoices, Materials, Payments, Cash, Worker savings, Categories, Settings.
- Exercised sale completion, save failure/retry, cancellation, cart navigation/reload/clear, stock restock/damage, product creation/edit/archive, expense entry with Arabic numerals, cash transfer/delete/undo, supplier creation, purchase with fractional quantity and partial payment, payment editing, blocked deletion of a paid invoice, worker creation/contribution/receipt, category creation, shortcuts and order types.
- Inspected empty states, cross-date edits, future stock, invalid dates, settings, recovery/storage, native menu actions and export paths.
- Tested sales geometry at 1440×1000, 1252×943, 1000×700, 900×580, 760×844, 390×844 and 390×640, with sidebar open and closed. No page-level horizontal overflow in those sales cases. Checkout stayed inside the unzoomed windows. Also checked seven other principal screens at 900×580 without page-level horizontal overflow.
- Tested actual Electron 200% zoom at 900×580 and found checkout inaccessible; narrow-phone cases are secondary diagnostics, since the shipped native window has a 900px minimum width.
- Ran the existing automated suite: **96 passed / 96**. Those tests do not cover all findings below; passing them does not negate reproduced defects.
- Generated daily, purchase and sale PDFs from sample records. Native save/open dialogs, physical printing, real scanner hardware, VoiceOver and a full WCAG conformance audit were not exercised. Export/import storage paths were inspected and covered by existing relevant tests; browser preview export limitations are not counted as app bugs.
- Performance sample: one synthetic 5,000-sale history render, about 798ms including forced layout on this machine. Treat as a reproducible warning, not a statistical benchmark.
- Real restaurant accounts and the user’s browser draft were not used or modified. Temporary browser/Electron audit profiles were separate.

Screenshots, raw measurements and sample PDFs are under `outputs/ux-audit-2026-10-26/`. The interactive report provides screen links alongside relevant findings.

## Priorities

P0 = widespread blocker or unrecoverable loss requiring immediate stop; none established in this review. P1 = significant correctness, recovery, accessibility or task-completion problem; fix before trusting the new flows in routine use. P2 = meaningful friction or clarity gap; address in the next UX pass. P3 = useful polish or maintenance after the workflows are sound.

**64 audit items: 63 findings plus one owner-requested design change. 16 P1, 44 P2, 4 P3; no P0 established.**

## Design and technical health

These are reviewer assessments, not automated certification scores.

| Nielsen heuristic | Score / 4 | Main reason |
| --- | ---: | --- |
| Visibility of system status | 2 | Save state hides with sidebar; filters and dates can mislead |
| Match with the real world | 2 | Arabic task language works, but totals and inventory date meanings conflict |
| User control and freedom | 1 | Draft loss and unsafe whole-state undo |
| Consistency and standards | 2 | Filter, date and module-context behavior varies |
| Error prevention | 1 | Empty-supplier dead end, hidden date, overly broad defaults |
| Recognition rather than recall | 2 | Explicit navigation, but related tasks are scattered |
| Flexibility and efficiency | 2 | Custom shortcuts and quick cash checkout; repeated modal friction |
| Aesthetic and minimalist design | 3 | Cohesive palette and clear bill, with redundant headings/panels |
| Error recovery | 2 | Save failure retains input; field guidance and draft recovery are weak |
| Help and documentation | 2 | Useful embedded rules, but lengthy text substitutes for guided flow |
| **Total** | **19 / 40** | **Strong base; substantial workflow correction needed** |

| Technical dimension | Score / 4 | Main reason |
| --- | ---: | --- |
| Accessibility | 2 | Focus loss, contrast failures and zoom blocker |
| Performance | 2 | Oversized thumbnails and unbounded history rendering |
| Responsive design | 2 | Unzoomed desktop fits; enlarged/short viewport fails |
| Theme consistency | 2 | Tokens exist, but many later overrides and hard-coded values; dark mode is not a requirement |
| Visual anti-patterns | 3 | Mostly intentional, with repetitive headings and containers |
| **Total** | **11 / 20** | **Significant work needed** |

## What should remain

1. Arabic RTL, warm light surfaces, calm green accents and clear tabular financial numerals.
2. The owner’s sales arrangement: products on the left, bill on the right, checkout anchored and independent item scrolling at normal desktop sizes.
3. Product reference photos, exact-total cash checkout without reintroducing the cash-received input, editable order types and configurable top shortcuts.
4. The owner’s latest direction: replace persistent sidebars/edge panels with pop-out panels over the workspace (D64). Keep a clear, reachable menu trigger; the earlier collapsed-sidebar treatment is no longer the target design.
5. Validated atomic saving, preserved historical sale prices, visible cancellation reasons, blocked deletion of paid purchase invoices, and the separation of daily cash, safe cash, supplier debt and worker savings.

## Findings

### D01 · P1 · First invoice can leave the app stuck

**Area:** Purchases · **Evidence:** Observed

With no suppliers, Purchases still offers Add invoice. Clicking it throws an Arabic exception meaning “Select a supplier first.”, creates no visible drawer, and leaves an internal drawer state that prevents navigation.

**Why it matters:** A first-time owner meets a silent dead end before recording the first purchase. Escape is an undocumented recovery.

**Proposed change:** Offer “Add a supplier and start an invoice” when no suppliers exist. Validate prerequisites before opening the entry form; show any failure visibly and clear the pending state.

**Acceptance check:** Start with empty accounts, add the first supplier, continue directly into the invoice, and verify navigation still works after canceling.

**Source:** [app/ui/suppliers.js:77](../../electron-reference/app/ui/suppliers.js:77), [app/ui/suppliers.js:189](../../electron-reference/app/ui/suppliers.js:189), [app/ui/renderer.js:121](../../electron-reference/app/ui/renderer.js:121), [app/ui/renderer.js:247](../../electron-reference/app/ui/renderer.js:247)

[Screen evidence](../../outputs/ux-audit-2026-10-26/bug-empty-invoice.png)

### D02 · P1 · Editing a statement row uses the wrong day

**Area:** Daily accounts · **Evidence:** Observed

From the statement, editing a 25 October expense while the selected day is 26 October opens “Add expense”, with an empty amount and the 26 October date. The edit action passes an ID without its date.

**Why it matters:** The owner cannot reliably correct an older expense. Validation prevents a duplicate expense ID from being saved, but the resulting failure is confusing; this is not evidence of existing data corruption.

**Proposed change:** Resolve the expense and its original date from the clicked row. Open a correctly populated edit form and return to the same filtered statement after saving.

**Acceptance check:** Edit an expense from a different day and confirm that exactly that record changes, with its original date retained unless explicitly edited.

**Source:** [app/ui/renderer.js:61](../../electron-reference/app/ui/renderer.js:61), [app/ui/renderer.js:130](../../electron-reference/app/ui/renderer.js:130), [app/ui/renderer.js:256](../../electron-reference/app/ui/renderer.js:256), [app/ui/model.js:388](../../electron-reference/app/ui/model.js:388)

[Screen evidence](../../outputs/ux-audit-2026-10-26/bug-edit-older-expense.png)

### D03 · P1 · Cash filter labels shared spending as daily spending

**Area:** Daily accounts · **Evidence:** Observed

For a 30,000 shared expense split 18,000 daily / 12,000 cash, filtering the statement to cash shows total 12,000, daily share 12,000 and cash share 0.

**Why it matters:** A report intended to explain the money gives a materially false breakdown.

**Proposed change:** Calculate displayed shares from the selected funding source, preserving the original allocation separately. For the cash-only example show daily 0 and cash 12,000.

**Acceptance check:** Assert all three summary amounts for daily-only, cash-only and shared expenses under every funding filter.

**Source:** [app/ui/renderer.js:57](../../electron-reference/app/ui/renderer.js:57), [app/ui/renderer.js:58](../../electron-reference/app/ui/renderer.js:58)

[Screen evidence](../../outputs/ux-audit-2026-10-26/bug-statement-cash.png)

### D04 · P1 · Manual-total form previews the wrong expense total

**Area:** Daily accounts · **Evidence:** Observed

The daily-total editing drawer shows 42,500 as the calculated category sum in the sample, while the daily share is 20,500. The drawer sums whole expenses, including the cash portions.

**Why it matters:** It invites the owner to copy a number that violates the approved daily/cash separation.

**Proposed change:** Preview only the daily share in this drawer. Label it “Total daily-funded shares” and show any cash total separately, if needed.

**Acceptance check:** With shared and cash-only expenses, the preview must equal the automatic daily total on the page.

**Source:** [app/ui/renderer.js:158](../../electron-reference/app/ui/renderer.js:158), [app/ui/model.js:18](../../electron-reference/app/ui/model.js:18)

### D05 · P1 · Two balance previews disagree in one invoice form

**Area:** Purchases · **Evidence:** Observed

With an existing balance of 60,000, a new 5,000 invoice and immediate 5,000 payment, the main preview correctly says 60,000 remains. The payment note says 55,000 because it subtracts the payment without adding the unsaved invoice.

**Why it matters:** The owner cannot know which figure to trust at the moment of saving.

**Proposed change:** Use one draft calculation for the entire form: balance before + new invoice − payment. Reuse its result in every summary and use “Amount still owed to the supplier”.

**Acceptance check:** The invoice summary, allocation note and saved ledger must agree for unpaid, partial, full and excess-to-debt payments.

**Source:** [app/ui/suppliers.js:103](../../electron-reference/app/ui/suppliers.js:103), [app/ui/suppliers.js:135](../../electron-reference/app/ui/suppliers.js:135)

[Screen evidence](../../outputs/ux-audit-2026-10-26/invoice-form.png)

### D06 · P1 · Fractional quantities appear as whole numbers

**Area:** Purchases · **Evidence:** Observed

A saved quantity of 2.5 is displayed as 3 in purchase analysis and its table; its money value remains 12,500. The screen uses the integer money formatter for quantities.

**Why it matters:** Users can misread received quantities and suspect that the price calculation is wrong.

**Proposed change:** Use a quantity formatter retaining up to three decimals everywhere quantities appear, including summary totals.

**Acceptance check:** Show 0.125, 2.5 and 10.001 accurately in list, edit form, analysis and PDF.

**Source:** [app/ui/renderer.js:8](../../electron-reference/app/ui/renderer.js:8), [app/ui/suppliers.js:25](../../electron-reference/app/ui/suppliers.js:25)

[Screen evidence](../../outputs/ux-audit-2026-10-26/invoices.png)

### D07 · P1 · A blank sale date still saves using a hidden old date

**Area:** Sales · **Evidence:** Observed

Clearing the visible date leaves saleDraft.date at 2026-10-26 and checkout enabled. The change handler ignores invalid/empty dates. The draft also retains its date while the app stays open.

**Why it matters:** The date seen by the cashier is no longer the date used by the transaction; a long-running session can also retain yesterday’s date.

**Proposed change:** Keep visible and stored dates synchronized, block checkout on an invalid date, and show a prominent historical-date badge with “Return to today”. Refresh an empty new draft at day change; never silently change a populated draft.

**Acceptance check:** Clear the date, select yesterday, and cross midnight in a simulated clock; verify the actual saved date and visible warning.

**Source:** [app/ui/commerce.js:15](../../electron-reference/app/ui/commerce.js:15), [app/ui/commerce.js:110](../../electron-reference/app/ui/commerce.js:110), [app/ui/commerce.js:95](../../electron-reference/app/ui/commerce.js:95)

### D08 · P1 · An archived item gets stuck in the current bill

**Area:** Sales · **Evidence:** Observed

Add an item, visit inventory and stop it from selling, then return. Its remove button does nothing because the common action handler rejects archived products before processing removal.

**Why it matters:** Checkout fails for the archived item, and the cashier may have to clear the entire customer order.

**Proposed change:** Always allow removal and reduction of existing cart lines. Mark unavailable lines clearly and block only additions/checkout until resolved.

**Acceptance check:** Archive an item already in a two-item bill; remove that item while preserving the other line and discount.

**Source:** [app/ui/commerce.js:87](../../electron-reference/app/ui/commerce.js:87), [app/ui/model.js:362](../../electron-reference/app/ui/model.js:362)

### D09 · P1 · Remaining fractional stock cannot be added to a bill

**Area:** Sales · **Evidence:** Observed

With 0.5 available, the product tile is enabled, but clicking tries to add 1 and shows insufficient stock. There is no cart line in which to enter 0.5.

**Why it matters:** A valid sale is impossible through the normal UI, even though the model supports fractional quantities.

**Proposed change:** For fractional units, open a quantity entry or add a valid default no greater than available stock. Keep one-tap +1 for countable items.

**Acceptance check:** Sell 0.5 of a fractional item with exactly 0.5 available, without changing its stock record first.

**Source:** [app/ui/commerce.js:23](../../electron-reference/app/ui/commerce.js:23), [app/ui/commerce.js:88](../../electron-reference/app/ui/commerce.js:88)

### D10 · P1 · Future stock is labeled as available now

**Area:** Inventory · **Evidence:** Observed

A restock dated 27 October makes inventory show 30 available on 26 October, while Sales correctly shows 20. Inventory calls the stock calculation without a date cutoff.

**Why it matters:** The owner sees two conflicting stock figures and may promise goods not yet received.

**Proposed change:** Use today’s date for “Currently available”. If future receipts are allowed, show them separately as scheduled, with an explicit as-of date.

**Acceptance check:** A future restock must not change today’s available quantity or low-stock indicator.

**Source:** [app/ui/commerce.js:38](../../electron-reference/app/ui/commerce.js:38), [app/ui/commerce.js:44](../../electron-reference/app/ui/commerce.js:44), [app/ui/model.js:295](../../electron-reference/app/ui/model.js:295)

### D11 · P1 · Global Undo can erase a completed sale

**Area:** Recovery · **Evidence:** Observed

A completed sale enters the general state-snapshot undo history. Invoking Undo removes it entirely instead of retaining a void record. Sale numbering is derived from existing records, so a removed latest number can be reused.

**Why it matters:** An already issued receipt can lose its corresponding transaction, bypassing the cancellation reason and preserved history that the app otherwise provides.

**Proposed change:** Use void/reversal for completed sales. Limit ordinary Undo to safe drafts or route sale Undo into the cancellation flow; keep invoice numbers reserved.

**Acceptance check:** Complete and export a sale, invoke Undo, then make another sale. The first record and its number must remain traceable.

**Source:** [app/ui/renderer.js:88](../../electron-reference/app/ui/renderer.js:88), [app/ui/renderer.js:227](../../electron-reference/app/ui/renderer.js:227), [app/ui/model.js:361](../../electron-reference/app/ui/model.js:361)

### D12 · P1 · Closing forms silently discards entered work

**Area:** Recovery · **Evidence:** Observed

Entering an expense amount and pressing Escape loses it; reopening is blank. Closing via the backdrop does the same. Settings drafts are also replaced by navigation; native settings/import actions can close a drawer.

**Why it matters:** One accidental click can lose a long purchase invoice or a partially entered payment.

**Proposed change:** Track dirty forms. Preserve a local draft or ask “Discard changes?” only when something changed. Offer Continue editing / Discard. Apply the same policy to menus and app close.

**Acceptance check:** Exercise Escape, backdrop, close button, navigation, native menu and app quit with both clean and dirty forms.

**Source:** [app/ui/renderer.js:118](../../electron-reference/app/ui/renderer.js:118), [app/ui/renderer.js:247](../../electron-reference/app/ui/renderer.js:247), [app/ui/renderer.js:296](../../electron-reference/app/ui/renderer.js:296), [app/main.cjs:81](../../electron-reference/app/main.cjs:81)

### D13 · P1 · The current sale has no recovery after clearing or restarting

**Area:** Recovery · **Evidence:** Observed

Clear bill immediately removes all lines without confirmation or undo. Reloading also removes the bill. Navigation between pages does preserve it, so persistence is inconsistent.

**Why it matters:** A cashier can lose an entire customer order through a stray click or app restart.

**Proposed change:** Persist the active draft locally, restore it explicitly on restart, and make Clear offer a short Undo or a populated-bill confirmation. Keep it separate from completed financial records.

**Acceptance check:** Restore lines, quantities, discount, type and date after restart; clearing and undoing must restore the exact draft.

**Source:** [app/ui/commerce.js:3](../../electron-reference/app/ui/commerce.js:3), [app/ui/commerce.js:77](../../electron-reference/app/ui/commerce.js:77), [app/ui/commerce.js:92](../../electron-reference/app/ui/commerce.js:92)

### D14 · P1 · Cart actions discard keyboard focus

**Area:** Accessibility · **Evidence:** Observed

After clicking a product, document.activeElement becomes BODY because the catalog and cart are rebuilt. Successful saves also rebuild the page before trying to restore focus to the old trigger.

**Why it matters:** Keyboard users lose their position after common actions and must traverse the interface again.

**Proposed change:** Update affected rows in place or restore focus by stable product/action ID after rendering. After closing a saved form, focus the new/edited row or its equivalent action.

**Acceptance check:** Complete a sale and edit an expense using only the keyboard; focus must remain visible and predictable after every action.

**Source:** [app/ui/commerce.js:91](../../electron-reference/app/ui/commerce.js:91), [app/ui/commerce.js:28](../../electron-reference/app/ui/commerce.js:28), [app/ui/renderer.js:89](../../electron-reference/app/ui/renderer.js:89), [app/ui/renderer.js:118](../../electron-reference/app/ui/renderer.js:118)

### D15 · P1 · Secondary text falls below normal-text contrast requirements

**Area:** Accessibility · **Evidence:** Measured

Computed save-status text is #647568 at 11px on #eff2e9: approximately 4.33:1. The same muted color on #eaf0e4 is approximately 4.22:1. Both are below the 4.5:1 normal-text threshold.

**Why it matters:** Small status messages and guidance are harder to read, particularly for users with low vision.

**Proposed change:** Create a darker muted-text token for tinted surfaces. Recheck active text, hints, labels and status messages against their actual background.

**Acceptance check:** Verify at least 4.5:1 for normal active text; keep the calm palette without relying on faint text for hierarchy.

**Source:** [app/ui/styles.css:1](../../electron-reference/app/ui/styles.css:1), [app/ui/styles.css:3](../../electron-reference/app/ui/styles.css:3), [app/ui/styles.css:6](../../electron-reference/app/ui/styles.css:6)

### D16 · P1 · 200% zoom can put checkout outside the reachable screen

**Area:** Accessibility · **Evidence:** Measured

At the supported 900×580 window with Electron zoom set to 200%, the effective viewport was 450×290. Checkout ended at y=485; catalog height was about 18px and cart height about 20px. Body scrolling is disabled.

**Why it matters:** A user enlarging text can lose access to the main action, not merely see a less attractive layout.

**Proposed change:** Add a short-height/zoom fallback: collapse secondary navigation and switch between Items and Bill, or allow the bill area/page to scroll while preserving access to checkout.

**Acceptance check:** At 200% zoom, complete a multi-item sale and resolve an inline error without zooming back out.

**Source:** [app/ui/commerce.css:20](../../electron-reference/app/ui/commerce.css:20), [app/ui/commerce.css:66](../../electron-reference/app/ui/commerce.css:66), [app/ui/commerce.css:87](../../electron-reference/app/ui/commerce.css:87)

[Screen evidence](../../outputs/ux-audit-2026-10-26/sales-200-percent.png)

### D17 · P2 · Savings date and visible history describe different periods

**Area:** Workers · **Evidence:** Observed

Selecting an end date of 25 October reduces the summary to 1,000, but the history still includes the 26 October contribution.

**Why it matters:** Visible rows do not reconcile with the summary; users can mistake later entries for included entries.

**Proposed change:** Apply the selected end date consistently, or explicitly label a separate all-time history and provide its own filters.

**Acceptance check:** Every visible filtered history sum must reconcile with its matching summary.

**Source:** [app/ui/savings.js:13](../../app/ui/savings.js:13), [app/ui/savings.js:14](../../app/ui/savings.js:14)

### D18 · P2 · Thirteen equally weighted sections make the app harder to learn

**Area:** Navigation · **Evidence:** Design

The sidebar puts selling, purchase setup, daily accounts, workers and settings in one continuous list. At 900×580 several destinations require sidebar scrolling.

**Why it matters:** New users must infer which pages form one task and where to go next.

**Proposed change:** Group destinations under Sales and Inventory, Purchases and Suppliers, Accounts, and Administration. Keep customizable shortcuts; follow D64 for the owner’s requested pop-out navigation.

**Acceptance check:** A first-time user can locate selling, supplier payment and backup without exploring every section.

**Source:** [app/ui/index.html:23](../../electron-reference/app/ui/index.html:23)

[Screen evidence](../../outputs/ux-audit-2026-10-26/sales-900-580-open.png)

### D19 · P2 · Repeated navigation and large slogan headings consume working space

**Area:** Navigation · **Evidence:** Design

Sales repeats history and inventory links already present in the top shortcuts and sidebar. Most pages devote a large header to slogans such as “Clear accounts, every day.” while the actual page name is a small eyebrow.

**Why it matters:** The app spends space explaining itself instead of showing the task, especially on small laptop windows.

**Proposed change:** Use the actual task as the heading—Daily Expenses, Cashbox, Inventory—and one compact context line. Keep page-specific actions; avoid repeating navigation already visible.

**Acceptance check:** At 900×580, useful data and the primary task appear earlier without removing important controls.

**Source:** [app/ui/renderer.js:40](../../electron-reference/app/ui/renderer.js:40), [app/ui/renderer.js:48](../../electron-reference/app/ui/renderer.js:48), [app/ui/commerce.js:18](../../electron-reference/app/ui/commerce.js:18)

### D20 · P2 · Shortcut numbers imply keyboard shortcuts that do not exist

**Area:** Navigation · **Evidence:** Source

Each top shortcut displays 1–6, but there are no corresponding keyboard handlers. Native shortcuts mainly cover expenses, backup and settings.

**Why it matters:** A power user may press the shown numbers expecting navigation and get no response.

**Proposed change:** Either remove numeric key styling or implement and display a safe modifier combination, such as ⌘1–⌘6, without capturing ordinary typing. Add a short shortcut help sheet.

**Acceptance check:** Displayed keyboard hints must match actual behavior and must not fire while typing in forms.

**Source:** [app/ui/commerce.js:7](../../electron-reference/app/ui/commerce.js:7), [app/ui/renderer.js:289](../../electron-reference/app/ui/renderer.js:289), [app/main.cjs:34](../../electron-reference/app/main.cjs:34)

### D21 · P3 · Shortcut customization has no preview or duplicate guidance

**Area:** Settings · **Evidence:** Design

Six independent dropdowns allow the same destination repeatedly. The resulting bar is only apparent after saving.

**Why it matters:** Users can waste limited shortcut slots and have to repeatedly save and inspect the result.

**Proposed change:** Show a live miniature toolbar, allow reorder, and gently flag duplicate destinations while preserving the ability to leave slots empty.

**Acceptance check:** Users can predict the RTL order and see repeated choices before saving.

**Source:** [app/ui/commerce.js:10](../../electron-reference/app/ui/commerce.js:10), [app/ui/model.js:349](../../electron-reference/app/ui/model.js:349)

### D22 · P2 · Filtering behavior changes from screen to screen

**Area:** Filtering · **Evidence:** Source

Statement and purchase filters apply immediately; sales history requires “Show”. Changes to auto-applied filters rebuild the entire page. Reversed date ranges are explicitly checked only in sales history.

**Why it matters:** Users can mistake unsubmitted sales filters for active ones, or read a reversed range as an empty dataset.

**Proposed change:** Use one consistent apply model with visible active-filter chips, Today / This month / All presets and Clear. Validate ranges before presenting totals; preserve focus.

**Acceptance check:** Changing dates, clearing filters and pressing Enter behave consistently across all reports.

**Source:** [app/ui/renderer.js:245](../../electron-reference/app/ui/renderer.js:245), [app/ui/commerce.js:85](../../electron-reference/app/ui/commerce.js:85), [app/ui/suppliers.js:20](../../electron-reference/app/ui/suppliers.js:20)

### D23 · P2 · History rows omit year and sales time

**Area:** Dates · **Evidence:** Source

Many tables use shortDate, which shows only day and month. Sales history also omits the saved transaction time.

**Why it matters:** Records from different years or multiple sales on the same day are harder to distinguish and locate.

**Proposed change:** Show the year when a range crosses years and show time in sales history/receipts. Use an explicit full date in edit and confirmation contexts.

**Acceptance check:** Two records from the same day/month in different years must be distinguishable without opening each one.

**Source:** [app/ui/renderer.js:11](../../electron-reference/app/ui/renderer.js:11), [app/ui/commerce.js:49](../../electron-reference/app/ui/commerce.js:49), [app/ui/suppliers.js:61](../../electron-reference/app/ui/suppliers.js:61)

### D24 · P2 · Every completed sale interrupts the next sale with a receipt drawer

**Area:** Sales · **Evidence:** Design

Checkout saves successfully and always opens a modal receipt, which must be dismissed before selling again.

**Why it matters:** An extra action is added to every transaction during a busy service.

**Proposed change:** Use a compact success state with invoice number, View receipt, Print/Save and Undo-via-void. Make opening a full receipt optional; immediately prepare the next empty bill.

**Acceptance check:** A cashier can complete consecutive simple sales without dismissing a modal each time.

**Source:** [app/ui/commerce.js:95](../../electron-reference/app/ui/commerce.js:95)

### D25 · P2 · Cash collection is implicit at the final action

**Area:** Sales · **Evidence:** Design

The button says “Complete sale”. Exact payment is assumed, while the explanatory cash hint is hidden by the fixed-layout CSS.

**Why it matters:** A new cashier may think the action only creates an order rather than confirming receipt of money.

**Proposed change:** Keep the requested no-amount-entry checkout. Use “Confirm cash sale” or a short “Total received in cash” cue and include the amount in the action or adjacent confirmation.

**Acceptance check:** A new user understands that tapping the action records paid cash, without adding another amount field.

**Source:** [app/ui/commerce.js:18](../../electron-reference/app/ui/commerce.js:18), [app/ui/commerce.css:45](../../electron-reference/app/ui/commerce.css:45), [app/ui/model.js:363](../../electron-reference/app/ui/model.js:363)

### D26 · P2 · Rare bill options compete with the current order

**Area:** Sales · **Evidence:** Design

The date and discount always occupy space, even in an ordinary full-price sale. At 900×580 the cart shows roughly one complete line before scrolling.

**Why it matters:** Frequently checked order contents compete with less frequent adjustments.

**Proposed change:** Keep order type visible. Make discount and historical date compact expandable controls with a clear badge whenever active. Offer a compact product density while retaining the reference photos.

**Acceptance check:** A normal multi-item order is easier to review, and active discounts/backdating remain unmistakable.

**Source:** [app/ui/commerce.js:18](../../electron-reference/app/ui/commerce.js:18), [app/ui/commerce.css:35](../../electron-reference/app/ui/commerce.css:35), [app/ui/commerce.css:38](../../electron-reference/app/ui/commerce.css:38)

[Screen evidence](../../outputs/ux-audit-2026-10-26/sales-900-580-open.png)

### D27 · P2 · Available quantity does not explain what is already in the bill

**Area:** Sales · **Evidence:** Source

A product says “Available: 20” even after some of those units are in the current bill; the disabled state is based on available minus in-cart quantity.

**Why it matters:** The tile can become disabled while still displaying a positive available number, without explaining why.

**Proposed change:** Show “In stock: 20 · In order: 2” or a remaining-to-add figure. Explain a disabled tile as “All available quantity is in the order” or “Out of stock”.

**Acceptance check:** At maximum cart quantity, the tile text explains the disabled state without relying on color.

**Source:** [app/ui/commerce.js:23](../../electron-reference/app/ui/commerce.js:23)

### D28 · P2 · An open bill silently adopts a newly edited product price

**Area:** Sales · **Evidence:** Source

Draft lines store product ID and quantity; draftLines reads the current product price. Editing a price in inventory while a bill is open changes that bill on return.

**Why it matters:** The quoted customer total can change without the cashier explicitly agreeing to reprice it.

**Proposed change:** Snapshot the price when adding to the draft, or show a clear price-changed notice offering Keep quoted price / Apply new price according to the owner’s chosen policy.

**Acceptance check:** An inventory price edit must not silently alter a populated bill.

**Source:** [app/ui/commerce.js:12](../../electron-reference/app/ui/commerce.js:12), [app/ui/model.js:362](../../electron-reference/app/ui/model.js:362)

### D29 · P2 · Barcode and keyboard selling stop at search

**Area:** Sales · **Evidence:** Source

Products have a barcode/code field and search matches it, but there is no scan-and-Enter add flow, search shortcut or keyboard checkout command.

**Why it matters:** A keyboard or scanner user still has to reach for the mouse for each sale.

**Proposed change:** On an exact unique code match, Enter adds the item with clear feedback; provide a discoverable search shortcut and a deliberate checkout shortcut. Hardware scanner support still needs testing.

**Acceptance check:** A keyboard-wedge scan followed by Enter adds exactly one item; ambiguous matches never add silently.

**Source:** [app/ui/commerce.js:55](../../electron-reference/app/ui/commerce.js:55), [app/ui/commerce.js:100](../../electron-reference/app/ui/commerce.js:100), [app/ui/renderer.js:289](../../electron-reference/app/ui/renderer.js:289)

### D30 · P2 · Sales history cannot filter the metadata the app already saves

**Area:** Sales · **Evidence:** Source

History supports dates and invoice/item search, but has no status or order-type filter and does not show order type in the table.

**Why it matters:** Finding a canceled sale or reviewing delivery versus dine-in requires opening receipts one by one.

**Proposed change:** Add status and order-type filters, a type column or compact label, and explicit completed/void counts. Retain the “not profit” distinction.

**Acceptance check:** Find only canceled delivery sales in a selected period and reconcile their exclusion from net sales.

**Source:** [app/ui/commerce.js:47](../../electron-reference/app/ui/commerce.js:47), [app/ui/commerce.js:49](../../electron-reference/app/ui/commerce.js:49)

### D31 · P2 · No search results is presented as an empty inventory

**Area:** Inventory · **Evidence:** Observed

Searching for a nonexistent item in a populated inventory shows “Add your first inventory item”.

**Why it matters:** It falsely implies the inventory is empty and encourages an unnecessary duplicate item.

**Proposed change:** Use “No matching item” with Clear search. Reserve first-item onboarding for an actually empty catalog.

**Acceptance check:** Empty catalog and zero search matches must have different messages and actions.

**Source:** [app/ui/commerce.js:44](../../electron-reference/app/ui/commerce.js:44)

### D32 · P2 · Low-stock and archived items are not directly filterable

**Area:** Inventory · **Evidence:** Design

The low-stock badge is static. The table mixes active, low, out-of-stock and stopped products with only a text search.

**Why it matters:** The owner must scan the entire inventory to find the items needing action.

**Proposed change:** Make the low-stock count a filter; add Active / Low / Out / Stopped tabs and a group filter. Default to active items.

**Acceptance check:** One click lists every product needing replenishment, and stopped items can be recovered easily.

**Source:** [app/ui/commerce.js:38](../../electron-reference/app/ui/commerce.js:38), [app/ui/commerce.js:43](../../electron-reference/app/ui/commerce.js:43)

### D33 · P2 · Editing an item changes its position in lists

**Area:** Navigation · **Evidence:** Observed

Saving an unchanged edit to the first product moves p0 to the end. Product, supplier, material and worker saves commonly remove then append the edited item.

**Why it matters:** Staff lose spatial memory; a frequently used product appears to disappear after a price correction.

**Proposed change:** Replace records in place and keep a deliberate stable order. Add explicit ordering only when requested, rather than using save time as position.

**Acceptance check:** Editing a name or price must not change catalog/list position unless the selected sort requires it.

**Source:** [app/ui/commerce.js:70](../../electron-reference/app/ui/commerce.js:70), [app/ui/suppliers.js:154](../../electron-reference/app/ui/suppliers.js:154), [app/ui/suppliers.js:165](../../electron-reference/app/ui/suppliers.js:165), [app/ui/savings.js:42](../../app/ui/savings.js:42)

### D34 · P2 · The product form exposes irrelevant stock fields

**Area:** Inventory · **Evidence:** Source

Turning stock tracking off leaves opening quantity/date and low-stock threshold fields visible and required; a positive opening quantity is rejected only on submit.

**Why it matters:** Users entering a prepared meal must understand stock concepts that do not apply to that item.

**Proposed change:** Group fields into Basic details, Price, and Stock. Reveal opening quantity, date and threshold only when tracking is on; explain locked tracking/unit settings for existing history.

**Acceptance check:** Create a non-tracked meal without entering stock information or encountering irrelevant validation.

**Source:** [app/ui/commerce.js:55](../../electron-reference/app/ui/commerce.js:55), [app/ui/commerce.js:71](../../electron-reference/app/ui/commerce.js:71)

### D35 · P2 · Stock mistakes have no durable correction workflow

**Area:** Inventory · **Evidence:** Source

Stock history is read-only and offers no edit or reversal. Session Undo may help immediately, but after restart the user must invent a compensating restock/damage entry.

**Why it matters:** An incorrect opening quantity or restock date remains hard to explain and repair accurately.

**Proposed change:** Provide a controlled “Correct movement” or reversal linked to the original, with reason and date validation. Preserve the original event rather than silently overwriting history.

**Acceptance check:** Correct an old mistaken stock entry after restart and explain both movements in the item history.

**Source:** [app/ui/commerce.js:58](../../electron-reference/app/ui/commerce.js:58), [app/ui/commerce.js:74](../../electron-reference/app/ui/commerce.js:74)

### D36 · P2 · Stock history cannot explain the running balance

**Area:** Inventory · **Evidence:** Design

History shows date, quantity and text, without balance after each movement or a direct link to the sale. Sorting is by date only, so same-day events are not meaningfully sequenced.

**Why it matters:** The owner sees that stock changed but must calculate why the present balance is what it is.

**Proposed change:** Show opening balance, signed movement, resulting balance and source link, with a clear same-day ordering policy. Label reversals and void effects explicitly.

**Acceptance check:** Follow a product from opening through sales, restock, damage and void without manual arithmetic.

**Source:** [app/ui/commerce.js:59](../../electron-reference/app/ui/commerce.js:59), [app/ui/commerce.js:60](../../electron-reference/app/ui/commerce.js:60)

### D37 · P2 · A six-field invoice row is compressed into a long drawer

**Area:** Purchases · **Evidence:** Design

Each item exposes material, carton quantity, piece quantity, unit, carton price and piece price. At desktop width they fit into a 700px drawer; payment, notes, allocation and Save are further down.

**Why it matters:** Multi-item entry involves cramped fields and repeated scrolling between lines, totals and saving.

**Proposed change:** Use a dedicated invoice editor with a persistent supplier/date header, expandable line details and a sticky total/save area. Keep carton and piece amounts distinct; do not invent carton conversion.

**Acceptance check:** Enter and correct a 10-line invoice while totals and Save remain accessible and each price is readable.

**Source:** [app/ui/suppliers.js:79](../../electron-reference/app/ui/suppliers.js:79), [app/ui/suppliers.js:90](../../electron-reference/app/ui/suppliers.js:90), [app/ui/styles.css:11](../../electron-reference/app/ui/styles.css:11)

[Screen evidence](../../outputs/ux-audit-2026-10-26/invoice-form.png)

### D38 · P2 · Purchase analysis mixes units and repeats invoice debt on each item

**Area:** Purchases · **Evidence:** Source

The summary adds every material’s quantities into carton/piece totals even when units differ. The line-level table repeats the invoice’s full remaining balance on every item row.

**Why it matters:** A combined quantity is not meaningful across kilos and pieces, and repeated debt looks like a per-item amount that might be summed.

**Proposed change:** Group quantities by material and unit. Present invoices as parent rows with expandable item lines, or label remaining debt once at invoice level.

**Acceptance check:** A mixed-unit, multi-line invoice cannot be mistaken for an additive item-debt report.

**Source:** [app/ui/suppliers.js:22](../../electron-reference/app/ui/suppliers.js:22), [app/ui/suppliers.js:25](../../electron-reference/app/ui/suppliers.js:25)

### D39 · P2 · Catalog wording suggests supplier-specific materials although the catalog is shared

**Area:** Purchases · **Evidence:** Source

The invoice hint says a new material is saved “for the supplier”, and the supplier tab says “Permanent materials”, while the implementation uses one catalog across all suppliers.

**Why it matters:** The owner may change a default price believing it applies to one supplier only.

**Proposed change:** Consistently call it “Shared material catalog for all suppliers”. Explain that it fills defaults, while each invoice retains its own price; keep the catalog’s scope visible in supplier views.

**Acceptance check:** A user can predict where a new material and changed default price will appear.

**Source:** [app/ui/suppliers.js:39](../../electron-reference/app/ui/suppliers.js:39), [app/ui/suppliers.js:79](../../electron-reference/app/ui/suppliers.js:79), [app/ui/suppliers.js:98](../../electron-reference/app/ui/suppliers.js:98)

### D40 · P2 · Payments and materials lack basic retrieval tools

**Area:** Purchases · **Evidence:** Source

Payments renders all records with no date, supplier, invoice or funding filter. Materials has no search or active/stopped filter.

**Why it matters:** Finding a specific payment or material becomes a scanning task as records accumulate.

**Proposed change:** Add targeted search and filters, consistent date presets, result counts and empty-filter recovery. Keep the selected filters when editing a row.

**Acceptance check:** Find a supplier’s cash payment from last month and a stopped material without scanning all rows.

**Source:** [app/ui/suppliers.js:42](../../electron-reference/app/ui/suppliers.js:42), [app/ui/suppliers.js:60](../../electron-reference/app/ui/suppliers.js:60)

### D41 · P2 · Suppliers cannot be retired from daily selection

**Area:** Purchases · **Evidence:** Source

Supplier editing supports name, phone, opening debt and note; there is no archive state. Every supplier continues to appear in selection lists.

**Why it matters:** Old or accidentally added suppliers permanently increase the chance of choosing the wrong account.

**Proposed change:** Add archive/reactivate with preserved history. Warn about outstanding balances and exclude archived suppliers from new-entry defaults while allowing historical access.

**Acceptance check:** Retire a supplier without deleting invoices, debt or payments, then restore it when needed.

**Source:** [app/ui/suppliers.js:7](../../electron-reference/app/ui/suppliers.js:7), [app/ui/suppliers.js:67](../../electron-reference/app/ui/suppliers.js:67)

### D42 · P2 · Custom expense categories cannot be renamed or retired

**Area:** Daily accounts · **Evidence:** Source

The categories screen only adds a category or changes primary/additional type. There is no correction or archive action for a custom category name.

**Why it matters:** A typo or obsolete category remains in every day’s screen and dropdowns.

**Proposed change:** Allow renaming/archiving custom categories while preserving stable IDs and history. Keep required original categories protected; never remove referenced records.

**Acceptance check:** Correct a custom-category typo without changing past amounts or losing its statement history.

**Source:** [app/ui/renderer.js:70](../../electron-reference/app/ui/renderer.js:70), [app/ui/renderer.js:160](../../electron-reference/app/ui/renderer.js:160), [app/ui/model.js:382](../../electron-reference/app/ui/model.js:382)

### D43 · P2 · Unused categories expand every daily expense page

**Area:** Daily accounts · **Evidence:** Design

Every category absent from the selected day is rendered as an empty expense row. Large category sets therefore create long lists of “+ Add amount”.

**Why it matters:** Recorded expenses and the remaining-balance action become harder to find among unused slots.

**Proposed change:** Show recorded entries first and offer a compact frequently used category picker. Put unused categories behind “Add expense” or a collapsed area.

**Acceptance check:** A day with 3 expenses and 100 categories should primarily show the 3 recorded entries.

**Source:** [app/ui/renderer.js:47](../../electron-reference/app/ui/renderer.js:47), [app/ui/renderer.js:50](../../electron-reference/app/ui/renderer.js:50)

### D44 · P2 · The day-closing workflow is spread across distant sections

**Area:** Daily accounts · **Evidence:** Design

Sales, daily total, overall balance, cash expenses, remaining cash and transfer actions are separated vertically. Remaining cash is below both expense tables.

**Why it matters:** An owner must piece together the correct closing sequence and remember whether the cash count includes earlier sales.

**Proposed change:** Add a compact “Review day” flow: review sales and funding shares → count actual remaining cash → preview the approved balance calculation → optionally transfer to the safe. Preserve existing formulas.

**Acceptance check:** Close a day with shared expenses and sales without double-counting or navigating back and forth.

**Source:** [app/ui/renderer.js:49](../../electron-reference/app/ui/renderer.js:49), [app/ui/renderer.js:52](../../electron-reference/app/ui/renderer.js:52), [app/ui/renderer.js:143](../../electron-reference/app/ui/renderer.js:143)

[Screen evidence](../../outputs/ux-audit-2026-10-26/expenses.png)

### D45 · P2 · Direct cash deposit and transfer from daily cash look too similar

**Area:** Daily accounts · **Evidence:** Design

“Deposit in cashbox” on the cash card adds a direct deposit. The similarly named remaining-balance action transfers daily cash and reduces the daily remainder.

**Why it matters:** Choosing the wrong entry point can record the same physical movement with a different accounting effect.

**Proposed change:** Distinguish “External cashbox deposit” from “Transfer from daily balance”. Before saving, show source, destination and both balances after the action.

**Acceptance check:** A first-time user moving today’s cash into the safe chooses the transfer path without needing documentation.

**Source:** [app/ui/renderer.js:37](../../electron-reference/app/ui/renderer.js:37), [app/ui/renderer.js:65](../../electron-reference/app/ui/renderer.js:65), [app/ui/renderer.js:136](../../electron-reference/app/ui/renderer.js:136), [app/ui/renderer.js:149](../../electron-reference/app/ui/renderer.js:149)

### D46 · P2 · Manual overrides are easy to apply but hard to interpret later

**Area:** Daily accounts · **Evidence:** Design

A daily total can be manually overridden, and the overall balance can be edited independently. The screen shows a manual badge for the total but no reason/history for these corrections.

**Why it matters:** Later reconciliation cannot easily distinguish deliberate corrections from arithmetic mistakes.

**Proposed change:** Show calculated value, recorded value and difference; request a brief reason for overriding and preserve a correction history. Do not redefine balance as profit or sales.

**Acceptance check:** Review an old overridden day and explain who/what changed and the difference from recorded items, within the app’s single-user scope.

**Source:** [app/ui/renderer.js:49](../../electron-reference/app/ui/renderer.js:49), [app/ui/renderer.js:155](../../electron-reference/app/ui/renderer.js:155), [app/ui/renderer.js:158](../../electron-reference/app/ui/renderer.js:158)

### D47 · P2 · Cash history lacks period filtering and balance after each movement

**Area:** Daily accounts · **Evidence:** Design

The cash table lists all movements with amount and note; only the all-time current balance is prominent.

**Why it matters:** Tracing why the safe balance differs on a particular day requires manual calculation and scrolling.

**Proposed change:** Add a date range, source/type filter, opening and closing balance for that range, and a running balance column. Label the existing current balance as all-time/current.

**Acceptance check:** Reconcile a selected week’s cash movement totals to its opening and closing balances.

**Source:** [app/ui/renderer.js:67](../../electron-reference/app/ui/renderer.js:67)

### D48 · P2 · Worker search does not produce a worker-specific account history

**Area:** Workers · **Evidence:** Source

Searching changes only the roster. The history below continues showing everyone, and there is no dedicated worker detail view.

**Why it matters:** Reviewing one worker’s contributions and receipts requires mentally filtering unrelated records.

**Proposed change:** Make a worker row open a pop-out detail dialog with schedule, selected-period balance, contributions and receipts; carry worker and date filters into the history.

**Acceptance check:** Select one worker and see only their entries while keeping the pooled available balance clearly separate.

**Source:** [app/ui/savings.js:14](../../app/ui/savings.js:14), [app/ui/savings.js:69](../../app/ui/savings.js:69)

### D49 · P2 · Receipt entry defaults to the entire shared savings pool

**Area:** Workers · **Evidence:** Design

Opening a worker receipt pre-fills the full available pooled balance, not an empty amount.

**Why it matters:** A quick Save can allocate the entire pool to one worker accidentally. The domain correctly permits pooled receipts; the default is the risky part.

**Proposed change:** Start with an empty amount and offer an explicit “Receive all accumulated funds” action with a before/after preview.

**Acceptance check:** A normal receipt requires a deliberate amount choice, and full-pool receipt remains available without changing the accounting rules.

**Source:** [app/ui/savings.js:28](../../app/ui/savings.js:28)

### D50 · P2 · Import confirmation lacks a useful preview of what will replace what

**Area:** Backup and reports · **Evidence:** Source

The native confirmation says data will be replaced and a backup retained, but shows no selected filename details, covered dates or record counts.

**Why it matters:** The owner cannot easily recognize an old or wrong backup before replacing current accounts.

**Proposed change:** Show source filename, version, date coverage and counts beside current-data counts, plus the saved recovery-copy location. Retain cancel as default and validation before replacement.

**Acceptance check:** Identify a stale backup and cancel without altering current accounts.

**Source:** [app/main.cjs:71](../../electron-reference/app/main.cjs:71), [app/main.cjs:76](../../electron-reference/app/main.cjs:76)

### D51 · P2 · Backup safety is described but not operationally visible

**Area:** Backup and reports · **Evidence:** Design

Settings explains local saving and a previous-file backup, but shows no last manual backup time or direct recovery choice. Startup read failure mainly offers importing a backup.

**Why it matters:** Users may confuse local saving with an independent backup and may not know how to restore the automatic previous copy.

**Proposed change:** Add a backup health section: last successful external/manual export, current data location, and a guided validated restore from available local snapshots. Explain that same-device copies do not protect against device loss.

**Acceptance check:** A user with a damaged primary file can find and preview a valid recovery copy without searching folders manually.

**Source:** [app/ui/renderer.js:71](../../electron-reference/app/ui/renderer.js:71), [app/ui/renderer.js:297](../../electron-reference/app/ui/renderer.js:297), [app/storage.cjs:14](../../electron-reference/app/storage.cjs:14), [app/storage.cjs:28](../../electron-reference/app/storage.cjs:28)

### D52 · P2 · Reports do not cover several review and sharing tasks

**Area:** Backup and reports · **Evidence:** Source

Export supports daily expenses, a purchase invoice and a sale receipt. There is no period sales/statement/cash/worker report or standalone payment receipt. A day with only sales rejects the daily-expense PDF as having no recorded day.

**Why it matters:** Users can see useful summaries but cannot share the same filtered view. The existing daily report should not be mistaken for a complete sales/day-closing report.

**Proposed change:** Add clearly named exports for the views actually needed, beginning with the filtered expense statement and sales summary; add a payment receipt. Keep daily expense PDF scoped honestly and offer the appropriate sales export on sales-only days.

**Acceptance check:** An exported filtered report reproduces the visible dates, filters and totals, with cash, debt and profit meanings kept distinct.

**Source:** [app/reports/pdf.cjs:30](../../electron-reference/app/reports/pdf.cjs:30), [app/reports/pdf.cjs:64](../../electron-reference/app/reports/pdf.cjs:64), [app/ui/renderer.js:61](../../electron-reference/app/ui/renderer.js:61), [app/ui/commerce.js:49](../../electron-reference/app/ui/commerce.js:49)

### D53 · P2 · Successful export does not help the user find the file

**Area:** Backup and reports · **Evidence:** Source

PDF success only shows “PDF saved” even though the bridge returns the file path. Backup success is similarly generic.

**Why it matters:** The user may repeat an export or search Finder to discover where it went.

**Proposed change:** Show the saved filename and Open / Show in folder actions, with a persistent result until dismissed for lengthy exports.

**Acceptance check:** After exporting, open the exact saved output directly from the success state.

**Source:** [app/ui/renderer.js:230](../../electron-reference/app/ui/renderer.js:230), [app/ui/renderer.js:240](../../electron-reference/app/ui/renderer.js:240), [app/main.cjs:62](../../electron-reference/app/main.cjs:62)

### D54 · P3 · Customer receipts use only the app identity

**Area:** Backup and reports · **Evidence:** Design

Sale PDFs and on-screen receipts are headed Daftar / Restaurant Accounts, without configurable restaurant identity or sale time.

**Why it matters:** A receipt shared with a customer is less recognizable as the restaurant’s document.

**Proposed change:** Add owner-approved restaurant display name and optional contact/footer settings, then apply them to customer receipts. Keep reference product images out of printed financial documents unless needed.

**Acceptance check:** A customer can identify the restaurant and transaction without confusing the app name for the business.

**Source:** [app/reports/pdf.cjs:62](../../electron-reference/app/reports/pdf.cjs:62), [app/reports/pdf.cjs:67](../../electron-reference/app/reports/pdf.cjs:67), [app/ui/commerce.js:63](../../electron-reference/app/ui/commerce.js:63)

### D55 · P2 · Saving state disappears when the sidebar is closed

**Area:** Feedback · **Evidence:** Design

Persistent save status lives inside the sidebar. With it collapsed, users mainly see brief toasts. Checkout saving does not change the button text to a saving state.

**Why it matters:** A slow save can look like an ignored click, and an error can disappear before the user understands it.

**Proposed change:** Place a compact save indicator in the always-visible toolbar and give active actions a Saving state. Keep unresolved errors visible with Retry and preserve the draft.

**Acceptance check:** With the sidebar closed and a delayed/failed save, users can see whether the action is pending, saved or failed.

**Source:** [app/ui/index.html:38](../../electron-reference/app/ui/index.html:38), [app/ui/renderer.js:14](../../electron-reference/app/ui/renderer.js:14), [app/ui/renderer.js:85](../../electron-reference/app/ui/renderer.js:85), [app/ui/commerce.js:95](../../electron-reference/app/ui/commerce.js:95)

### D56 · P2 · Save actions scroll out of view in long forms

**Area:** Forms · **Evidence:** Design

The submit footer belongs to the scrollable drawer form, below all fields and explanatory notes. This is particularly noticeable in purchase, product and payment forms.

**Why it matters:** Users must repeatedly scroll to save or check whether a primary action exists.

**Proposed change:** Use a sticky dialog action bar outside the scrolling fields, following D64, with Save and Cancel. Keep the error summary reachable and do not cover focused fields.

**Acceptance check:** On a 900×580 window, Save remains reachable while editing the first or last field of every long form.

**Source:** [app/ui/renderer.js:163](../../electron-reference/app/ui/renderer.js:163), [app/ui/styles.css:6](../../electron-reference/app/ui/styles.css:6)

[Screen evidence](../../outputs/ux-audit-2026-10-26/invoice-form.png)

### D57 · P2 · Validation often identifies the problem without locating the field

**Area:** Forms · **Evidence:** Source

A shared form-error box scrolls into view, but inputs generally receive no aria-invalid/aria-describedby state or targeted field error. Some low-level validation falls back to “Invalid data file.”

**Why it matters:** Users must hunt for the field to correct, especially in large invoices.

**Proposed change:** Return field-specific errors, mark the invalid input, focus the first invalid field and retain a concise summary. Replace generic data-file wording for normal entry mistakes.

**Acceptance check:** A bad quantity, duplicate number and funding mismatch each identify the exact correction point without clearing valid input.

**Source:** [app/ui/renderer.js:188](../../electron-reference/app/ui/renderer.js:188), [app/ui/renderer.js:225](../../electron-reference/app/ui/renderer.js:225), [app/ui/model.js:257](../../electron-reference/app/ui/model.js:257)

### D58 · P2 · Important labels and small controls need a readability pass

**Area:** Accessibility · **Evidence:** Measured

Money-source notes and table sublabels often use 10–11px text. The cart quantity input measured about 46×14px and the sale date about 125×21px; many text actions have minimal padding.

**Why it matters:** Dense Arabic text is difficult to read and small controls demand precise pointing. Size alone is not a complete WCAG target-size verdict because spacing exceptions apply.

**Proposed change:** Use a legible operational text scale and larger hit areas for quantity, dates and row actions. Aim for comfortable 40–44px controls where space permits, and audit adjacent-target spacing.

**Acceptance check:** Review at normal and enlarged text with keyboard and touch/trackpad input, keeping financial values and units readable.

**Source:** [app/ui/commerce.css:5](../../electron-reference/app/ui/commerce.css:5), [app/ui/styles.css:9](../../electron-reference/app/ui/styles.css:9), [app/ui/styles.css:11](../../electron-reference/app/ui/styles.css:11)

### D59 · P2 · Product creation can duplicate an existing field ID

**Area:** Accessibility · **Evidence:** Observed

Opening Add product from the sales no-result state creates two elements with id="product-group": the catalog filter and the product group text input.

**Why it matters:** Labels and ID-based lookup can point to the wrong control, and changing the form group also triggers the catalog-filter handler.

**Proposed change:** Give catalog-group-filter and product-group-input distinct IDs and keep their event handling scoped to their containers. Give search fields explicit persistent accessible labels rather than relying on placeholders.

**Acceptance check:** Every rendered ID is unique; changing a product group cannot change the sales filter.

**Source:** [app/ui/commerce.js:18](../../electron-reference/app/ui/commerce.js:18), [app/ui/commerce.js:55](../../electron-reference/app/ui/commerce.js:55), [app/ui/commerce.js:108](../../electron-reference/app/ui/commerce.js:108)

### D60 · P2 · History renders thousands of rows in one pass

**Area:** Performance · **Evidence:** Measured

In an isolated synthetic run, 100 sales rendered in about 30ms with 1,253 DOM nodes; 5,000 sales rendered/layouted in about 798ms with 55,153 nodes. This is a local measurement, not a device-wide benchmark.

**Why it matters:** Normal growth can produce noticeable pauses when opening or filtering history.

**Proposed change:** Paginate or window long tables, default history to a useful recent period, and index repeated lookups. Keep totals computed over the full filtered result, not only the visible page.

**Acceptance check:** Test 5,000+ sales and long purchase/cash histories; filtering and opening should remain responsive without changing totals.

**Source:** [app/ui/commerce.js:49](../../electron-reference/app/ui/commerce.js:49), [app/ui/renderer.js:67](../../electron-reference/app/ui/renderer.js:67), [app/ui/suppliers.js:61](../../electron-reference/app/ui/suppliers.js:61)

### D61 · P2 · Eight small product thumbnails use about 20MB of PNG assets

**Area:** Performance · **Evidence:** Measured

The eight bundled photos are roughly 2.1–2.9MB each, although they appear as small cropped cards. Lazy loading is already present.

**Why it matters:** The app package and image decoding work are larger than the displayed result requires.

**Proposed change:** Create appropriately sized optimized derivatives, retain originals separately, and provide responsive image sizes. Keep the user-requested reference photos and their consistent crops.

**Acceptance check:** Compare appearance and cold-load decoding after optimization; no visible quality loss at actual card size.

**Source:** [app/ui/photos/](../../electron-reference/app/ui/photos), [app/ui/commerce.js:23](../../electron-reference/app/ui/commerce.js:23)

### D62 · P3 · Repeated overrides make spacing and component states inconsistent

**Area:** Visual system · **Evidence:** Source

The CSS has successive overrides for sales layout, responsive rules and sidebar controls; many colors and dimensions bypass the existing tokens.

**Why it matters:** Small future layout changes can unexpectedly differ by screen size, increasing the cost of maintaining a consistent UI.

**Proposed change:** Consolidate final component rules, define shared control/text/spacing tokens, and document the supported compact layout. Preserve the existing calm green identity.

**Acceptance check:** The same control has predictable sizing and states across sales, accounting, settings and drawers.

**Source:** [app/ui/commerce.css:1](../../electron-reference/app/ui/commerce.css:1), [app/ui/commerce.css:20](../../electron-reference/app/ui/commerce.css:20), [app/ui/commerce.css:91](../../electron-reference/app/ui/commerce.css:91), [app/ui/styles.css:1](../../electron-reference/app/ui/styles.css:1)

### D63 · P3 · Action labels and context labels are not always specific

**Area:** Copy · **Evidence:** Design

Many drawers—including products and suppliers—show “Daftar / Day Log”. Read-only receipts say “Continue”. Singular counts display forms such as “1 products”.

**Why it matters:** Small ambiguities reduce orientation and make a polished app feel assembled from unrelated screens.

**Proposed change:** Use the actual module in form context, “New sale” or “Close receipt” for receipt actions, and Arabic plural rules for counts. Keep the friendly Iraqi voice consistent.

**Acceptance check:** A user can identify the module and the effect of an action from its label alone.

**Source:** [app/ui/renderer.js:163](../../electron-reference/app/ui/renderer.js:163), [app/ui/commerce.js:27](../../electron-reference/app/ui/commerce.js:27), [app/ui/commerce.js:63](../../electron-reference/app/ui/commerce.js:63)

### D64 · P2 · Replace sidebars with pop-out panels — owner requested

**Area:** Navigation · **Evidence:** User request

The owner added during this review: “the sidebars should be a pop out window instead of sidebar bc annoying”. This supersedes the earlier preference to retain persistent sidebar presentation; it is a requested design direction, not a newly reproduced defect.

**Why it matters:** Side panels consume space and feel intrusive to the owner, even when they can collapse.

**Proposed change:** Use a compact Menu trigger that opens navigation as a dismissible pop-over panel above the workspace. Present short entry/edit forms in centered pop-up dialogs instead of edge-attached drawers. Keep the page and draft underneath intact; use a large dialog or dedicated editor for long purchase invoices. Default to in-app overlays rather than separate operating-system windows unless that is specifically desired.

**Acceptance check:** Opening a panel must not squeeze or shift the page. Closing returns focus to its trigger and restores the full workspace. Dirty forms are protected, Escape and keyboard focus work, and long dialogs remain usable at 200% zoom.

**Source:** [app/ui/index.html:20](../../electron-reference/app/ui/index.html:20), [app/ui/renderer.js:163](../../electron-reference/app/ui/renderer.js:163), [app/ui/styles.css:6](../../electron-reference/app/ui/styles.css:6)

## Proposed experience after corrections

**Cashier:** open Sales → find/scan product → adjust bill → choose order type → confirm cash sale → immediately start the next sale. Receipt remains available without blocking the next customer. The draft survives interruption, and a canceled sale remains traceable.

**Purchases:** choose or create supplier → enter the invoice in a spacious editor → optionally pay now → review one consistent balance/funding preview → save → return to the invoice with receipt and payment actions. If stock is received, offer a separate explicit stock-recording step; never silently convert supplier materials into meals.

**Day closing:** review recorded sales and expense funding → count actual remaining cash → show the approved calculation → optionally transfer some/all to the safe → export an accurately scoped report. Keep worker savings out of this flow.

**Stock correction:** find item or filter low stock → inspect running history → record receipt/damage/correction with reason → see resulting quantity for the selected date. A correction stays linked to its original movement.

**Backup and recovery:** see last backup and location → export or choose recovery copy → preview what it contains → confirm replacement → receive a clear result with file location. The existing safety validation stays in place.

## Personas and cognitive load

- **First-time owner/accountant:** the first-invoice dead end is the highest-risk onboarding failure. The distinction between external safe deposit and daily-cash transfer needs visible guidance, not recall from Settings.
- **Cashier during a rush:** focus loss, one receipt modal per sale, unprotected cart clearing, changing item positions and missing scan/Enter behavior slow repeated transactions.
- **Owner reviewing an older day:** cross-day editing, omitted years, misleading funding totals and inconsistent as-of filtering undermine trust even when stored amounts are intact.
- **Keyboard/low-vision user:** lost focus and the 200% zoom checkout failure block independence; faint 10–11px helper text compounds the problem.

The critique skill’s referenced cognitive-load/persona/scoring files were absent from the installed package. I used the supplied skill criteria and this explicit local checklist rather than claiming to have read missing references: clear primary action (pass on Sales), coherent task groups (gap), stable date/filter context (gap), consistent interaction rules (gap), progressive disclosure (gap), visible save/result status (gap when sidebar closed), recoverable mistakes (gap), context-specific concise help (partial gap). This is a qualitative seven-gap assessment, not a validated user-study score.

## Optional capabilities, not confirmed bugs or approved scope

These deserve a separate product decision if they match the restaurant’s actual work. Their absence is not counted in the findings total:

- Held bills / multiple open orders for interruptions or table service.
- Customer details, delivery contact/address, delivery fees or kitchen order routing. The current order type is descriptive only.
- Partial refunds and exchanges. Full-sale cancellation is currently supported.
- Recipe/raw-material consumption or automatic purchase-to-stock conversion. Current stock tracks finished sale items, and the accounting domains must stay separate.
- Actual restaurant product-photo upload and image crop controls. The current eight pictures are explicitly reference images, as requested.
- Thermal receipt printing, card/credit payments or multiple staff permissions. Current scope is a local cash-sales app for one restaurant.
- Startup-page preference, cash-drawer opening balance and a fuller shift workflow. These require clear operational definitions before implementation.

## Recommended implementation order

1. **Correctness and recovery:** D01–D16 first, with regression scenarios matching the acceptance checks. Preserve existing records and financial definitions.
2. **Task structure and forms:** simplify navigation, implement guided first use, consistent dates/filters, stable item order, focused validation and persistent draft handling. Apply `harden`, `clarify` and `onboard` where appropriate.
3. **Repeated-work efficiency:** reduce checkout interruptions; improve purchase entry, inventory correction/history and filtered reporting. Apply `arrange` and `distill` while retaining the approved sales layout.
4. **Accessibility and performance:** fix zoom and focus behavior, tune text/targets and paginate long lists; optimize thumbnail assets. Apply `adapt`, `accessibility` and `optimize`.
5. **Visual finishing:** consolidate tokens, context labels and spacing with `normalize`, then `polish`. Re-run `audit` and `critique` after the changes.

This is a proposed sequence, not authorization to implement every item. Fixes can be taken individually or grouped by priority; the useful next decision is whether to start with the verified correctness/recovery issues or also include the cashier and purchase-editor improvements in the same release.

## Standards used for specific accessibility observations

Normal active text needs at least 4.5:1 contrast, with defined exceptions: [W3C — Contrast Minimum](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html). The measured tinted-surface examples above fall below that threshold.

Small controls require a size-and-spacing review, not a blanket failure based only on height: [W3C — Target Size Minimum](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html). Form guidance and focus recommendations follow [W3C — Labels or Instructions](https://www.w3.org/WAI/WCAG22/Understanding/labels-or-instructions.html) and [W3C — Focus Order](https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html). No full WCAG conformance claim is made.
