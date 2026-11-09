# Bundled ICU consumer composition

Date: 2026-11-08. Actor: bundled_icu_consumer. Status: source implemented and host source tests passed; native target qualification remains with the parent campaign.

## Scope and ownership

Dakhl_Restaurant now resolves `IcuCollationAdapter.loadBundled()` through the reviewed Madar package. The app owns its two explicit source profiles: en-US event comparison and ar saved-material-name comparison. Unsupported or unavailable native assets return no comparator; the loader does not substitute host sorting. Explicit `loadLibrary(path)` remains available for historical isolated macOS smoke checks. The adapter owns cleanup when either profile cannot open and when the app closes the runtime.

Madar implementation/API changes: N/A in this task. The parent owns the new package revision, strict-hook configuration and target packaging. This consumer consumes [the engine bundled-native contract](../../../Madar_Engine/docs/reference/icu-bundled-mobile-contract.md); it contains no copied engine implementation, corpus or native library source. Design: N/A for runtime composition and acceptance tests.

## Tests and evidence

- Added the bundled consumer regression before changing runtime code. It failed against the executable-relative loader; `bundled-consumer-source-red.log` retains the failure.
- After composition changed, all three source tests passed: missing explicit runtime fails closed; bundled runtime opens distinct profiles and enforces normalization/NUL/strict-input/lifecycle behavior; historical explicit-path compatibility still works. Evidence: `bundled-consumer-source-green.log`.
- Added `integration_test/bundled_icu_native_test.dart`. It calls the engine's opt-in conformance helper, requires 1,506 compared pairs (1,384 reference plus 122 independent) and 20 edge checks, then verifies the actual app runtime's distinct profiles and disposal. It emits finite-corpus hashes and target identity in structured report data. It never accesses an account or preferences store. Native execution has not been claimed by this worker.
- Updated the retained complete-envelope native smoke to require bundled runtime availability on the qualified ARM64 target instead of asserting mobile unavailability. Removed stale nullable-report conditions after the required assertion.
- Four owned source paths analyze clean. The parent requested additional QA-main analysis; it exposed a missing root-owned import for `RestaurantAccountProfile`. The parent received the exact source path (`restaurant_journal_mapper.dart`). Field-access analysis found no fence-field errors. Failed supplemental analysis remains in `bundled-consumer-analysis-final.log`; it does not invalidate the clean owned-source result.
- Formatting reports zero final changes. The parent coordinates pub-get, native compilation, target execution and final independent review. No native build, device action, pin/configuration change or Git mutation occurred in this task.

Evidence root: `outputs/completion-review/remaining-completion-001/`. Source hashes, storage and ownership: `bundled-consumer-handoff.json`.

## Storage and efficiency

Free space: 84,380,528 → 84,378,300 KiB; shared activity prevents attributing global changes to this worker. Git remained 18,525,496 KiB with no temporary object stores. Build shrank 26,024 KiB, outputs grew 304 KiB and `.dart_tool` stayed unchanged. The four source files and compact test logs remain canonical acceptance artifacts. Removed the worker-owned 256,720-byte temporary required-document aggregation after reading; no account data, design source or recovery evidence was removed. Source scratch deletion is logical-byte accounting, not a claim about APFS physical reclamation.

Initial command output combined unrelated large documentation chunks and truncated the result. Later reads narrowed to the actual API, source and decisive test output. Token/cost and exact task-start timing are unknown; the parent timer owns campaign timing. Avoid repeating full documentation concatenations or native work whose receipt already exists.

Next action: parent runs the new conformance integration on macOS ARM64, iOS ARM64 simulator and Android ARM64; physical-phone execution remains unavailable per owner. A compiled iOS device artifact does not establish physical execution, signing acceptance or release readiness.
