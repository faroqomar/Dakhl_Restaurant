# PR11 lifecycle child native assets

CI run 42534413186 at 9537df0 passed 1,425 tests and failed the two SIGKILL lifecycle checks before their checkpoints. Both child processes could open a protected store but could not read the host-created base. The direct VM invocation bypassed Dart native-asset hooks; this is consistent with Linux lacking dependencies that the local macOS environment supplies. The precise child capability code was absent from the original failure, so that diagnosis remains an inference pending the hosted successor.

The app test harness now uses `dart run`, matching Madar’s existing process-test launch convention. Child failures include the safe capability code. Both checkpoint, SIGKILL, complete-envelope, CAS, retry and replay assertions remain unchanged. Madar runtime/API and app persistence changes: N/A; this is consumer test-process composition.

All five focused lifecycle tests pass locally, including both real process kills; analysis reports zero issues and formatting changes zero files. Hosted Linux successor remains pending. Independent read-only recheck found no blocker and confirmed the engine harness convention. No duplicate compiler run or timeout relaxation was needed. Evidence: `outputs/completion-review/ci-lifecycle-20261109/`.

Storage: free space 82,569,808 → 82,492,812 KiB across this batch; initial evidence 8 KiB, no Git temporary object stores. The shared-volume difference exceeds these small receipts and is not attributed to them. No cache cleanup, production accounts or runtime bundles changed. Retain these bounded receipts for the CI repair.
