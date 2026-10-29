# Phase 01 presentation verification

`presentation_test.dart` covers component semantics and observable interaction using synthetic strings/callbacks: invalid/busy state, hidden menu, Escape/focus return, modal focus cycle, dirty cancel, actual test keyboard insets, shortcut choices, desktop catalog/bill ordering, quantity intents, and 320/200% reflow through 390/1024/1440/1920.

`visual_contract_test.dart` is tagged `golden`. Its five snapshots were generated, visually inspected, and then compared without updating. Conditions: macOS host; Flutter 3.47.8, framework 737ba8f885, engine cf636b1dfb; widget-test renderer/default test target; ar locale; device scale 1; offline bundled Amiri Regular, Inter variable and MaterialIcons; photos explicitly decoded before capture; fixed synthetic presentation values. Font bytes/provenance are in `assets/fonts/SOURCE.md`. The 320px image uses actual 200% TextScaler and scrolls to both actions.

Run comparisons with `flutter test --no-pub test/ui`. Golden CI must use one controlled environment and must not update baselines automatically. The Lead owns root test-tag registration and CI selection. Cross-platform native pixels are separate evidence.

These snapshots verify the current bounded implementation, not byte equality with Electron or approval of new designs. Differences have scoped reasons: approved actual Amiri/Inter text replaces macOS outlines; targets increase to at least 44px; the synthetic catalog contains eight provided photo examples rather than the entire 33-item reference; extra-large text stacks/scrolls labels and actions; the toolbar becomes scrollable if its wrapped height would consume the view. Native OS calendar/select rendering and font rasterization can differ. The source focus, radius, gutters, effective sales accent and money/date direction roles remain explicit in the widget code.

Quantity controls emit strings/step intents and do no numeric or money arithmetic. The bounded sales/invoice examples never post or save domain records. Root shell ViewModels own session state, preferences and guarded commands; engine contracts/adapters are outside these widgets. Placeholder routes deliberately contain no later-phase domain workflow. Widget tests and static goldens do not establish native accessibility, keyboard, safe-area/back behavior, process restart persistence or engine conformance; those remain Lead/native/independent-review gates.


## Independent review corrections

The three visual P2 corrections restore the desktop numbered shortcut hints, the frozen sidebar brand/subtitle/route icons, and inclusive narrow gutters at700/760 versus761px. The Sales stacking boundary is inclusive at760px as in the same frozen media query. Empty shortcut slots retain their original numbering. Source evidence: `electron-reference/app/ui/index.html:22–37`, `commerce.js:7`, `ux.js:85`, `ux.css:4/8/178`; frozen icon vectors remain the existing renderer.js paths. The desktop Sales snapshot changed only for the visible hints; an open-menu snapshot was added and visually inspected. The three controls/invoice PNG baselines remain byte-identical. The open-menu golden enables real shadow rendering explicitly; the debug flag is restored in `finally` before test invariants run.

The editor adds controlled retry/canSave presentation so the root can expose a read-again action after a protected conflict instead of an inert Save. The root owns recovery behavior. A root-app regression reproduced stale visible date/discount after session Undo; both fields now use DakhlField's optional controlled `value`. Controlled fields adopt a changed external value while preserving active text/selection when the supplied value is unchanged. Tests verify model and visible text after edit/blur/Undo and navigation away/back. `initialValue` remains one-time initialization for uncontrolled uses.

## Native delta evidence

The current native Android invoice test uses real view metrics/OS keyboard, no inset/size overrides, and retains/discards only its synthetic fixture before restoring route/six slots. It does not submit a domain save or establish TalkBack/native back gestures. iPhone Device Hub captures and final live AX labels are separate. Current conditions, screenshots, compiled source snapshots and limitations are in docs/phases/01-build-evidence.md.
