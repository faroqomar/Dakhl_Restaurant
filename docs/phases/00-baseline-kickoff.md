# Phase 00 — kickoff and reference assessment

Date: 2026-10-28 (Asia/Baghdad). Initial status: PLANNING; kickoff completed before implementation. Current status: DESIGN for the owner's subsequent [Penpot screenshot-recreation prerequisite](00-penpot-reference-recreation.md). The Figma attempt below is historical. Scope: [phase 00](../planning/flutter-rebuild/phases/00.md), no dependencies. Live status: [PHASES.md](../../PHASES.md).

## Authorization and ownership

The owner requested Lead + UX, initialization of phase 00, return of prior screenshots/references, and a stop before proceeding. Non-UI phases record Design: N/A. This record does not authorize another phase or establish completion.

- Lead owns PHASES.md and this kickoff's evidence/log/index updates.
- UX Agent `phase00_ux` performed read-only scope/reference assessment and inspected sales, expenses and settings reference images.
- Planner Agent `phase00_plan` produced the bounded read-only implementation plan below, as required by the project workflow.
- No Workers or implementation Reviewer were launched. Neither agent changed files or approved implementation.

Git branch: `codex/phase-00-baseline`, created from `aa624bc` in the existing checkout. No separate worktree was created. Existing uncommitted Electron relocation, documentation, workflow and configuration changes were retained; no files were staged, committed, discarded or published. Those prerequisite changes need a separately traceable baseline before a phase-only PR can be prepared. PR: pending; CI and merge approval: pending.

## UX applicability and references

**Design: N/A for the technical phase 00 shell.** Phase 00 covers delivery/toolchain setup, a blank Arabic RTL capability shell and isolated platform-service probes. It does not implement product navigation, components or screen redesign. The initial setup-only kickoff required no Figma work. The owner subsequently requested [Figma recreation before proceeding](00-figma-reference-preparation.md); that added prerequisite has pending validation and approval. Native font/dialog accessibility and cancel/error behavior still require later capability evidence; they have not passed.

If product UI enters scope, reopen the design gate: validate the suitable reference in Figma, check responsive layout, accessibility and usability, cover applicable loading/empty/invalid/error/retry/cancel/success states, and stop for explicit owner design approval before implementation. Phase 01 remains TODO.

Existing references returned to the owner:

- [Phase 00 gallery](../planning/flutter-rebuild/gallery.html?phase=00) and [complete gallery](../planning/flutter-rebuild/gallery.html).
- [Desktop sales](../planning/flutter-rebuild/screenshots/desktop-sales.png), [daily expenses](../planning/flutter-rebuild/screenshots/desktop-expenses.png), [settings/data](../planning/flutter-rebuild/screenshots/desktop-settings-data.png).
- [Design board](../planning/flutter-rebuild/screenshots/design-system.png), [design contract](../planning/flutter-rebuild/design-system.md) and [capture guide](../planning/flutter-rebuild/capture-guide.md).
- [Existing Figma file](https://www.figma.com/design/kLJU2TbqeTqKoWrUYKSoKG). The [local handoff](../../outputs/figma-transfer/RESUME.md) records a partial transfer, known RTL/product-order defects and a past Starter quota interruption. Access was not checked during the initial kickoff; the subsequent [live attempt](00-figma-reference-preparation.md) confirmed the quota block. Canvas state remains unread and no new Figma validation or design approval is claimed.
- The owner-supplied Nook screenshot is documented in [decision 0005](../decisions/0005-sales-reference-redesign.md). Its original attachment was not located in this kickoff; current Dakhl_Restaurant screenshots are the available derived reference, not a recovered original attachment.

The reference pack uses synthetic Electron data. Narrow captures are not native Android/iPhone screenshots and cannot prove safe areas, keyboards, fonts or platform dialogs. The board is an extracted reference, not an approved new Flutter design.

## Read-only implementation plan

1. Separate the existing prerequisite adoption/layout work from the phase PR baseline while preserving it. Retain dedicated phase isolation and explicit ownership.
2. Freeze/verify screenshot and asset manifests, source hashes, synthetic fixtures and feature-to-phase inventory; preserve electron-reference/ and the reference pack.
3. Verify and pin Flutter/Dart and dependency versions. Record minimum OS versions, supported Mac architectures and actual test devices/OS versions.
4. Create the Flutter workspace at the root with development-only identifiers/storage and a blank offline Arabic RTL shell. Never open production restaurant accounts for tests.
5. Define narrow file/storage/PDF/share/print service boundaries. Write meaningful tests before behavior and prove platform capabilities with synthetic records before selecting packages.
6. Establish Arabic-font/asset licensing and build/launch on macOS, Android and iPhone. Record device/OS/build versions and captures; an iOS simulator does not prove iPhone installation.
7. Record signing/distribution arrangements and cancellation/failure/recovery evidence. Obtain independent review, mandatory CI and a traceable PR; owner merge approval and applicable release/rollback evidence remain necessary for DONE.

## Verification and remaining gates

- Kickoff checks: source/tracker consistency, local links and frozen screenshot integrity; actual results are recorded in the task log.
- Flutter tests/builds/launches: **not run**; no Flutter implementation exists from this task.
- Required implementation tests: isolated development storage; synthetic write/read/restart; invalid input and failed-write preservation; file cancel/retry; Arabic PDF output/shaping and share/print entry/cancellation. Mark genuinely inapplicable blank-shell states N/A individually.
- CI: pending inspection of mandatory remote checks; planned formatting, static analysis, tests and target builds. No passed or skipped-required-check claim.
- Benchmarks: N/A; no optimization requirement. Record capability measurement conditions without inventing targets.
- Independent implementation review and re-verification: pending.
- Physical Android/iPhone access, iPhone installation/signing, Android key custody, Mac distribution/architectures, minimum OS matrix and font/plugin choices: pending verification/decisions. Credentials remain outside Git.
- Staging/migration/rollback: not exercised; no deployment or real data migration performed.
- PR, merge approval, merged revision and release evidence: pending. No phase completion or design approval inferred from the kickoff request.

Stop boundary: the owner replaced Figma with Penpot and authorized only the three phase-00 screenshot designs plus matching wireframes. Complete [that prerequisite](00-penpot-reference-recreation.md) and obtain owner design approval before proceeding. Do not start product UI implementation or phase 01 from this record.
