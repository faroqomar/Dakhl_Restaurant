# Project Phase Tracker

Source of phase definitions: [PLANS.md](PLANS.md). Rules: [AGENTS.md](AGENTS.md). Adopted 2026-10-28 from the owner’s supplied tracker template.

The standing joint workflow in [PROMPTS.md](PROMPTS.md) applies to every phase and linked engine work item. Each project keeps its own status/evidence; an unaffected side records N/A with a reason. This workflow update does not advance any phase.

## Statuses

TODO → DESIGN → PLANNING → BUILDING → REVIEW → VERIFYING → PR → DONE

Use BLOCKED when progress cannot continue and record the reason and required action. Skip inapplicable steps and record N/A. Branch, PR, design approval and verification are evidence fields, not assumed from status labels.

## Phases

| Phase | Name | Status | Branch | PR |
| --- | --- | --- | --- | --- |
| 00 | [Baseline and delivery setup](docs/planning/flutter-rebuild/phases/00.md) | BLOCKED | codex/phase00-engine-split | [Merged PR2](https://github.com/faroqomar/Dakhl_Restaurant/pull/2) |
| 01 | [Design system, navigation and interaction shell](docs/planning/flutter-rebuild/phases/01.md) | DESIGN | codex/phase01-scope (preparation only) | — |
| 02 | [Local accounts, validation and safe persistence](docs/planning/flutter-rebuild/phases/02.md) | TODO | — | — |
| 03 | [Sellable products and inventory](docs/planning/flutter-rebuild/phases/03.md) | TODO | — | — |
| 04 | [Cash sales, saved receipt, drafts and held orders](docs/planning/flutter-rebuild/phases/04.md) | TODO | — | — |
| 05 | [Sales history, returns and voids](docs/planning/flutter-rebuild/phases/05.md) | TODO | — | — |
| 06 | [Daily accounting, expense categories and cashbox](docs/planning/flutter-rebuild/phases/06.md) | TODO | — | — |
| 07 | [Suppliers, debts, materials and prices](docs/planning/flutter-rebuild/phases/07.md) | TODO | — | — |
| 08 | [Purchase invoices, analysis and supplier payments](docs/planning/flutter-rebuild/phases/08.md) | TODO | — | — |
| 09 | [Settings, backups, import and recovery](docs/planning/flutter-rebuild/phases/09.md) | TODO | — | — |
| 10 | [Statements, day review, PDF reports and printing](docs/planning/flutter-rebuild/phases/10.md) | TODO | — | — |
| 11 | [Complete MVP verification, migration rehearsal and release](docs/planning/flutter-rebuild/phases/11.md) | TODO | — | — |

## Per-Phase Record

### Phase 00

- **Name:** Baseline and delivery setup
- **Status:** Technical prerequisite VERIFIED — native iPhone acceptance independently closed and Penpot design approved on 2026-10-29. Evidence integration/overall DONE remain pending. The exact owner-approved source is merged; all six premerge Actions checks passed. Completion remains unestablished. [Step6 record](docs/phases/00-step6-merge.md).
- **Dependencies:** None
- **Design approval:** N/A for the original technical shell. The owner added a design prerequisite: recreate only `desktop-sales.png`, `desktop-expenses.png` and `desktop-settings-data.png`, with matching wireframes, in Penpot. Validation and approval evidence: [Penpot record](docs/phases/00-penpot-reference-recreation.md). The superseded blank-shell boards are not the approval artifact. Owner explicitly approved the existing Phase 00 set on 2026-10-29.
- **Branch / Worktree:** approved implementation branch `codex/phase00-engine-split` and original `codex/phase00-penpot` preserved; current documentation review branch `codex/phase00-merge-record` at `/Users/eros/.codex/worktrees/phase00-penpot/Dakhl_Restaurant`. Preparation baseline `614cf0f` separates prior design/naming documentation from implementation; original base `ecf692b`. Root-checkout work preserved.
- **Assigned agents:** Lead (integration, device evidence, tracker/PR); Workers `phase00_bootstrap` (root/native scaffold, blank shell and CI), `phase00_contracts` (capability contracts/repository/ViewModel), `phase00_native` (native adapters, offline font and integration harness). Prior Planner/UX evidence retained; independent Reviewer `phase00_build_review` completed implementation review.
- **Implementation plan:** [Phase scope](docs/planning/flutter-rebuild/phases/00.md); [current read-only implementation plan](docs/phases/00-implementation-plan.md) prepared 2026-10-28; [initial kickoff](docs/phases/00-baseline-kickoff.md). Existing phase00 isolation reused; no implementation or design approval inferred.
- **Automated tests:** current Step4:48 app,27 engine adapter,24 consumer source-gate and140 reference tests passed;179/9/21 frozen hashes matched. Android native export/open newly passed. Prior baseline:46 Flutter unit/widget tests passed; native fresh-nonce write/stop/read passed on macOS, Android emulator and iPhone Simulator, with macOS wrong-nonce rejection/recovery. 140 preserved Electron reference tests passed separately; 179 screenshot/9 source/21 asset hashes unchanged. [Build evidence](docs/phases/00-build-evidence.md).
- **CI:** All six Actions checks passed on approved app `00baa5731776ecb7b0fe91911892cd5006d421f4` and engine `784b139753a0e2a07d3f97eedb326debfe068395`. Main reference run40717097493 passed; Flutter run40717097492 is tracked in the Step6 record. Initial private-source failure remains historical; skipped CodeRabbit is not a pass.
- **Engine separation:** Owner directed parallel Madar/app development on2026-10-28. Shared result/ports and file/PDF handoff adapters moved to Madar packages; app consumes the recorded engine commit. Extraction branch `codex/phase00-engine-split`; original phase00 branch preserved. [Boundary0018](docs/decisions/0018-madar-engine-boundary.md). Final48 app tests/27 engine adapter tests and3 app builds passed after integration; private engine source is published for draft review and read-only CI access is configured; required hosted results remain evidence-based.
- **Benchmarks:** N/A — no optimization requirement.
- **Independent review:** Step4 `phase00_code_audit` found no actionable runtime defect; `phase00_delivery_audit` independently closed the repaired source-resolution P2 and retained missing-evidence gates. [Report](docs/phases/00-step4-review.md). Earlier `phase00_build_review` independently reviewed implementation and final local evidence; stale-data nonce and mobile-runner uninstall findings repaired/re-verified, no remaining actionable implementation defect. Native boundary limits remain documented. Prior UX reference review is separate; no pixel identity/design approval inferred.
- **Staging / Rollback:** Development-only ID/data sandbox verified; no production account migration or release. Rollback is to stop the isolated development build; preserved Electron/data remain untouched. Distribution/signing beyond debug/simulator is pending.
- **PR:** [Engine PR1](https://github.com/faroqomar/Madar_Engine/pull/1), separately approved [snapshot PR1](https://github.com/faroqomar/Dakhl_Restaurant/pull/1), then [app PR2](https://github.com/faroqomar/Dakhl_Restaurant/pull/2) merged in dependency order. App merge `c7f4a4202fb248e614c536ecbed67d8864f24685` preserves the exact approved source tree and immutable engine pin. Retargeted phase diff was byte-identical. [Step6 evidence](docs/phases/00-step6-merge.md).
- **User approval:** Owner invoked Step6 for presented engine `784b139` / app `00baa57`, then separately approved snapshot `ecf692b` and proceeding. Exact approved heads were merged without source changes. This does not approve the Penpot design, waive missing native evidence, authorize deployment or establish DONE. Later documentation revisions require separate approval.
- **Decisions / Lessons:** [0015 — canonical Penpot workspace](docs/decisions/0015-penpot-design-workspace.md). Reuse this page for future design requests. Outlined lettering preserves font appearance; original text strings must remain available separately. No whole-screen raster substitution in editable artwork.
- **Evidence:** [Technical build/tests/platform evidence](docs/phases/00-build-evidence.md); [development baseline decision](docs/decisions/0017-phase00-development-baseline.md); [Penpot recreation](docs/phases/00-penpot-reference-recreation.md); [kickoff](docs/phases/00-baseline-kickoff.md); [historical Figma blocker](docs/phases/00-figma-reference-preparation.md); [task log](docs/log/2026-10-28-phase-00-kickoff.md).
- **Completed:** —

### Phase 01

- **Name:** Design system, navigation and interaction shell
- **Status:** VERIFYING — approved bounded implementation built locally; native dependency independently closed. Local checks pass; remaining native verification and hosted delivery gates are explicit in build evidence.
- **Dependencies:** 00
- **Design approval:** Approved — owner explicitly approved the [existing Phase 01 design/wireframe set and listed differences](docs/phases/01-penpot-design-review.md) on 2026-10-29.
- **Branch / Worktree:** implementation `codex/phase01-build`, `/Users/eros/.codex/worktrees/phase01-build-app/Dakhl_Restaurant`, clean base `f73b14b5a7cc6d2421f670938b2435af137ddb0f`; original dirty scope/design worktrees preserved, no PR/publication.
- **Assigned agents:** Lead (composition/isolation/evidence); read-only Planner `phase01_scope`; engine Worker `phase01_engine_build`; shell Worker `phase01_shell_build`; UI/native Worker `phase01_capture`; independent code Reviewer `phase01_docs_review`; independent UX `phase01_references`. Each owns its project/layer; no copied engine code.
- **Implementation plan:** [Bounded Step 2 proposal](docs/phases/01-implementation-plan.md), including read-only Planner advice and owner-confirmed full-restart route/shortcut restoration; approved Step 3 request and explicit designs recorded on 2026-10-29; technical dependency closed. Historical proposed/blocked sections retain provenance.
- **Automated tests:** PASS locally — 134 app tests (including five controlled goldens), app analysis/format; 24 engine-source checker regressions and resolved-source check. Real different-process route/six-slot restoration passed on macOS/Android/iPhone; evidence records exact compiled snapshots and native limits.
- **CI:** Configured — existing quality/three-target gates preserved, CAP-01 tests added, golden comparisons on macOS. Local checks/builds recorded separately; hosted CI not run, new engine pin is local until publication is authorized.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Plan review closed. Engine code/API/tests independently reviewed; app code review closed three P2s (modal retry, uncertain-commit overlap, visible Undo); UX review closed three P2s (desktop hints, menu identity/icons, inclusive760px boundary). Final focused reconciliation verified74/74 source hashes and honest reuse; native images independently reviewed. Owner manually confirmed Mac ⌘3/⌘K both work. Native mobile back/gesture and native accessibility traversal remain open.
- **Staging / Rollback:** Isolated development data only. Real rollback/future-format preservation and fresh-process checks pass; stop development build to roll back UI, retain dedicated preferences DB. No production migration/deployment.
- **PR:** —
- **User approval:** Step 3 authorizes the presented plan/build scope; existing Phase 00/01 designs and listed differences explicitly approved on 2026-10-29. Phase 00 native acceptance is not waived; no exact revision merge or deployment approval.
- **Decisions / Lessons:** [Shell contract/setup](docs/reference/phase01-shell-contract.md); [prevention catalogue](docs/how-to/repeated-problems.md). Device Hub is the verified native app; absence of old Simulator.app is not an access blocker.
- **Evidence:** [Current build results and remaining gates](docs/phases/01-build-evidence.md); [Step 1 readiness](docs/phases/01-scope-readiness.md); [Step 1.5 design review](docs/phases/01-penpot-design-review.md); [design task log](docs/log/2026-10-29-phase01-penpot-design.md). [Step 2 plan/log](docs/log/2026-10-29-phase01-implementation-plan.md). [Step 3 approval and native preflight](docs/log/2026-10-29-phase01-step3-preflight.md). Native artifact evidence is separate from runtime verification.
- **Engine/app contract:** App owns presentation, route/six-slot payload and safeguards. Implemented Madar CAP-01 owns local-only snapshot storage/adapter; owner-confirmed restart requirement supersedes earlier engine N/A assessment. Independently reviewed local CAP-01 pin `6d4ae39f35b005dfa1123a82c6df316901e1e1e4` now consumed; exact resolved-source check passed, no publication/merge.
- **Completed:** —

### Phase 02

- **Name:** Local accounts, validation and safe persistence
- **Status:** TODO
- **Dependencies:** 00, 01
- **Design approval:** N/A — non-UI setup/data/release scope; reassess if UI changes are introduced.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/02.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 02 execution evidence yet.
- **Completed:** —

### Phase 03

- **Name:** Sellable products and inventory
- **Status:** TODO
- **Dependencies:** 01, 02
- **Design approval:** Pending — validate the current reference in Penpot and record user approval before UI implementation.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/03.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 03 execution evidence yet.
- **Completed:** —

### Phase 04

- **Name:** Cash sales, saved receipt, drafts and held orders
- **Status:** TODO
- **Dependencies:** 01, 02, 03
- **Design approval:** Pending — validate the current reference in Penpot and record user approval before UI implementation.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/04.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 04 execution evidence yet.
- **Completed:** —

### Phase 05

- **Name:** Sales history, returns and voids
- **Status:** TODO
- **Dependencies:** 02, 03, 04
- **Design approval:** Pending — validate the current reference in Penpot and record user approval before UI implementation.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/05.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 05 execution evidence yet.
- **Completed:** —

### Phase 06

- **Name:** Daily accounting, expense categories and cashbox
- **Status:** TODO
- **Dependencies:** 01, 02, 05
- **Design approval:** Pending — validate the current reference in Penpot and record user approval before UI implementation.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/06.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 06 execution evidence yet.
- **Completed:** —

### Phase 07

- **Name:** Suppliers, debts, materials and prices
- **Status:** TODO
- **Dependencies:** 01, 02, 06
- **Design approval:** Pending — validate the current reference in Penpot and record user approval before UI implementation.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/07.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 07 execution evidence yet.
- **Completed:** —

### Phase 08

- **Name:** Purchase invoices, analysis and supplier payments
- **Status:** TODO
- **Dependencies:** 02, 06, 07
- **Design approval:** Pending — validate the current reference in Penpot and record user approval before UI implementation.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/08.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 08 execution evidence yet.
- **Completed:** —

### Phase 09

- **Name:** Settings, backups, import and recovery
- **Status:** TODO
- **Dependencies:** 01, 02, 04, 06, 08
- **Design approval:** Pending — validate the current reference in Penpot and record user approval before UI implementation.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/09.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 09 execution evidence yet.
- **Completed:** —

### Phase 10

- **Name:** Statements, day review, PDF reports and printing
- **Status:** TODO
- **Dependencies:** 03, 04, 05, 06, 07, 08, 09
- **Design approval:** Pending — validate the current reference in Penpot and record user approval before UI implementation.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/10.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 10 execution evidence yet.
- **Completed:** —

### Phase 11

- **Name:** Complete MVP verification, migration rehearsal and release
- **Status:** TODO
- **Dependencies:** 00–10
- **Design approval:** N/A — non-UI setup/data/release scope; reassess if UI changes are introduced.
- **Branch / Worktree:** —
- **Assigned agents:** —
- **Implementation plan:** [Scope reference](docs/planning/flutter-rebuild/phases/11.md); phase-specific read-only Planner output pending.
- **Automated tests:** Pending — no Flutter phase verification performed.
- **CI:** Pending — assess mandatory checks and record evidence/N/A at phase planning.
- **Benchmarks:** N/A — no numeric optimization requirement set; establish baseline, conditions and target before optimization.
- **Independent review:** Pending
- **Staging / Rollback:** Pending — assess applicability; verify required migration/recovery/release paths.
- **PR:** —
- **User approval:** Pending — no phase/merge approval recorded.
- **Decisions / Lessons:** —
- **Evidence:** [Evidence index](docs/phases/README.md); no phase 11 execution evidence yet.
- **Completed:** —

## Completion Rule

Mark DONE only after all applicable requirements pass, the PR is approved and merged, and required release validation is completed. Never mark a phase DONE based only on implementation progress. Never automatically start the next phase.

Prior Electron tests, screenshots, planning and folder relocation remain historical reference evidence. They do not mark any Flutter phase as started, reviewed, approved, merged or completed.

## Documentation maintenance outside phases

- 2026-10-28: [Required current Madar documentation reading](docs/log/2026-10-28-madar-documentation-rule.md). Documentation maintenance only; runtime/contracts and phase progression are N/A. Existing acceptance gates remain pending.

## Device Hub correction — 2026-10-29

Interactive iPhone access is available through Device Hub 27.1, `/Applications/Xcode.app/Contents/Applications/DeviceHub.app` (`com.apple.dt.Devices`). The old Simulator.app absence is no longer a blocker. Native acceptance is in progress and remains unverified until the actual checks complete. See the dated Step 3 preflight correction. Existing plan/design approvals stand; no merge/deployment approval or Phase 01 implementation pass is inferred.

## Native dependency closure / Phase 01 Step 3 execution — 2026-10-29

Focused independent review closed the previously outstanding iPhone Simulator technical acceptance after real open/export cancellation, synthetic export/reopen, share dismissal, print cancellation and recovery checks on unchanged approved Phase 00 source. Existing design/plan approvals and Step 3 authorization permit Phase 01/CAP-01 implementation. Status for current Phase 01/CAP-01 execution: **IN PROGRESS**. Phase 00/CAP-00 evidence integration and overall DONE remain separate; no automatic merge, supported-release claim or deployment. Detailed consumer authority: `docs/phases/00-ios-native-acceptance.md` in Dakhl_Restaurant. Earlier blocked sections are historical.
