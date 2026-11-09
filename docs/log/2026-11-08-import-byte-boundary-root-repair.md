# C0-12 import byte-boundary QA repair

The independent source review found two preparation defects: authority comparison omitted files larger than64KiB, and failed close/cleanup could disable retry or dispose the model before storage release. Root repaired the QA harness before native expansion. The production importer remains capped at20,971,520 bytes; no runtime schema or engine API changed.

The repaired fixture hashes every authority file with streaming SHA256. Close/cleanup use success-only state, single-flight futures and an operation interlock. Native storage closes before model disposal; a failed owned-root deletion or closeout remains retryable. The mounted QA retains its cleanup retry button after failure. Strict owned-path/link checks remain enabled.

Eight host tests pass: exact canonical schema11 UTF8 size, actual40MiB regular-file staging and SHA256/readback/cleanup, L+1 parsed equivalence, large archive insertion/same-length mutation detection, failed close retry, partial deletion retry, active-picker interlock and mounted cleanup retry. Four affected files analyze without issues. The native file-picker cases have not run.

Root added behavioral regression tests alongside the repairs after independent source findings; no pre-fix behavioral RED is claimed. Retained attempts distinguish compile-only local owner/Zone typing errors from five noncanonical temporary-root setup failures. Resolving the test roots fixed setup while preserving the production symlink guard. Five empty, current-task-owned directories were removed after bounded checks.

The existing resolved crypto3.0.8 package now has an explicit development dependency for QA hashing. Offline enforced resolution changed only its lock classification; all113 package entries remain identical. This is not part of the earlier compiled C0 iOS binary. The fresh focused review packet binds exact current sources, metadata and logs at [recheck-inputs.json](../../outputs/completion-review/import-byte-boundary/root-repair/recheck-inputs.json).

Engine runtime/API: N/A. Consume reviewed ac8b4edc2c915ed22c0991685c33967b3360e7fa; reusable native-file/storage capabilities are unchanged. App ownership is synthetic QA fixture/UI/test composition. Native macOS exact-limit cancel and oversized-reject acceptance remains pending independent source recheck and reviewed preflight. No Penpot/login work, real records, live migration, approval or release changed.

Storage: the passing staging test removes its exact L/L+1 pair and owned store. The review manifest records free space and task-evidence size; canonical source/failed attempts stay retained. Detailed timing and cost remain unknown where not captured by the retained runner.

## Focused successor

The27binding review verified the original two repairs, then found wrong selected bytes could throw before releasing the open interlock. Root moved validation inside finally and added delegate-finally release. Two new regressions first failed behaviorally, then all10 host tests and four-file analysis passed. The successor [selected-result-recheck-inputs.json](../../outputs/completion-review/import-byte-boundary/root-repair/selected-result-recheck-inputs.json) retains the original packet, failures and exact-source bindings. Two failed RED stores totaling397,904 logical bytes were removed after exact task marker, UID, no-link and no-open-handle checks; the first abbreviated-marker check refused all deletion. Native acceptance remains pending.
