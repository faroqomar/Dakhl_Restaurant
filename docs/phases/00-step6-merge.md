# Phase 00 — approved integration, incomplete acceptance

Date: 2026-10-28. The owner invoked Step6 after the exact phase revisions were presented and separately approved prerequisite snapshot `ecf692b49672fa9e1d64a983f89ba7ccf16cf0fe`. Design approval and completion are separate gates.

| Order | Approved revision | Merged PR / commit |
| --- | --- | --- |
| 1 | Engine `784b139753a0e2a07d3f97eedb326debfe068395` | [Madar PR1](https://github.com/faroqomar/Madar_Engine/pull/1), `f8c31256dc1066f337a46710f7bfe5a3fe842fb1` |
| 2 | Snapshot `ecf692b49672fa9e1d64a983f89ba7ccf16cf0fe` | [App PR1](https://github.com/faroqomar/Dakhl_Restaurant/pull/1), `1fb8a82a582308498b8527d69e4b060c85c69dd4` |
| 3 | App `00baa5731776ecb7b0fe91911892cd5006d421f4` | [App PR2](https://github.com/faroqomar/Dakhl_Restaurant/pull/2), `c7f4a4202fb248e614c536ecbed67d8864f24685` |

Normal merges preserved approved-head ancestry. Engine merge and approved head both have tree `552c2a0d7c98b45e4f79c400437fea96805ecc9a`; app merge and approved head both have tree `a9de0f008a4dba6abef4a26acac2e40f3ae8058f`. The snapshot merge tree matched the app's reviewed base. After retargeting app PR2 to main, its binary diff SHA-256 remained `ffa4231438edc1a23f0ae1064dc999c1c3e1862d3e02d6edebdf868476fa135e`. No approved implementation was revised. `engine-dependency.json` retains the exact approved engine pin; this follow-up changes only its descriptive status.

All six premerge Actions checks passed: [Flutter quality and three builds](https://github.com/faroqomar/Dakhl_Restaurant/actions/runs/40710445554), [frozen integrity and reference regressions](https://github.com/faroqomar/Dakhl_Restaurant/actions/runs/40710445475). Cubic completed on app `00baa57` with zero findings. The earlier independent source-resolution P2 remains closed. Local Step6 source-resolution/boundary verification passed. Dated 48 app, 27 adapter, 24 dependency-gate and 140 reference test results remain linked in [Step4](00-step4-review.md), not relabeled as new executions. Benchmarks: N/A, no optimization.

Postmerge checks: [main reference run40717097493](https://github.com/faroqomar/Dakhl_Restaurant/actions/runs/40717097493) passed. [Main Flutter run40717097492](https://github.com/faroqomar/Dakhl_Restaurant/actions/runs/40717097492) is in progress at this record's preparation; its result must be recorded separately. Skipped CodeRabbit is not a pass.

## Snapshot review dispositions

Cubic completed on snapshot `ecf692b` with 55 findings. Independent reviewer `phase00_delivery_audit` triaged all 55 and found no additional blocker for passive preservation of the explicitly approved private snapshot. They are not all fixed or false positives. Groups: 12 skill/evaluation-guidance; 24 documentation/planning/provenance, including two privacy claims; one reference PDF layout; two overlapping Electron verification harness; 14 historical outputs/tools/evidence; one machine-specific memory-wrapper issue; one preview-helper security issue.

The valid DNS-rebinding issue in `electron-reference/scripts/preview-design.cjs` requires Host/origin hardening and adversarial tests **before the helper is used again**. It is not the Flutter entrypoint, reference package start command or current CI path; it was not launched for this merge. Private visibility and loopback binding do not fix it. Historical Figma component signature/wrapping/binding defects remain if those tools are reused; Penpot supersedes that incomplete transfer. Stale harness paths and overclaimed historical focus/totals evidence cannot support current acceptance. Token inventory discrepancies need resolution before phase01 implementation; no phase01 work starts here.

The privacy claims concern documented owner-requested menu planning and an explicitly illustrative order, and do not establish an account-data leak. This is not comprehensive privacy certification or authorization for public publication. No figures are reproduced here. Preserve archival/source records; any fixes to approved revisions require renewed approval. Madar changes for these reference findings: N/A, app/reference-only responsibility. Engine review separately records its Windows portability defect and pinned SDK limits in its own Step6 log.

A postmerge GitHub API check confirmed 17 open [Dependabot alerts](https://github.com/faroqomar/Dakhl_Restaurant/security/dependabot), all in `electron-reference/package-lock.json`: 16 for undici and one for Electron, with nine high and eight medium severity labels. They remain unresolved. This is a dependency-alert inventory, not an exploitability/reachability assessment or Flutter security certification. Dedicated advisory/reachability triage and applicable remediation are required before legacy app/tool reuse or release. The approved frozen dependencies were not silently upgraded.

## Remaining gates and recovery

Phase00 remains **BLOCKED**, not DONE. Explicit approval of the three Penpot reproductions/wireframes and required iPhone Simulator native chooser/export/reopen/share/print evidence remain pending. Simulator is the authorized target; physical-phone signing is deferred, not passed. Existing provider materialization/cache, external replacement rollback, coordinated cross-process/power-loss durability and physical-output limits remain. The engine's supported business release and financial policies are not established.

No deployment, installation, production-data access, migration or rollback occurred in Step6. The isolated dev app may be stopped without altering preserved Electron/data. Any later source rollback must revert the consumer phase before removing its engine dependency, using the recorded merge commits and fresh authorization. Future phases remain TODO. Documentation follow-ups are reviewable changes requiring their own revision approval before merge.
