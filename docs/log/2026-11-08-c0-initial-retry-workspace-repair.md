# Initial account retry workspace repair

Recorded: 2026-11-08T07:36:03.905584+00:00. App-owned bootstrap/shell composition; engine runtime/API changes: N/A. Current reviewed engine pin is ac8b4edc2c915ed22c0991685c33967b3360e7fa, a test/log-only successor preserving bb00 runtime values.

The new real PowerSync bootstrap suite exposed an access-denial retry regression: after a genuine OS-denied account-root open, restored access and visible Retry loaded Saved with the expected document/fence/revision, but the form workspace became empty. The preserved final red run had five passes and one failure. That finding establishes in-memory workspace loss; no disk overwrite was asserted for that run.

The shell previously skipped restoring first authority after initial bootstrap to preserve legitimate local drafts on first account creation. That exception also covered a late existing account revealed by retry. Root added a latch for an initial protected read and restores that account's workspace before queuing any new workspace. It clears the latch once authority is adopted; genuine absence followed by explicit first save still preserves a local draft.

The shared host/native cases now assert both sides: the pre-save draft survives first creation and healthy reopen; denied-root Retry restores the seeded form with zero mutations, unchanged workspace revision1/token and actual disk payload. All six real-store host cases pass; targeted analysis reports zero issues; all109 affected app/catalog tests pass. [Source/result freeze](../../outputs/completion-review/c0-protected-bootstrap/root-repair/review-inputs.json). Old red snapshots/logs remain immutable.

C0-10 source review and actual target execution remain pending. Earlier C1 runtime and performance results retain their historical source identity; this narrow later app.dart change needs explicit compatibility assessment, not an assertion that their old full-source manifests still match current. No UI design/policy/live account/native/remote action occurred in this repair. The root Flutter window is released after the above completed host commands.

New fixture cleanup runs through owned marked-root teardown and restores temporary POSIX permissions. Worker removed two confirmed interrupted task roots before handoff. Preserve canonical binaries, original input/recovery evidence and the retained2KB synthetic native export. Final storage review and separate project memory delivery follow the review batch; neither is implied by test success.
