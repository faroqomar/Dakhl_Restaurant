# C0-12 import byte-boundary preparation

Date: 2026-11-08. Status: test-only source prepared; scoped analysis and two host fixture tests passed. Actual native selection remains pending. This preparation does not close C0-12, C7-07, C7-10, design approval, a phase, or delivery.

## Request and ownership

Prepare structurally valid schema11 UTF-8 files at 20,971,520 bytes and 20,971,521 bytes, then prepare a QA entrypoint for the actual native picker, bounded import, real replacement dialog, cancellation and unchanged-state checks. Use fresh, marked synthetic storage and preserve existing campaigns.

- App ownership: new acceptance tests, fixture generation, account-location composition, state observations and QA entrypoint. No production source, existing C0/C1 helper, dependency, pin, configuration or Git mutation belongs to this task.
- Madar runtime/API: N/A. The app uses the existing public file/workspace capabilities and default `NativeFileTransfer` at the unchanged 20 MiB cap. Observed engine HEAD: `ac8b4edc2c915ed22c0991685c33967b3360e7fa`; app HEAD: `cc91fae438101fce7ff4729e12bf3c2b64dacd70`. The campaign must bind its eventual exact source and runtime identities independently.
- The native campaign controller retains exclusive Flutter/pub/build/test-runner and Device ownership during preparation. This worker ran only source inspection, editing, formatting, scoped standalone Dart analysis and storage checks.

## Source-derived fixture

The current `LegacyAccountCodec` checks incoming and canonical encoded bytes at 20 MiB. Its transaction rules permit 100,000 entries, unique ASCII identifiers, positive amounts, `deposit`/`withdrawal`, and the recognized singular `note` field with a 2,000-character maximum. The fixture uses `codec.empty()` and 10,000 deposits, date `2026-11-08`, amount `1`, fixed ASCII IDs and ISO `createdAt`.

The generator first canonicalizes empty notes and measures base byte count B. It requires `0 <= 20971520 - B <= 10000 * 2000`, fills that many ASCII `n` characters across the recognized notes, and requires exact size and codec decode/re-encode byte identity. The oversized sibling appends one LF byte. JSON parsing therefore retains the same map; the separate incoming-byte check rejects L+1. No unknown-field padding, changed limit or schema12 activation occurs.

The retained tests check exact size, canonical identity, recognized fields, IDs, per-note capacity and total note bytes. A separate test parses the oversized sibling, re-encodes the same canonical L-byte document, and expects `payload_too_large` when decoding its L+1 incoming bytes. Both passed in the later authorized host window recorded below.

## QA path and evidence

Entrypoint: `integration_test/support/c0_import_boundary_qa_main.dart`. Required defines: `C0_BOUNDARY_FIXTURE` with a fresh lowercase v4 UUID and `C0_BOUNDARY_STAGE` with one of `cancel-open`, `exact-cancel`, `oversize`, `exact-confirm`. Each UUID permits one selection and refuses reuse. Run only after independent source review and the campaign's reviewed workflow preflight.

The entrypoint uses an owned namespace beneath the canonical application-support path. It creates an intent, marker, small saved target, previous copy, source archive and saved workspace. It never calls the production account-location factory. The real `AccountsSurface` owns file selection and the real Arabic replacement dialog. An observation wrapper delegates open to default `NativeFileTransfer` without an injected picker callback. The wrapper disables export in this import-only QA surface.

Use **Stage owned files** only when needed. It writes regular files under the printed `QA_ROOT/picker-inputs` path and compares every byte against the canonical input. The host campaign must capture SHA256 of those exact files before selecting them. The receipt's FNV1a32 value is a noncryptographic diagnostic; acceptance uses complete byte comparison. The harness does not use `NativeFileTransfer.save` to stage L+1 because that adapter also caps outgoing bytes at L.

On macOS, the host can navigate the actual picker to the printed owned path. Mobile provider access remains unverified. If existing access cannot expose the owned files to the real provider, retain a blocked result. This task adds no permission, Info.plist, provider or app feature change. Providers may materialize full files before Dart receives them; neither this harness nor a passing Dart limit proves native memory/disk bounds.

After the host selects/dismisses through the native UI and resolves the real dialog, use **Verify settled case**:

- `cancel-open`: require native cancellation, saved state, no pending import or confirmation, and unchanged persisted authority.
- `exact-cancel`: require the exact incoming bytes, `importReady`, one observed real replacement dialog, cancellation and unchanged authority.
- `oversize`: require adapter `input_too_large`, no `importReady`, pending import or replacement dialog, and unchanged authority. The regular import-error dialog is a separate observation.
- `exact-confirm`: after explicit operator confirmation, require canonical exact payload, changed replacement fence, empty workspace, previous-copy equality to the complete baseline snapshot and an exact archived imported source.

The baseline compares persisted payload, store/generation fence, revision, write token, persisted/view workspace, previous-copy identity/snapshot, pointer/previous bytes and baseline source/identity archive bytes. Source files also retain complete byte equality. The harness rejects an older pending import before selection because the controller retains older selections on picker failure by design.

Capture actual native chooser/confirmation evidence and source/binary/file hashes outside the app before cleanup. **Cleanup owned fixture** closes the account owner, validates markers, canonical root and absence of symlink entries, retains compact event receipts in the namespace, removes the owned root and retains the intent tombstone. It refuses cleanup during an in-flight native/account operation. The campaign controller must also complete its measured storage review.

## Preparation audit

| UTC | Actor / batch | Result and timing | Cause / avoidability / next automation |
| --- | --- | --- | --- |
| 07:47:25 | Worker intake and storage baseline | Confirmed assigned source paths absent. Free 95,878,712 KiB; `.git` 18,430,636 KiB; `outputs` 7,396,232 KiB. | Existing repository size; no attribution to this task. Reuse one compact baseline receipt. |
| 07:47–07:50 | Worker rule/source reads and separate Hindsight recalls | Both `daftar` and `madar` recalls succeeded. Current codec/adapter/controller sources govern implementation. Several combined source/recall outputs exceeded useful response budgets and truncated. | Avoidable output overhead; retrieve projected recall fields and smaller source ranges in future. Exact sub-batch UTC/duration unavailable. |
| 07:50–07:54 | Worker test-first source authoring and harness composition | Added only the assigned three Dart files. Full fixture generation and native execution deferred under controller ownership. | Dependency on exclusive runner ownership; no waiting poll loop. |
| Before 07:54:52 | Worker format and scoped standalone Dart analysis, first attempt | Formatter passed. Analyzer reported seven style infos: unnecessary typed-data import and missing block braces. Corrected them in owned files. | Avoidable authoring/style defects; final scoped check acceptance is zero issues. Tool batch elapsed 4.4 s. |
| Before 07:54:52 | Worker second format/analysis batch | Formatter: 0 changes. Analyzer: No issues found. | Required recheck after edits; batch elapsed 4.0 s. No Flutter test result follows. |
| 07:54:52 | Worker source/storage inspection | Free 95,335,536 KiB; `.git` unchanged at 18,430,636 KiB. No top-level Git object temporary directories reported. Owned outputs 4 KiB; new Dart files 36 KiB allocated. A nonmatching zsh source-path glob aborted one optional search; current engine path identified in the following bounded file search. | Avoidable shell-glob error. Use known explicit paths or `rg --files`. Concurrent campaign storage accounts for changes outside this worker's bounded outputs; producer not established here. |

Exact token/cost totals and per-read durations are unknown. No persistent campaign timer was started because this task prepares sources and does not start a native/benchmark campaign. The controller owns that timer and the phase execution journal.

## Storage closeout

At 07:56:32 UTC, free space was 95,220,884 KiB, a decrease of 657,828 KiB from intake across the shared workspace/device campaign. The measured project total was 29,175,416 KiB including `.git` 18,430,636 KiB, `build` 2,007,632 KiB, `.dart_tool` 810,892 KiB and `outputs` 7,396,256 KiB. Only Git and outputs have comparable intake measurements here: Git was unchanged; outputs grew 24 KiB. Initial total/build/tool-cache sizes were not measured, so their growth is unknown.

No top-level `.git/objects/tmp_objdir-*` store appeared. No process other than the inspection command referenced this task's fixture/artifact names. This worker generated no boundary files, native binaries, exports, screenshots, archives or account databases. The new Dart sources, log and compact review/baseline receipts are the canonical retained artifacts; later runtime fixture pairs remain reproducible and must be removed through the marked cleanup path after evidence capture. No confirmed disposable task artifact required removal; reclaimed space: 0 bytes. The shared free-space decrease is below 2 GiB and free space exceeds 10 GiB. This observation does not identify the concurrent producer or establish a fixed leak.

The compact [review manifest](../../outputs/completion-review/import-byte-boundary/review-manifest.json) binds this preparation's sources, contracts, checks and limits. It records the final task-owned artifact size. Parent retains ownership of the full campaign's storage diagnosis and eventual cleanup evidence.

## Verification and remaining work

Scoped standalone Dart analysis passed for the three new Dart files. Formatter found zero changes after fixes. The initial review manifest preserves preparation-time hashes and limits. Two host acceptance tests later passed; native build, picker selection, device operation and production account mutation remain unexecuted by this worker.

Next: independent source review; resolve findings; run reviewed workflow preflight; stage and hash real files; execute supported native cases with actual dialog evidence; retain blocked provider paths; record receipts and measured cleanup. Parent owns project memory sync/check and tracker reconciliation. This worker makes no phase closeout or approval claim.

## Authorized host fixture test window

The controller released the Flutter host runner after the native C0 and financial host work ended. This worker refreshed the scoped `daftar` recall and ran exactly `flutter test --no-pub test/accounts/import_boundary_fixture_test.dart`. The runner reported both tests passed, with final display `00:04 +2: All tests passed!`, exit code 0. The tool's initial batch included recall and yielded after 10.0 s; the final poll returned completion. Precise runner start/end UTC is unknown. No source correction or second test attempt was needed.

The worker sent **WINDOW RELEASE** to the controller immediately after observing the runner exit, before documentation, hash or storage work. The two passing assertions cover the 20,971,520-byte recognized canonical schema11 fixture and the 20,971,521-byte LF sibling's unchanged parsed map plus incoming-byte rejection. They establish codec fixture behavior in a host test process. They do not establish actual native selection, controller/dialog behavior or native resource limits. No 40 MiB fixture pair was written to disk.

At 08:11:49 UTC, all three Dart SHA256 values still matched the initial review manifest. Storage was 92,940,164 KiB free, `.git` 18,430,636 KiB, `build` 1,993,692 KiB, `.dart_tool` 789,648 KiB and owned output directory 12 KiB allocated. No top-level temporary Git object directories appeared. Compared with 07:56:32, `.git` was unchanged and build/tool caches decreased; shared free space decreased by 2,280,720 KiB. The controller reported an ongoing OS swap investigation, which this worker has not independently verified. That unexplained system decrease requires the controller's diagnosis before another sustained storage-producing batch. This worker produced only compact receipts/log updates after releasing the runner; it removed no shared caches or files. Reclaimed task-owned storage: 0 bytes. Retained source/tests and compact evidence remain canonical; no test-owned fixture files or teardown residue exist.

The successor [host-tested manifest](../../outputs/completion-review/import-byte-boundary/review-manifest-host-tested.json) preserves the initial manifest by path/hash, records actual host results and binds the updated log. Parent retains source review, native preflight/execution and memory sync/check ownership.
