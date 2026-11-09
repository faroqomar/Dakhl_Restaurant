# Paid-spending consumer integration candidate

Status: locally verified candidate; focused independent source review and exact engine pin pending.

`DailyCashQueries.statement` now composes codec-valid restaurant expenses and supplier payments, omits historical zero expenses, and delegates calculation/filtering/ranking/paging to the public Madar query. The app retains the source presentation envelope, payment labels and raw IDs; `(sourceKind,id)` distinguishes source namespaces. No invoice or liability becomes a paid row. Existing daily cash, refunds and cashbox calculations remain outside this change.

Four new consumer cases plus the existing frozen Node daily-cash oracle pass. They cover equal raw IDs across expense/payment namespaces, zero omission, retained payment metadata, source funding filters, unpaid invoice exclusion and valid period totals above the individual entry limit across101rows/threepages. The new statement domain projection first failed compilation before implementation; one test fixture attempted to mutate a frozen map and was corrected to a mutable fixture copy. Targeted analysis passes. These tests import only public barrels.

Madar owns the reusable query; no arithmetic/ranking/paging copy remains in this statement method. Candidate versions are domain0.1.0-dev.5 and application0.1.0-dev.4, with other package versions unchanged. The exact engine commit and consumer pin must follow focused review. No report UI, operation benchmark, migration, merge or release is claimed.
