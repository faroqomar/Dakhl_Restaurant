# Repeated problems and prevention — Dakhl_Restaurant

Date: 2026-10-28. Status: owner-directed standing practice, documented locally. Source: observed phase00 preparation, design, builds, reviews and merges, plus the owner's request to prevent repeated time/token waste. The catalog records failure, cause and prevention; it does not claim all underlying issues are repaired. Exact total time/tokens were not measured.

## Apply on every task

Before retrying a known issue, consult its entry and the relevant task skill. Record every new/repeated complication during the task: symptom, cause, failed attempt, verified remedy or unresolved status, prevention, evidence and owning project. Include unnecessary agent work. Update existing entries instead of duplicating guides. Keep accounts, credentials, raw conversations and hidden reasoning out.

Read required rules once per task, then refresh changed sections/current facts. Use bounded output and wait intervals, a small evidence ledger and focused specialists. Batch stable documentation before final review when possible. Preserve required tests, independent review, design/revision approvals and truthful pending states. The engine counterpart owns shared capability/source lessons; this record owns app integration, design and reference behavior.

## Workflow and integration lessons

| ID | Observed problem / cause | Prevention and verification |
| --- | --- | --- |
| A01 | Broad file/tool/memory reads were repeated and returned oversized/truncated output. | Query exact terms/fields, inspect relevant sections and cache useful identifiers. Discover names before requesting one tool schema. Filter structured results before returning them; truncation is not successful inspection. Do not reload unchanged rules for every small follow-up in the same task. |
| A02 | Repeated status polling and duplicate reviews/builds lengthened the run. | Batch independent queries and use event/cursor support or sensible backoff, normally 45–60 seconds for active builds. Reuse established evidence only with revision/environment continuity; review deltas plus affected risks. Do not manually rerun every platform for a prose-only edit. Required hosted checks remain required. |
| A03 | Postmerge documentation was split into new PRs, triggering another full platform pipeline and new approval round. | Prepare stable docs with phase changes before review. Record unknowable final merge IDs/run outcomes in PR metadata or a dated evidence record, then batch necessary follow-ups. Do not create an endless commit/build loop to record a document's own merge. A genuinely changed approved head still needs renewed approval. CI optimization itself needs its own authorized change; no bypass or silent path-filter edits. |
| A04 | The older snapshot dependency was not resolved until merge time. | Present baseline PR, engine PR, app PR, target branches, exact heads and merge order together. Obtain missing prerequisite approval early. Retarget to main only after verifying the merged baseline and unchanged phase diff; never report a merge into a staging branch as main integration. |
| A05 | Private engine checkout failed before hosted tests; workflow upload also hit CLI credential-scope rejection. | Preflight the delivery path and engine-only source access early. Reuse the configured authorized read-only access and existing GitHub integration; verify actual checkout and exact revisions. Never print keys, delete CI or broaden credentials to work around the error. See the engine counterpart for ownership details. |
| A06 | The recorded engine pin did not originally prove resolved Dart imports. | Keep `scripts/check-engine.py` and its meaningful redirect/override/YAML/source-cleanliness tests. Verify actual package configuration/lock and clean source at the recorded engine checkout. Normal engine merges can preserve the reviewed source ancestor; do not repin just for a docs merge. No copied engine implementation. |
| A07 | Mixed scratch files and unrelated dirty checkouts obscured what was actually delivered. | Reuse suitable isolation, preserve others' work and stage explicit owned paths. Keep current versus superseded artifacts identifiable. Distinguish approved pushed/merged work from unrelated local edits, ignored output and untracked evidence. Do not claim the entire workspace was uploaded. Scope whitespace/static checks to the introduced diff and new files; pre-existing archived whitespace is not a new regression. A full-file whitespace check repeated this mistake during the catalog task and was narrowed without changing historical text. |
| A08 | Healthy memory checks were run against a registered root while new documents existed only in a worktree. | Verify source-root/bank routing, preserve the shared registry and unrelated root edits, then deliver relevant sanitized worktree docs explicitly to project-daftar with provenance and completed-operation verification. An empty root queue does not prove worktree delivery. Engine memory remains separate. |
| A09 | Financial/reference history, proposed scope and verified Flutter behavior risked being treated as interchangeable. | Preserve one-restaurant/offline/Arabic RTL/IQD/history policies and unresolved gates. Frozen source/screenshots are references, not a new financial policy, product implementation or design approval. Use dated evidence and actual target results; no real-account testing. |

## Native/device lessons

| ID | Observed problem / cause | Prevention and verification |
| --- | --- | --- |
| A10 | Restart persistence could falsely pass from stale state or fail because a mobile test runner removed app data. | Use a fresh nonce per run, write/stop/read pairs and retained-data assertions; use the documented no-uninstall route where applicable. Cover wrong-nonce rejection/recovery. A successful build alone is not a native persistence result. |
| A11 | The owner authorized the Mac's iPhone Simulator, but physical-phone/signing requirements could remain unnecessarily in the current-run blocker list. | Use the explicitly authorized target. Keep physical signing deferred rather than passed; do not repeatedly ask for hardware already replaced by simulator direction. Report unavailable Simulator UI tooling precisely instead of repeatedly guessing/installing broader frameworks. Native dialogs remain pending until observed. |
| A12 | Plugin-level capabilities were overgeneralized from a synthetic probe. | Accepted payload/Dart-reader limits do not bound provider whole-file materialization/cache. System share handoff does not prove external receipt, and print entry does not prove physical printing. Keep picker roundtrip, cancellations, denied writes, replacement rollback and process/power-loss limits explicit; do not certify production import/export from the preview. |
| A13 | Fixture cleanup raced with inherited Git hooks/configuration. | Isolate test-fixture Git/config/hooks without altering user defaults. Keep cleanup strict and retain realistic regression cases, rather than suppressing failures or rerunning randomly until green. |

## Penpot/design lessons

The detailed existing 41-error Penpot record (`/Users/eros/.codex/skills/penpot/references/mistakes-2026-10-28.md`) and Penpot skill (`/Users/eros/.codex/skills/penpot/SKILL.md`) are the primary transfer guide, with [project skill provenance](../log/2026-10-28-penpot-skill.md). Do not duplicate its low-level font/SVG/import fixes into another writable guide. These absolute skill paths refer to this owner's machine; use the installed skill location in another environment.

| ID | Observed problem / cause | Prevention and verification |
| --- | --- | --- |
| A14 | Technical-shell inference produced blank boards instead of the owner's requested screenshot reproductions. | Inspect the supplied references and confirm the exact phase deliverable before drawing. Phase00's added prerequisite is only three desktop references and matching wireframes, not the whole application. Show references back to the owner; do not infer design approval from recreation intent. |
| A15 | Six boards were imported before one native sample proved typography, photos, icons, crops and controls. Small defects then caused full reimports. | Use the existing canonical Penpot space. Prove one representative native import/export first, store shape IDs, then patch/export only affected boards. Check the known local connection before reinstalling infrastructure; use the owner-authorized computer-use fallback when MCP is blocked. |
| A16 | Source-renderer parity/media metadata was mistaken for correct native Penpot output. | Inspect actual native exports, not just the source capture or media IDs. Verify photo fills/crop, Arabic shaping/weight/baselines, control values, pseudos, disclosure markers and SVG transforms using the detailed skill. Preserve text strings when outlines are required; disclose editability/pixel differences. |
| A17 | Verbose geometry dumps, incorrect endpoint/capture assumptions, distant retired boards and speculative renderer investigations consumed time. | Use the skill's validated endpoint/export path and compact counts/IDs. Select only intended boards for review. Inspect the actual saved screenshot/metadata before diagnosing new rendering causes; retain documented color-management conditions. Label superseded artifacts, and stop after verified scope rather than announcing repeated final checks. |
| A18 | Native fidelity, responsive/accessibility findings and owner approval were conflated. | Keep screenshot comparison, editability, relevant states, runtime accessibility/device validation and explicit owner approval distinct. Report known contrast/target-size concerns and discrepancies. Non-UI engine work records Design: N/A; no phase advancement or product UI implementation is inferred. |

## Legacy findings retained, not fixed

| ID | Finding | Required guardrail |
| --- | --- | --- |
| A19 | The preserved preview helper has a valid Host/origin/DNS-rebinding weakness. | Do not reuse `electron-reference/scripts/preview-design.cjs` before hardening and adversarial verification. Private repository visibility and loopback binding do not remove the defect. |
| A20 | Snapshot review recorded 55 skill/docs/tool/evidence findings; old Figma transfer and several harnesses are incomplete or stale. | Keep the [independent dispositions](../phases/00-step6-merge.md). Do not label all fixed/false positives, use historical focus/totals overclaims as current acceptance, or silently rewrite archives. Resolve token-inventory discrepancies before phase01 implementation; no phase01 is started here. |
| A21 | The merge record inventories 17 legacy lockfile alerts, including high-severity findings. | Treat the count as a dated inventory, not a permanent live count or exploitability assessment. Reference CI also consumes that lockfile. Dedicated advisory/reachability triage, applicable remediation and re-verification are required before affected legacy reuse/release. No silent dependency upgrade or security-readiness claim. |
| A22 | Review comments threatened to expand an already approved revision into unrelated repairs. | Triage validity/scope/severity and record deferred gates. Fix current blockers with proportionate tests and renewed head approval; preserve approved heads for nonblocking follow-ups. Never change code, policy, permissions or scope merely to silence a reviewer. |

## Documentation translation lessons

| ID | Observed problem / cause | Prevention and verification |
| --- | --- | --- |
| A23 | English translation introduced financial-term drift (worker advances became savings; an unconfirmed invoice became a receipt), changed completed actions into instructions and weakened recovery/source-data limits. Initial cross-review did not catch these; hosted PR5 review did. | Compare financial nouns, status/tense, permission boundaries and recovery meaning directly with the original source, then independently review the corrections. Keep runtime identifiers and frozen UI unchanged; label translated UI quotations and historical snapshots explicitly. Correct matching authored captions and indexes without rewriting source history. PR5 corrections preserve values, dates, reference hashes and engine pin; no accounting behavior is changed. |

## Review-service availability

| ID | Observed problem / cause | Prevention and verification |
| --- | --- | --- |
| A24 | After translation fixes, a request to rerun Cubic on PR5 was rejected because the GitHub organization subscription was inactive. Earlier-head automated results cannot be presented as a review of the corrected head. | Do not retry the same unavailable service or change billing/subscription settings without owner authorization. Preserve the earlier findings and their independently verified corrections. Use the required independent Reviewer and applicable hosted checks for the current revision; report the unavailable automated rerun honestly. A missing required check remains pending or blocked, never passed; this record does not waive any gate. |

## Evidence and maintenance

[Step4](../phases/00-step4-review.md), [Step5](../phases/00-pr-approval.md), [Step6](../phases/00-step6-merge.md), [native evidence](../phases/00-build-evidence.md) and [Penpot reproduction](../phases/00-penpot-reference-recreation.md) preserve detailed outcomes. The engine counterpart is Madar_Engine, `docs/how-to/repeated-problems.md`; shared capabilities remain there, never copied here.

This documentation maintenance changes no runtime code, CI, dependency pin, design, financial policy or phase status. Tests/builds/benchmarks: N/A for behavior changes because none are introduced; verify documentation links, owned diff and memory delivery instead. Known native/design/security findings remain pending, not repaired by writing this guide.
