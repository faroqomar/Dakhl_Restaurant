# Portable metadata repository integration

Date: 2026-11-08. Status: isolated app composition candidate; four focused checks passed, targeted analysis clean. Owner build-first sequencing defers the full tests/benchmarks/independent review. No normal bootstrap, migration, verified opening, cutover, engine pin or release change.

## Concrete integration

`PortableMetadataRepositoryBridge` borrows one existing Madar store and projects the validated portable account into the schema11 `DocumentSnapshot` expected by existing metadata ViewModels. It translates an allowed metadata candidate into the same complete portable envelope and delegates exact expected-snapshot compare-and-swap, backup and write acknowledgement to that owner. It preserves journals, receipt identities/outcomes, lineage, provenance and cutover. It implements no SQL, filesystem transaction, backup, idempotency or storage-recovery algorithm. Madar source/API change: N/A.

`RestaurantOperationsSession` exposes initialized `metadataRepository` and `metadataBridge`, includes their acknowledged full snapshot in reader synchronization and excludes peer writes during metadata uncertainty. Existing catalog/category/party controllers can use this repository; acknowledged financial writes refresh its reads, invalidating old captured edit sessions while retaining their input. Metadata writes refresh sales, spending, parties, settings and reports through the existing session. `reconcileMetadata()` calls the existing repository reconciliation policy, then synchronizes readers. A new storage fence/account lineage requires disposal and a newly opened session.

The exact whitelist permits categories, products, stock entries, materials, preferences, supplier metadata and day chicken counts. Supplier opening balances must remain unchanged, including deletion of a nonzero opening. Financial day fields, sales/returns, invoice/payment/debt rows, transactions/transfers, retired history and other source fields remain canonical-value identical. New chicken-only days require empty expenses and null balance/override/remaining. Existing codec/source validation still applies to the whole candidate. The bridge refuses creation, replacement, source preservation/import and recovery. Its close releases its projection listeners, never the borrowed store.

Stable bridge rejection codes include `metadata_financial_mutation_refused`, `metadata_financial_day_refused`, `metadata_opening_debt_refused`, `metadata_replacement_refused`, `metadata_creation_refused`, `metadata_import_refused`, `metadata_recovery_refused`, stale authority and existing codec/unknown-write errors. Existing account and full-envelope capacity limits remain intact.

## Single workspace owner

Root additionally assigned narrow `saveFormDraft(Map<String, String>)` methods in TicketWorkspaceController, SalesViewModel and SalesWorkflowSession. Each freezes caller input before asynchronous work and uses the existing fenced transition path to replace only form values while preserving current active/held tickets. Root's portable shell queues these form changes through `session.sales.saveFormDraft`, avoiding stale complete workspace replacement through another repository owner.

`sales.draftNeedsReadback` now excludes metadata/settings/spending/parties, checkout and reader refresh during unresolved workspace writes. The existing `reconcileDraft()` resolves that owner's original pending write before new changes. Worker reported the direct sales-operations history boundary; root then reported adding an operations-only own-draft uncertainty closure while retaining peer-only recovery access for `reconcileDraft`. Root extended the focused test with a direct-void assertion and owns that successor's verification.

## Portability boundary

This repository is for metadata/forms, not an AccountsSurface data-transfer owner. Schema11 export through AccountsViewModel would omit journals despite the bridge protecting imports. Root agreed to keep normal schema11 AccountsSurface only in the normal branch and use a separate complete-envelope portable data surface in the explicit portable branch. No export/import/recovery UI is authorized through this projection. Parent app-shell injection and its acceptance are root-owned, outside this worker's source ownership.

## Checks and observed repair

`flutter test --no-pub test/accounts/portable_metadata_repository_bridge_test.dart`: successor 4 passed. Tests exercise actual existing catalog/category/party ViewModels over the bridge, sell a newly created product through the same financial session, preserve the complete envelope during chicken edits, refuse financial/opening/import/replace/recovery mutations, resolve a committed lost acknowledgement through the existing repository, reject a stale catalog draft after an expense, and preserve active/held tickets while freezing form input. An unresolved form write blocks checkout/settings until draft reconciliation. Closing the projection leaves the borrowed store readable.

First run passed3/4 and exposed a session notification race: bridge readback launched reader synchronization while AccountsRepository still held its pending token, so `reconcileMetadata` joined an earlier `commit_unknown` result. Worker wrapped metadata reconciliation in the existing session action guard, suppressing intermediate auto-sync until repository acknowledgement finishes. The four-case rerun passed. This was a reproduced app-composition issue, not a Madar storage defect or a reason to duplicate recovery logic.

Final targeted analysis of bridge/session, the three narrow sales files and the focused test: no issues. Initial analyzer style diagnostics concerned redundant null assertions and missing braces; worker corrected them. No full suite, native/SQLite fault campaign, benchmark or independent review ran. Root took the compiler window afterward for its separately owned explicit portable-app integration widget. Exact timing/token cost totals are unknown.

## Storage receipt

Initial free space 96,318,692 KiB. Final measurement at2026-11-08T12:23:58Z: 96,213,720 KiB (-104,972 KiB shared-volume change); `.git`18,437,560 KiB. Canonical new bridge and focused test each12KiB; retain them with this log and the scoped session/method changes. No Git temporary object directory appeared. Worker created no build, screenshot, PDF export, archive or scratch copy. Other workers used the volume concurrently; cause attribution remains unknown. No low-space or unexplained2GiB growth threshold occurred. Shared active compiler/build outputs remain root-owned; no unsafe cleanup was performed. Root batches authoritative Markdown memory delivery.
