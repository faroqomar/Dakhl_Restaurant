# Phase 01 — Step 1 scope, references and readiness

Historical preparation record. The plan and both Penpot design sets were subsequently approved, the native technical prerequisite was verified, and Phase 01 was implemented. Read [current review corrections](01-review-corrections.md) and PHASES.md for current disposition. Earlier pending/N/A/old-pin statements apply only to this preparation stage.

Date: 2026-10-29. Status: Step 1 assessment recorded; implementation not ready. Owner request: establish scope/readiness only, with references shown back, clear ownership/dependencies/tracking and no implementation or assumed approval.

## Source and isolation

App baseline: `f73b14b5a7cc6d2421f670938b2435af137ddb0f` (local `origin/main`). Engine documentation baseline: `07d2bb1b4c920113457f0338aff2b00410dc9241` (local `origin/main`). These are local revision observations, not a fresh remote-status or CI query.

App documentation branch: `codex/phase01-scope`, worktree `/Users/eros/.codex/worktrees/phase01-scope-app/Dakhl_Restaurant`. Separate engine documentation branch: `codex/phase01-scope`, worktree `/Users/eros/.codex/worktrees/phase01-scope-engine/Madar_Engine`. Existing dirty root checkouts, prior worktrees and their evidence are preserved. PR/publication/merge: not requested or performed in Step 1. This preparation branch does not establish implementation-plan approval or the later implementation baseline.

Read both projects' AGENTS/PLANS/PHASES/PROMPTS, Madar README/documentation index/FULLSTACK/responsibility list/next-session/memory guidance, and relevant delivery/prevention records. [Detailed Phase 01 scope](../planning/flutter-rebuild/phases/01.md) remains unchanged; [tracker](../../PHASES.md) owns execution status. Current Penpot rules supersede the detailed scope's remaining Figma wording.

## Ownership and public boundary

| Owner | Bounded Phase 01 responsibility |
| --- | --- |
| Dakhl_Restaurant | Arabic RTL tokens/typography, reusable presentation components, responsive layout, navigation and six configurable shortcuts, route restoration/fallback, focus/keyboard/mobile-back handling, session undo dispatch and dirty-form protection. Views consume presentation models through ViewModels; no direct persistence access or financial calculations in widgets. |
| Madar_Engine | Implementation, new capability ID and new public API: **N/A** for this presentation-only scope. Widgets, themes, navigation and presentation translations remain consumer-owned under Madar's responsibility list. Keep existing capabilities compatible; no speculative framework or duplicate backend. |
| Existing contract | Preserve `madar_application` and `madar_flutter_adapters` preview `0.1.0-dev.1` at reviewed source `784b139753a0e2a07d3f97eedb326debfe068395`, as recorded in [engine-dependency.json](../../engine-dependency.json). Newer engine documentation does not require repinning runtime source. Actual resolved-package conformance remains a later verification gate. |

If planning reveals a genuinely reusable value/validation/operation contract, stop that dependent scope and register bounded Madar work with independent engine plus consumer/conformance tests. Do not implement shared financial behavior in fields or silently settle policy. The [engine-owned counterpart](https://github.com/faroqomar/Madar_Engine/blob/d705576122f817093bcc9ab1bf935010958fea70/docs/log/2026-10-29-phase01-scope-readiness.md) records this justified N/A separately.

Lead owns scope/tracking and integration boundaries. Read-only Planner `phase01_scope` assessed ownership, dependencies and acceptance; UX `phase01_references` assessed saved references and design needs. Independent documentation review is recorded in the dated task log. No Workers or implementation are authorized by Step 1.

## In scope and limits

- Presentation tokens, licensed Arabic typography and tabular Latin financial display; buttons/icons, text/money/quantity/date/select controls, tables/pagination/filters/badges, compact empty/loading/status/error shells, standard/wide dialogs and toolbar/shortcuts.
- Grouped dismissible navigation popover with scrim, active/save/error state, unknown-route fallback to Sales and retired shortcut cleanup without exposing the retired worker screen.
- Focus traversal/trap/return, Escape and mobile back, dirty-form discard/cancel behavior and preservation of an active ticket. Route shells may use synthetic presentation state; later business pages and durable account/settings/ticket storage remain their owning phases.
- Preserve calm green/light surfaces, Arabic RTL/IQD, full-width aligned gutters, desktop catalog left/bill right, compact related totals, centered dialogs and reachable narrow-screen actions.

No sales posting, inventory/accounting engine, invoice payment logic, migration, production persistence, cloud/auth/multitenancy, real records, installation or deployment is included. References to business screens specify component composition, not permission to implement those later-phase workflows.

## Previously supplied references

All six files below were visually inspected and their SHA-256 values matched the frozen [screenshot manifest](../planning/flutter-rebuild/screenshot-manifest.json). Captured 2026-10-27 from synthetic Electron state. They establish reference composition, not Flutter/native verification or design approval. Pixel dimensions are twice logical dimensions.

| Supplied reference | Logical size | Stored pixels | Use |
| --- | --- | --- | --- |
| [Design inventory](../planning/flutter-rebuild/screenshots/design-system.png) | 1440×1200 | 2880×2400 | Colors, typography, controls, table and layout inventory |
| [Desktop navigation](../planning/flutter-rebuild/screenshots/desktop-navigation.png) | 1440×1000 | 2880×2000 | Grouped popover, scrim and active route |
| [Desktop invoice dialog](../planning/flutter-rebuild/screenshots/desktop-invoice-new.png) | 1440×1000 | 2880×2000 | Wide dialog, fields, totals and actions |
| [Narrow invoice dialog](../planning/flutter-rebuild/screenshots/phone-invoice-new.png) | 390×844 | 780×1688 | Narrow fields, internal scrolling and footer |
| [Desktop sales](../planning/flutter-rebuild/screenshots/desktop-sales.png) | 1440×1000 | 2880×2000 | Toolbar, six shortcuts, catalog/bill composition |
| [Narrow sales](../planning/flutter-rebuild/screenshots/phone-sales.png) | 390×844 | 780×1688 | Wrapped shortcuts, catalog and failed-save toast |

The narrow invoice reference visibly squeezes the invoice-number field. The narrow sales reference shows a failed-save toast and does not show checkout within its initial viewport. These require explicit usability treatment and owner-reviewed differences; static captures do not prove scroll reachability, native keyboard behavior or recovery. Frozen screenshot bytes and their Arabic text remain unchanged. The English-translated HTML design inventory is documentation and is not a replacement pixel baseline for the frozen Arabic board.

## UI design needs — required, approval pending

Design is **required**, not N/A. Step 1 identifies needs only; no Penpot boards are created or edited. Later Step 1.5 must reuse the [canonical Penpot file/page](https://design.penpot.app/#/workspace?team-id=bfddaaba-4180-81d4-8008-db9f13093baa&file-id=122350ae-89ad-8027-8008-dba0bd5cf454&page-id=122350ae-89ad-8027-8008-dba0bd5cf455), preserve Phase 00 work and prepare named Phase 01 component/shell/dialog designs with matching structural wireframes.

Required coverage: default/focus/disabled/loading/validation/error states; save/failure/retry/cancel; popover open/closed and focus return; dirty-form discard/cancel; narrow keyboard-open forms, safe areas, mobile back, reachable save/cancel and large text. Include 390×844 reference fidelity, 320 logical width/200% text, medium 1024×768, desktop 1440×1000 and wide 1920×1080. Static design approval remains separate from runtime accessibility and native-device evidence.

Phase 00's bundled [Amiri Regular provenance/license](../../assets/fonts/SOURCE.md) is available, but does not approve Phase 01 typography. Establish target-specific goldens and report Arabic glyph/rendering differences instead of promising cross-platform pixel identity. Use current reference assets/icons with their provenance; no sample product becomes an approved menu addition.

## Dependencies and blockers

| Gate | Current evidence | Required next outcome |
| --- | --- | --- |
| Phase 00 dependency | **BLOCKED**, even though exact source was merged; [Step6](00-step6-merge.md) and PHASES.md | Explicit approval of its three Penpot reproductions/wireframes and required iPhone Simulator chooser/export/reopen/share/print acceptance. Physical-phone signing is deferred, not the active Simulator gate. |
| Phase 01 design | No phase-specific approval | Prepare and verify bounded Penpot designs/wireframes when requested, then obtain explicit owner approval before UI implementation. |
| Token provenance | Existing review requires reconciliation before implementation | Reconcile computed tokens, frozen CSS cascade/component/media overrides and board values; document intentional differences. Initial base styles alone do not establish conflicts: ux.css overrides muted/radius/heading values. JSON's single 24px gutter does not express the documented narrow 14px override. Do not edit frozen assets to hide discrepancies. |
| Implementation plan/authorization | Step 1 only; Step 2 not executed | Approved bounded plan, suitable implementation isolation/base and applicable tests/CI before building. |
| Legacy tool reuse, conditional | Preview helper Host/origin flaw and dated dependency alerts remain unresolved | Do not launch the helper. Dedicated triage/remediation is required before affected legacy-tool/app reuse; passive screenshot review does not resolve or exercise it. |

No additional financial-policy decision is needed to assess this shell; unresolved policies continue to block their affected future business contracts. No blocker is waived by this assessment.

## Verification and tracking

Step 1 verification: source/tracker/pin review, independent read-only Planner/UX findings, visual inspection and **6/6 frozen screenshot hashes matched**. Documentation links/diff/scope and independent review are recorded in [task log](../log/2026-10-29-phase01-scope-readiness.md). No runtime tests/builds/CI/device runs were executed; earlier Phase 00 results remain dated evidence. Benchmarks, new packages/logger implementation, schema/migration/release/rollback execution: N/A for this documentation-only task.

Later planning must carry meaningful component-state/platform goldens; route/focus/hidden-menu/fallback/shortcut tests; dirty-form cancellation and ticket-preservation cases; safe-area/keyboard/back/large-text checks; resolved-engine-source/boundary conformance and existing mandatory CI. Existing engine independent tests remain required when applicable; do not invent new engine tests for unchanged contracts. New execution-path diagnostics must follow safe structured logging policy without payloads/telemetry. Detailed test/CI selection and package justification belong to Step 2, not an implemented result here.

Phase 01 remains **TODO**, with Step 1 assessment recorded and implementation blocked by the gates above. Phase 00/CAP-00 status is unchanged. Design/plan/implementation/merge/deployment approval and advancement to later steps are not inferred.
