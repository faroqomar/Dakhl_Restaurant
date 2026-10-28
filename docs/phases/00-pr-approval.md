# Phase00 / CAP-00 — draft PR review package

Date:2026-10-28. **Draft review only; not ready for merge approval.** The owner requested Step5, then explicitly approved narrowly scoped read-only engine access for CI. Neither instruction approves merge, release, production migration or the next phase.

| Project | Draft PR | Base/dependency |
|---|---|---|
| Madar_Engine | [PR1](https://github.com/faroqomar/Madar_Engine/pull/1) / [diff](https://github.com/faroqomar/Madar_Engine/pull/1/files) | main initialized with preserved documentation baseline a335bea; engine implementation remains unmerged |
| Dakhl_Restaurant | [PR2](https://github.com/faroqomar/Dakhl_Restaurant/pull/2) / [diff](https://github.com/faroqomar/Dakhl_Restaurant/pull/2/files) | codex/project-baseline-upload/ecf692b; prerequisite [baseline PR1](https://github.com/faroqomar/Dakhl_Restaurant/pull/1) remains unmerged; also depends on engine PR1 |

## Changes and ownership

Madar owns pure capability contracts/results and optional generic file/PDF handoffs, preview0.1.0-dev.1. App owns blank Arabic RTL development shell, ViewModel/UI, synthetic validation/revision safeguards, native identity, and licensed offline Arabic PDF layout/font. No engine source is copied into the app. The consumer manifest pins the actual engine commit/package versions, and its gate verifies resolved import roots, overrides/lock consistency and clean source.

The app diff also contains the authorized naming/Penpot preparation and standing workflow updates. These do not imply design approval. Frozen Electron source,179 reference captures and real restaurant records remain protected. No product screens or financial/business engine modules are introduced.

## Evidence and limits

[Step4 review](00-step4-review.md) records48 app tests,27 engine adapter tests,24 dependency-gate regressions,140 reference tests,179/9/21 frozen hashes, static analysis/format/lint and the repaired source-resolution P2. Independent review closed that finding. Debug/native evidence remains dated where unchanged source is being reused; Android external export/reopen was observed anew. Benchmarks:N/A.

Initial hosted reference workflow [40707872640](https://github.com/faroqomar/Dakhl_Restaurant/actions/runs/40707872640) passed. Initial Flutter workflow [40707872616](https://github.com/faroqomar/Dakhl_Restaurant/actions/runs/40707872616) failed at private engine checkout before tests/builds; downstream builds were skipped, not passed. The owner-approved access repair is independently reviewed; actual rerun results are shown in the linked PR checks, never inferred from configuration.

## Private source access

A private faroqomar/Madar_Engine repository now hosts the engine draft. CLI workflow upload was rejected, then the existing connected GitHub integration published the exact app commit with all CI files intact. No broader OAuth permission was granted. The source repository variable is configured.

With explicit owner approval, an engine-only deploy key was added with GitHub read_only=true, the private half stored directly in app Actions secret MADAR_ENGINE_SSH_KEY and temporary local key files deleted. No broad personal token, signing key or private key appears in source/artifacts/chat output. Hosted checkout uses the full engine SHA, strict host checking, contents:read and persist-credentials:false. Fork pull_request events do not gain repository secrets; no pull_request_target trigger or deployment path was added.

## Remaining gates

Required hosted Flutter checks must pass on the actual PR revision. iPhone Simulator native dialogs/external roundtrip and explicit owner Penpot approval remain pending. Physical-phone signing is deferred by the simulator direction; provider materialization, replacement rollback, coordinated cross-process/power-loss durability and physical output remain prototype limits. Future production/release requirements must not inherit unsupported guarantees.

Review both linked diffs and the final engine pin together. Merge only explicitly approved revisions in dependency order; a changed app revision after engine pinning requires renewed approval. Keep both drafts and work items blocked while required evidence is missing. Nothing is merged or released.
