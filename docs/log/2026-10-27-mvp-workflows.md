# Implement MVP workflows — 2026-10-27

The owner requested documenting scope and implementing returns, held orders, post-payment receipts and screen states, with a simple daily review. Initial setup and backup reminders remain deferred. [Approved scope](../planning/2026-10-27-mvp-completion.md).

Implemented in source: schema 11 and a separate returns ledger; exact discount allocation; effects dated on return; optional stock restoration; duplicate-return/double-cancellation prevention; and system-dialog printing from saved records. Astra's UI includes payment receipts, returns, held orders and their states.

Actual verification: all 140 npm test tests passed without failure. 15 UI cases across 1512×982, 1024×768 and 390×844 passed, covering hold/resume/payment/receipt/return/day review without page/dialog horizontal overflow. Images in outputs/mvp-review were reviewed, with three mocked print calls. Neither restaurant accounts nor a real printer was used.

Limits: physical printing is unverified because no printer was available. Held orders are local, outside account backups. The installed Mac application was not updated. Browser preview was refreshed while preserving its current sample data.

Documentation is saved in planning, decision 0010, references and usage guide. Project memory: sync/check returned a healthy service and no pending/failed work, but sources=0; this does not prove document indexing.

Next: owner trial of sales/returns/held-order flows. Initial setup and backup reminders remain deferred by the request.
