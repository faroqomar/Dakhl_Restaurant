# Madar application capability contracts

Development candidate `0.1.0-dev.5`. Pure Dart capability outcomes, file/PDF handoff, local preferences, complete-document/workspace ports, durable command coordination and explicit collation contracts. The package contains no Flutter, vendor/database/cloud, filesystem or hardware implementation, and no restaurant accounting policy. This is not a published or supported engine release.

The current SDK range is Dart `>=3.13.7 <3.14.0`. The collation port adds no external runtime dependency; native setup belongs to the optional adapter.

Consumers own validation/schema, display copy, namespace choices, route/shortcut semantics, document composition and user safeguards. Optional engine adapters implement these contracts. Existing `CapabilityResult`, `FileTransferCapability` and `PdfHandoffCapability` APIs remain unchanged from `0.1.0-dev.1`.

## Local preferences

`LocalPreferencesStore.read(String namespace)` returns `CapabilityResult<PreferenceSnapshot?>`; successful null means absent, not failed. `replace(String namespace, String payload, {int? expectedRevision})` returns the committed immutable snapshot and revision. Null revision means create-if-absent; a stale revision yields `PreferenceErrorCodes.conflict` without changing stored state.

Namespaces contain 1–64 ASCII `[a-z0-9._-]` characters. Opaque valid-Unicode payloads are limited to 16 KiB UTF-8; consumers own JSON/schema and migration. Returned revisions are positive signed 64-bit integers; never timestamps or money. The store persists one complete snapshot atomically. It exposes neither SQL nor a business-record repository, delete/reset operation, sync backend or UI cancellation.

`PreferenceErrorCodes` defines invalid namespace/payload/revision, size, conflict, unavailable/corrupt/unsupported state, revision exhaustion, uncertain commit and closed-store errors. Diagnostic messages are sanitized English; translate by stable code. Never treat `commit_unknown` as definitive rollback: read before retry to discover the actual complete snapshot. Success acknowledges transaction commit, not power-loss/device recovery. Preserve unsupported/corrupt state rather than silently resetting.

```dart
final read = await store.read('sample.display.v1');
if (read case CapabilitySuccess<PreferenceSnapshot?>(:final value)) {
  final saved = await store.replace('sample.display.v1', '{"density":"compact"}',
    expectedRevision: value?.revision);
  // Display Saved only for CapabilitySuccess<PreferenceSnapshot>.
}
```

The optional [madar_data adapter](../data/README.md) documents setup, lifecycle, concurrency, typed errors, offline behavior and generic usage. The application interface depends only on capability outcomes; adapters own storage and logging. A second application can reuse the port without the restaurant's UI or schema.

Verify with `dart pub get --enforce-lockfile`, `dart analyze`, and `dart test` from this directory. A generic consumer test exercises absent/save/conflict semantics and boundary-tool tests reject vendor/presentation leaks; actual adapter data-integrity tests are independent in `packages/data`. Avoid tests that merely mirror sealed constructors.

## Complete document/workspace contract — CAP-02 preview

`LocalDocumentWorkspaceStore` is separate from the16KiB preferences port. It accepts app-validated opaque UTF-8 document/workspace payloads (20MiB each) and returns `CapabilityResult`; adapter-specific setup/durability evidence lives in `madar_data`. `StorageFence(storeId,generation)` is immutable value identity, independent of numeric revision. Every successful workspace read, including absence, carries it through `WorkspaceState`; stale results must be discarded by consumer ViewModels.

`readDocument()` returns null only for true absence. `writeDocument(payload,writeToken:,expected:,replaceGeneration:)` uses create-if-absent or expected fence/revision CAS; ordinary writes retain generation, explicit replacement commits a fresh generation with the document. `writeWorkspace(payload,fence:,expectedRevision:,writeToken:)` is fenced CAS; its null expected revision means create-if-absent in that generation. `readPrevious()` independently inspects previous bytes without requiring a readable primary. `preserveSource(bytes)` archives the selected original bytes and returns an opaque identity. `recoverPrevious(selection,payload:,writeToken:)` uses the app-validated/migrated payload, preserves source/old container paths and activates a verified fresh container/fence. `close()` drains/releases ownership without deleting data.

Write tokens support bounded latest-write readback, not indefinite idempotency. After `commit_unknown` or `recovery_publication_unknown`, mutations remain gated until `resolvePendingWrite()` confirms actual authority/token; the caller rereads snapshots before retry. Backup publication and primary commit are not one transaction. A failed primary commit can leave the previous copy equal to current. First creation has no prior acknowledged document and no previous copy. Corrupt/future/incomplete states remain protected; errors are never empty data.

`DocumentErrorCodes` specifies sanitized invalid/size/revision/token, unsupported/corrupt, unavailable/busy, conflict/stale-generation, exhaustion, backup publication, uncertain acknowledgement, closed, incomplete and identity-collision failures. Consumer apps own localization and account-schema meaning. The interface contains no SQLite/filesystem implementation, cloud/upload behavior or guarantees against device loss/power loss. See [the CAP-02 plan](../../docs/reference/cap02-account-workspace-plan.md) and [ADR0010](../../docs/decisions/0010-local-account-workspace-snapshots.md) for the bounded adapter protocol and separate approval/verification state.

`resumeInitialCreation(payload,writeToken:)` explicitly resumes a protected interrupted first creation only when the caller-validated canonical payload matches its original versioned intent. It preserves all candidates and does not reinterpret incomplete state as absence or build defaults. See the adapter documentation for coordinated source/archive validation and positive handle-drain requirements.


## Durable command coordinator candidate (0.1.0-dev.4)

The public `madar_application.dart` barrel now exposes the generic coordinator, state codec, identities, receipts and result variants. Independent source review passed for this additive export. Exact consumer pin adoption is recorded separately; this remains a local development package, not a published release. [Complete API, initialization, failure, privacy and capacity contract](../../docs/reference/completion-durable-coordinator-contract.md).

Initialize the account through the existing bootstrap first. Then supply a nonnull consumer state codec, caller-owned operation identity, captured `expectedFence`, and a pure proposal that preserves prior receipts. Identical retries replay their recorded result; changed payloads fail, and explicit recorded rejections remain failures. An omitted caller fence only pins authority for that invocation and cannot protect a form captured earlier.

Use the public barrel, not `src/` imports. The complete state plus receipt writes through one store owner with CAS. UTF-8 capacity is bounded to20MiB; malformed or dropped receipt history fails before writing. Diagnostics emit commit, replay, replayed rejection and failure outcomes with opaque IDs/codes and monotonic timing; throwing sinks cannot alter results. A failed replay outcome mapper leaves a replay receipt with no typed presentation outcome.

The SDK UTF-8 codec adds no external dependency. Boundary tests continue to reject IO, isolate, vendor and Flutter imports. Public-barrel tests cover the candidate in the application package and through the real data adapter. The after-commit SIGKILL fixture covers one explicit boundary, not arbitrary power-loss resilience. Feature benchmarks and actual consumer receipt-schema integration remain pending.

## Collation port candidate (0.1.0-dev.5)

This additive version exposes `CollationPort`, `CollationSession`, `CollationProfile`, `CollationOptions`, `CollationProvenance` and the collation error types through `madar_application.dart`. The durable coordinator's introduced version remains `0.1.0-dev.4`; the earlier capability APIs retain their history above. The collation source and version metadata passed their scoped independent reviews. Each consumer must adopt an exact reviewed source revision with a consistent pin, path lock and resolved package roots; the package version alone does not establish adoption.

Depend on this package for the pure contract and inject a `CollationPort` supplied by an adapter. The application package does not load a library or select an ambient locale. Use `CollationProfile.enUs` (`en-US`) or `CollationProfile.ar` (`ar`); `CollationProfile.parse` rejects unsupported, empty, differently cased and embedded-NUL identifiers. Inspect the adapter's provenance and supported profiles before opening a session.

`openSession(profile, options: ...)` returns a synchronous resource with `compare`, `compareBytes`, `profile`, `options`, `isClosed` and idempotent `close`. `compare` preserves equal collation weights as zero. Consumers retain encounter ordinals when stable ordering matters because Dart's `List.sort` does not guarantee stability. Reuse a session for a batch and close it when finished; the owner of the port calls `dispose`, which closes its child sessions.

```dart
import 'package:madar_application/madar_application.dart';

List<String> orderLabels(CollationPort port, List<String> labels) {
  final session = port.openSession(CollationProfile.enUs);
  try {
    final indexed = labels.indexed.toList();
    indexed.sort((a, b) {
      final order = session.compare(a.$2, b.$2);
      return order != 0 ? order : a.$1.compareTo(b.$1);
    });
    return [for (final entry in indexed) entry.$2];
  } finally {
    session.close();
  }
}
```

The pure options type can describe several configurations. An adapter must reject configurations it has not qualified. The current optional ICU adapter accepts only value-equivalent `CollationOptions.standard`: tertiary strength, case-first off, numeric ordering off, non-ignorable punctuation, normalization on and French collation off. It rejects other options before opening a native session. No lexical or host-OS fallback is permitted.

Malformed UTF-16 strings and malformed UTF-8 bytes fail with `CollationInvalidInputException`. Byte comparison uses explicit lengths, preserving embedded NULs. `CollationUnavailableException` covers an unavailable engine, unsupported profile/options or public adapter loading failure. `CollationClosedException` covers closed sessions and disposed ports. Consumers should use these stable types and keep private text out of diagnostics.

### Optional adapter and qualification limits

[`madar_icu_collation`](../icu_collation/README.md), candidate `0.1.0-dev.1`, implements the port using a caller-managed native library path. Its README contains native setup, public loading examples, disposal and error details. It validates ICU `78.2`, Unicode `17.0` and CLDR `48.0` against the qualified baseline. Tested support is standalone macOS ARM64 only; other targets fail unavailable. No Flutter/mobile adapter or consumer comparator wiring is established by this package. The core remains pure Dart; FFI and native code belong to the optional adapter.

The retained host campaign and package tests establish finite agreement for 1,506 comparison pairs and six source-order cases. They do not prove all-input parity, Electron/upstream data identity, mobile behavior or a supported release. [Corrected host provenance](../../docs/reference/completion-collation-corrected-2.md) and [the package repair review](../../docs/log/2026-11-08-collation-package-independent-recheck.md) preserve exact inputs and limitations.

Run this package's checks with `dart pub get --offline --enforce-lockfile`, `dart analyze` and `dart test`. Optional-adapter tests require their documented retained native/reference artifacts for native qualification; a clean checkout lacks those ignored artifacts and explicitly skips the affected cases. Hosted Linux execution, consumer operation benchmarks and native/mobile delivery remain separate.

### Consumer source checkpoints

At metadata preparation on 2026-11-08, Dakhl_Restaurant declared reviewed commit `d316fd6076375daa3f412889f73eaebfeeb5d4d4` and application `0.1.0-dev.4`; its guard rejected the then-dirty candidate. That is a historical preparation snapshot, not current consumer status. The [metadata preparation log](../../docs/log/2026-11-08-collation-checkpoint-metadata.md) preserves its evidence.

Use each consumer's explicit engine dependency manifest, path lock, resolved package roots and current source-check receipt to establish its adopted revision. A local source checkpoint and deliberate adoption do not establish hosted CI, optional-adapter wiring, mobile qualification or release.
