# MVP acceptance and cutover checklist

Status: all Flutter checks pending. These checkboxes describe future evidence, not results from the Electron baseline.

The adopted [AGENTS.md](../../../AGENTS.md), [PLANS.md](../../../PLANS.md) and [PHASES.md](../../../PHASES.md) govern execution. Each phase requires dedicated Git isolation and PR traceability, applicable Figma validation/user design approval, meaningful tests before behavior changes and independent review. Record benchmarks as numeric evidence or justified N/A. DONE also requires the approved merged PR and applicable release/rollback checks; never automatically start the next phase.

## Functional completion

- [ ] Phases 00–10 meet their individual acceptance criteria; all 12 current screens and related dialogs work on macOS, Android and iPhone.
- [ ] A complete synthetic day covers purchase invoice → partial/shared settlement → stock → cash sales → hold/resume → refund → expense → record remaining → transfer → review → reports.
- [ ] Original/changed/void/refunded sales, dated stock, supplier balances, payments, daily shares, remaining snapshots and cashbox reconcile with the JavaScript corpus.
- [ ] Every supported old schema imports with the same IDs, snapshots and historical values; worker compatibility data is retained without a worker screen.
- [ ] Every mutation has validation, save status, cancel, failure/retry and restart evidence. No duplicate posting from retry/double tap/restart.

## Visual and interaction completion

- [ ] Actual macOS/Android/iPhone captures are attached for every phase; owner-reviewed changes have decision records and before/after references.
- [ ] Typography, RTL, financial digits, photo assets, colors, alignment, density, dialogs, table overflow, empty and error states match their approved baseline.
- [ ] Small/medium/large screens, phone safe areas, soft keyboard, landscape, large text and reduced motion are covered; primary actions remain reachable.
- [ ] Keyboard, screen reader semantics, focus visibility/trapping/restoration and mobile back/gesture behavior are verified.

## Offline and portable-data completion

- [ ] Core work succeeds with connectivity disabled; no login/network dependency is introduced.
- [ ] Force-close/reopen restores the last committed accounts and the active/held workspace correctly.
- [ ] macOS → Android → iPhone → isolated macOS backup round-trip retains all finalized records and supported settings; drafts remain device-only.
- [ ] Import preview, pre-import backup, replacement confirmation, cancellation, malformed/oversized/future-version file rejection and previous-copy restore are exercised.
- [ ] Disk/write failure and interrupted writes preserve recoverable valid state. Concurrent/stale writer conflicts cannot overwrite a newer account/workspace.

## Reports and native services

- [ ] Seven report types export on all targets; actual PDFs are rendered and all pages inspected for Arabic shaping, pagination, long text and exact totals.
- [ ] System share/save/open works on Android and iPhone, and save/open/reveal works on macOS where appropriate.
- [ ] Native system print dialogs are tested, including no printer/cancel/failure; no accounting mutation occurs during printing. Physical successful printing is recorded when a compatible printer is available; do not claim it without evidence.
- [ ] Native file pickers and permission-denial paths are tested outside widget tests.

## Installed delivery and rollback

- [ ] Signed macOS, Android and iPhone artifacts use the agreed delivery channels and preserve data after an update.
- [ ] Each platform has a physical-device installation/launch/native-service record with app build, OS and device model.
- [ ] A synthetic migration rehearsal succeeds before live cutover. Any later live import uses a private verified backup, amount/record-count comparison and an untouched rollback copy.
- [ ] Electron and Flutter never write the same production file concurrently. A rollback restores the correct backup/version rather than trusting an incompatible newer export.
- [ ] The owner receives builds, source, release notes, known limitations, backup/recovery instructions and rollback instructions.
- [ ] No unresolved incorrect-total, lost-record, duplicate-posting or failed-recovery defect remains. Missing credentials, hardware or native test evidence are listed as blockers.

## Evidence record per target

| Evidence | macOS | Android | iPhone |
| --- | --- | --- | --- |
| Signed installed build + OS/device | Pending | Pending | Pending |
| Complete day flow offline | Pending | Pending | Pending |
| Domain/data parity corpus | Pending | Pending | Pending |
| Native file import/export/recovery | Pending | Pending | Pending |
| Draft/held restart recovery | Pending | Pending | Pending |
| Visual/keyboard/large text | Pending | Pending | Pending |
| Seven actual PDFs inspected | Pending | Pending | Pending |
| Share/open/print native behavior | Pending | Pending | Pending |
| Update persistence + rollback | Pending | Pending | Pending |

Flutter’s official integration_test does not interact with native platform UI; combine domain/widget/integration checks with native device verification for file pickers, share sheets and print dialogs. Source: [Flutter integration testing](https://docs.flutter.dev/cookbook/testing/integration/introduction).

Delivery references, to recheck during implementation: [iOS/TestFlight/signing](https://docs.flutter.dev/deployment/ios), [Android release/signing](https://docs.flutter.dev/deployment/android), [macOS release/signing](https://docs.flutter.dev/deployment/macos).
