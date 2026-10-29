# Phase 01 — app shell contract and development setup

Date: 2026-10-29. Implementation preview for the owner-approved Phase 01 plan/designs. Shared storage is Madar-owned; this document owns only consumer composition, payload/UI semantics and safeguards. Exact checks, native evidence, remaining gates and revisions are in [build evidence](../phases/01-build-evidence.md) and [PHASES.md](../../PHASES.md).

## Packages and startup

Use Flutter 3.47.8 / Dart 3.13.7 and the committed lockfiles. The app resolves sibling `../Madar_Engine` packages. The current locally reviewed engine candidate is `6d4ae39f35b005dfa1123a82c6df316901e1e1e4`: `madar_application 0.1.0-dev.2`, `madar_data 0.1.0-dev.1` and unchanged `madar_flutter_adapters 0.1.0-dev.1`. This commit is local until separately authorized publication; do not claim a new remote checkout can fetch it yet. Before consumer verification, run locked dependency resolution and `python3 scripts/check-engine.py` to verify the actual resolved source, versions and boundaries.

`main.dart` composes `AppPreferencesStore.native()` and `DakhlRestaurantApp`. The app adapter supplies its development location and delegates all persistence to Madar. It shares one initialization, retries initialization failures on a later read, and releases a store that opens after disposal. `ShellPreferencesDirectory` permits only its own `dakhl_restaurant_phase01_shell/preferences.sqlite` beneath application support; it rejects legacy names and linked/non-file destinations. This is separate from the Phase 00 probe and installed legacy restaurant data. No SQL, business data or storage algorithm is implemented in the app.

Riverpod supplies the app ViewModel; go_router opens its twelve bounded destinations. UI components consume strings/selection models and callbacks. `ShellViewModel` owns presentation state, guards and preferences coordination. A router request and a shortcut/menu request use the same dirty-state decision; unknown/retired routes fall back to Sales. Desktop application-exit requests and mobile back use the same guard. Unavailable/corrupt/newer preferences permit safe session navigation without silently writing defaults over protected data.

## Persisted payload and state

Namespace: `dakhl_restaurant.shell.v1`. Exact v1 JSON fields:

```json
{"schemaVersion":1,"lastRouteId":"sales","shortcuts":["sales","inventory","sale-history","expenses","cash","settings"]}
```

Exactly six string slots preserve order, duplicates and empty slots. Known retired `savings` becomes empty; unknown last route becomes Sales. Defaults do not become a saved migration merely because initialization completed. Malformed/newer data is retained and reported; do not delete/reset it to make startup pass.

The UI announces Saved only after the engine acknowledges a complete snapshot. Failed saves retain drafts and expose an explicit retry in the modal as well as the shell. Conflict recovery rereads without writing, keeps the editor draft and requires a later deliberate save. Unknown-commit recovery is single-flight, reads back before retry and preserves later navigation intent. Gated initial reads, generation guards and disposal prevent stale responses from replacing newer state.

Session form/ticket maps and undo callbacks never enter this payload. Session Undo restores visible controlled date/discount text and quantity presentation as well as the ViewModel. It does not reverse posted money or implement sales calculations. Durable account/settings workflows, ticket recovery, stock, posting, purchasing and recovery remain in later owning phases. All non-Sales destinations are bounded shell surfaces; synthetic Sales/invoice examples do not implement those workflows.

## Presentation and accessibility

Amiri Arabic and Inter Latin/tabular numerals are bundled offline with licenses and immutable source hashes under `assets/fonts/`. Eight approved frozen photo assets under `assets/ui/` remain synthetic examples. They do not create a product menu or claim full 33-item screenshot parity.

Approved effective tokens, desktop Command hints, menu brand/icons/group order, 24px/14px gutters (narrow through760px), stronger focus, at-least44px targets and narrow/large-text stacking are implemented. Controls include default/focus/disabled/loading/invalid/error states, standard/wide guarded dialogs, table/filter/pagination and compact status/retry shells. Root-owned search focus and session command dispatch remain separate from native text undo. Save/cancel remain reachable by scrolling with large text and keyboard insets.

Five controlled macOS widget goldens verify current component/Sales/menu/invoice layouts. They are not native screenshots or cross-platform pixel-equality claims. Tests load bundled fonts/photos/icons, pin sizes/text scale and reject unexplained changes. CI excludes `golden` in the Linux quality job and verifies that tag on the pinned macOS host; it never updates baselines automatically. See [visual test conditions](../../test/ui/README.md).

## Verification and limits

Use `flutter test --no-pub`, `flutter analyze --no-pub`, formatting, the Python source-checker regression suite and the boundary verifier. Native persistence uses `integration_test/shell_preferences_test.dart` with a fresh UUID, write/stop/read stages, `--no-uninstall`, a persisted nonce marker, a different-process PID and exact restored route/six slots/revision. A wrong-nonce negative check must fail before a valid recovery read; do not count stale state as acceptance. Native tests use only this isolated development store.

Structured debug diagnostics come from the engine event sink and contain event/level/operation/outcome/code/duration, never payloads, namespaces, paths or account data. No remote telemetry, connector, authentication or upload queue is composed. Failure copy is translated by the app, not raw engine diagnostics displayed to users.

Normal acknowledged process-restart persistence is covered. Power-loss/device loss, uninstall/clear-data retention, arbitrary multi-process access, financial migration/recovery, physical printing/hardware and unsupported platforms are not promised. Downgrade retains this dedicated database; Phase 00 ignores its separate location, and unknown/newer payloads remain protected. Published source and prior-head CI are verified in the linked PRs. Changed review-correction heads still require fresh CI and exact-revision approval; source integration and supported release remain separate.

## Step4 routing and feedback corrections

A healthy reread may preserve a newer session route without writing. The shell now respects hasUnsavedPreferences and shows an informational unsaved warning instead of claiming Saved. Native Android framework Back registration must stay true for a guarded destination: both outer ShellRoute and inner page share one reactive PopScope decision and single-flight back command. The iOS-only leading-edge completion adapter is restricted to24logical edge pixels, touch input and dominant completed travel; it defers to child gestures, excludes open menu/modals and Sales, and uses the same dirty guard. It adds no history or pop animation. These are repairs of the approved interaction contract, not new engine capabilities.

Historical independent verification; current live screen-reader acceptance is owner-excluded, not passed: [Step4 report](../phases/01-step4-review.md). TalkBack settings were restored after inconclusive automated traversal; do not claim a full accessibility pass.
