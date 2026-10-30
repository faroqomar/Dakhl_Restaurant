# Phase 02 — Step3 build and verification

Date:2026-10-30. Status: BUILDING; app and engine source independently reviewed; exact reviewed-pin and real consumer conformance checks passed; native/per-operation evidence pending. No merge/publication or production-account testing.

## Scope and ownership

Owner Step3 instructed implementation of the presented Phase02 outcome and in-scope engineering choices without questions. The selected bounded plan, ADR0010, PREF-01,20MiB workspace profile and six-pair Penpot set govern. Original planning/design trees and all frozen references remain preserved. App build branch codex/phase02-build: /Users/eros/.codex/worktrees/phase02-build-app/Dakhl_Restaurant; engine counterpart /Users/eros/.codex/worktrees/phase02-build-engine/Madar_Engine.

Madar owns explicit-policy exact values, opaque fenced snapshot contracts, single-owner local-only PowerSync/SQLite persistence, independent previous/source/recovery artifacts, uncertain-write readback and safe diagnostics. Dakhl_Restaurant owns schema1–11 canonical codecs/legacy compatibility, account/device preference meaning, workspace presentation schema, repositories/ViewModels and the approved persistence/recovery UI. No shared backend copied into the app. The pure domain/application packages contain no Flutter/vendor/platform implementation.

## Implemented consumer behavior

- True absence remains visibly unsaved until explicit save; corrupt/future/incomplete state never becomes empty or Saved. Original selected bytes are preserved through the engine before import mutation.
- Canonical account validation preserves supported IDs/relationships/history and compatibility-only records. UTF8 input and two-space serialized output have separate20MiB checks; Arabic/Persian digits, IQD/quantity/calendar and evidenced legacy timestamp behavior follow source profiles. An explicit BigInt-only binary64 integer-expression compatibility helper preserves the historical validator's grouped remaining-expression behavior; strict exact/prefix helpers elsewhere remain unchanged.
- Account preferences are authoritative when a valid account exists; last route stays device-local. First explicit creation seeds existing six-slot device fallback. Successful account save precedes best-effort cache work; cache or workspace failure cannot falsify account acknowledgement or relabel an unsaved draft Saved.
- Known failure retains selected import/input. Latest picker cancellation/invalid selection cannot silently confirm an older retained selection. Replacement/recovery is explicit, invalidates old workspace only after success, and fences old async callbacks.
- Unknown outcomes gate writes until token/fence readback. Conflict requires authoritative reload, preserves pending selection for fresh confirmation, and uses the existing discard guard before changing a dirty account session. Cancel does not acknowledge unsaved workspace or resolve authority conflict.
- Incomplete first creation resumes only through a typed original-canonical-payload-matching engine path; reselecting an original source is explicit, never automatic defaults/reset.
- Workspace schema1 stores current presentation/form and up to40held presentation records. Operational hold/resume/sales posting remains later-phase scope. Oversized drafts remain visible, fail without store writes, and do not strand the ViewModel busy.

## Actual verification so far

| Evidence | Result |
| --- | --- |
| App analysis | No issues; outputs/phase02/app-analyze-final2.log |
| Full non-golden unit/widget suite |456passed; outputs/phase02/app-suite-final.log |
| Existing golden contracts |5passed without updates; outputs/phase02/app-golden-final.log |
| Focused persistence/UI/callback regressions |24passed; outputs/phase02/cancel-conflict-green.log |
| Codec frozen oracle |271tests;267cases185accept82reject, including known timestamp/aggregate regressions; synthetic only |
| Frozen reference integrity |179screenshots/9source/21assets unchanged |
| Electron reference tests |140passed after locked dependency installation; initial missing-jsdom failure preserved |
| Source/version helper tests |28passed; final reviewed-pin check still pending |
| App benchmark runner contracts |8passed; actual measurements pending |
| Independent app source + picker harness review |No remaining actionable source findings; native/profile results remain separate |

See the [running audit](../log/phase-02-execution.md), worker fragments and exact logs under outputs/phase02. No unexecuted native/CI/performance/release gate is passed. Live reader/TalkBack verification is owner-excluded, not passed.

## Remaining Step3 gates

The final engine close-safety regression was repaired with coordinated read-only primary-copy preflight before managed SDK construction. Actual final-source data121/121, domain9, application9, native-adapter27 and hostbenchmark19 tests pass; source/format/analyses/boundaries and renewed independent review are clear. Engine committed locally at ea9c21adfde746c40d0e8d15a7e5bbe017beb70c; packages/tool source clean. App deliberately adopts this exact reviewed revision with application0.1.0-dev.3/data0.1.0-dev.2/domain0.1.0-dev.1/native0.1.0-dev.1. Enforced locked resolution and scripts/check-engine.py pass. Four actual-adapter consumer scenarios pass on the adopted pin; version check remains unreleased0.0.0+1. Other original runtime checkouts remain untouched.


Next run native builds and fresh nonce/PID native write-stop-read/negative/recovery on macOS/Android emulator/iPhone Simulator, actual macOS native picker cancellations and synthetic import/recovery handoff, and separate six-case20sample per-operation profile baselines for declared synthetic fixtures. Mobile performance has no supported collector yet and cannot inherit macOS figures. Hosted CI/PR/publication/merge/release remain unexecuted/unapproved. Candidate0.0.0+1 remains an unreleased development candidate; no tag/versioned delivery is claimed.
