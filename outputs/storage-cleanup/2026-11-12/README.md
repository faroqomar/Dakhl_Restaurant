# Reference retirement evidence

Canonical receipts for owner-authorized Electron source retirement and disposable metadata cleanup, 2026-11-12. These compact records supplement `docs/log/2026-11-12-reference-cleanup.md`.

- `baseline.json`: exact initial source, tracked-state hashes and storage measurements.
- `electron-removal.json`: source-content/private-file/open-handle guards, removed allocation and retained symlink targets.
- `metadata-cleanup.json`: exact disposable paths and allocation; no Git object deletion.
- `reference-integrity.json`: retained 179 screenshot and 21 asset hash checks.
- `legacy-fixture-verification.json`: worker capture/affected checks and native-hook recovery.
- `legacy-fixture-tests.log`: successful source-absent affected suite.
- `tooling-tests.log`: preserved first failed Python 3.9 attempt.
- `tooling-tests-python313.log`: successful supported-interpreter retry.
- `engine-check.log`, `flutter-analyze.log`, `dart-format.log`, `flutter-tests.log`: current verification output.

No restaurant-account files, dependency binaries, app bundles, duplicate screenshots or raw conversation dumps belong in this directory. Final storage/review receipts follow after verification. Retain logs because they record actual failed/successful attempts; do not use them as release approval.

Publication note: raw `*.log` files remain local under the existing log ignore rule; they contain terminal progress/control whitespace. Committed JSON receipts and the maintenance log record the commands, outcomes and failed attempts. The raw logs listed above are host-local evidence, not files supplied by a fresh clone.
