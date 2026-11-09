# 0007 — Remove the worker-advance UI while preserving history

Status: approved by the owner's explicit request and implemented in source. Date: 2026-10-27. Source: the request to remove worker advances from the application, with its screenshot.

## Decision and rationale

Remove the worker-advance page, forms and actions from the UI, navigation and shortcut configuration. Remove loading of its UI module and delete that file. Earlier shortcuts to it become empty slots without breaking account import.

The request removes a feature from the application; it does not authorize destruction of financial records. The `workers` and `savingsEntries` fields, validation, save/backup paths and historical reports remain only for compatibility. No balances, expenses, sales or inventory change, and no record-deleting migration is required.

This supersedes the availability of the worker-advance screen in earlier documentation and the worker-UI portion of [decision 0004](0004-ux-popouts-and-recovery.md), preserving the independence rules for historical financial records. [Verification outcome](../log/2026-10-27-remove-worker-savings.md).
