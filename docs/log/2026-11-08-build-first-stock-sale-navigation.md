# Stock history to saved receipt navigation

Date: 2026-11-08. Status: read-only implementation candidate; focused execution results appended below. No independent review, native acceptance, benchmark or full suite.

## Scope and ownership

App-only C1-16 integration using existing approved stock-history and saved-receipt views. Madar implementation/API/Design changes: N/A; source identities, projections, receipt composition and storage contracts remain unchanged. Root owns `app.dart` mounting; worker owns narrow callback changes in inventory/history and one new widget test. No financial mutation, source backfill, engine pin, schema activation or design expansion.

`InventorySurface(onOpenSale:)` forwards an exact saved sale identity from stock history. Sale clicks validate the current inspected account snapshot and exactly one existing source sale. Return clicks resolve exactly one saved return record to its parent saved sale, validating the parent before handoff. Existing explicit return callbacks remain compatible. The stock dialog closes before navigation. Missing/stale/unavailable sources show feedback rather than invent a receipt or navigate by a guessed number.

`SalesHistorySurface(initialSaleId:, onInitialSaleHandled:)` waits for available account data, opens the exact saved receipt once after mounting and signals consumption. Root clears pendingSaleId on that callback. Rebuilds do not repeat the consumed request. Missing/duplicate source IDs show a failure and consume that request; a saved void retains its original identity and opens read-only with the existing void receipt state. No active ticket or financial command is created.

## Actual preparation checks

Targeted Dart analysis over inventory surface, stock-history dialog, saved-history surface and the new widget test passed. Added four bounded scenarios: sale-row navigation, return-row parent navigation, missing-ID refusal and saved-void identity. Linked scenarios capture unchanged acknowledged account bytes and verify once-only receipt opening after request consumption/rebuild. Root/worker coordinated the shared Flutter compiler; execution results follow rather than being assumed.

No new design assets, exports, archives or task scratch stores. Baseline available disk: 96,224,156 KiB; catalog folder 144 KiB, sales folder 140 KiB, shared Git objects 4,640,292 KiB, shared build 2,142,228 KiB. Final storage/cleanup review follows execution. Source/test/log remain canonical artifacts; active shared build output belongs to the ongoing build campaign.

Compiler wait: root had already started four bridge and one portable-app small checks; worker prepared navigation tests/docs independently, then one coordination wait timed out at 10 seconds. This is shared compiler serialization, not a product failure. No build/test process was started concurrently by this worker.

## Focused execution and corrections

`flutter test --no-pub test/catalog/stock_saved_sale_navigation_test.dart`: **4 passed**. The sale and return sources each opened the exact parent saved receipt; source account bytes stayed unchanged, the stock dialog closed, and clearing/consuming the request prevented a repeated receipt after dismissal/rebuild. Missing identity failed visibly; the saved void opened its original read-only receipt.

Two earlier invocations had harness failures. First, the inventory action lay outside the visible horizontal table region; the test tapped before scrolling, so the dialog never opened. Added `ensureVisible` for the real inventory/source controls. Second, Escape did not dismiss the receipt in this fixture; the test then incorrectly expected it absent. Used the actual close control and separate async-dismiss/reverse-animation frames, reusing root's already reported remedy. The final four-case run passed. No source behavior was patched to hide these fixture failures. The missed reuse of root's known dismiss-frame remedy was avoidable test overhead.

Shared compiler coordination used one 10-second timeout, two subsequent 30-second timeouts and a final message-ended wait. These are requested wait bounds, not measured active engineering time. Root released its five-case window before this worker invoked Flutter. Test invocations reported about 5–8 seconds each. Tokens/cost and full phase active effort remain unknown.

Final bounded analyzer covered the three owned source files, the focused test and root `app.dart`. Owned paths had no findings; the only info was root `app.dart:704` braces style, reported for root to fix within its ownership. No broad suite, native run, benchmark or independent review.

## Completion storage review

Final available disk: 96,181,884 KiB (42,272 KiB below baseline). Catalog folder 148 KiB (+4); sales 144 KiB (+4); new canonical test 7,643 bytes. Shared Git objects 4,640,912 KiB (+620); shared build 2,174,044 KiB (+31,816). Concurrent root/worker test/build activity prevents full attribution. No unexplained multi-GiB increase or low-space threshold occurred. Source changes, test and this log remain canonical. Test stores were in-memory; no exports, screenshots, archives, duplicate copies or scratch stores need retention/cleanup. Cleanup reclaimed 0 bytes; shared active compiler artifacts remain in use.

Root has separately wired the callback and pending identity with an account-fence guard. This task establishes the connected read-only behavior under the four focused widget cases, not formal C1-16 independent/native/benchmark closure. Parent owns tracker and sanitized memory reconciliation.
