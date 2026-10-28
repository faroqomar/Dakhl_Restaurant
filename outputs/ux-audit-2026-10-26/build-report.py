from pathlib import Path
import json, html, collections
root=Path('/Users/eros/Dev/Eros_Projects/ResturanetAccounting')
out=root/'outputs/ux-audit-2026-10-26'
issues=[]
def add(priority,area,title,evidence,impact,change,check,source,kind='Observed',shot=None):
 issues.append(dict(id=f'D{len(issues)+1:02}',priority=priority,area=area,title=title,evidence=evidence,impact=impact,change=change,check=check,source=source,kind=kind,shot=shot))

add('P1','Purchases','First invoice can leave the app stuck',
'With no suppliers, Purchases still offers Add invoice. Clicking it throws “اختار مورداً أولاً.”, creates no visible drawer, and leaves an internal drawer state that prevents navigation.',
'A first-time owner meets a silent dead end before recording the first purchase. Escape is an undocumented recovery.',
'Offer “إضافة مورد وبدء فاتورة” when no suppliers exist. Validate prerequisites before opening the entry form; show any failure visibly and clear the pending state.',
'Start with empty accounts, add the first supplier, continue directly into the invoice, and verify navigation still works after canceling.',
'app/ui/suppliers.js:77; app/ui/suppliers.js:189; app/ui/renderer.js:121; app/ui/renderer.js:247',shot='bug-empty-invoice.png')
add('P1','Daily accounts','Editing a statement row uses the wrong day',
'From the statement, editing a 25 October expense while the selected day is 26 October opens “إضافة مصروف”, with an empty amount and the 26 October date. The edit action passes an ID without its date.',
'The owner cannot reliably correct an older expense. Validation prevents a duplicate expense ID from being saved, but the resulting failure is confusing; this is not evidence of existing data corruption.',
'Resolve the expense and its original date from the clicked row. Open a correctly populated edit form and return to the same filtered statement after saving.',
'Edit an expense from a different day and confirm that exactly that record changes, with its original date retained unless explicitly edited.',
'app/ui/renderer.js:61; app/ui/renderer.js:130; app/ui/renderer.js:256; app/ui/model.js:388',shot='bug-edit-older-expense.png')
add('P1','Daily accounts','Cash filter labels shared spending as daily spending',
'For a 30,000 shared expense split 18,000 daily / 12,000 cash, filtering the statement to cash shows total 12,000, daily share 12,000 and cash share 0.',
'A report intended to explain the money gives a materially false breakdown.',
'Calculate displayed shares from the selected funding source, preserving the original allocation separately. For the cash-only example show daily 0 and cash 12,000.',
'Assert all three summary amounts for daily-only, cash-only and shared expenses under every funding filter.',
'app/ui/renderer.js:57; app/ui/renderer.js:58',shot='bug-statement-cash.png')
add('P1','Daily accounts','Manual-total form previews the wrong expense total',
'The daily-total editing drawer shows 42,500 as the calculated category sum in the sample, while the daily share is 20,500. The drawer sums whole expenses, including the cash portions.',
'It invites the owner to copy a number that violates the approved daily/cash separation.',
'Preview only the daily share in this drawer. Label it “مجموع حصص اليومي” and show any cash total separately, if needed.',
'With shared and cash-only expenses, the preview must equal the automatic daily total on the page.',
'app/ui/renderer.js:158; app/ui/model.js:18')
add('P1','Purchases','Two balance previews disagree in one invoice form',
'With an existing balance of 60,000, a new 5,000 invoice and immediate 5,000 payment, the main preview correctly says 60,000 remains. The payment note says 55,000 because it subtracts the payment without adding the unsaved invoice.',
'The owner cannot know which figure to trust at the moment of saving.',
'Use one draft calculation for the entire form: balance before + new invoice − payment. Reuse its result in every summary and use “يبقى عليك للمورد”.',
'The invoice summary, allocation note and saved ledger must agree for unpaid, partial, full and excess-to-debt payments.',
'app/ui/suppliers.js:103; app/ui/suppliers.js:135',shot='invoice-form.png')
add('P1','Purchases','Fractional quantities appear as whole numbers',
'A saved quantity of 2.5 is displayed as 3 in purchase analysis and its table; its money value remains 12,500. The screen uses the integer money formatter for quantities.',
'Users can misread received quantities and suspect that the price calculation is wrong.',
'Use a quantity formatter retaining up to three decimals everywhere quantities appear, including summary totals.',
'Show 0.125, 2.5 and 10.001 accurately in list, edit form, analysis and PDF.',
'app/ui/renderer.js:8; app/ui/suppliers.js:25',shot='invoices.png')
add('P1','Sales','A blank sale date still saves using a hidden old date',
'Clearing the visible date leaves saleDraft.date at 2026-10-26 and checkout enabled. The change handler ignores invalid/empty dates. The draft also retains its date while the app stays open.',
'The date seen by the cashier is no longer the date used by the transaction; a long-running session can also retain yesterday’s date.',
'Keep visible and stored dates synchronized, block checkout on an invalid date, and show a prominent historical-date badge with “الرجوع لليوم”. Refresh an empty new draft at day change; never silently change a populated draft.',
'Clear the date, select yesterday, and cross midnight in a simulated clock; verify the actual saved date and visible warning.',
'app/ui/commerce.js:15; app/ui/commerce.js:110; app/ui/commerce.js:95')
add('P1','Sales','An archived item gets stuck in the current bill',
'Add an item, visit inventory and stop it from selling, then return. Its remove button does nothing because the common action handler rejects archived products before processing removal.',
'Checkout fails for the archived item, and the cashier may have to clear the entire customer order.',
'Always allow removal and reduction of existing cart lines. Mark unavailable lines clearly and block only additions/checkout until resolved.',
'Archive an item already in a two-item bill; remove that item while preserving the other line and discount.',
'app/ui/commerce.js:87; app/ui/model.js:362')
add('P1','Sales','Remaining fractional stock cannot be added to a bill',
'With 0.5 available, the product tile is enabled, but clicking tries to add 1 and shows insufficient stock. There is no cart line in which to enter 0.5.',
'A valid sale is impossible through the normal UI, even though the model supports fractional quantities.',
'For fractional units, open a quantity entry or add a valid default no greater than available stock. Keep one-tap +1 for countable items.',
'Sell 0.5 of a fractional item with exactly 0.5 available, without changing its stock record first.',
'app/ui/commerce.js:23; app/ui/commerce.js:88')
add('P1','Inventory','Future stock is labeled as available now',
'A restock dated 27 October makes inventory show 30 available on 26 October, while Sales correctly shows 20. Inventory calls the stock calculation without a date cutoff.',
'The owner sees two conflicting stock figures and may promise goods not yet received.',
'Use today’s date for “المتوفر حالياً”. If future receipts are allowed, show them separately as scheduled, with an explicit as-of date.',
'A future restock must not change today’s available quantity or low-stock indicator.',
'app/ui/commerce.js:38; app/ui/commerce.js:44; app/ui/model.js:295')
add('P1','Recovery','Global Undo can erase a completed sale',
'A completed sale enters the general state-snapshot undo history. Invoking Undo removes it entirely instead of retaining a void record. Sale numbering is derived from existing records, so a removed latest number can be reused.',
'An already issued receipt can lose its corresponding transaction, bypassing the cancellation reason and preserved history that the app otherwise provides.',
'Use void/reversal for completed sales. Limit ordinary Undo to safe drafts or route sale Undo into the cancellation flow; keep invoice numbers reserved.',
'Complete and export a sale, invoke Undo, then make another sale. The first record and its number must remain traceable.',
'app/ui/renderer.js:88; app/ui/renderer.js:227; app/ui/model.js:361')
add('P1','Recovery','Closing forms silently discards entered work',
'Entering an expense amount and pressing Escape loses it; reopening is blank. Closing via the backdrop does the same. Settings drafts are also replaced by navigation; native settings/import actions can close a drawer.',
'One accidental click can lose a long purchase invoice or a partially entered payment.',
'Track dirty forms. Preserve a local draft or ask “تجاهل التغييرات؟” only when something changed. Offer Continue editing / Discard. Apply the same policy to menus and app close.',
'Exercise Escape, backdrop, close button, navigation, native menu and app quit with both clean and dirty forms.',
'app/ui/renderer.js:118; app/ui/renderer.js:247; app/ui/renderer.js:296; app/main.cjs:81')
add('P1','Recovery','The current sale has no recovery after clearing or restarting',
'Clear bill immediately removes all lines without confirmation or undo. Reloading also removes the bill. Navigation between pages does preserve it, so persistence is inconsistent.',
'A cashier can lose an entire customer order through a stray click or app restart.',
'Persist the active draft locally, restore it explicitly on restart, and make Clear offer a short Undo or a populated-bill confirmation. Keep it separate from completed financial records.',
'Restore lines, quantities, discount, type and date after restart; clearing and undoing must restore the exact draft.',
'app/ui/commerce.js:3; app/ui/commerce.js:77; app/ui/commerce.js:92')
add('P1','Accessibility','Cart actions discard keyboard focus',
'After clicking a product, document.activeElement becomes BODY because the catalog and cart are rebuilt. Successful saves also rebuild the page before trying to restore focus to the old trigger.',
'Keyboard users lose their position after common actions and must traverse the interface again.',
'Update affected rows in place or restore focus by stable product/action ID after rendering. After closing a saved form, focus the new/edited row or its equivalent action.',
'Complete a sale and edit an expense using only the keyboard; focus must remain visible and predictable after every action.',
'app/ui/commerce.js:91; app/ui/commerce.js:28; app/ui/renderer.js:89; app/ui/renderer.js:118')
add('P1','Accessibility','Secondary text falls below normal-text contrast requirements',
'Computed save-status text is #647568 at 11px on #eff2e9: approximately 4.33:1. The same muted color on #eaf0e4 is approximately 4.22:1. Both are below the 4.5:1 normal-text threshold.',
'Small status messages and guidance are harder to read, particularly for users with low vision.',
'Create a darker muted-text token for tinted surfaces. Recheck active text, hints, labels and status messages against their actual background.',
'Verify at least 4.5:1 for normal active text; keep the calm palette without relying on faint text for hierarchy.',
'app/ui/styles.css:1; app/ui/styles.css:3; app/ui/styles.css:6',kind='Measured')
add('P1','Accessibility','200% zoom can put checkout outside the reachable screen',
'At the supported 900×580 window with Electron zoom set to 200%, the effective viewport was 450×290. Checkout ended at y=485; catalog height was about 18px and cart height about 20px. Body scrolling is disabled.',
'A user enlarging text can lose access to the main action, not merely see a less attractive layout.',
'Add a short-height/zoom fallback: collapse secondary navigation and switch between Items and Bill, or allow the bill area/page to scroll while preserving access to checkout.',
'At 200% zoom, complete a multi-item sale and resolve an inline error without zooming back out.',
'app/ui/commerce.css:20; app/ui/commerce.css:66; app/ui/commerce.css:87',kind='Measured',shot='sales-200-percent.png')
add('P2','Workers','Savings date and visible history describe different periods',
'Selecting “المتابعة لغاية” 25 October reduces the summary to 1,000, but the history still includes the 26 October contribution.',
'Visible rows do not reconcile with the summary; users can mistake later entries for included entries.',
'Apply the selected end date consistently, or explicitly label a separate all-time history and provide its own filters.',
'Every visible filtered history sum must reconcile with its matching summary.',
'app/ui/savings.js:13; app/ui/savings.js:14')
add('P2','Navigation','Thirteen equally weighted sections make the app harder to learn',
'The sidebar puts selling, purchase setup, daily accounts, workers and settings in one continuous list. At 900×580 several destinations require sidebar scrolling.',
'New users must infer which pages form one task and where to go next.',
'Group destinations under البيع والمخزن, المشتريات والموردون, الحسابات, and الإدارة. Keep customizable shortcuts; follow D64 for the owner’s requested pop-out navigation.',
'A first-time user can locate selling, supplier payment and backup without exploring every section.',
'app/ui/index.html:23',kind='Design',shot='sales-900-580-open.png')
add('P2','Navigation','Repeated navigation and large slogan headings consume working space',
'Sales repeats history and inventory links already present in the top shortcuts and sidebar. Most pages devote a large header to slogans such as “كل يوم، حسابه واضح.” while the actual page name is a small eyebrow.',
'The app spends space explaining itself instead of showing the task, especially on small laptop windows.',
'Use the actual task as the heading—المصاريف اليومية, القاصة, المخزن—and one compact context line. Keep page-specific actions; avoid repeating navigation already visible.',
'At 900×580, useful data and the primary task appear earlier without removing important controls.',
'app/ui/renderer.js:40; app/ui/renderer.js:48; app/ui/commerce.js:18',kind='Design')
add('P2','Navigation','Shortcut numbers imply keyboard shortcuts that do not exist',
'Each top shortcut displays 1–6, but there are no corresponding keyboard handlers. Native shortcuts mainly cover expenses, backup and settings.',
'A power user may press the shown numbers expecting navigation and get no response.',
'Either remove numeric key styling or implement and display a safe modifier combination, such as ⌘1–⌘6, without capturing ordinary typing. Add a short shortcut help sheet.',
'Displayed keyboard hints must match actual behavior and must not fire while typing in forms.',
'app/ui/commerce.js:7; app/ui/renderer.js:289; app/main.cjs:34',kind='Source')
add('P3','Settings','Shortcut customization has no preview or duplicate guidance',
'Six independent dropdowns allow the same destination repeatedly. The resulting bar is only apparent after saving.',
'Users can waste limited shortcut slots and have to repeatedly save and inspect the result.',
'Show a live miniature toolbar, allow reorder, and gently flag duplicate destinations while preserving the ability to leave slots empty.',
'Users can predict the RTL order and see repeated choices before saving.',
'app/ui/commerce.js:10; app/ui/model.js:349',kind='Design')
add('P2','Filtering','Filtering behavior changes from screen to screen',
'Statement and purchase filters apply immediately; sales history requires “عرض”. Changes to auto-applied filters rebuild the entire page. Reversed date ranges are explicitly checked only in sales history.',
'Users can mistake unsubmitted sales filters for active ones, or read a reversed range as an empty dataset.',
'Use one consistent apply model with visible active-filter chips, Today / This month / All presets and Clear. Validate ranges before presenting totals; preserve focus.',
'Changing dates, clearing filters and pressing Enter behave consistently across all reports.',
'app/ui/renderer.js:245; app/ui/commerce.js:85; app/ui/suppliers.js:20',kind='Source')
add('P2','Dates','History rows omit year and sales time',
'Many tables use shortDate, which shows only day and month. Sales history also omits the saved transaction time.',
'Records from different years or multiple sales on the same day are harder to distinguish and locate.',
'Show the year when a range crosses years and show time in sales history/receipts. Use an explicit full date in edit and confirmation contexts.',
'Two records from the same day/month in different years must be distinguishable without opening each one.',
'app/ui/renderer.js:11; app/ui/commerce.js:49; app/ui/suppliers.js:61',kind='Source')
add('P2','Sales','Every completed sale interrupts the next sale with a receipt drawer',
'Checkout saves successfully and always opens a modal receipt, which must be dismissed before selling again.',
'An extra action is added to every transaction during a busy service.',
'Use a compact success state with invoice number, View receipt, Print/Save and Undo-via-void. Make opening a full receipt optional; immediately prepare the next empty bill.',
'A cashier can complete consecutive simple sales without dismissing a modal each time.',
'app/ui/commerce.js:95',kind='Design')
add('P2','Sales','Cash collection is implicit at the final action',
'The button says “إتمام البيع”. Exact payment is assumed, while the explanatory cash hint is hidden by the fixed-layout CSS.',
'A new cashier may think the action only creates an order rather than confirming receipt of money.',
'Keep the requested no-amount-entry checkout. Use “تأكيد البيع النقدي” or a short “تم استلام الإجمالي نقداً” cue and include the amount in the action or adjacent confirmation.',
'A new user understands that tapping the action records paid cash, without adding another amount field.',
'app/ui/commerce.js:18; app/ui/commerce.css:45; app/ui/model.js:363',kind='Design')
add('P2','Sales','Rare bill options compete with the current order',
'The date and discount always occupy space, even in an ordinary full-price sale. At 900×580 the cart shows roughly one complete line before scrolling.',
'Frequently checked order contents compete with less frequent adjustments.',
'Keep order type visible. Make discount and historical date compact expandable controls with a clear badge whenever active. Offer a compact product density while retaining the reference photos.',
'A normal multi-item order is easier to review, and active discounts/backdating remain unmistakable.',
'app/ui/commerce.js:18; app/ui/commerce.css:35; app/ui/commerce.css:38',kind='Design',shot='sales-900-580-open.png')
add('P2','Sales','Available quantity does not explain what is already in the bill',
'A product says “المتوفر 20” even after some of those units are in the current bill; the disabled state is based on available minus in-cart quantity.',
'The tile can become disabled while still displaying a positive available number, without explaining why.',
'Show “بالمخزن 20 · بالطلب 2” or a remaining-to-add figure. Explain a disabled tile as “الكمية كلها بالطلب” or “نافد”.',
'At maximum cart quantity, the tile text explains the disabled state without relying on color.',
'app/ui/commerce.js:23',kind='Source')
add('P2','Sales','An open bill silently adopts a newly edited product price',
'Draft lines store product ID and quantity; draftLines reads the current product price. Editing a price in inventory while a bill is open changes that bill on return.',
'The quoted customer total can change without the cashier explicitly agreeing to reprice it.',
'Snapshot the price when adding to the draft, or show a clear price-changed notice offering Keep quoted price / Apply new price according to the owner’s chosen policy.',
'An inventory price edit must not silently alter a populated bill.',
'app/ui/commerce.js:12; app/ui/model.js:362',kind='Source')
add('P2','Sales','Barcode and keyboard selling stop at search',
'Products have a barcode/code field and search matches it, but there is no scan-and-Enter add flow, search shortcut or keyboard checkout command.',
'A keyboard or scanner user still has to reach for the mouse for each sale.',
'On an exact unique code match, Enter adds the item with clear feedback; provide a discoverable search shortcut and a deliberate checkout shortcut. Hardware scanner support still needs testing.',
'A keyboard-wedge scan followed by Enter adds exactly one item; ambiguous matches never add silently.',
'app/ui/commerce.js:55; app/ui/commerce.js:100; app/ui/renderer.js:289',kind='Source')
add('P2','Sales','Sales history cannot filter the metadata the app already saves',
'History supports dates and invoice/item search, but has no status or order-type filter and does not show order type in the table.',
'Finding a canceled sale or reviewing delivery versus dine-in requires opening receipts one by one.',
'Add status and order-type filters, a type column or compact label, and explicit completed/void counts. Retain the “not profit” distinction.',
'Find only canceled delivery sales in a selected period and reconcile their exclusion from net sales.',
'app/ui/commerce.js:47; app/ui/commerce.js:49',kind='Source')
add('P2','Inventory','No search results is presented as an empty inventory',
'Searching for a nonexistent item in a populated inventory shows “أضف أول صنف للمخزن”.',
'It falsely implies the inventory is empty and encourages an unnecessary duplicate item.',
'Use “ماكو صنف مطابق” with Clear search. Reserve first-item onboarding for an actually empty catalog.',
'Empty catalog and zero search matches must have different messages and actions.',
'app/ui/commerce.js:44')
add('P2','Inventory','Low-stock and archived items are not directly filterable',
'The low-stock badge is static. The table mixes active, low, out-of-stock and stopped products with only a text search.',
'The owner must scan the entire inventory to find the items needing action.',
'Make the low-stock count a filter; add Active / Low / Out / Stopped tabs and a group filter. Default to active items.',
'One click lists every product needing replenishment, and stopped items can be recovered easily.',
'app/ui/commerce.js:38; app/ui/commerce.js:43',kind='Design')
add('P2','Navigation','Editing an item changes its position in lists',
'Saving an unchanged edit to the first product moves p0 to the end. Product, supplier, material and worker saves commonly remove then append the edited item.',
'Staff lose spatial memory; a frequently used product appears to disappear after a price correction.',
'Replace records in place and keep a deliberate stable order. Add explicit ordering only when requested, rather than using save time as position.',
'Editing a name or price must not change catalog/list position unless the selected sort requires it.',
'app/ui/commerce.js:70; app/ui/suppliers.js:154; app/ui/suppliers.js:165; app/ui/savings.js:42')
add('P2','Inventory','The product form exposes irrelevant stock fields',
'Turning stock tracking off leaves opening quantity/date and low-stock threshold fields visible and required; a positive opening quantity is rejected only on submit.',
'Users entering a prepared meal must understand stock concepts that do not apply to that item.',
'Group fields into Basic details, Price, and Stock. Reveal opening quantity, date and threshold only when tracking is on; explain locked tracking/unit settings for existing history.',
'Create a non-tracked meal without entering stock information or encountering irrelevant validation.',
'app/ui/commerce.js:55; app/ui/commerce.js:71',kind='Source')
add('P2','Inventory','Stock mistakes have no durable correction workflow',
'Stock history is read-only and offers no edit or reversal. Session Undo may help immediately, but after restart the user must invent a compensating restock/damage entry.',
'An incorrect opening quantity or restock date remains hard to explain and repair accurately.',
'Provide a controlled “تصحيح حركة” or reversal linked to the original, with reason and date validation. Preserve the original event rather than silently overwriting history.',
'Correct an old mistaken stock entry after restart and explain both movements in the item history.',
'app/ui/commerce.js:58; app/ui/commerce.js:74',kind='Source')
add('P2','Inventory','Stock history cannot explain the running balance',
'History shows date, quantity and text, without balance after each movement or a direct link to the sale. Sorting is by date only, so same-day events are not meaningfully sequenced.',
'The owner sees that stock changed but must calculate why the present balance is what it is.',
'Show opening balance, signed movement, resulting balance and source link, with a clear same-day ordering policy. Label reversals and void effects explicitly.',
'Follow a product from opening through sales, restock, damage and void without manual arithmetic.',
'app/ui/commerce.js:59; app/ui/commerce.js:60',kind='Design')
add('P2','Purchases','A six-field invoice row is compressed into a long drawer',
'Each item exposes material, carton quantity, piece quantity, unit, carton price and piece price. At desktop width they fit into a 700px drawer; payment, notes, allocation and Save are further down.',
'Multi-item entry involves cramped fields and repeated scrolling between lines, totals and saving.',
'Use a dedicated invoice editor with a persistent supplier/date header, expandable line details and a sticky total/save area. Keep carton and piece amounts distinct; do not invent carton conversion.',
'Enter and correct a 10-line invoice while totals and Save remain accessible and each price is readable.',
'app/ui/suppliers.js:79; app/ui/suppliers.js:90; app/ui/styles.css:11',kind='Design',shot='invoice-form.png')
add('P2','Purchases','Purchase analysis mixes units and repeats invoice debt on each item',
'The summary adds every material’s quantities into carton/piece totals even when units differ. The line-level table repeats the invoice’s full remaining balance on every item row.',
'A combined quantity is not meaningful across kilos and pieces, and repeated debt looks like a per-item amount that might be summed.',
'Group quantities by material and unit. Present invoices as parent rows with expandable item lines, or label remaining debt once at invoice level.',
'A mixed-unit, multi-line invoice cannot be mistaken for an additive item-debt report.',
'app/ui/suppliers.js:22; app/ui/suppliers.js:25',kind='Source')
add('P2','Purchases','Catalog wording suggests supplier-specific materials although the catalog is shared',
'The invoice hint says a new material is saved “للمورد”, and the supplier tab says “المواد الدائمية”, while the implementation uses one catalog across all suppliers.',
'The owner may change a default price believing it applies to one supplier only.',
'Consistently call it “كتالوج مواد مشترك لكل الموردين”. Explain that it fills defaults, while each invoice retains its own price; keep the catalog’s scope visible in supplier views.',
'A user can predict where a new material and changed default price will appear.',
'app/ui/suppliers.js:39; app/ui/suppliers.js:79; app/ui/suppliers.js:98',kind='Source')
add('P2','Purchases','Payments and materials lack basic retrieval tools',
'Payments renders all records with no date, supplier, invoice or funding filter. Materials has no search or active/stopped filter.',
'Finding a specific payment or material becomes a scanning task as records accumulate.',
'Add targeted search and filters, consistent date presets, result counts and empty-filter recovery. Keep the selected filters when editing a row.',
'Find a supplier’s cash payment from last month and a stopped material without scanning all rows.',
'app/ui/suppliers.js:42; app/ui/suppliers.js:60',kind='Source')
add('P2','Purchases','Suppliers cannot be retired from daily selection',
'Supplier editing supports name, phone, opening debt and note; there is no archive state. Every supplier continues to appear in selection lists.',
'Old or accidentally added suppliers permanently increase the chance of choosing the wrong account.',
'Add archive/reactivate with preserved history. Warn about outstanding balances and exclude archived suppliers from new-entry defaults while allowing historical access.',
'Retire a supplier without deleting invoices, debt or payments, then restore it when needed.',
'app/ui/suppliers.js:7; app/ui/suppliers.js:67',kind='Source')
add('P2','Daily accounts','Custom expense categories cannot be renamed or retired',
'The categories screen only adds a category or changes primary/additional type. There is no correction or archive action for a custom category name.',
'A typo or obsolete category remains in every day’s screen and dropdowns.',
'Allow renaming/archiving custom categories while preserving stable IDs and history. Keep required original categories protected; never remove referenced records.',
'Correct a custom-category typo without changing past amounts or losing its statement history.',
'app/ui/renderer.js:70; app/ui/renderer.js:160; app/ui/model.js:382',kind='Source')
add('P2','Daily accounts','Unused categories expand every daily expense page',
'Every category absent from the selected day is rendered as an empty expense row. Large category sets therefore create long lists of “+ إضافة مبلغ”.',
'Recorded expenses and the remaining-balance action become harder to find among unused slots.',
'Show recorded entries first and offer a compact frequently used category picker. Put unused categories behind “إضافة مصروف” or a collapsed area.',
'A day with 3 expenses and 100 categories should primarily show the 3 recorded entries.',
'app/ui/renderer.js:47; app/ui/renderer.js:50',kind='Design')
add('P2','Daily accounts','The day-closing workflow is spread across distant sections',
'Sales, daily total, overall balance, cash expenses, remaining cash and transfer actions are separated vertically. Remaining cash is below both expense tables.',
'An owner must piece together the correct closing sequence and remember whether the cash count includes earlier sales.',
'Add a compact “مراجعة اليوم” flow: review sales and funding shares → count actual remaining cash → preview the approved balance calculation → optionally transfer to the safe. Preserve existing formulas.',
'Close a day with shared expenses and sales without double-counting or navigating back and forth.',
'app/ui/renderer.js:49; app/ui/renderer.js:52; app/ui/renderer.js:143',kind='Design',shot='expenses.png')
add('P2','Daily accounts','Direct cash deposit and transfer from daily cash look too similar',
'“إيداع بالقاصة” on the cash card adds a direct deposit. The similarly named remaining-balance action transfers daily cash and reduces the daily remainder.',
'Choosing the wrong entry point can record the same physical movement with a different accounting effect.',
'Distinguish “إيداع خارجي للقاصة” from “تحويل من رصيد اليوم”. Before saving, show source, destination and both balances after the action.',
'A first-time user moving today’s cash into the safe chooses the transfer path without needing documentation.',
'app/ui/renderer.js:37; app/ui/renderer.js:65; app/ui/renderer.js:136; app/ui/renderer.js:149',kind='Design')
add('P2','Daily accounts','Manual overrides are easy to apply but hard to interpret later',
'A daily total can be manually overridden, and the overall balance can be edited independently. The screen shows a manual badge for the total but no reason/history for these corrections.',
'Later reconciliation cannot easily distinguish deliberate corrections from arithmetic mistakes.',
'Show calculated value, recorded value and difference; request a brief reason for overriding and preserve a correction history. Do not redefine balance as profit or sales.',
'Review an old overridden day and explain who/what changed and the difference from recorded items, within the app’s single-user scope.',
'app/ui/renderer.js:49; app/ui/renderer.js:155; app/ui/renderer.js:158',kind='Design')
add('P2','Daily accounts','Cash history lacks period filtering and balance after each movement',
'The cash table lists all movements with amount and note; only the all-time current balance is prominent.',
'Tracing why the safe balance differs on a particular day requires manual calculation and scrolling.',
'Add a date range, source/type filter, opening and closing balance for that range, and a running balance column. Label the existing current balance as all-time/current.',
'Reconcile a selected week’s cash movement totals to its opening and closing balances.',
'app/ui/renderer.js:67',kind='Design')
add('P2','Workers','Worker search does not produce a worker-specific account history',
'Searching changes only the roster. The history below continues showing everyone, and there is no dedicated worker detail view.',
'Reviewing one worker’s contributions and receipts requires mentally filtering unrelated records.',
'Make a worker row open a pop-out detail dialog with schedule, selected-period balance, contributions and receipts; carry worker and date filters into the history.',
'Select one worker and see only their entries while keeping the pooled available balance clearly separate.',
'app/ui/savings.js:14; app/ui/savings.js:69',kind='Source')
add('P2','Workers','Receipt entry defaults to the entire shared savings pool',
'Opening a worker receipt pre-fills the full available pooled balance, not an empty amount.',
'A quick Save can allocate the entire pool to one worker accidentally. The domain correctly permits pooled receipts; the default is the risky part.',
'Start with an empty amount and offer an explicit “استلام كل المتجمع” action with a before/after preview.',
'A normal receipt requires a deliberate amount choice, and full-pool receipt remains available without changing the accounting rules.',
'app/ui/savings.js:28',kind='Design')
add('P2','Backup and reports','Import confirmation lacks a useful preview of what will replace what',
'The native confirmation says data will be replaced and a backup retained, but shows no selected filename details, covered dates or record counts.',
'The owner cannot easily recognize an old or wrong backup before replacing current accounts.',
'Show source filename, version, date coverage and counts beside current-data counts, plus the saved recovery-copy location. Retain cancel as default and validation before replacement.',
'Identify a stale backup and cancel without altering current accounts.',
'app/main.cjs:71; app/main.cjs:76',kind='Source')
add('P2','Backup and reports','Backup safety is described but not operationally visible',
'Settings explains local saving and a previous-file backup, but shows no last manual backup time or direct recovery choice. Startup read failure mainly offers importing a backup.',
'Users may confuse local saving with an independent backup and may not know how to restore the automatic previous copy.',
'Add a backup health section: last successful external/manual export, current data location, and a guided validated restore from available local snapshots. Explain that same-device copies do not protect against device loss.',
'A user with a damaged primary file can find and preview a valid recovery copy without searching folders manually.',
'app/ui/renderer.js:71; app/ui/renderer.js:297; app/storage.cjs:14; app/storage.cjs:28',kind='Design')
add('P2','Backup and reports','Reports do not cover several review and sharing tasks',
'Export supports daily expenses, a purchase invoice and a sale receipt. There is no period sales/statement/cash/worker report or standalone payment receipt. A day with only sales rejects the daily-expense PDF as having no recorded day.',
'Users can see useful summaries but cannot share the same filtered view. The existing daily report should not be mistaken for a complete sales/day-closing report.',
'Add clearly named exports for the views actually needed, beginning with the filtered expense statement and sales summary; add a payment receipt. Keep daily expense PDF scoped honestly and offer the appropriate sales export on sales-only days.',
'An exported filtered report reproduces the visible dates, filters and totals, with cash, debt and profit meanings kept distinct.',
'app/reports/pdf.cjs:30; app/reports/pdf.cjs:64; app/ui/renderer.js:61; app/ui/commerce.js:49',kind='Source')
add('P2','Backup and reports','Successful export does not help the user find the file',
'PDF success only shows “تم حفظ ملف PDF” even though the bridge returns the file path. Backup success is similarly generic.',
'The user may repeat an export or search Finder to discover where it went.',
'Show the saved filename and Open / Show in folder actions, with a persistent result until dismissed for lengthy exports.',
'After exporting, open the exact saved output directly from the success state.',
'app/ui/renderer.js:230; app/ui/renderer.js:240; app/main.cjs:62',kind='Source')
add('P3','Backup and reports','Customer receipts use only the app identity',
'Sale PDFs and on-screen receipts are headed دفتر / حسابات المطعم, without configurable restaurant identity or sale time.',
'A receipt shared with a customer is less recognizable as the restaurant’s document.',
'Add owner-approved restaurant display name and optional contact/footer settings, then apply them to customer receipts. Keep reference product images out of printed financial documents unless needed.',
'A customer can identify the restaurant and transaction without confusing the app name for the business.',
'app/reports/pdf.cjs:62; app/reports/pdf.cjs:67; app/ui/commerce.js:63',kind='Design')
add('P2','Feedback','Saving state disappears when the sidebar is closed',
'Persistent save status lives inside the sidebar. With it collapsed, users mainly see brief toasts. Checkout saving does not change the button text to a saving state.',
'A slow save can look like an ignored click, and an error can disappear before the user understands it.',
'Place a compact save indicator in the always-visible toolbar and give active actions a Saving state. Keep unresolved errors visible with Retry and preserve the draft.',
'With the sidebar closed and a delayed/failed save, users can see whether the action is pending, saved or failed.',
'app/ui/index.html:38; app/ui/renderer.js:14; app/ui/renderer.js:85; app/ui/commerce.js:95',kind='Design')
add('P2','Forms','Save actions scroll out of view in long forms',
'The submit footer belongs to the scrollable drawer form, below all fields and explanatory notes. This is particularly noticeable in purchase, product and payment forms.',
'Users must repeatedly scroll to save or check whether a primary action exists.',
'Use a sticky dialog action bar outside the scrolling fields, following D64, with Save and Cancel. Keep the error summary reachable and do not cover focused fields.',
'On a 900×580 window, Save remains reachable while editing the first or last field of every long form.',
'app/ui/renderer.js:163; app/ui/styles.css:6',kind='Design',shot='invoice-form.png')
add('P2','Forms','Validation often identifies the problem without locating the field',
'A shared form-error box scrolls into view, but inputs generally receive no aria-invalid/aria-describedby state or targeted field error. Some low-level validation falls back to “ملف البيانات غير صالح.”',
'Users must hunt for the field to correct, especially in large invoices.',
'Return field-specific errors, mark the invalid input, focus the first invalid field and retain a concise summary. Replace generic data-file wording for normal entry mistakes.',
'A bad quantity, duplicate number and funding mismatch each identify the exact correction point without clearing valid input.',
'app/ui/renderer.js:188; app/ui/renderer.js:225; app/ui/model.js:257',kind='Source')
add('P2','Accessibility','Important labels and small controls need a readability pass',
'Money-source notes and table sublabels often use 10–11px text. The cart quantity input measured about 46×14px and the sale date about 125×21px; many text actions have minimal padding.',
'Dense Arabic text is difficult to read and small controls demand precise pointing. Size alone is not a complete WCAG target-size verdict because spacing exceptions apply.',
'Use a legible operational text scale and larger hit areas for quantity, dates and row actions. Aim for comfortable 40–44px controls where space permits, and audit adjacent-target spacing.',
'Review at normal and enlarged text with keyboard and touch/trackpad input, keeping financial values and units readable.',
'app/ui/commerce.css:5; app/ui/styles.css:9; app/ui/styles.css:11',kind='Measured')
add('P2','Accessibility','Product creation can duplicate an existing field ID',
'Opening Add product from the sales no-result state creates two elements with id="product-group": the catalog filter and the product group text input.',
'Labels and ID-based lookup can point to the wrong control, and changing the form group also triggers the catalog-filter handler.',
'Give catalog-group-filter and product-group-input distinct IDs and keep their event handling scoped to their containers. Give search fields explicit persistent accessible labels rather than relying on placeholders.',
'Every rendered ID is unique; changing a product group cannot change the sales filter.',
'app/ui/commerce.js:18; app/ui/commerce.js:55; app/ui/commerce.js:108')
add('P2','Performance','History renders thousands of rows in one pass',
'In an isolated synthetic run, 100 sales rendered in about 30ms with 1,253 DOM nodes; 5,000 sales rendered/layouted in about 798ms with 55,153 nodes. This is a local measurement, not a device-wide benchmark.',
'Normal growth can produce noticeable pauses when opening or filtering history.',
'Paginate or window long tables, default history to a useful recent period, and index repeated lookups. Keep totals computed over the full filtered result, not only the visible page.',
'Test 5,000+ sales and long purchase/cash histories; filtering and opening should remain responsive without changing totals.',
'app/ui/commerce.js:49; app/ui/renderer.js:67; app/ui/suppliers.js:61',kind='Measured')
add('P2','Performance','Eight small product thumbnails use about 20MB of PNG assets',
'The eight bundled photos are roughly 2.1–2.9MB each, although they appear as small cropped cards. Lazy loading is already present.',
'The app package and image decoding work are larger than the displayed result requires.',
'Create appropriately sized optimized derivatives, retain originals separately, and provide responsive image sizes. Keep the user-requested reference photos and their consistent crops.',
'Compare appearance and cold-load decoding after optimization; no visible quality loss at actual card size.',
'app/ui/photos/; app/ui/commerce.js:23',kind='Measured')
add('P3','Visual system','Repeated overrides make spacing and component states inconsistent',
'The CSS has successive overrides for sales layout, responsive rules and sidebar controls; many colors and dimensions bypass the existing tokens.',
'Small future layout changes can unexpectedly differ by screen size, increasing the cost of maintaining a consistent UI.',
'Consolidate final component rules, define shared control/text/spacing tokens, and document the supported compact layout. Preserve the existing calm green identity.',
'The same control has predictable sizing and states across sales, accounting, settings and drawers.',
'app/ui/commerce.css:1; app/ui/commerce.css:20; app/ui/commerce.css:91; app/ui/styles.css:1',kind='Source')
add('P3','Copy','Action labels and context labels are not always specific',
'Many drawers—including products and suppliers—show “دفتر / سجل اليوم”. Read-only receipts say “متابعة”. Singular counts display forms such as “1 أصناف”.',
'Small ambiguities reduce orientation and make a polished app feel assembled from unrelated screens.',
'Use the actual module in form context, “بيع جديد” or “إغلاق الوصل” for receipt actions, and Arabic plural rules for counts. Keep the friendly Iraqi voice consistent.',
'A user can identify the module and the effect of an action from its label alone.',
'app/ui/renderer.js:163; app/ui/commerce.js:27; app/ui/commerce.js:63',kind='Design')

add('P2','Navigation','Replace sidebars with pop-out panels — owner requested',
'The owner added during this review: “the sidebars should be a pop out window instead of sidebar bc annoying”. This supersedes the earlier preference to retain persistent sidebar presentation; it is a requested design direction, not a newly reproduced defect.',
'Side panels consume space and feel intrusive to the owner, even when they can collapse.',
'Use a compact Menu trigger that opens navigation as a dismissible pop-over panel above the workspace. Present short entry/edit forms in centered pop-up dialogs instead of edge-attached drawers. Keep the page and draft underneath intact; use a large dialog or dedicated editor for long purchase invoices. Default to in-app overlays rather than separate operating-system windows unless that is specifically desired.',
'Opening a panel must not squeeze or shift the page. Closing returns focus to its trigger and restores the full workspace. Dirty forms are protected, Escape and keyboard focus work, and long dialogs remain usable at 200% zoom.',
'app/ui/index.html:20; app/ui/renderer.js:163; app/ui/styles.css:6',kind='User request')

counts=collections.Counter(i['priority'] for i in issues)
metadata={"date":"2026-10-26","sourceVersion":"1.11.0","schema":9,"counts":dict(counts),"issues":issues}
(out/'findings.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2))
intro='''# Daftar — full app, UX and UI audit

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
'''
summary=f'**{len(issues)} audit items: 63 findings plus one owner-requested design change. {counts["P1"]} P1, {counts["P2"]} P2, {counts["P3"]} P3; no P0 established.**\n\n'
md=intro.replace('## Design and technical health',summary+'## Design and technical health')
for i in issues:
 refs=[]
 for ref in i['source'].split('; '):
  parts=ref.rsplit(':',1); f=parts[0];line=parts[1] if len(parts)==2 else None
  refs.append(f'[{ref}](../../{f}'+(':'+line if line else '')+')')
 md+=f'\n### {i["id"]} · {i["priority"]} · {i["title"]}\n\n**Area:** {i["area"]} · **Evidence:** {i["kind"]}\n\n{i["evidence"]}\n\n**Why it matters:** {i["impact"]}\n\n**Proposed change:** {i["change"]}\n\n**Acceptance check:** {i["check"]}\n\n**Source:** '+', '.join(refs)+'\n'
 if i['shot']:md+=f'\n[Screen evidence](../../outputs/ux-audit-2026-10-26/{i["shot"]})\n'
ending='''
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
'''
md+=ending
(root/'docs/planning/2026-10-26-full-app-ux-audit.md').write_text(md)
(out/'report.md').write_text(md)

def esc(s):return html.escape(str(s),quote=True)
areas=list(dict.fromkeys(i['area'] for i in issues))
rows=[]
for i in issues:
 image_link=f'<a href="{i["shot"]}" target="_blank">View screen evidence ↗</a>' if i['shot'] else ''
 rows.append(f'''<article class="finding" id="{i['id']}" data-priority="{i['priority']}" data-area="{esc(i['area'])}" data-kind="{i['kind']}">
 <div class="finding-top"><span class="priority {i['priority']}">{i['priority']}</span><span>{i['id']} · {esc(i['area'])}</span><span class="evidence">{i['kind']}</span></div>
 <h3>{esc(i['title'])}</h3><p>{esc(i['evidence'])}</p><dl><dt>Why it matters</dt><dd>{esc(i['impact'])}</dd><dt>What should change</dt><dd>{esc(i['change'])}</dd></dl>
 <details><summary>Acceptance check and source</summary><p>{esc(i['check'])}</p><code>{esc(i['source'])}</code></details>{image_link}</article>''')
html_page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Daftar — UX audit</title>
<style>
:root{--ink:#17382d;--muted:#506456;--line:#d9e0d6;--bg:#f6f7f2;--paper:#fefefa;--green:#245b42}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}main{max-width:1120px;margin:auto;padding:56px 32px}a{color:var(--green);text-underline-offset:3px}header{border-bottom:1px solid var(--line);padding-bottom:28px}.eyebrow{text-transform:uppercase;font-size:12px;letter-spacing:.12em;color:var(--muted)}h1{font:600 clamp(32px,5vw,55px)/1.1 Georgia,serif;margin:14px 0}h2{font-size:23px;line-height:1.3;margin:35px 0 12px}h3{font-size:21px;line-height:1.4;margin:10px 0}.lead{max-width:850px;font-size:19px}.muted{color:var(--muted);font-size:14px}.stats{display:flex;gap:24px;flex-wrap:wrap;padding:18px 0;border-block:1px solid var(--line);margin-top:24px}.stats span{font-size:14px}.stats b{font-size:24px;margin-right:5px}.scope{display:grid;grid-template-columns:1fr 1fr;gap:32px}.scope ul{padding-left:22px}button,input,select{font:inherit;min-height:44px;border:1px solid #aab9a6;border-radius:6px;background:var(--paper);color:var(--ink);padding:8px 12px}button{cursor:pointer}button:focus-visible,input:focus-visible,select:focus-visible,summary:focus-visible,a:focus-visible{outline:3px solid #245b42;outline-offset:3px}.filters{position:sticky;top:0;background:var(--bg);border-bottom:1px solid var(--line);padding:18px 0;z-index:2;display:grid;grid-template-columns:2fr 1fr 1.4fr auto;gap:12px}.filters label{display:flex;flex-direction:column;font-size:12px;gap:5px}.filters button{align-self:end}.finding{padding:28px 0;border-bottom:1px solid var(--line);scroll-margin-top:130px}.finding-top{display:flex;gap:14px;align-items:center;font-size:12px;color:var(--muted)}.priority{padding:3px 10px;border-radius:4px;font-weight:700}.P1{background:#f1dfd8;color:#782f25}.P2{background:#eee8d5;color:#65531c}.P3{background:#e0e9dd;color:#325638}.evidence{margin-left:auto}p{margin:10px 0}dl{display:grid;grid-template-columns:155px 1fr;gap:12px;margin:18px 0}dt{font-size:13px;font-weight:650;padding-top:3px}dd{margin:0}details{font-size:13px;color:var(--muted);margin:18px 0 10px}summary{cursor:pointer;min-height:28px}code{white-space:normal;overflow-wrap:anywhere;font-size:12px}.finding>a{font-size:13px}.note{padding:18px 22px;border-left:3px solid var(--green);background:#eaf0e4}.thumbs{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}.thumbs img{width:100%;aspect-ratio:1.55;object-fit:cover;object-position:top;border:1px solid var(--line)}.thumbs a{font-size:13px}.checklist li{margin-bottom:8px}footer{padding:35px 0;color:var(--muted);font-size:13px}#empty{padding:40px 0}#result-count{font-size:13px;color:var(--muted)}[hidden]{display:none!important}@media(max-width:720px){main{padding:28px 18px}.scope{grid-template-columns:1fr;gap:8px}.filters{grid-template-columns:1fr 1fr;position:static}.filters label:first-child{grid-column:1/-1}dl{grid-template-columns:1fr;gap:3px}dd{margin-bottom:12px}.thumbs{grid-template-columns:1fr}.stats{gap:14px}.finding-top{flex-wrap:wrap}}@media print{.filters,.thumbs,button{display:none}.finding{break-inside:avoid}main{padding:0}details{display:block}.scope{display:block}}
</style><main><header><div class="eyebrow">Daftar / review / 26 October 2026</div><h1>A calm interface.<br>Workflows that need firmer ground.</h1><p class="lead">The full app inspection, with evidence, user impact and a concrete next design for every finding.</p><p class="muted">Source 1.11.0 · Schema 9 · 13 sections reviewed · Isolated sample accounts · Inspection only</p></header>
'''
html_page+=f'<div class="stats"><span><b>{len(issues)}</b> audit items</span><span><b>{counts["P1"]}</b> major</span><span><b>{counts["P2"]}</b> improvements</span><span><b>{counts["P3"]}</b> polish</span><span><b>96/96</b> existing tests pass</span></div>'
html_page+='''<div class="scope"><section><h2>Fix trust and recovery first</h2><p>Wrong funding labels, cross-day editing, contradictory invoice previews, draft loss and inaccessible zoom states deserve attention before visual polish.</p><p>No P0 incident or actual loss of restaurant records was established. Existing passing tests do not cover every reproduced problem.</p></section><section><h2>Preserve the approved direction</h2><p>Keep Arabic RTL, the calm green palette, photo cards, products left / bill right, fast exact-total cash payment, editable order types, top shortcuts. The owner’s latest addition asks for pop-out panels in place of sidebars (D64).</p></section></div>
<p class="note">Nothing in the app was changed by this audit. Your live browser draft and real restaurant accounts were left alone. Recommendations below are proposals, not approved implementation.</p>
<h2>Evidence snapshots</h2><div class="thumbs"><a href="bug-statement-cash.png" target="_blank"><img src="bug-statement-cash.png" alt="Statement showing the incorrect funding breakdown">Shared cash mislabeled as daily</a><a href="invoice-form.png" target="_blank"><img src="invoice-form.png" alt="Purchase invoice editor">Purchase entry and balance previews</a><a href="sales-200-percent.png" target="_blank"><img src="sales-200-percent.png" alt="Sales page at 200 percent zoom with checkout outside view">Checkout at 200% zoom</a></div>
<h2>The complete findings list</h2><p class="muted">Observed = exercised in the UI. Measured = captured sizes, colors or timings. Source = verified in implementation. Design = a recommendation based on the current experience. User request = the owner’s added design direction.</p>
<div class="filters"><label>Search findings<input id="search" type="search" placeholder="Try: draft, supplier, cash, keyboard…"></label><label>Priority<select id="priority"><option value="">All priorities</option><option>P1</option><option>P2</option><option>P3</option></select></label><label>Area<select id="area"><option value="">All areas</option>'''+''.join(f'<option>{esc(a)}</option>' for a in areas)+'''</select></label><button id="reset">Clear filters</button></div><p id="result-count" role="status" aria-live="polite"></p><div id="findings">'''+''.join(rows)+'''</div><p id="empty" hidden>No matching findings. Clear the filters to see the full list.</p>
<h2>What the improved flows should feel like</h2><ol class="checklist"><li><strong>Selling:</strong> find or scan → review bill → confirm cash → next customer. Receipt access stays available without a forced interruption.</li><li><strong>Purchases:</strong> choose or create supplier → spacious invoice editor → optional payment → one consistent balance preview → save and return to the invoice.</li><li><strong>Day closing:</strong> review sales and funding → count actual remaining cash → preview approved calculation → optional safe transfer → accurately scoped report.</li><li><strong>Inventory:</strong> filter items needing action → inspect running history → receive, adjust or correct → see the resulting quantity at the right date.</li><li><strong>Recovery:</strong> preserve drafts; preview backups; retain reversals and issued sale numbers.</li></ol>
<h2>Order of work</h2><p>Correctness and recovery → task structure and consistent forms → cashier/purchase efficiency → accessibility and performance → final visual polish. The detailed written report includes the health scores, personas, evidence coverage, acceptance checks and optional capabilities.</p><p><a href="report.md">Open the full written report</a> · <a href="findings.json">Structured findings</a> · <a href="evidence.json">UI evidence</a> · <a href="additional-evidence.json">Zoom / performance / PDF evidence</a></p>
<h2>Limits and standards</h2><p class="muted">This review covers the current source and isolated previews, not a guarantee of every defect. Native file dialogs, real printers/scanners, VoiceOver and full WCAG conformance were not tested. Narrow-phone views are secondary diagnostics; the native app’s minimum window width is 900px. Generated sample PDFs: <a href="daily.pdf">daily</a>, <a href="purchase.pdf">purchase</a>, <a href="sale.pdf">sale</a>.</p><p class="muted">Accessibility references: <a href="https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html">W3C contrast</a>, <a href="https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html">target size and spacing</a>, <a href="https://www.w3.org/WAI/WCAG22/Understanding/labels-or-instructions.html">labels</a>, <a href="https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html">focus order</a>.</p><footer>Daftar · One restaurant · Local records · Audit proposals only</footer></main>
<script>const fields=['search','priority','area'].map(id=>document.getElementById(id));function filter(){const [q,p,a]=fields.map(e=>e.value.toLowerCase());let count=0;document.querySelectorAll('.finding').forEach(el=>{const show=(!q||el.textContent.toLowerCase().includes(q))&&(!p||el.dataset.priority.toLowerCase()===p)&&(!a||el.dataset.area.toLowerCase()===a);el.hidden=!show;if(show)count++});document.getElementById('result-count').textContent=count+' audit items shown';document.getElementById('empty').hidden=count!==0}fields.forEach(e=>e.addEventListener('input',filter));document.getElementById('reset').addEventListener('click',()=>{fields.forEach(e=>e.value='');filter();fields[0].focus()});filter();</script></html>'''
(out/'report.html').write_text(html_page)
print(json.dumps({'findings':len(issues),'counts':dict(counts),'report':str(out/'report.html')},indent=2))
