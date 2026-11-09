# Native ICU code/resource layout fix

Date:2026-11-08. App-owned native packaging fix; engine implementation/API/pin change:N/A because the existing canonical signed native payload and adapter remain unchanged. No normal app/account launch, native rebuild, Git mutation, source export or dependency change ran in this lane.

## Defect and change

The first current native macOS pilot failed before launch: CodeSign treated `Contents/Frameworks/MadarIcu/LICENSE` as an unsigned nested code object. The old generated layout mixed plain license/provenance files with Mach-O code.

`scripts/embed_icu_macos.py` now keeps only the original signed dylibs and exact loader symlinks beneath `Contents/Frameworks/MadarIcu`. It copies LICENSE and the unchanged source manifest into `Contents/Resources/MadarIcu`. The source comparator loader path and relative `@loader_path` topology stay unchanged. The helper neither re-signs nor rebuilds native code. All canonical native file hashes remain checked before and after staging.

Existing old generated copies migrate only after full payload verification. New-layout reuse verifies both code and resources and retains the code inode. Changed or unexpected files in an existing generated copy cause refusal; cleanup never deletes uncertain files. Canonical engine source can retain its separate loader-smoke evidence, which is not copied into the app.

## Executed checks

Four Python tests pass: code/resource separation with unchanged native bytes/topology and inode reuse, verified old-layout migration, changed old payload preservation/refusal, and unknown generated file preservation/refusal. Tests use small synthetic bytes and temporary roots; they do not prove native signing. Existing `test/app/source_collation_runtime_test.dart` two cases pass against the canonical runtime. No Flutter source or Xcode phase change was necessary.

Root owns independent source recheck, fresh source-bound preflight, rebuild, outer-app CodeSign and sandboxed ICU-load acceptance. The original CodeSign failure remains preserved in `outputs/completion-review/review-stage-001/native-campaign-001/macos-pilot-attempt-001.log`. No native pass is inferred from unit tests.

## Storage

The lane created only the helper/test source, this compact receipt and small temporary tests. Unit-test temporary directories were removed by their registered cleanup. Explicit task scratch scripts/recall copies were removed after use. The parent owns the canonical native build and full campaign storage/memory reconciliation.

Initial lane free disk:89,340,144KiB; final:89,315,272KiB (−24,872KiB global movement). Final canonical sizes: `.git`18,442,132KiB, `build`2,161,348KiB, `outputs`7,400,168KiB. Source/test/log additions are small; global concurrent movement is not attributed to this lane. No native bundle copies or staging directories were retained by the lane; reproducible temporary fixtures were cleaned. Initial per-directory sizes were not sampled, so their lane deltas are unknown.
