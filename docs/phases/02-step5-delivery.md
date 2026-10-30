# Phase02 — Step5 draft pull-request delivery

Date: 2026-10-30. **DRAFT / NOT MERGE-READY.** The engine draft is published, but app source publication is access-blocked. The local app packet is reviewable; no app PR or hosted app-CI result exists. This is not merge approval or phase completion. The Android preservation failure is a blocking incident: Flutter automatically uninstalled/reinstalled after a signing mismatch; prior installed-app data retention is unverified. The raw Android WRITE success is excluded. Android Open/Save cancellation and current iOS verification remain unavailable. No new target installation, restore, reset, merge, tag, release or phase is authorized.

## Pull requests and dependencies

- **App PR: unavailable; publication access-blocked.** The attempted local committed candidate is `0b75862a87aad3ae044ed0e3df4c6e3acfd7cd0b` on `codex/phase02-review`, consisting of tested app5a11 plus documentation/evidence. GitHub rejected its push because the active OAuth credential lacks the workflow scope needed to update `.github/workflows/flutter.yml`. No app PR was created; no app hosted checks ran. Current follow-up documentation remains local until its separate commit is recorded.
- Engine draft PR: [Madar_Engine#6](https://github.com/faroqomar/Madar_Engine/pull/6), initial publication head `a731885a8875cdda78197d8df355d18a739e48e8`. It preserves the reviewed runtime and separate host revisions as ancestors with unchanged relevant trees. The app depends on runtime a6, not the documentation publication HEAD.
- Engine hosted checks are ongoing at the initial published head as last observed for this handoff. The app has no hosted candidate/checks because publication was rejected. No current hosted check is labelled passed here; local tests do not substitute for hosted CI.

The existing strict SSH trust check also failed, and no usable agent/default SSH identity or configuration was available. No credential, trust setting, GitHub policy or permission was changed; required workflow/CI changes were not stripped. No further push retry is warranted until actual access changes. The rejection does not alter reviewed source, runtime pin or local test evidence.

| Role | Actual tested revision | Ownership and continuity |
| --- | --- | --- |
| App | `5a11c66dbf665972b17b545c105eac74c17bfeeb` | Restaurant schema/history validation, legacy timestamps, ViewModels/UI/composition, safeguards and real workflow measurement scenarios. Publication adds documentation/evidence only; source continuity must be checked before pushing. |
| Runtime engine | `a6a8ebdd8f68f5d603d56dc3f3d0f13cc3e38294` | Sole shared opaque fenced document/workspace ports and optional persistence; exact app pin in `engine-dependency.json`. No engine implementation copied into the app. |
| Separate measurement host | `63bbed8303bf8561084c5f82a3ebd52e2bf9e95d` | Generic protocol/resource collection. This is the actual host used in the final cohort, independent of the runtime pin. |

App public contract remains the reviewed Madar packages, consumed once at the exact immutable revision. Offline single-restaurant, Arabic RTL, IQD and historical-record protections remain. No new financial/recovery policy, cloud/auth/multitenancy or whole-app redesign is selected.

## Verification actually available

- Current Step4 app5a11/runtimea6: **529 non-golden tests passed**, whole-app analysis had no issues, enforced source/contract check passed. [Exact receipt](../../outputs/phase02/step4-bootstrap-current-checks.json) retains timestamps and actual durations; raw command logs remain local.
- Runtime engine a6: **132 data tests/analyzer passed**; independent original-prefix reproduction,15 protection cases and2 real SIGKILL checks. Relevant unchanged domain/application/native-adapter evidence is reused at its actual earlier source; no fresh rerun is implied. Engine-owned details belong in its linked review.
- Final local Mac performance: **18 distinct operation/profile cases ×20 =360 samples**, one attempt each, all cleanup confirmed. Raw20-value arrays and aggregate CPU/RSS are in the [machine index](../../outputs/phase02/step4-final-performance/summary.json) and [18-case table](02-step4-performance.md). Independent review checked805 artifact/statistical assertions and108 hashes with zero discrepancies. This is a descriptive source-specific baseline, with no agreed numeric budget, optimization delta or reliability certification. Earlier failed/partial source epochs remain separate.
- Mac native recovery matrix: accepted six-stage component evidence at app62/runtimea6, with5 positive process IDs and intended wrong-nonce refusal. Later benchmark-only changes do not turn it into a current full native run. Current Android is blocked and iOS unverified.
- Earlier five goldens, frozen reference integrity, reference tests and engine/host checks are reused only under their documented source continuity. Counts overlap and are not summed as unique tests. Live screen-reader verification is owner-excluded, never passed; existing semantics, focus and keyboard checks still apply.

[Independent current review and remaining gates](02-step4-review.md), [confirmed Android incident](../log/2026-10-30-phase02-android-preservation-incident.md), [independent incident review](../../outputs/phase02/step4-native-evidence-review.md), [independent metrics review](../../outputs/phase02/step4-final-performance-independent-review.md).

## Version and distribution

The app candidate remains **unreleased `0.0.0+1`**. No prior approved delivered binary/version record has been established for this Step5 package, and no release or new binary candidate is prepared here. This documentation/evidence packaging retains the tested version to preserve artifact comparability. A future delivered binary requires the documented version preparation, monotonic build number, source/review/rollback evidence and explicit approval. Preview package versions remain identified by exact Git revision. The pinned V8 adaptation retains its full BSD source notice; future binary redistribution must carry that notice in accompanying materials.

## Review packet and limits

The [evidence manifest](02-step5-evidence-manifest.json) records every copied file's original and publication SHA-256, distinguishes publication-only link/status wording from byte-identical metrics and designated review reports, and lists excluded local-only references. Final measurement JSON and its captured summary remain byte-identical. The packet includes selected English documentation, independent review summaries, safe test/source receipts, synthetic fixture-size summaries and preserved native Penpot previews. The [design gallery](../../outputs/penpot/phase02/review-gallery.md) is historical design evidence, not runtime verification or new owner approval.

This selective packet adds no raw command logs, current Phase02 live execution journal, account payloads, signing stores/private keys, private task configuration or full Penpot page payloads. Previously tracked historical journals remain in repository ancestry. Local-only paths/hashes are explicitly identified instead of broken public links. Individual native timing-event and periodic resource traces were not retained and cannot be reconstructed; raw latency arrays and source guards support the bounded baseline. No data restoration, physical signing/device migration, power-loss certification or production rollback result is claimed.

## Approval boundary

No owner merge approval is requested while required checks or the Android preservation/iOS gates are unresolved. Draft PR publication does not make the phase ready or DONE. Engine PR#6 is available; app PR creation remains blocked by the actual credential rejection. The Lead records any final local documentation head, remote engine-CI outcome and independent packaging review before the Step5 handoff. A new authentication attempt or access change is not inferred from documentation. Remaining non-blocking method limits are recorded alongside the blocking incident, never substituted for it.
