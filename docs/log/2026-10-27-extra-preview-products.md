# Add 25 illustrative preview products

Status: implemented and verified. Date: 2026-10-27. Request: add 25 samples to Sales to try the catalog.

Change: added a browser-preview data generator alongside the base test fixture, containing 25 extra products across the existing five groups with illustrative prices/quantities. The total became 33 products. The preview bridge merges missing IDs without duplication or replacement of existing preview data. Photos are references, and some products exercise the no-image state. The local preview server was restarted and both browser tabs refreshed.

Verification: the model validated 33 products, including 25 additions. Both previews show 33 cards; reloading does not duplicate additions. Existing illustrative preview sales remained unchanged. npm test passed 120/120. Local image: outputs/layout-review/sample-products-33.png. Restaurant account files, the installed application and the base test fixture were untouched.

Memory: recall returned withdrawn historical sources, so current files were used. The previous check had no pending/failed work but sources=0. Sync/check are repeated without interpreting that result as proof of indexing documents with no registered sources.
