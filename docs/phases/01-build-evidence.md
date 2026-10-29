# Phase 01 — implementation and verification evidence

Date:2026-10-29. Current status: **VERIFYING, locally implemented**. The owner authorized Step3 on the presented plan, required full-restart restoration, and separately approved both existing Penpot design sets and listed differences. Phase00's formerly outstanding native dependency passed focused independent review through Device Hub. This is not overall DONE, merge approval or a release.

## Scope and ownership delivered

| Owner | Implemented outcome |
| --- | --- |
| Madar_Engine CAP-01 | Pure Dart opaque local-preferences port and versioned snapshot; optional PowerSync local-only adapter with atomic expected-revision commits, conflict/rollback/unknown-commit outcomes, format protection, lifecycle and safe structured diagnostics. Independent tests plus compiling generic second-consumer example. |
| Dakhl_Restaurant | Approved Arabic RTL tokens/components, offline fonts/icons/photos, grouped navigation and twelve route shells, six-slot editor, guarded forms/back/exit, session-only ticket/Undo, saved/error/retry states and root Riverpod/go_router composition. |
| Public contract | App owns v1 route/six-slot JSON and isolated development directory; Madar owns storage. Only last route and six slots persist. No sale/invoice posting, financial arithmetic, accounts, stock, recovery policy, connector, sync or telemetry. |

Detailed usage, schema, setup/error behavior and limits: [shell contract](../reference/phase01-shell-contract.md). Synthetic Sales/invoice examples demonstrate presentation only; later business screens remain in their owning phases. Inter/Amiri and eight provided photo assets are bundled with provenance. The full33-item reference menu is not implemented.

## Isolation and exact sources

- App build tree: `/Users/eros/.codex/worktrees/phase01-build-app/Dakhl_Restaurant`, branch `codex/phase01-build`, clean base `f73b14b5a7cc6d2421f670938b2435af137ddb0f`.
- Engine build tree: `/Users/eros/.codex/worktrees/phase01-build-engine/Madar_Engine`, same branch name in its separate repository, base `07d2bb1b4c920113457f0338aff2b00410dc9241`. The app's sibling link resolves exactly this tree.
- Independently reviewed engine local commit: `6d4ae39f35b005dfa1123a82c6df316901e1e1e4`; application0.1.0-dev.2, data0.1.0-dev.1, unchanged native-adapter0.1.0-dev.1. Manifest/lock/actual resolved-source check pass. The commit is not yet published; fresh hosted checkout cannot be promised until publication is authorized.
- Dirty preparation trees, prior Phase00 worktree, canonical roots, frozen references and prior Penpot boards are preserved. No production account path was opened. Development bundle remains `com.eros.dakhlrestaurant.phase00`; preferences use only `dakhl_restaurant_phase01_shell/preferences.sqlite` beneath its isolated support root.

The initial native conformance source is retained in `outputs/phase01-build/source-snapshot.json`. Later source deltas are explicitly recorded in the final manifest, rather than retrospectively treating initial runs as exact-final-source tests. Final main-entrypoint builds restore the development applications after diagnostic test entrypoints.

## Local checks and meaningful regressions

| Check | Actual result and evidence |
| --- | --- |
| Full app unit/widget/visual suite | **134 pass**, including five controlled macOS goldens; `final-source-tests.log`. |
| App analysis / format | Pass, no issues/no changes; `final-source-analysis.log`, `final-source-format.log`, command/exit receipts `final-local-checks.json`. |
| Engine independent and compatibility | **5 application +16 actual adapter/process +27 existing native-adapter tests**, all pass; three package analyses/locked resolutions, formatter, boundary verifier and generic example pass. Engine authority: `outputs/cap01/verification.json` and package READMEs. |
| Consumer engine isolation/source resolution | **24 Python checker regressions** and real resolved-source/version/boundary checker pass after reviewed repin. |
| Different-process persistence | macOS/Android/iPhone write-stop-read pairs pass with exact nonce, different writer/reader PID, same shell revision and exact route/six slots; macOS deliberate wrong nonce fails, valid reread recovers. `native-{macos,android,ios}.json`, matching logs and retained harness `integration_test/shell_preferences_test.dart`. |
| Main-entrypoint builds | macOS/iOS final rebuilds pass; Android final debug build/install-preserving-data/main launch pass; final native UI/main restoration is recorded below. Build is distinct from UI/native acceptance. |

Specifications ran red before implementation at their meaningful layers: route/slot normalization/protected reads and save coordination; actual engine transactions/reopen/process interruption; app development-directory boundaries; root navigation/back/dirty cancel/retry. Independent review added deterministic regressions before repairing modal retry, unknown-commit overlapping rereads/null payload, and stale visible text after session Undo. Widget keyboard tests cover Meta/Ctrl bindings and editable-field ownership, including first-slot numbering and current IME search target. These do not establish physical-key delivery.

Initial native persistence pairs compiled the earlier snapshot. Subsequent fixes affect uncertain-commit recovery, UI-controlled fields/semantics, menu hints/layout and root style; the reviewed engine, directory adapter and normal acknowledged persistence contract remain unchanged. Focused regression tests cover those changes and final main native builds use current runtime source. No claim that every initial native interaction was rerun after each presentation-only change.

## Visual and native evidence

Five controlled widget goldens load actual offline fonts/icons/photos and opaque backgrounds, with fixed locale/scale/renderer. They cover controls, desktop Sales, open navigation,390px invoice and320px/200% invoice/actions. Responsive tests additionally cover700/760/761,1024/1440/1920 and root large text. See [visual conditions/differences](../../test/ui/README.md). Independent UX review closed desktop Command hints, frozen menu brand/icons and inclusive760px gutter/stacking corrections; unchanged goldens were not regenerated.

**iPhone through Device Hub27.1:** actual iOS27.0 iPhone18Pro runtime. `native-ui/ios-navigation.png`, `ios-invoice.png`, `ios-keyboard-actions.png`, `ios-discard-guard.png`, `ios-retained-edit.png` show menu/RTL, native keyboard with save/cancel above it, retained typed fixture after canceling discard, and guarded removal of only that fixture. The final rebuilt shell is `ios-final-shell.png`. Final live AX verification shows single explicit menu/editor/Undo labels after duplicate Tooltip metadata was excluded; visual tooltips remain. Independent UX inspected all six captures and found no new actionable visual issue. Screenshots do not certify VoiceOver order, all text scales, every menu item or physical iPhone gestures.

**macOS:** final main application is restored and accessible through its exact build path. Native modifier-key automation was inconclusive: a bounded45-second temporary observer saw no key-down events. Diagnostic exit0 means observer completion only; its source was removed and cleanup verified. No speculative focus implementation was retained. Widget Meta/Ctrl tests pass. The owner subsequently confirmed both real ⌘3 navigation and ⌘K Search focus work in the restored main app; this closes the Mac modifier check by manual observation, distinct from the inconclusive automated probe. Evidence: `outputs/phase01-step3/native-keyboard-probe-disposable-{status.json,log}`.

**Android:** real fresh-process persistence passed on existing emulator-5554, preserving userdata. A focused permanent native test on Android17/API37,411.43×923.43logical at2.625DPR and textscale1, passed with actual Gboard inset336.38logical (initial0). Both actions stayed hit-testable above it; Cancel→continue retained typed model/visible text, explicit fixture discard restored the original route/six slots, and no domain Save was pressed. Test source/hash, command, exit0 and screenshot hashes are in `native-ui/android-native-ui-status.json`. Final main APK rebuild/install-with-data-preserved/launch passed; SHA-256 `0fd1ad33a5698bfe73a965bc0f2159e18d2f298e303bf677f3b9eda1ef1ffb2d`. Use `android-main-visible.png` for the loaded restored shell; earlier `android-main-restored.png` is correctly labeled startup-splash-only. Real back gesture/TalkBack and physical Android hardware are not asserted.

Native test targets are development/emulator targets. No physical phone/printer/provider guarantee, full screen-reader certification or cross-platform byte-equal pixels is claimed. Approved typography, larger targets, focus and narrow layouts retain their approved differences from frozen Electron pixels.

## Independent review, CI and remaining gates

Independent engine review found no actionable defect. App Reviewer closed all three P2 findings through focused re-verification; UX Reviewer closed all three scoped visual P2 findings. Final focused reconciliation independently recomputed74/74 source hashes and confirmed the six documented runtime deltas and evidence-reuse limits; no new code defect was found. Independent native UX inspection found no actionable iPhone/Android visual finding. Android retained test exercises in-app Cancel/discard, not OS Back. Real Android Back/iPhone gesture and native accessibility traversal remain unestablished; the owner manually confirmed Mac ⌘3 and ⌘K both work; do not relabel these artifacts as those passes.

Existing CI gates are preserved. CAP-01 locked analysis/tests and controlled macOS golden verification were added; CI never updates goldens automatically. Local results do not establish hosted Actions results. No new PR/push, production migration, merge, deployment or supported release. Numeric optimization benchmarks **N/A**: no optimization requested or performed.

Rollback: stop the development build and retain its dedicated preferences database; Phase00's separate probe ignores it. Engine tests preserve prior committed/corrupt/future-format data and rollback failed transactions. Uninstall/clear-data/device loss/power loss, arbitrary multiprocess and business recovery are outside this guarantee. Do not reset data to make a test pass.

Before closing Step3 verification: native mobile back/gesture and native accessibility traversal remain open; the owner confirmed the Mac keyboard check passed; final source/evidence reconciliation and separate project memory delivery are recorded by their receipts. Android native IME/layout check passed. Publication/hosted CI and exact owner-approved merge/release remain later gates; no Phase02 advancement.

Separate memory delivery: canonical app110/engine34source checks have no pending/failed work. These checks cover registered canonical roots only. Build-worktree source hashes and final operation completion are recorded separately in `outputs/memory/phase01-build-delivery.json` in each project; read the receipt state before claiming delivery.

Final checkout reconciliation: a later documentation-only engine commit advanced HEAD and the unchanged consumer checker correctly rejected it. Preserve documentation commit `a918fbc053066226ef087a7e39c5a41fa8c8e8c9` on `codex/phase01-build`; consume the build worktree detached at reviewed `6d4ae39f35b005dfa1123a82c6df316901e1e1e4`, with owned documentation/evidence restored from that preserved commit. No runtime file or pin changed, no work was reset/discarded and the exact-source checker passed again. Engine outputs/cap01/final-checkout-state.json records this distinction. Further documentation must not advance the active runtime checkout used by the consumer.
