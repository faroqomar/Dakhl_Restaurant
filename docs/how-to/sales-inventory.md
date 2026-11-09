# Sales, inventory and shortcuts

Status: source-preview guide for 1.12.0. Date: 2026-10-27. Source: current Daftar screens and sales tests. UI labels are translated into English for documentation; the application remains Arabic RTL.

1. Open **Inventory → Add product**. Enter name, sale price, unit, optional group and opening quantity dated when available. Disable **Track this product's quantity** for meals not stocked as a fixed count; unnecessary inventory fields disappear.
2. Use **Restock / Adjustment** to receive stock or record shortage/waste. **Movements** shows additions and sales. These are sellable-product quantities; ingredient purchase invoices and supplier payments remain in their own sections.
3. Open **Sales**. Search by name/code or choose a group. Select a product to add it, then use quantity buttons or enter a decimal quantity. The ticket survives navigation and is saved as a local draft recovered after reopening the application. It is not a sale until confirmed.
4. Enter any discount and choose **Order type**, review the total, then select **Confirm cash sale**. This records receipt of the exact invoice value without entering cash received. Inventory updates and the receipt opens automatically after successful saving, with a new ticket ready. **Save PDF** allows choosing the receipt file.
5. Open **Sales history** to search by period, number and product and reopen a receipt. **Void this sale** requires a reason and restores the entire quantity while preserving the voided receipt. Physically refund the net receipt amount to the customer when voiding. A void corrects the original sale date; for partial or later-dated returns use **Return products**. Voiding is not allowed after a return is recorded.
6. Under **Settings and backups → Top-bar shortcuts**, choose a screen for each of six slots and select **Save shortcuts**. **No shortcut** hides the button. Choices are included in backups; settings remain reachable through popout navigation and the customize action.

## Daily account and cashbox

Recorded cash sales appear in daily expenses. When entering remaining cash, enter actual cash after all recorded activity, including earlier sales. A sale after the remaining-cash entry is added automatically. Sales are not received twice by the cashbox; when transferring daily cash, record depositing the remaining amount into the cashbox using the existing procedure. Sales totals are not net profit and do not automatically include ingredient costs.

Inventory, sales and settings use the same account file/backups; updating earlier versions preserves their records and adds the new lists empty.

## More screen space — 2026-10-26

The top-bar menu opens navigation over the page without squeezing the workspace. Escape, close or an outside click dismisses it. The current ticket remains. Add/edit forms are centered dialogs and request confirmation only when they contain unsaved changes.

## Order types and reference images

In settings, use **Order-type management** to add, disable or delete a type and set the default; changing names does not alter earlier receipts. Under **Inventory → Edit product**, choose a suitable reference image or **No image**. These are generated illustrative images. On large screens products/ticket scroll internally; smaller or zoomed screens allow page scrolling to reach payment. **Compact view** reduces product-card size while preserving images.

## Review, corrections and backups

- Sales history supports period, state and order type, with export of the current view. The current ticket retains prices shown when products were added.
- In inventory movements, **Correct movement** requests a reason and saves a reversal; then record the correct movement. A correction that would make historical inventory negative is rejected.
- **Day review** combines funding-share review, actual-cash entry, balance preview and an optional cashbox transfer. **External cashbox deposit** is independent of **Transfer from daily balance**.
- Settings show the last export and provide the earlier backup. Import/restore show a summary before replacement and save the previous file. Export regularly to a location independent of the device.
- Receipt identity is optional in settings. After export, the Mac application offers open-file and reveal-in-folder actions.
- Use ⌘/Ctrl + K for search, an exact code then Enter to add, ⌘/Ctrl + Enter for cash confirmation and ⌘/Ctrl + 1–6 for shortcuts outside text fields.

## Product tabs — 2026-10-27

Choose a group using the tabs above search; its count is the number of active products in that group. **All products** shows everything, and search filters the selected group. Selecting a card or its corner add icon adds the product to the ticket. Choosing a group preserves the incomplete receipt. On small windows, scroll groups horizontally and the page to reach the ticket and confirmation.

## MVP update — 2026-10-27

- **Hold order** saves the current ticket with an optional name and opens an empty one. **Held orders** at the top of sales supports resume/delete. Resuming while products are present first holds the current ticket. Orders are unpaid, reserve no stock and stay on the device; they are not in the account backup file.
- After successful **Confirm cash sale**, automatically open the receipt with line/amount details and close, print and save-PDF actions. Printing is optional and uses the system dialog; cancelling printing does not cancel the sale.
- Under **Sales history → Receipt details → Return products**, choose quantity, whether stock is restored, date and reason. Review the calculated discounted amount and confirm it was refunded from daily cash. The original sale remains saved and the return deducts collections only on its return date; it does not deduct from the cashbox.
- A sale with returns cannot be voided; remaining quantities may be returned. A return is neither a price edit nor a new discount.
- First-run setup and backup reminders are deferred until the end of application work; current backup tools remain available.
