# Phase02 — Step4 independent review and verification

Date: 2026-10-30. **NOT READY for full approval.** Original runtime defects and later benchmark-harness findings are independently repaired/reverified. Local checks and the final Mac measurements pass. Android installation preservation failed; previous app-data retention is unverified. Android cancellation, current iOS evidence, hosted CI and owner approval remain open. Phase02 is not DONE.

## Blocking and pending gates

| Gate | Current evidence and disposition |
| --- | --- |
| Android preservation | **BLOCKED.** Temporary tool configuration generated a separate debug signing store. A signature mismatch triggered Flutter automatic uninstall/reinstall despite --no-uninstall. Missing signing preflight was an agent failure. Old picker-fixture data is absent; prior installed-app data retention is unverified. Raw WRITE success is excluded. No data restoration was attempted. |
| Android acceptance | No accepted current matrix or Open/Save cancellation. Further installation stopped; task emulator shut down without wipe/reset/snapshot restore. Only power state restored. Signing material preserved in place, not copied into Git/knowledge. Future installation requires fail-closed certificate/preservation preflight. |
| Current iOS | Provider inventory stalled; targeted readiness timed out20.005s. Owned commands stopped, no simulator/service reset or assumed state. Earlier iPhone successes remain historical. |
| Hosted CI/source delivery | No candidate hosted CI executed or supplied. Read-only phase02 branch-ref queries returned none; no source publication was performed. Local results cannot stand in for mandatory hosted checks. |
| Approval/release | No owner merge/phase-completion approval, PR, push, merge, tag, release, production migration or next phase. Physical signing/install/power-loss/production rollback evidence is not claimed. |

[Confirmed Android incident and accountability](../log/2026-10-30-phase02-android-preservation-incident.md), independent incident/native review, read-only remote-ref receipt (local-only artifact `outputs/phase02/step4-remote-readonly.json`, SHA-256 `43f3d9b94f4cc8051626e4aa698eda29125cbe3557a186304720f79745e7f9d1`).

## Exact local candidate and responsibilities

| Role | Exact revision |
| --- | --- |
| App | `5a11c66dbf665972b17b545c105eac74c17bfeeb` |
| Consumed runtime engine | `a6a8ebdd8f68f5d603d56dc3f3d0f13cc3e38294` |
| Separate measurement host | `63bbed8303bf8561084c5f82a3ebd52e2bf9e95d` |

App source fixes landed at62edbf788, failure-only diagnostics atdf72f769 and initial-only readiness at5a11c66d. Current app version is unreleased0.0.0+1; compatible unpublished engine preview versions remain unchanged. The exact Git revisions identify them. Current candidate.

Madar alone owns exact primitives, fenced opaque document/workspace ports and optional local persistence. Dakhl_Restaurant owns schema1–11/history compatibility, source-specific timestamps, restaurant meanings, ViewModels/UI/composition and app safeguards. Shared implementation is not copied. Generic measurement protocol/resources remain in Madar; app-only instrumented UI, fixture transport and safe model-stage evidence remain here. No cloud/auth/multitenancy, new accounting policy, runtime JavaScript dependency or normal UI redesign was added.

Existing [Penpot designs/references](02-penpot-design-review.md) and earlier work are preserved. Step4 changes no product UI; engine Design N/A. Arabic RTL, offline/single-restaurant/IQD/history constraints remain. Live screen-reader verification is owner-excluded, never passed; existing keyboard/focus/semantics safeguards remain applicable.

## Findings repaired by separate authors and independently closed

| Finding | Verified correction and review |
| --- | --- |
| APP-P2-01: supported legacy timestamps rejected | Pinned V8 tokenizer/composer adaptation preserves original text and separate financial-date policy. First regex repair remained blocked after90/4036 and35/55 mismatches. Final324 full-model/4,127 compact cases match source in UTC/Baghdad;1,840 further independent comparisons have zero mismatches. Source/receipt/upstream/BSD hashes verified. Review. |
| ENG-STEP4-01: legitimate early initial creation cannot resume | Verified matching intent before containers/format creation resumes only proven empty stages. Unknown/corrupt/future/nonempty and contradictory authority stay protected. Full132 data/analyzer checks and independent original reproduction/15 protections/2SIGKILL checks pass at exact four hashes. [Engine review](https://github.com/faroqomar/Madar_Engine/blob/a731885a8875cdda78197d8df355d18a739e48e8/docs/reference/cap02-step4-review.md). |
| P3: stale performance cases/pin | Nine ready registry IDs and revision-manifest authority independently verified; six provenance notes changed without changing scenario IDs/workloads/status. Review. |
| Diagnostic artifact creation authority | A matching filename did not establish ownership. Meaningful foreign-valid-manifest RED led to a private publication binding minted only after owned exclusive create/flush and revalidated unchanged content/parent. Static11-key4KiB capture rejects private/extra/duplicate fields, foreign attempts, symlinks and pipes. Generic failed results remain unchanged. Review. |
| Initial render observation race | A native failure recorded initialRender timeout, absent state, attempted1/completed0 before migration. SDK source proves a reachable asynchronous attachment/warm-up metadata gap. Readiness now precedes fresh-baseline selection, while real matching native frame/rasterFinish and one total10s guard remain mandatory. Meaningful16pass/2fail RED→18pass GREEN; earlier test-binding mistakes preserved. Specific historic interleavings remain unproven. Review. |

The Lead coordinated authors/reviewers and did not self-approve implementation. Independent technical closure is not owner approval. [Timestamp grammar/provenance/full BSD obligations](../reference/legacy-v8-timestamp-compatibility.md); future binary redistribution must carry the retained notice in accompanying materials, not a claimed current release package.

## Verification actually established

| Scope | Result and practical limits |
| --- | --- |
| Current app5a11/runtimea6 | **529** non-golden tests pass,18.423s; whole-app analysis no issues,5.939s; enforced source/contract boundaries pass,0.828s. Exact receipt. |
| Focused current harness |18 producer tests and26 runner tests pass, with independent source/security/deadline reviews. Counts overlap the full suite. Native safe failure capture was actually exercised on the predecessor initialRender timeout. |
| Runtime engine |132 data tests/analyzer at exacta6 source; independent15 protection/2SIGKILL/original-prefix reproduction. Exact-value/application/native-adapter source is unchanged; relevant earlier checks retain their original scope. |
| Native process recovery | Mac six-stage matrix accepted at62/a6:5 distinct positive PIDs, deliberate wrong-nonce refusal, original read continuity and recovery fresh store/generation. Later changes affect opt-in benchmark instrumentation only; this remains component evidence at its actual source. Current Android is excluded/blocked and iOS unverified. Index (local-only artifact `outputs/phase02/step4-native/summary.md`, SHA-256 `98267335276517fec240970d8104c34a8fc5b786e5ebc5d13b62c603ca0e86a1`). |
| Current Mac baseline |18 distinct cases×20=360 real samples, one attempt each, cleanup confirmed, no owned profile/campaign processes. One5a11 source/binary/fixture method; no old epoch or isolated result selected.805 fresh independent artifact/statistical checks/108 hashes found0 discrepancies. [Metrics/method](02-step4-performance.md), independent review. |
| Unchanged evidence | Prior5 goldens, frozen reference integrity, reference tests, domain/application/native-adapter and generic host26/source-helper28 evidence is reused only with its documented relevant source continuity; no repeated unchanged test run to fill the audit. |

Counts overlap and are not a unique-test sum. Failed REDs, unsafe installation, incomplete source epochs and hardware/access gaps are never relabelled passed. Fixtures are authored/marked and separate from normal app data. Impact checks read known synthetic names/package identity only, not normal account payloads; that does not establish retention of the old Android data.

## Measurements and remaining uncertainty

Final source fingerprint `b04753cd7925359de3baef86748fcd3c030d0c6e68df7143c785a5bdd0dc6fe3`; binary `0d32c268da110e029ecd36d93741cda25c832cac26872f69ba692142119b2eb4`. Full input tree `15073d8bc40405796e4665632d7a1b6d8057e30e053567b5ec3882d557a82559`. Campaign12:45:18.462–13:03:05.972UTC,1067.510s; command wall sum1058.102s overlaps it. Six actual operations cover small10/medium1,000/largest10,000 synthetic records, largest20,759,123 canonical bytes; workspace3,416 bytes/active1+held40. No near-limit workspace or mobile-capacity claim.

Latency ends at actual matching native rasterFinish; resource sampling covers broader reset/bootstrap/observer/cleanup windows. Raw20-value latency arrays and aggregate resources are retained; individual timing-event/periodic-resource traces are not reconstructable. No numeric budget, optimization delta or reliability certification exists. Bootstrap changed setup work, so old resource epochs are not compared.

The original Step3 medium failure and Step4 generic medium failure remain preserved without exact causal proof. Predecessor62/df72 partials, isolated/prefix diagnostics and captured initialRender timeout stay separate. The corrected reachable startup race and current360 successes do not prove every historic interleaving or all-attempt reliability. No engine/parser fault was inferred from the pre-command timeout.

## Delivery, audit and next boundary

Separate app/engine trackers, English documentation and project-daftar/project-madar knowledge remain distinct. Source/project work is preserved; the redundant isolated engine-fix checkout was archived recoverably only after all13 artifacts and its journal were copied/hash-verified in the active engine tree. Runtime remains exacta6. Temporary Android signing material remains outside Git/knowledge in its private task directory, intentionally not deleted.

Execution/time-cost/automation audit (local-only artifact `docs/log/phase-02-execution.md`, SHA-256 `d490433a2ead39ecf2f36721364cd1003b550152426fa7b98b90c3bb069c639c`) records actions, failed attempts, measured/unknown intervals and avoidable work. Active effort, token totals and monetary cost are unknown. Sanitized milestone delivery is tracked by separate saved-operation/source-hash receipts; canonical zero-queue status alone is not worktree-source proof.

Further Android installation requires actual preservation/signing evidence and a fail-closed preflight; no restoration or new namespace is silently authorized. Current iOS/hosted checks and explicit owner gates remain open. No merge, release or next phase is inferred from this report.
