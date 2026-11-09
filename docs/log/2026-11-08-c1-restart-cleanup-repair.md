# C1 restart QA cleanup repair

2026-11-08T06:18:04.305158+00:00 — Independent source review found one cleanup defect in the isolated QA fixture: an early closed flag skipped retries after a retained-handle close error, and an initial failed owner prevented later closes. Root added a trusted QA close seam and a safe red test: expected three owner attempts but observed only origin. Its assertion failed before any unsafe deletion; finally released actual handles.

Root now shares concurrent close completion, tracks successful releases, drains all owners and marks closed only after full success. Errors propagate before recursive deletion. All five fixture tests pass and analysis is clean. Prior two QA source files remain byte-exact as text snapshots for the already-frozen326-source benchmark pilot; no benchmark dependency source changed. [Repair manifest](../../outputs/completion-review/c1-restart-portability/close-repair/review-inputs.json). Focused independent recheck and actual native process/file-provider proof remain pending.

No product, engine, pin, native-project or live account changed. Ownership: app-only QA composition over the existing Madar close contract; engine implementation/API N/A.

2026-11-08T06:30:02.927367+00:00 — Focused recheck confirmed the original failed-close defect fixed but found post-close target creation. Safe red test reproduced it and closed the unexpected owner before any deletion. Root added terminal lifecycle guards, early import-owner registration and readiness checks; six fixture tests and final analysis pass. Intermediate source is preserved separately, original benchmark snapshots unchanged. Native execution remains pending final focused recheck.
