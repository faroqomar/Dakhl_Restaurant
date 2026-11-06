# Completion CI evidence classification fix

PR11 at31a76d4 failed the quality job during full Flutter analysis. Historical `.dart` probes under outputs referenced deliberately untracked report source and contained probe-only print statements. The outputs symlink exposed the same probes twice.

Both archived probe sources now use `.dart.txt`; Git confirms100% content-preserving renames. No analyzer exclusions, lint changes, tests, app behavior, dependency pin or engine code changed. Engine responsibility/API N/A: documentation artifact classification only. Full local analysis passed with no issues; hosted successor verification remains pending. Raw failed/success logs are compressed losslessly beside evidence. Whole-Completion blockers remain; changed app revision needs renewed approval before merge.

Prevention: keep historical executable snippets in text archives; run full repository analysis after packaging evidence, not only targeted source analysis. This fixes a packaging mistake introduced during Step5. No production data touched.
