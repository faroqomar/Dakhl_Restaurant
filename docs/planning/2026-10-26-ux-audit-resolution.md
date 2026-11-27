# Daftar — audit fixes and verification

Status: all 64 listed changes implemented in source 1.12.0 / schema 10. Authorized by the owner’s “fix them all” request, including replacing sidebars with pop-out panels. Date: 26 October 2026.

The changes retain the Arabic RTL layout, calm green identity, one-restaurant scope and existing accounting formulas. Tests use illustrative data only.

## Verification

- 113 automated tests passed, including native import/cancel/recovery, corrupt-file preservation and exported-file access.
- All 13 sections visited in an isolated Electron browser; no page script errors in the recorded flows.
- Desktop, small viewport and 200% zoom checks, including checkout and long invoice entry.
- 5,000-sale sample: 50 visible rows per page, full-result totals and working pagination. Timing is machine-specific; see verification.json.
- All eight report types generated as actual PDFs. Representative invoice and sales PDFs rasterized and visually inspected.
- macOS ARM64 package built separately from the existing installed app.

Evidence: automated test output, browser checks, PDF checks, package output.

## Item-by-item resolution

| ID | Original finding | Implemented change | Verification basis |
| --- | --- | --- | --- |
| D01 | First invoice can leave the app stuck | First purchase creates its supplier, then continues into the invoice; failed opening clears dialog state. | Browser flow checks and automated regression tests |
| D02 | Editing a statement row uses the wrong day | Historical expense edits resolve the original record and date. | Browser flow checks and automated regression tests |
| D03 | Cash filter labels shared spending as daily spending | Statement totals use the selected funding share and preserve the original allocation. | Browser flow checks and automated regression tests |
| D04 | Manual-total form previews the wrong expense total | Manual expense-total preview uses daily-funded spending only. | Browser flow checks and automated regression tests |
| D05 | Two balance previews disagree in one invoice form | Invoice and payment previews share the same draft balance calculation. | Browser flow checks and automated regression tests |
| D06 | Fractional quantities appear as whole numbers | Quantities retain up to three decimals in lists, analysis and reports. | Automated model/UI/native regression checks and source review |
| D07 | A blank sale date still saves using a hidden old date | Checkout rejects blank dates; different dates have a visible warning and Today action. | Browser flow checks and automated regression tests |
| D08 | An archived item gets stuck in the current bill | Stopped products can be removed from an open bill; checkout explains what must be resolved. | Browser flow checks and automated regression tests |
| D09 | Remaining fractional stock cannot be added to a bill | Adding an item with fractional stock uses the remaining valid quantity. | Browser flow checks and automated regression tests |
| D10 | Future stock is labeled as available now | Inventory availability is calculated as of today; future movements are labeled in history. | Automated model/UI/native regression checks and source review |
| D11 | Global Undo can erase a completed sale | Completed-sale Undo opens cancellation; completed and void invoices remain in the record. | Browser flow checks and automated regression tests |
| D12 | Closing forms silently discards entered work | Dirty forms and settings ask before discard, including Escape, menus and native window close. | Browser flow checks and automated regression tests |
| D13 | The current sale has no recovery after clearing or restarting | The active bill is saved locally by account; restart restores it, and clearing a populated bill asks first. | Browser flow checks and automated regression tests |
| D14 | Cart actions discard keyboard focus | Cart actions and dialog closure restore focus by stable control/record identity. | Browser flow checks and automated regression tests |
| D15 | Secondary text falls below normal-text contrast requirements | Darker muted text and shared readable control styles replace low-contrast secondary text. | Shared color tokens and rendered-screen contrast check; not a formal accessibility certification |
| D16 | 200% zoom can put checkout outside the reachable screen | Short or zoomed screens scroll to checkout; large desktop sales retain the split layout. | Browser flow checks and automated regression tests |
| D17 | Savings date and visible history describe different periods | Savings history consistently respects the selected end date and worker search. | Browser flow checks and automated regression tests |
| D18 | Thirteen equally weighted sections make the app harder to learn | Navigation is grouped into four task families, with all thirteen destinations retained. | Source review and captured browser screens |
| D19 | Repeated navigation and large slogan headings consume working space | Page titles name the actual task; repeated cash and supplier side rails become optional pop-outs. | Source review and captured browser screens |
| D20 | Shortcut numbers imply keyboard shortcuts that do not exist | Modifier shortcuts are implemented and explained; ordinary number typing remains untouched. | Browser flow checks and automated regression tests |
| D21 | Shortcut customization has no preview or duplicate guidance | Shortcut settings have a live preview, reorder controls and duplicate guidance. | Source review and captured browser screens |
| D22 | Filtering behavior changes from screen to screen | Dated reports use explicit Apply, validated ranges and period presets; active selections remain visible. | Source review and captured browser screens |
| D23 | History rows omit year and sales time | History includes the year; sales include the saved time in history and receipt. | Source review and captured browser screens |
| D24 | Every completed sale interrupts the next sale with a receipt drawer | Saving a sale prepares the next empty bill and shows optional receipt, PDF and cancellation actions. | Browser flow checks and automated regression tests |
| D25 | Cash collection is implicit at the final action | Checkout explicitly confirms a cash sale for the displayed exact total. | Source review and captured browser screens |
| D26 | Rare bill options compete with the current order | Discount and sale date live in an expandable section; compact product density retains photos. | Source review and captured browser screens |
| D27 | Available quantity does not explain what is already in the bill | Product cards show stock and quantity already in the bill, with explicit sold-out/full-cart states. | Source review and captured browser screens |
| D28 | An open bill silently adopts a newly edited product price | A draft keeps the price quoted when its product was added. | Automated model/UI/native regression checks and source review |
| D29 | Barcode and keyboard selling stop at search | Exact product-code Enter adds the item; search and checkout have deliberate modifier shortcuts. | Browser flow checks and automated regression tests |
| D30 | Sales history cannot filter the metadata the app already saves | Sales history filters status and order type and shows completed/void counts. | Source review and captured browser screens |
| D31 | No search results is presented as an empty inventory | Inventory and catalog distinguish an empty collection from no search matches, with Clear actions. | Source review and captured browser screens |
| D32 | Low-stock and archived items are not directly filterable | Inventory filters active, low, empty and stopped stock, and product groups. | Source review and captured browser screens |
| D33 | Editing an item changes its position in lists | Product, supplier, material and worker edits replace the record in its existing position. | Automated model/UI/native regression checks and source review |
| D34 | The product form exposes irrelevant stock fields | Stock-only fields hide and disable when tracking is off; existing-history restrictions are explained. | Automated model/UI/native regression checks and source review |
| D35 | Stock mistakes have no durable correction workflow | Stock corrections create a validated linked inverse movement and require a reason. | Browser flow checks and automated regression tests |
| D36 | Stock history cannot explain the running balance | Stock history shows signed movements, chronological running balances, source links and corrections. | Source review and captured browser screens |
| D37 | A six-field invoice row is compressed into a long drawer | Purchase entry is a centered large editor with supplier/date context, expandable carton details and fixed totals/actions. | Source review and captured browser screens |
| D38 | Purchase analysis mixes units and repeats invoice debt on each item | Purchase quantities are grouped by material/unit; remaining debt appears once per invoice parent. | Automated model/UI/native regression checks and source review |
| D39 | Catalog wording suggests supplier-specific materials although the catalog is shared | Material wording consistently describes the shared catalog and invoice-specific price snapshots. | Source review and captured browser screens |
| D40 | Payments and materials lack basic retrieval tools | Payments and materials have targeted search, filters, counts and recoverable empty results. | Source review and captured browser screens |
| D41 | Suppliers cannot be retired from daily selection | Suppliers can be stopped/reactivated while retaining history and remaining-balance context. | Automated model/UI/native regression checks and source review |
| D42 | Custom expense categories cannot be renamed or retired | Custom categories can be renamed/stopped without changing IDs; original categories remain protected. | Automated model/UI/native regression checks and source review |
| D43 | Unused categories expand every daily expense page | Daily expenses show recorded entries without rendering every unused category. | Source review and captured browser screens |
| D44 | The day-closing workflow is spread across distant sections | Review day combines sales/funding review, actual cash count, balance preview and optional safe transfer. | Source review and captured browser screens |
| D45 | Direct cash deposit and transfer from daily cash look too similar | External safe deposits and daily-cash transfers have distinct labels and before/after previews. | Automated model/UI/native regression checks and source review |
| D46 | Manual overrides are easy to apply but hard to interpret later | Manual totals/balances require a reason and retain before/after correction history, including Undo. | Automated model/UI/native regression checks and source review |
| D47 | Cash history lacks period filtering and balance after each movement | Cash history has period/source filtering, opening/closing balances and running balance after each movement. | Source review and captured browser screens |
| D48 | Worker search does not produce a worker-specific account history | Worker names open their own dated history with schedule, contributions, receipts and a filtered PDF. | Source review and captured browser screens |
| D49 | Receipt entry defaults to the entire shared savings pool | Savings receipts start with an empty amount; receive-all is an explicit action with a balance preview. | Browser flow checks and automated regression tests |
| D50 | Import confirmation lacks a useful preview of what will replace what | Native import previews selected/current counts, dates and schema, with the recovery-copy location and Cancel default. | Automated model/UI/native regression checks and source review |
| D51 | Backup safety is described but not operationally visible | Settings show export/previous-backup status; validated recovery preserves the previous current file, including corruption. | Automated model/UI/native regression checks and source review |
| D52 | Reports do not cover several review and sharing tasks | Saved-record PDF exports cover filtered statements, sales, cash, workers and payment receipts, alongside existing reports. | Automated model/UI/native regression checks and source review |
| D53 | Successful export does not help the user find the file | Successful exports retain the filename with Open and Show in folder actions. | Automated model/UI/native regression checks and source review |
| D54 | Customer receipts use only the app identity | Restaurant name, optional contact and receipt footer can be saved in settings and are escaped in exports. | Browser flow checks and automated regression tests |
| D55 | Saving state disappears when the sidebar is closed | The toolbar always shows save state; failures preserve input and offer retry; active forms indicate saving. | Browser flow checks and automated regression tests |
| D56 | Save actions scroll out of view in long forms | Forms have separate scrolling content and persistent actions; extreme zoom allows the whole dialog to scroll. | Browser flow checks and automated regression tests |
| D57 | Validation often identifies the problem without locating the field | Entry validation marks and focuses the field, expands hidden details if necessary, and keeps the error summary. | Automated model/UI/native regression checks and source review |
| D58 | Important labels and small controls need a readability pass | Operational text and frequently used controls use shared readable sizes and larger hit areas. | Source review and captured browser screens |
| D59 | Product creation can duplicate an existing field ID | Catalog and product-group fields have distinct IDs; search fields have accessible labels. | Source review and captured browser screens |
| D60 | History renders thousands of rows in one pass | Long histories and product lists paginate; stock rendering uses a shared balance index. Totals cover all matches. | Browser flow checks and automated regression tests |
| D61 | Eight small product thumbnails use about 20MB of PNG assets | Responsive 240/480px WebP derivatives total about 500 KB; original PNGs remain in the workspace and are excluded from packaging. | Measured optimized asset sizes and checked packaged archive contents |
| D62 | Repeated overrides make spacing and component states inconsistent | Commerce styling is consolidated; shared interaction tokens and responsive overrides live in the shared UX stylesheet. | Source review and captured browser screens |
| D63 | Action labels and context labels are not always specific | Dialog context names the module; receipt/checkout actions are specific and common counts use Arabic plural forms. | Source review and captured browser screens |
| D64 | Replace sidebars with pop-out panels — owner requested | Navigation, cash context, supplier selection and entry forms are in-app pop-out panels/dialogs; page width stays unchanged. | Browser flow checks and automated regression tests |

## Practical limits

- Hardware barcode scanners, physical printers and a full VoiceOver session were not tested.
- The browser preview uses illustrative local data. Native file import, recovery and exports are verified in isolated tests and available in the Mac build.
- The existing installed app and real restaurant records were not modified. The new build is under dist/Daftar-darwin-arm64.
- The original audit is a historical baseline, not a claim that these issues remain open. Further user feedback can reveal additional issues.
