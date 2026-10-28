# Phase 00 — build evidence

Date:2026-10-28. Status: VERIFYING. Scope: [implementation plan](00-implementation-plan.md). The owner's Orchestrate & Build request authorizes the technical baseline only; no product-screen or reference-design approval is inferred.

## Ownership and isolation

Branch/worktree: `codex/phase00-penpot`, `/Users/eros/.codex/worktrees/phase00-penpot/Dakhl_Restaurant`. Prior authorized design/naming/planning preparation is isolated in commit `614cf0f`; implementation begins after it. Preserved intermediate Penpot extraction files remain unstaged and outside the build's scope.

| Agent | Owned scope |
|---|---|
| Lead | Integration, platform/runtime checks, evidence/tracker/PR; no competing edits in Worker ownership. |
| `phase00_bootstrap` | Root Flutter metadata/SDK pins/pubspec/lock/ignore, Android/iOS/macOS scaffold, blank shell, shell tests and targeted CI. |
| `phase00_contracts` | `lib/capabilities/`, `test/capabilities/`: contracts, isolated synthetic repository and probe ViewModel. |
| `phase00_native` | `lib/platform/`, `assets/fonts/`, `test/platform/`, `integration_test/`: native candidates, offline font and probe harness. |

Workers coordinate interfaces/dependencies directly and do not commit, overwrite each other or self-approve. The bootstrap owner controls dependency resolution. Independent Reviewer `phase00_build_review` reviewed implementation and repaired findings; no remaining actionable implementation defect was reported.

## Initial verified toolchain

`flutter --version` and `flutter doctor -v` on2026-10-28: Flutter3.47.8/revision737ba8f885; Dart3.13.7; macOS27.2/build26B123/ARM64; Xcode27.1/build27A9275; AndroidSDK37.0.0 with platform37.2/build-tools37.0.0 and emulator37.2.12.0; Android Studio bundled JDK25.0.3; CocoaPods1.17.0. Doctor reported no issues and Android licenses already accepted. No licenses or signing credentials were changed in this task.

Connected targets initially: macOS desktop and Chrome only. Existing Android/iOS virtual targets are inspected separately. No physical iPhone/Android installation or signing proof is inferred from toolchain health.

Numeric optimization benchmarks:N/A; no performance target exists. No passing result is prefilled.

Owner target update: the owner replied **“use the simulator in the mac”** on2026-10-28. This run uses iPhone Simulator; physical-device signing/installation is deferred, not treated as a simulator pass. Existing iPhone18Pro/iOS27.0 and Flutter_API_37_2/Android37.2 virtual targets were started without reset or data erasure.

## Observed harness failures and corrections

The first write/read probe reused a fixed specimen, allowing stale data to satisfy a later run. Independent review identified this P2. The harness now requires a fresh validated16–64-character `PHASE00_RUN_NONCE`, writes it into the synthetic message and verifies the exact nonce on read. Missing/malformed/mismatched identities have regression coverage. macOS wrong-nonce rejection and correct-nonce recovery were exercised rather than merely described.

Initial Android/iOS write stages passed but paired read stages failed before nonce validation because the repository had no recovered specimen. Review traced the runner precondition to pinned Flutter test source: `commands/test.dart:308–313` defaults `--uninstall` true and `test/integration_test_device.dart:143–151` uninstalls at teardown. That deleted the development app's test data between stages; it is not a passing restart test or a demonstrated repository defect. The README now uses `--no-uninstall` in both stages and negative/recovery commands. New mobile pairs use fresh nonces and retain only this isolated development app's data. Superseding results are recorded separately; the earlier failures are not relabeled passed.

Native picker review also showed that the underlying Android/iOS provider may materialize/copy a whole selected file before the Dart size check. The4096-byte guarantee now applies only to validated accepted/returned payloads and the Dart reader. Native cache-size bounding and existing external-document rollback remain unverified; these plugins are phase00 synthetic-probe candidates, not certified production import/export infrastructure.

## Verified local results

- Full Flutter unit/widget suite: **46 passed**, including23 core capability/repository/ViewModel tests,5 shell/identity tests and18 native-boundary/probe tests. Test-first red states and behavioral corrections were recorded by the owning Workers.
- Formatting and static analysis: passed on final integrated code.
- Frozen Electron reference suite: **140 passed**, run with its already-installed root-checkout dependencies via `NODE_PATH`; no reference source/dependencies were modified.
- Frozen integrity: independent review verified **179 screenshot hashes,9 source hashes and21 reference assets**, all unchanged.
- Debug builds: macOS ARM64, Android APK and unsigned iOS Simulator build passed. macOS and iPhone Simulator artifacts have development ID `com.eros.dakhlrestaurant.phase00`; Android installed and cold-launched that same isolated ID. Shell screenshots show only the Arabic/Latin development identity, with no product screens.
- Fresh-nonce native write→verified process stop→read passed on macOS, Android emulator and iPhone Simulator. macOS also rejected a wrong nonce, retained data and recovered with the correct nonce. Native paths resolved into the development sandbox, and Arabic PDFs rendered on all three targets. Retained PDF/PNG artifacts visibly show joined Arabic, RTL order and readable Latin numerals.
- macOS native dialogs: open cancel and export cancel visibly returned cancellation; a112-byte synthetic file exported to a new task-owned disposable folder and reopened successfully. Native print chooser was opened and canceled with no printer/job selected. The system share popover was visibly opened then dismissed with Escape; no recipient/service was selected and nothing was sent. Its API's handoff success is not delivery or reliable dismissal evidence.

Current detailed evidence is under `outputs/phase00/`: target-native result JSONs, test/analyze/format logs, native PDF/PNG artifacts, shell/probe captures and the macOS dialog report. Do not confuse the intentionally failing wrong-nonce check with a failed positive gate, or the superseded mobile uninstall attempts with the fresh passing pairs.

## Target capability matrix and limits

| Capability | macOS 27.2 ARM64 | Android 17/API37 ARM64 emulator | iPhone 18 Pro/iOS27.0 Simulator |
|---|---|---|---|
| Debug build/install/launch | Passed | Passed | Passed, unsigned simulator |
| Fresh write / process stop / read | Passed, wrong-nonce rejection/recovery also passed | Passed | Passed |
| Offline Arabic PDF / native raster | Passed, visibly inspected | Passed, visibly inspected | Passed, visibly inspected |
| Native open/export cancellation | Observed | Observed | Pending interactive dialog check |
| New synthetic external export/open | Passed,112 bytes | Pending | Pending |
| Share chooser / print chooser | Observed; dismissed, no send/job | Observed; dismissed, no send/job | Pending interactive dialog check |

The first Android picker assertion ran before its asynchronous native transition. The picker was subsequently observed, canceled, and a fresh open/cancel check passed; export/cancel, PDF, share and print checks then passed. The iOS headless Simulator operated successfully for builds, launch, screenshots and native integration checks, but its interactive Simulator app/window was unavailable through current Mac app discovery. No iOS native-dialog pass is claimed.

Configured minimums: AndroidAPI24, iOS15, macOS12. These minimum OS versions and Intel Mac runtime were not tested. All package versions are pinned in `pubspec.yaml`/`pubspec.lock`; all target runtime checks use the same source and lockfile. Native VoiceOver/TalkBack, denied external writes, external destination rollback, picker process-death recovery, physical printing and provider cache limits remain unverified. Physical iPhone/signing is deferred by the owner's simulator direction. Android release-key custody and Mac/iOS distribution/signing remain pending; no credentials were added.

## Review and delivery

The independent reviewer identified two P2 evidence defects (stale run identity and mobile test-runner uninstall); both were repaired with regression coverage and fresh native pairs. Final code/evidence review reported no remaining actionable implementation defect. Hosted CI results and the scoped draft PR are recorded in the tracker when available. No merge, release, DONE or phase01 start is authorized by local results.

The phase PR targets `codex/project-baseline-upload`, whose baseline already contains the earlier repository organization. This avoids silently presenting those unrelated earlier commits as phase00 implementation. Preparation commit `614cf0f` contains the authorized naming/design prerequisite; the next commit carries the technical implementation.

Documentation checks: selected local links and staged private-file exclusion passed. Source diff whitespace check passed; the unmodified upstream OFL license and raw tool-output logs retain their original whitespace. `./scripts/memory sync` and `check` reported healthy,102 sources, no pending or failed delivery. The configured source registration points at the root checkout, so this does not prove delivery of worktree-only new Markdown; the sanitized current outcome/correction was also ingested directly.
