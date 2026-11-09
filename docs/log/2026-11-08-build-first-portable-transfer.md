# Build first portable transfer controller log

Recorded UTC: 2026-11-08T11:51:00Z (Local: 2026-11-08T14:51:00+03:00).
Status: implementation complete; 11 focused tests passing; clean static analysis (0 issues).
Advances isolated version 12 complete-envelope transfer capability.

## Context and assignment

- Retry of prior failed Gemini portable file workflow task (previous run interrupted by HTTP 502 with no source delivered).
- Exclusive ownership:
  - `lib/accounts/portable_account_transfer_controller.dart`
  - `test/accounts/portable_account_transfer_controller_test.dart`
  - `docs/log/2026-11-08-build-first-portable-transfer.md`
- Preserved concurrent work: native workers own UI files, dialogs, and root app/daily/financial command workflows. No edits to engine packages, pins, schema 11 repositories, live account databases, or cutover activation. No Git mutation, branch, worktree, or subagent spawning.

## Preflight and coordination

1. Storage check: 96,230,200 KiB available.
2. Hindsight memory preflight: scoped recall performed separately for `daftar` (`project-daftar`) and `madar` (`project-madar`) per `t3-hindsight-required/SKILL.md`. Verified existing observations, boundaries, and storage contracts.
3. Authority reviewed:
   - Madar store contract: `LocalDocumentWorkspaceStore` (CAS writeDocument, replaceGeneration, preserveSource, resolvePendingWrite).
   - Transfer capability: `FileTransferCapability` (open, save).
   - Envelope codec: `PortableJournalCodec` enforcing 20 MiB bound, UTF-8 validity, and version 12 invariants.
   - State model: `PortableJournalState` preserving `account`, `journals`, `receipts`, `accountLineage`, and `cutoverState`.

## Implementation details

Implemented `PortableAccountTransferController` and `PendingPortableAccountImport` in `lib/accounts/portable_account_transfer_controller.dart`:
1. **Explicit initialization**: Operates strictly on an isolated version 12 `DocumentSnapshot` and `LocalDocumentWorkspaceStore`. Does not bootstrap uninitialized accounts or mutate schema 11 repositories.
2. **Export exact bytes**: `exportBytes()` generates canonical version 12 bytes via `codec.encodeBytes(state)`. `exportTo(transfer)` writes exact bytes to `FileTransferCapability.save`.
3. **Import bounds and preparation**: `prepareImport(bytes)` enforces payload size bounds (<= 20 MiB), valid UTF-8, and complete version 12 envelope decoding. Creates `PendingPortableAccountImport` holding the decoded `state` and unmutated `originalBytes`.
4. **Original-byte preservation**: Source bytes are preserved via `store.preserveSource(originalBytes)` before any document write is attempted.
5. **Explicit fenced replacement**: `confirmImport()` verifies current store CAS snapshot, executes `store.writeDocument(..., replaceGeneration: true, expected: snapshot)`, advances generation fence, and replaces state while preserving complete history (journals, receipts, lineage, cutover, account).
6. **Unknown-outcome reconciliation**: If write acknowledgement is lost or fails with `commit_unknown`, the controller blocks further writes and sets `needsReadback = true`. `reconcile()` queries `store.resolvePendingWrite()` and `store.readDocument()`, safely accepting the replacement only if the committed token and payload match.
7. **Reload / Refresh**: `reload()` refreshes authority from the store, refusing to overwrite uncommitted pending imports unless explicitly discarded.

## Verification

- Compiler window requested and released after test execution.
- Focused unit tests:
  - Command: `flutter test test/accounts/portable_account_transfer_controller_test.dart`
  - Result: 11 tests passed (initialization, export bytes, exportTo, prepareImport bounds, legacy/corrupt rejection, pickImport lifecycle, cancelImport, fenced replacement with preserveSource, stale revision CAS guard, unknown write reconciliation).
- Non-regression check:
  - Command: `flutter test test/settings/portable_settings_controller_test.dart`
  - Result: 3 tests passed.
- Static analysis:
  - Command: `dart analyze lib/accounts/portable_account_transfer_controller.dart test/accounts/portable_account_transfer_controller_test.dart`
  - Result: 0 issues found.

## Ready API and remaining limits

- **Ready API**:
  - `PortableAccountTransferController({required store, required snapshot, required isWriteBlocked, codec})`
  - Properties: `snapshot`, `authorityFence`, `state`, `accountLineage`, `account`, `journals`, `receipts`, `cutoverState`, `sourceProvenance`, `pendingImport`, `hasPendingImport`, `busy`, `needsReadback`, `requiresReload`.
  - Methods: `exportBytes()`, `exportTo(transfer)`, `prepareImport(bytes)`, `pickImport(transfer)`, `cancelImport()`, `confirmImport()`, `reconcile()`, `reload({discardPendingImport})`.
  - `PendingPortableAccountImport`: `state`, `originalBytes`, `byteLength`.
  - `PortableAccountsSurface({required controller, transfer, onImportApplied})`:
    - Concrete import/export/settings data UI over `PortableAccountTransferController`.
    - Selected C7 `phone-settings-data` frame and approved Phase 02 patterns (A/B/C/E/F).
    - Exposes `onImportApplied(DocumentSnapshot snapshot)` callback upon committed fenced generation replacement.
- **Remaining limits**:
  - Parent composition owner coordinates reopening session after generation replacement.
  - Live account cutover activation and Schema 11 migrations remain uncoupled and preserved.
  - Native file dialogs depend on host platform `FileTransferCapability`.

## Surface UI implementation update

Recorded UTC: 2026-11-08T12:20:00Z (Local: 2026-11-08T15:20:00+03:00).
Status: implementation and focused widget smoke complete; 7 widget smoke tests passing (18 total transfer/surface tests passing); clean static analysis (0 issues).

### Scope and ownership
- Exclusive ownership:
  - `lib/accounts/portable_accounts_surface.dart` (new)
  - `test/accounts/portable_accounts_surface_test.dart` (new)
  - `docs/log/2026-11-08-build-first-portable-transfer.md` (compact update)
- Preserved: `lib/accounts/accounts_surface.dart`, `lib/app.dart`, shared sessions, metadata bridge, and existing live repositories untouched.

### Implemented UI capabilities
1. **C7 Phone-Settings-Data layout**:
   - Header: "نسخة إضافية، وراحة بال" and backup guidance.
   - Status Card: "حالة النسخ الاحتياطية", current restaurant name, account lineage, revision, journal count, receipt count, storage fence generation, and refresh action.
   - Export Section: "تصدير نسخة احتياطية", single-file version 12 description, export button, and error-retaining exact retry button (`portable-export-retry-button`).
   - Import Section: "استيراد نسخة محفوظة", file picker initiation, and error handling.
2. **Candidate preparation summary**:
   - When candidate import is prepared, displays candidate restaurant name, lineage, journal count, receipt count, cutover date, and byte length with explicit confirm and cancel actions.
3. **Guarded replacement confirmation**:
   - Dismissible confirmation modal (`showDakhlDialog`) before write.
   - Preserves source bytes via `store.preserveSource(originalBytes)`.
   - Replaces generation fence (`replaceGeneration: true`).
   - Dispatches `onImportApplied(newSnapshot)` callback to parent.
4. **Resilience and error recovery (Patterns A, B, C, E, F)**:
   - Unknown commit outcome: displays readback warning and triggers `controller.reconcile()`.
   - Stale revision: displays reload warning and triggers `controller.reload()`.
   - Retained input and localized error messages for all capability failures.
   - Verified on narrow viewport (320px) and large text scale (200%) without overflow.

### Verification
- Static analysis: `dart analyze lib/accounts/portable_accounts_surface.dart test/accounts/portable_accounts_surface_test.dart` (0 issues).
- Widget tests: `flutter test test/accounts/portable_accounts_surface_test.dart` (7 tests passed).
- Non-regression: `flutter test test/accounts/portable_account_transfer_controller_test.dart test/settings/portable_settings_controller_test.dart` (11 + 3 tests passed).
- Storage review: available 96,227,360 KiB; completion-review 18,232 KiB; git objects 4,640,292 KiB. Compiler window released.

