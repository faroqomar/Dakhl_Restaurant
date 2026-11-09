# Portable Journal Codec and Complete-State Foundation

Date: 2026-11-07
Status: Isolated candidate repaired after independent review; focused re-verification passes and independent recheck is pending. Runtime activation, live migration, actual cutover date/values and release remain separate gates.

## Context & Governance

Under [ADR 0021](../decisions/0021-completion-financial-policy.md) and the root contract [docs/phases/completion-journal-persistence-contract.md](../phases/completion-journal-persistence-contract.md), this task delivers the isolated F-04 / F-06 / F-07 foundation for the version 12 portable journal complete-state envelope.

Shared contracts and rules remain strictly in `Madar_Engine` pinned at `d316fd6076375daa3f412889f73eaebfeeb5d4d4` (`madar_application: 0.1.0-dev.4`, `madar_domain: 0.1.0-dev.5`). `Dakhl_Restaurant` owns the restaurant envelope, mapping, and consumer document composition without copying engine algorithms or altering existing runtime files.

## Ownership & Scope Boundaries

In accordance with sub-agent boundaries:
- **Created**:
  - `lib/accounts/portable_journal_state.dart`
  - `lib/accounts/portable_journal_codec.dart`
  - `test/accounts/portable_journal_codec_test.dart`
  - `test/accounts/portable_journal_conformance_test.dart`
  - `docs/log/2026-11-07-portable-journal-codec.md`
- **Untouched**:
  - Existing `AccountDocument`, `LegacyAccountCodec`, `AccountsRepository`, `bootstrap`, UI/view models, routes, mappers, trackers, and engine code were not modified.
  - All preexisting dirty/untracked files from concurrent workers remain preserved.
  - No git reset, branch switching, staging, commit, merge, or push performed.

## Design & Implementation Details

1. **Version 12 Portable Envelope (`PortableJournalState`)**:
   - Embeds the validated canonical schema 11 `AccountDocument` without altering the canonical representation.
   - Enforces version `12`.
   - Incorporates caller-owned `accountLineage` (non-empty trimmed string) strictly separated from storage-level `StorageFence`.
   - Preserves `PortableJournalSourceProvenance` (`sourceVersion`, `enrolledAt`, `migrated`).
   - Contains immutable lists of `PortableJournalEntry` and `DurableCommandReceipt`.

2. **Explicit Cutover State (`PortableJournalCutoverState`)**:
   - Source enrollment marks cutover as `isGated: true`, `hasActivePosting: false`, `cutoverDate: null`, `openingJournalId: null`.
   - Gated cutover state strictly rejects any attempt to assert active posting (`invalid_cutover_state`).
   - Historical and opening journals are never synthesized during legacy enrollment.

3. **Journals & Exact IQD Representation (`PortableJournalEntry`)**:
   - Uses Madar's `BalancedJournal` with exact IQD units, scale 0, and balanced debit/credit lines.
   - Preserves source provenance (`sourceType`, optional `sourceRecordId`), reversal links (`reversesId`), replacement links (`correctedFromJournalId`, `replacementJournalId`), and provenance timestamp (`recordedAt` distinct from accounting `effectiveDate`).
   - Validates uniqueness of journal IDs and verifies reversal targets exist in prior history.

4. **Public `DurableCommandStateCodec` (`PortableJournalCodec`)**:
   - Implements `DurableCommandStateCodec<PortableJournalState>`.
   - Reuses `LegacyAccountCodec` for validating legacy schemas 1..11 into canonical schema 11.
   - Enforces the 20 MiB document payload boundary (`DocumentLimits.accountBytes`). Payloads > 20 MiB fail closed with `payload_too_large`.
   - Corrupt JSON or invalid UTF-8 fails closed with `corrupt_state` without corrupting durable state.
   - Rejects versions != 12 with `unsupported_version`.
   - Extracts and attaches `DurableCommandReceipt` instances with strict sequence checking, unique `operationId` validation, and monotonic revision ordering per fence.

5. **Existing Runtime Rejection**:
   - Existing runtime `LegacyAccountCodec` stays at schema 11 and strictly rejects candidate version 12 payloads with `unsupported_version`.
   - There is no live activation path in this task.

6. **Single Storage Owner Conformance**:
   - Exercised against `PowerSyncLocalDocumentWorkspaceStore` and `DurableCommandCoordinator`.
   - Verified command acceptance, replay of identical payload (`DurableCommandReplayed`), rejection of tampered payload (`changed_payload_rejected`), persistence across store restart, fence generation replacement, and resolution of unknown write acknowledgements.

## Verification & Test Results

1. **Unit Tests (`test/accounts/portable_journal_codec_test.dart`)**:
   - 14 initial candidate tests covering version boundaries and selected legacy enrollment fixtures, account lineage validation, deep snapshot immutability, exact IQD journals and reversals, unbalanced journal rejection, duplicate journal rejection, receipt monotonicity and gap rejection, 20 MiB payload bound, malformed/corrupt JSON, and gated cutover invariants.
   - Result: 14 / 14 passed.

2. **Conformance Tests (`test/accounts/portable_journal_conformance_test.dart`)**:
   - 3 tests exercising actual store persistence, durable command coordinator execution, replay, changed payload rejection, close/reopen state integrity, restore fence generation replacement (`stale_authority_fence`), and unknown acknowledgement resolution via `store.resolvePendingWrite()`.
   - Result: 3 / 3 passed.

3. **Accounts Suite & Static Analysis**:
   - Full `test/accounts/` suite: 388 / 388 passed.
   - `flutter analyze lib/accounts/portable_journal_* test/accounts/portable_journal_*`: 0 issues found.

## Environment & Storage Evidence

- **Dakhl_Restaurant Commit**: `cc91fae438101fce7ff4729e12bf3c2b64dacd70`
- **Madar_Engine Commit**: `d316fd6076375daa3f412889f73eaebfeeb5d4d4`
- **Storage Baseline & Closeout**:
  - Baseline Available: 112 GiB, `.git` size: 18 GiB.
  - Closeout Available: 109 GiB, `.git` size: 18 GiB.
  - Free space remains well above the 10 GiB limit; zero unexplained repository growth.

## Next Steps & Remaining Gates

- Do not enable schema 12 live migration or runtime activation until explicit owner verification of cutover opening values and date.
- Root owners retain all aggregate trackers, checklist rows, and phase registers.
- Future integration tasks can consume `PortableJournalCodec` when the owner authorizes the financial posting and cutover transition phase.


## Root repair after independent review 639dd213

The initial passing suite missed validation and preservation defects. Root added requirement-driven regressions: 11 of the first 12 new cases failed before the repair. The repaired state validates at construction/copy and again before encoding. Stored reversal lines, policy and total must match the original inverse on the original effective date. Plain voids retain null correction links. Duplicate inverses, missing/cyclic correction targets and dangling replacement links fail closed. Reversal entry decoding takes the prior original as explicit context.

Nested metadata and verified opening maps use detached recursive snapshots; cycles, excessive nesting, floats, unsupported objects and unsafe JSON integers fail. Portable metadata uses JSON scalars only: exact values beyond its integer profile must use explicitly composed decimal strings; passing mapper BigInt metadata directly is rejected. A mapper-to-envelope composition contract remains necessary before posting integration. The reusable Madar domain entities and coordinator stay unchanged.

Envelope decoding rejects unknown durable fields, including nested entry/policy/line/receipt/provenance keys. Embedded account data must already match canonical schema 11; the codec rejects unknown or normalization-requiring fields rather than dropping them. Legacy enrollment retains the existing explicit conversion path. Policy validation reuses the restaurant mapper profiles, permits stricter caller caps, checks IQD scale 0 and bounds aggregate opening profiles to opening lineage.

The two supported cutover states have consistent flags/date/opening references. Established synthetic state requires an actual opening journal on its cutover date. This structural validation does not prove owner approval or real opening values. Receipt history validates operation uniqueness, contiguous sequence, outcomes and increasing revisions per provenance fence; revisions may reset under a new restore fence. Capacity overrides can tighten the 20 MiB store limit. Malformed typed/Unicode input produces structured errors.

Root verification: 34 focused codec/integrity/store conformance tests pass, including rich-history fixtures for every legacy version 1–11. Static analysis of the five affected source/test files passes. The three store tests prove clean close/reopen and injected acknowledgement recovery; they do not establish arbitrary process/power-loss safety. The existing runtime, repository, bootstrap and file actions still use schema 11.

Storage repair closeout: 114560784 KiB available, app Git 18418068 KiB (+260 from intake), engine Git 36664 KiB (unchanged), build 591740 KiB (−47716), dart_tool 204852 KiB (unchanged), review outputs 220 KiB (+4). Zero temporary Git object stores in both checkouts. Volume variation remains unattributed. Retained source/test/compact receipts and current caches; no obsolete bulk artifact or unique recovery object deleted. Temporary root test logs are disposable after compact evidence extraction.

Full accounts regression after the repair: 403 tests passed. This supersedes the initial 388-test count for the changed candidate.

Independent recheck 1fd9750a verified unchanged six-file input hashes, all eight prior defect classes, 34 focused/403 accounts tests and affected analysis with no blocking findings. Root confirmed those hashes remain unchanged during C1 repairs. The codec remains isolated; journal command reconciliation and runtime migration are separate. Valid Unicode surrogate pairs remain supported; malformed unpaired code units fail closed.
