Current Step5 delivery, 2026-10-30: **APP PUBLICATION ACCESS-BLOCKED / NOT MERGE-READY**. GitHub rejected the push of local candidate `0b75862a87aad3ae044ed0e3df4c6e3acfd7cd0b` because the active OAuth credential lacks workflow scope; no app PR or hosted app checks exist. [Engine draft PR#6](https://github.com/faroqomar/Madar_Engine/pull/6) is published; its CI is ongoing, not passed here. [Delivery evidence](docs/phases/02-step5-delivery.md) preserves tested app5a11/runtimea6/tool63 and all Android preservation/iOS blockers. No credentials, permissions, CI requirements or target state were changed; no merge, release or next phase. Earlier records below retain their original dated scope.

# Project Phase Tracker

Current completion, 2026-10-29: Phase 01 / development dashboard approved source integration is **DONE**. All four exact approved revisions merged after all 15 premerge checks passed. Owner accepted independent review with automatic review unavailable; TalkBack is owner-excluded, not tested. [Completion/rollback record](docs/phases/01-step6-completion.md). These completion/tracker updates are local documentation; no release, deployment or next phase. Earlier sections retain dated history.

Source of phase definitions: [PLANS.md](PLANS.md). Rules: [AGENTS.md](AGENTS.md). Adopted 2026-10-28 from the owner’s supplied tracker template.

The standing joint workflow in [PROMPTS.md](PROMPTS.md) applies to every phase and linked engine work item. Each project keeps its own status/evidence; an unaffected side records N/A with a reason. This workflow update does not advance any phase.

## Statuses

TODO → DESIGN → PLANNING → BUILDING → REVIEW → VERIFYING → PR → DONE

Use BLOCKED when progress cannot continue and record the reason and required action. Skip inapplicable steps and record N/A. Branch, PR, design approval and verification are evidence fields, not assumed from status labels.

## Phases

| Phase | Name | Status | Branch | PR |
| --- | --- | --- | --- | --- |
| 00 | [Baseline and delivery setup](docs/planning/flutter-rebuild/phases/00.md) | VERIFYING — technical prerequisite verified; historical completion pending | codex/phase00-engine-split | [Merged PR2](https://github.com/faroqomar/Dakhl_Restaurant/pull/2) |
| 01 | [Design system, navigation and interaction shell](docs/planning/flutter-rebuild/phases/01.md) | DONE — approved preview scope | `codex/phase01-build` | [Merged PR7](https://github.com/faroqomar/Dakhl_Restaurant/pull/7) |
| 02 | [Local accounts, validation and safe persistence](docs/planning/flutter-rebuild/phases/02.md) | VERIFYING — bounded native Android and API37 checks in progress | codex/phase02-build | [#9](https://github.com/faroqomar/Dakhl_Restaurant/pull/9) |
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
- **Status:** DONE — approved development-preview source integration. Both app PRs 7/8 and engine PRs 4/5 are merged; the six main app and six dashboard premerge jobs pass. Owner-excluded live reader verification is not a passing result. See the Step6 completion record for scope, revision and local-documentation publication limits.
- **Dependencies:** 00
- **Design approval:** Approved — owner explicitly approved the [existing Phase 01 design/wireframe set and listed differences](docs/phases/01-penpot-design-review.md) on 2026-10-29.
- **Branch / Worktree:** Implementation codex/phase01-build merged through PR7; tooling codex/dev-dashboard through PR8. Completion-only local branch codex/phase01-completion-record follows merged main. Original preparation/canonical/consumed worktrees and their files are preserved.
- **Assigned agents:** Lead (composition/isolation/evidence); read-only Planner `phase01_scope`; engine Worker `phase01_engine_build`; shell Worker `phase01_shell_build`; UI/native Worker `phase01_capture`; independent code Reviewer `phase01_docs_review`; independent UX `phase01_references`; Step4 independent reviewers `phase01_step4_app_audit` and `phase01_step4_engine_audit`. Each owns its project/layer; no copied engine code.
- **Implementation plan:** [Bounded Step 2 proposal](docs/phases/01-implementation-plan.md), including read-only Planner advice and owner-confirmed full-restart route/shortcut restoration; approved Step 3 request and explicit designs recorded on 2026-10-29; technical dependency closed. Historical proposed/blocked sections retain provenance.
- **Automated tests:** PASS — 14 focused/154 full app guard tests; dashboard suite 158 Flutter + 28 script + 7 cache tests and analysis. Earlier 147-test/native restoration captures retain their original revisions and device limits; they are not relabeled new runs. The actual exact engine-source checker passed after integration.
- **CI:** PASS at all four approved premerge heads: 1 + 6 + 2 + 6 jobs, including Android/macOS/iPhone development builds. Both final main trees equal the approved final child trees. Postmerge runs have their own live Actions status and are not fabricated passes.
- **Benchmarks:** Three actual macOS profile baselines passed: startup, route switch and shortcut save, with p50/p95, sampled RAM and CPU. See Step6 record/results for actual values and identity/sampling limits. No optimization or measured order/item workflow is claimed.
- **Independent review:** All genuine code findings closed and independently reverified. All 46 old automatic comments have dispositions. Owner confirmed Mac Command-3/Command-K; dated native Back/other captures retain scope. Live TalkBack is owner-excluded, not tested. Owner explicitly accepted completed independent review because fresh Cubic/Copilot reviews are unavailable.
- **Staging / Rollback:** Isolated development data only. Real rollback/future-format preservation and fresh-process checks pass; stop development build to roll back UI, retain dedicated preferences DB. No production migration/deployment.
- **PR:** Merged app PR7/PR8 with engine PR4/PR5, in compatible dependency order; exact heads/merge commits are in docs/phases/01-step6-completion.md. No additional revision is merged by the local completion documentation.
- **User approval:** Owner explicitly approved the four corrected exact heads with independent review, conditional on all configured checks passing; the condition passed and merges completed. Existing design/build approvals remain recorded. No deployment or next phase.
- **Decisions / Lessons:** [Shell contract/setup](docs/reference/phase01-shell-contract.md); [prevention catalogue](docs/how-to/repeated-problems.md). Device Hub is the verified native app; absence of old Simulator.app is not an access blocker.
- **Evidence:** [Current independent Step4 verdict](docs/phases/01-step4-review.md); [Current build results and remaining gates](docs/phases/01-build-evidence.md); [Step 1 readiness](docs/phases/01-scope-readiness.md); [Step 1.5 design review](docs/phases/01-penpot-design-review.md); [design task log](docs/log/2026-10-29-phase01-penpot-design.md). [Step 2 plan/log](docs/log/2026-10-29-phase01-implementation-plan.md). [Step 3 approval and native preflight](docs/log/2026-10-29-phase01-step3-preflight.md). Native artifact evidence is separate from runtime verification.
- **Engine/app contract:** App owns UI, route/six-slot payload, fixtures and safeguards; Madar owns generic contracts/storage and host measurement. Consumed runtime stays exact 6d4ae39f35b005dfa1123a82c6df316901e1e1e4, now preserved in merged engine ancestry; actual resolved-source checker passed.
- **Completed:** 2026-10-29 — approved development-preview source integration; local completion/tracker documentation and separate memory delivery. App version 0.0.0+1 remains unreleased; no installed production update or next phase.

### Phase 02

- **Name:** Local accounts, validation and safe persistence
- **Status:** BLOCKED — VERIFYING — owner explicitly requested in-scope fixes and paired merge. Bounded Android/iOS picker revalidation, API37 readiness and final-head checks remain pending; historical fixture impact is independently classified.
- **Dependencies:** Approved00/01 preview prerequisites retained; no Phase03 started.
- **Design:** Existing six Phase02 Penpot design/wireframe pairs retained. No Step4 product UI change; engine Design N/A. No new design/merge approval inferred.
- **Isolation:** App/runtime codex/phase02-build and separate codex/phase02-bench-tools. Original scope/design worktrees retained. Redundant isolated engine repair archived recoverably after13 artifact+journal copies/hash verification; runtimea6 unchanged.
- **Ownership/contracts:** Madar exact primitives/fenced opaque ports/optional durable adapter; app schema1–11/history/timestamps/settings/workspace/VM/UI/safeguards. App-only failure/readiness instrumentation changes neither generic measurement protocol nor normal UI. Four reviewed package revisions consumed with enforced source checks; no copied engine code/cloud/new business policy.
- **Exact app / runtime / tool:** `5a11c66dbf665972b17b545c105eac74c17bfeeb` / `a6a8ebdd8f68f5d603d56dc3f3d0f13cc3e38294` / `63bbed8303bf8561084c5f82a3ebd52e2bf9e95d`. Candidate unreleased0.0.0+1.
- **Tests:** Fresh529 non-golden app tests/whole-app analysis/exact source checks pass.18 producer and26 runner checks pass; counts overlap. Focused355 accounts/329codec cover324 full-model+4,127 compact timestamps against frozen source in UTC/Baghdad, with1,840 further independent comparisons. Engine132 data/analyzer plus independent original-prefix/15protection/2SIGKILL checks pass. Unchanged source evidence retains original scope; no unnecessary test rerun.
- **Independent review:** Original app/engineP2, procedureP3, diagnostic-authorityP2 and initial-only bootstrap correction independently closed for exact frozen hashes. Final805 artifact/statistical checks/108hashes found0 discrepancies. No self/owner approval inferred; historic specific failure interleavings remain unproven.
- **Native/builds:** Current iOS 27.0 simulator: all 9 expected outcomes passed at app5a11/runtimea6, including real Open/Save cancellation and selected-file replacement/recovery. The Android uninstall/reinstall incident is confirmed; prior installed-app data retention remains unverified. Fresh API37.2 first-screen check failed; API36 guarded install final verification/native acceptance pending. Existing Mac evidence retains its recorded source. Live screen-reader verification is owner-excluded, never passed.
- **Benchmarks:** Current5a11 fixed-source18distinct cases/360samples, oneattempt each, allcleanuptrue, independentverificationclear. [Current metrics/method](docs/phases/02-step4-performance.md). Prior62/df72 partials, isolated/prefix runs and Step3 failures remain separate. No numericbudget/optimization/reliability/mobilecapacity/cross-epochresourceclaim.
- **CI/recovery/release:** Workflow publishing permission repaired; app6f9 passed6/6 hosted checks and enginebca passed2/2. New guard/documentation candidate requires its own final-head checks. No validated historical Android restore point or restoration established. Physical signing, production migration and supported release remain unverified where applicable.
- **Approval / PR / completion:** Draft [appPR9](https://github.com/faroqomar/Dakhl_Restaurant/pull/9) depends on [enginePR6](https://github.com/faroqomar/Madar_Engine/pull/6). Neither merged; changed revisions require explicit owner merge approval. No DONE, tag, release, deployment or next phase.
- **Evidence:** [Current Step4 review](docs/phases/02-step4-review.md), [incident](docs/log/2026-10-30-phase02-android-preservation-incident.md), [current metrics](docs/phases/02-step4-performance.md), [historical Step3](docs/phases/02-step3-build.md), execution/time-cost audit (local-only artifact `docs/log/phase-02-execution.md`, SHA-256 `d490433a2ead39ecf2f36721364cd1003b550152426fa7b98b90c3bb069c639c`), [sanitized outcome](docs/log/2026-10-30-phase02-step4-review.md). Separate source-hash delivery status recorded by receipts.

- **2026-10-31 continuation:** [Current native/guard evidence](docs/phases/02-native-verification-2026-10-31.md). App-specific installation guard:37 cases / full65 scripts pass; no shared engine/API/product design changes. Historical dated pending entries below are superseded only by explicit current results.

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


## Phase01 — Step4 requested,2026-10-29

Owner requested completion of remaining Step3 checks and independent Step4 review. Reviewers `phase01_step4_app_audit` and `phase01_step4_engine_audit` audited separate app/engine scopes; engine runtime changes remain N/A for app-only repairs. Two app P2s (false Saved status and iOS edge-back) were independently repaired/reverified; a meaningful Android platform-channel regression confirmed inconsistent native Back registration and its root guard repair passed focused checks. Final native/quality evidence and readiness disposition are in [Step4 review](docs/phases/01-step4-review.md). No missing native/hosted evidence is passed, no merge/publication/deployment or Phase02 advancement.

Final Step4 disposition,2026-10-29: all three code findings independently closed; full Step3 verification and Phase01 approval readiness remain BLOCKED by pending genuine screen-reader traversal. TalkBack settings restored exactly after owner could not perform the manual check; no missing check passed. See the Step4 report and final147test/native build receipts.

## Development dashboard support initiative — 2026-10-29

Owner-authorized standalone developer console, separate from Phase 01 restaurant UI acceptance. App branch `codex/dev-dashboard`, base `f38ff281`; generic tooling branch `codex/dev-benchmarks` in Madar. Implementation and independent code review complete; no app/engine push, PR, merge, release or next phase inferred. [Delivery evidence](docs/log/2026-10-29-development-dashboard-delivery.md), [version/performance procedure](docs/how-to/versioning-and-performance.md), [app scenarios](tool/dev_dashboard/README.md).

Actual dashboard-launched local test run `run-da4fb11fcd67b2b6`: 246 passed. Benchmark run `run-f57aad3e9bc2b13a`: three real macOS profile operations measured separately. Runtime engine remains exact `6d4ae39f35b005dfa1123a82c6df316901e1e1e4`. UI design is a user-requested standalone minimalist developer console; no restaurant Penpot design changed. Phase 01 remains BLOCKED by reader acceptance; hosted app CI/approval/integration remain pending. Private Site publication is a separate developer-tool delivery and does not satisfy those gates.

## Development tooling Step5 — draft publication, 2026-10-29

[App draft PR](https://github.com/faroqomar/Dakhl_Restaurant/pull/8) links [paired tooling PR](https://github.com/faroqomar/Madar_Engine/pull/5); runtime prerequisites are enginePR4/appPR7. [Delivery record](docs/log/2026-10-29-step5-development-review.md). Changes remain draft and unmerged; final exact-head checks are in PR metadata, reader acceptance remains pending, no release/DONE inferred.

## Step6 — approved source integration, 2026-10-29

[Phase 01 / development dashboard completion and rollback evidence](docs/phases/01-step6-completion.md). Actual merge commits and independent/CI evidence are explicit. Current main source trees equal their exact owner-approved final heads. Completion metadata is committed locally; no unapproved additional revision was merged or pushed. No next phase.


### Step3 build started —2026-10-30

Phase02 IMPLEMENTING in dedicated codex/phase02-build. Owner Step3 instruction authorizes presented outcome and in-scope engineering choices; no questions, publication or merge. Prior planning/design gate entries are historical. Independent implementation review, exact reviewed engine adoption, full checks/native/per-operation measurements and completion evidence remain pending. Current test results belong only to their recorded suites; no inferred CI/native/release pass. See the running execution journal and worker fragments under outputs/phase02.


### Phase02 Android closure and merge authorization — 2026-10-31

Owner explicitly requested fixes, old-data investigation and verified paired merge without another routine confirmation. This authorizes the bounded source changes and subsequent merge; it waives no actual verification or production-data protections. [Historical incident assessment](docs/phases/02-android-incident-assessment.md) establishes known synthetic fixture loss/no recorded normal-account access, with unrecorded activity/byte retention unknown and no restoration claim. Independent review accepts that residual as non-blocking for development-preview integration after current guarded gates pass.

Test-only picker hardening removes uncancellable pumps across native Activity suspension, uses a real monotonic120s budget, scopes fullyLive frames and actual device touches, and restores both settings/timers.12 real-zone regression tests/analyzer and independent review pass. Native three-case verification on each affected mobile platform and current-head CI remain pending. Product library, business policies, engine runtimea6 and existing18-case/360-sample Mac baseline are unchanged; no new optimization or benchmark claim. Runtime libraries retain5a11 source continuity. No DONE/release/deployment/next phase yet.
