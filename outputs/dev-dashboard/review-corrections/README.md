# Corrected tooling verification — 2026-10-29

Captured against app source e385ce604d30f1388580b6c436ccfd64489494fb, benchmark tools 75c12fb436468b9149eedb59215a6a2632a2c480, and exact consumed runtime engine 6d4ae39f35b005dfa1123a82c6df316901e1e1e4. This commit adds evidence only. The dirty flag is retained: local evidence/receipt files existed during measurement. No optimization or supported release is claimed. Independent read-only verification rechecked the actual source/tool fingerprints, Xcode/SDK identity, result validation and comparability keys without rerunning the measurements.

Local checks: analysis has no issues; 158 Flutter tests, 28 script tests and 7 profile-cache tests pass. checks.json records each actual exit code; separate logs preserve command output. Raw tool output can contain analyzer/test formatting whitespace and is not authored source.

All three macOS profile scenarios passed with cleanup complete and no diagnostics:

| Scenario | Samples | Median ms | p95 ms | Sampled peak RAM MB | Average CPU % |
| --- | ---: | ---: | ---: | ---: | ---: |
| Startup | 5 | 561.583 | 1188.382 | 186.483 | 59.645 |
| Route switch | 20 | 14.231 | 22.978 | 197.329 | 29.583 |
| Save shortcuts | 20 | 13.648 | 18.600 | 193.298 | 28.114 |

This is a new provenance baseline after tool corrections, not a speedup comparison against older fingerprints. CPU uses one logical core = 100%; sampled RSS covers the direct process and may miss peaks between samples. Startup uses a fresh process through shell bootstrap and raster receipt, excludes compilation/installation and leaves OS caches uncontrolled. Workflow timing excludes native input dispatch; resource windows include protocol/receipt waits. Exact samples, environment, toolchain and scope are in profile-results.json.

Configured CI and automatic review must be assessed at the final PR head separately. Copilot review was unavailable because of quota; no passing review is invented. TalkBack is owner-excluded, not tested. No merge, deployment, release or next phase is asserted by these local receipts.
