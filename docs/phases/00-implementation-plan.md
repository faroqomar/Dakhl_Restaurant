# Phase 00 — implementation plan

Date: 2026-10-28. Prepared by read-only Planner `phase00_plan`; recorded by the Lead. **Planning only; implementation not authorized by this record.** Scope: [phase 00](../planning/flutter-rebuild/phases/00.md). Dependencies: none. [Tracker](../../PHASES.md).

The request left `{{PHASE}}` unset; phase 00 is inferred from the active tracker/chat. Its status remains **DESIGN**. The technical blank shell has Design: N/A, but the owner-added [Penpot prerequisite](00-penpot-reference-recreation.md) still needs explicit owner approval. This request does not establish that approval.

## Isolation and boundaries

Reuse the existing dedicated branch `codex/phase00-penpot`, worktree `/Users/eros/.codex/worktrees/phase00-penpot/Dakhl_Restaurant`, based on `ecf692b49672fa9e1d64a983f89ba7ccf16cf0fe`. The root checkout remains separately on `codex/project-baseline-upload`. Existing design/naming/documentation changes are preserved; identify and separate those prerequisite changes before staging implementation or preparing its PR. No reset, unrelated staging or duplicate worktree is required for this planning step.

Deliver baseline/toolchain/platform capability setup only. Preserve `electron-reference/`, restaurant records, legacy storage identities and all frozen captures. Do not implement product navigation, sales, expenses, settings, account migration, production persistence or cloud services. The three screenshot designs are reference prerequisites, not phase 00 product-screen deliverables.

## Implementation sequence and acceptance

| Work | Required result |
|---|---|
| Freeze the specification | Verify screenshot/asset/source manifests and synthetic fixtures; confirm every current feature has an owning phase in [feature coverage](../planning/flutter-rebuild/feature-coverage.md). Retain all 179 captures; do not recapture to hide differences. |
| Verify and pin the platform matrix | Verify Flutter/Dart, Xcode, Android SDK/JDK and CocoaPods compatibility; record exact toolchain/dependency versions, minimum OS versions, Mac architectures and actual test targets. Settle iPhone installation/signing, Android signing custody and Mac distribution; keep credentials outside Git. |
| Create the root Flutter workspace | Development-only app identifiers and data locations cannot resolve to legacy production data. Launch a blank, offline Arabic RTL shell on macOS, Android and iPhone. Product components/navigation remain phase 01 scope. |
| Define narrow service boundaries | Views/view models render/coordinate; platform services provide file selection, isolated file IO, PDF, sharing, printing and lifecycle. Durable writes use a repository boundary. Capability probes remain separate from later production-account persistence and accounting. |
| Prove capabilities before selecting packages | Use synthetic records to prove file import/export, local write/reopen, Arabic PDF output/share and system print entry points on all three platforms. Record font availability/licensing; Penpot outlines do not prove a redistributable Flutter font. Select packages from observed platform support. |
| Capture delivery evidence | Three launch records identify device/model, OS, app/build identifier, toolchain, result and captures. An actual iPhone installation is required; simulator/unsigned builds do not satisfy it. Record native cancellation/failure results separately from fake-service tests. |
| Review and deliver | Document package rationale, capability matrix, unresolved limits and applicable rollback. Obtain independent implementation review/re-verification, scoped PR and CI evidence. Owner merge approval, merged revision and applicable release evidence are required for DONE; phase 01 does not start automatically. |

## Realistic tests

Use the project-local [Flutter testing skill](../../.agents/skills/flutter-testing/SKILL.md); write meaningful tests before behavior changes.

| Layer | Scenarios and expected evidence |
|---|---|
| Unit/service contracts | Canceled selection differs from failure; malformed synthetic input is rejected; denied/failed write preserves existing synthetic output; retry succeeds without duplicate writes. |
| Widget | Arabic locale/RTL shell, readable Arabic shaping and Latin numerals; labeled/reachable capability actions with focus where controls exist; no product routes or unrelated UI. |
| Device/integration | Write synthetic bytes, terminate/relaunch and read them back; native import/export cancel; PDF generation/share handoff; print chooser entry/cancel; failures preserve source data and allow recovery. |
| Isolation | Verify development identifiers and temporary data root differ from the installed legacy app without opening restaurant accounts. |
| Evidence integrity | Frozen reference hashes, complete feature ownership, font/license record, selected versions, platform capability matrix and all three launch records. |

Cover pending/success/failure/cancel/retry states for capability operations. Product empty/populated/validation states belong to their owning phases. Native dialogs, safe areas, keyboards and runtime accessibility require actual platform evidence; static designs and widget fakes cannot certify them. Compare captures only at equivalent state, logical size and scale; do not treat a blank shell as an implementation of the three product screenshots.

**Numeric benchmarks: N/A.** Phase00 contains no optimization requirement or numeric performance target. Record execution conditions/results; do not invent latency targets or visual-similarity thresholds. Establish a measured baseline and explicit target before any later optimization.

## Necessary CI and observed readiness

Read-only inspection on 2026-10-28 found no root `pubspec.yaml`, `lib/`, `test/`, `integration_test/`, `analysis_options.yaml` or `.fvmrc`, and no local GitHub/GitLab/Codemagic/Bitrise/Azure/Jenkins pipeline configuration.

Remote inspection of `faroqomar/Dakhl_Restaurant` returned zero Actions workflows and zero repository rulesets. The `main` required-status-check endpoint returned 404, “Branch not protected.” These are configuration observations, not CI passes or a request to change protection settings.

Installed cache metadata identifies Flutter 3.47.8 / Dart 3.13.7; `xcodebuild -version` reported Xcode 27.1 / build 27A9275. Flutter/Dart, Xcode, Java and CocoaPods executables are discoverable; `adb` is absent from PATH. SDK metadata/executable discovery does not prove Android SDK/JDK readiness, target access, signing, licenses or a successful build.

Once implementation is authorized, add targeted PR checks using verified pinned versions: formatting, static analysis, unit/widget tests and Android/macOS/iOS build validation. Distinguish unsigned/simulator checks from signed physical-device installation. Keep `npm --prefix electron-reference test` as a separate reference regression gate, never proof of Flutter acceptance. Recheck remote mandatory checks before preparing the implementation PR.

## References and remaining decisions

Read [AGENTS.md](../../AGENTS.md), [PLANS.md](../../PLANS.md), [kickoff evidence](00-baseline-kickoff.md), [design contract](../planning/flutter-rebuild/design-system.md), [capture guide](../planning/flutter-rebuild/capture-guide.md), [feature coverage](../planning/flutter-rebuild/feature-coverage.md), [accounting parity](../planning/flutter-rebuild/accounting-parity.md) and [current Penpot review](00-penpot-ux-review.md).

Pending: owner Penpot design approval; verified toolchain/minimum-OS/Mac-architecture matrix; Android SDK/JDK and actual Android/iPhone access; signing/distribution choices; Arabic font/asset licenses; capability-supported package selection. Record unavailable evidence as pending, never passed.

No files were edited by the Planner. No application launch, account access, package installation, implementation, tests/builds, design approval, merge or phase completion occurred in this planning task.
