# Bootstrap and recovered-navigation successor

Date:2026-11-08. Source ownership: app composition/settings and the existing C0/C1 host acceptance helper only. Madar runtime/API change N/A: the defect is a missing consumer observer wakeup; shared persistence remains engine-owned.

The current failed-suite log narrows C0 loading/first creation to retained workspace form persistence (helper line143), rather than account recovery generally. Corrupt-primary/future/orphan/denied-root successors already pass in that log. `_queueWorkspace` refuses work while the newly bound sales owner loads, but `_bindSales` originally attached no root listener to sales completion. Added `_queueWorkspace` as a sales listener so retained shell form work resumes when that owner becomes idle. Existing generation/mutation guards remain.

C1 committed-unknown readback navigation still needs a bounded diagnostic; temporary test instrumentation records settings presence, settings dirtiness, repository uncertainty and discard-dialog presence after the existing Inventory action. No timeout or assertion was weakened. Source analyzer passes; focused execution awaits the serialized compiler window.

Initial storage free93,840,496KiB; final storage/actual checks pending. No Git mutation, production account access, native launch or disposable account copies created.

## Verified successor

C1 diagnostic showed settings present, no dirty values, no uncertain repository write, but the shell still requested discard. The local settings route did not subscribe to AccountsViewModel; its nested AccountsSurface recovered while the parent pending signal stayed stale. Added an accounts ListenableBuilder around local SettingsSurface, preserving the long-lived editor and dirty guards. Its existing post-frame signal now updates after readback. Isolated committed-unknown → readback → Inventory case passes. Temporary diagnostics are removed.

The first C0 successor passed retained form persistence, then exposed a helper race on fresh-owner reopen: native account acknowledgement preceded settings route rendering, so its one-time Data-tab check ran too early. The helper now waits for either the direct AccountsSurface or the actual Data tab before clicking it, retaining the original40-second deadline and assertions. The first-case successor passed with exact workspace/revision retention.

The four-suite check then caught one implicit workspace mutation on healthy denied-root retry: waking the root queue had serialized the fresh in-memory fallback ticket even though the acknowledged legacy form had not changed. The root queue now exits when sales owns ticket persistence and shell form equals the acknowledged form. User form edits still persist; healthy reopen remains byte-preserving.

Final combined C0 bootstrap, C1 visible recovery, assembled portable/normal app settings/undo and settings/report widget suites pass **22/22** in9seconds. Final app/helper analysis is clean. Evidence: `outputs/completion-review/review-stage-001/bootstrap-navigation-final-batch.log`; earlier failed/diagnostic receipts remain alongside it. No timeout extension, test skip, weaker assertion or production-account access occurred. Source frozen and compiler released to root.

Storage final sample is appended below. No disposable native outputs created by this lane; retained bounded logs document failed attempts and fixes. Root owns final aggregate storage and separate project memory delivery.

Final storage:free90,649,936KiB; Git18,442,132KiB/build2,215,960KiB/outputs7,399,660KiB. Against restart reference Git18,441,904/build2,183,840/outputs7,399,524, differences are228/32,120/136KiB. Lane created source+compact logs only;0bytes removed. Global free delta exceeds2GiB and is outside those measured app-directory changes; root is concurrently booting iOS, but this sample alone does not attribute cause. Root must reconcile global growth before expanding native batches; no uncertain artifact was deleted.
