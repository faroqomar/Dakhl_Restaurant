# Mounted acceptance test repair

Date: 2026-11-08. Status: callback tests repaired; C1 bootstrap routing defect referred to composition owner. No independent/native acceptance claim.

## Ownership and boundary

Worker owns `test/accounts/account_callback_fence_test.dart` and `test/catalog/c1_visible_recovery_workflow_test.dart`; root owns production composition. Madar changes: N/A, existing store/fence contracts suffice. No engine pin/API change, Git mutation, real accounts or native target launch.

## Changes and checks

The former callback tests inspected the replaced Phase01 demo surface. They now capture the actual mounted SalesSurface model, call its retained form-save callback after generation replacement, and assert disposed refusal with unchanged workspace bytes/write count. Oversized draft coverage uses the mounted shell's public form setter, preserving the retained 20 MiB invalid draft and zero additional store writes.

The narrow run passed both callback cases. C1's first real-store case still failed at mounting. Its original attempt then stalled in teardown and the owned runner was interrupted after about 37 seconds. A real-zone mount successor completed teardown but retained the failure. A third bounded attempt added explicit shell-readiness diagnostics: account saved, account not busy, shell ready, route sales despite the fixture's persisted inventory route. Production routing repair belongs to root; no timeout was extended and no condition weakened. Current fixture starts native-backed initState inside tester.runAsync and retains a useful state diagnostic on failure.

Evidence: `outputs/completion-review/review-stage-001/acceptance-repair-attempt1.log`, `c1-mount-attempt2.log`, `c1-mount-attempt3.log`. Compiler window returned to root. Full C1 successor and focused analysis remain pending.

## Storage

Baseline sample: free 93,951,132 KiB; app .git 18,440,772 KiB, build 2,182,764 KiB, outputs 7,398,940 KiB. Only two test sources, this compact log and retained bounded test receipts were created/changed. No copies, exports, screenshots or disposable account fixtures retained by this worker; existing test framework cleans its synthetic temporary directory. Parent owns final aggregate storage/memory delivery. Concurrent global disk changes are unattributed.
