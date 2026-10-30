# Phase 02 — Step 3 build and local verification

Step4 update, 2026-10-30: fresh independent review found blocking in-scope defects; [current repair/readiness record](02-step4-review.md) supersedes current-clear wording below. All Step3 source/results remain dated historical evidence.

Date: 2026-10-30. Status: **VERIFYING — authorized implementation and local checks complete; no merge or release.** Independent source, native, measurement and documentation-accuracy reviews are clear within the limits below. Separate project-bank delivery is evidenced by its dedicated saved-operation/hash receipt, independently of canonical queue status.

## Scope and ownership

The owner invoked Step3 for the presented Phase02 outcome and asked the Lead to resolve in-scope choices without questions. The selected bounded plan, ADR0010, PREF-01, 20 MiB workspace profile and six-pair Penpot set govern. Earlier dated approval-pending watermarks remain historical. Original planning/design trees and frozen references are preserved. No whole-app redesign, later posting/catalog/stock workflow, cloud, authentication or retention policy was added.

Madar owns reusable exact values, opaque fenced document/workspace contracts, single-owner local persistence, independent source/previous/recovery artifacts, unknown-outcome readback and safe diagnostics. Dakhl_Restaurant owns schema1–11 compatibility, restaurant record meaning, account/device preference precedence, workspace presentation schema, repositories/ViewModels and the bounded UI. Shared implementation is written once in Madar.

## Implemented behavior

- True absence stays unsaved until explicit save. Corrupt, future or incomplete authority never becomes an empty or Saved account. Valid selected source bytes are archived before store mutation.
- Canonical validation preserves supported entities, IDs, relationships, historical fields and compatibility-only records. Input and two-space serialized output each have a separate 20 MiB UTF-8 limit. Exact IQD/quantity/date handling and evidenced legacy timestamp behavior follow the frozen source profile. A BigInt-only helper preserves the historical validator's grouped integer-expression rounding; strict exact helpers remain strict.
- Valid account shortcuts are authoritative; last route stays device-local. First explicit creation seeds the existing six-slot device fallback. Account acknowledgement precedes best-effort cache updates; cache/workspace failure cannot falsify account success or acknowledge an unsaved draft.
- Invalid/cancelled selection cannot confirm an older retained file. Known failure retains input. Replacement/recovery requires explicit confirmation, then fences old callbacks/workspace only after success.
- Unknown outcomes gate related writes until matching token/fence readback resolves authority. Conflicts require authoritative reload, preserve the pending selection for fresh confirmation and use the dirty-session discard guard. Cancel neither saves workspace nor resolves an authority conflict.
- Interrupted first creation resumes only through an explicit original-canonical-payload-matching intent. No default/reset path replaces protected intent.
- Workspace schema1 persists current presentation/form state and up to40 held presentation records. Operational hold/resume and order posting remain later-phase work. Oversized drafts remain visible, perform no write and do not strand the ViewModel busy.

## Exact revisions and isolation

| Role | Reviewed revision / location |
| --- | --- |
| App | `69fef62452dd70a57de1c024d0ef49d807f272a1`, codex/phase02-build in phase02-build-app/Dakhl_Restaurant |
| Consumed runtime engine | `ea9c21adfde746c40d0e8d15a7e5bbe017beb70c`, codex/phase02-build in phase02-build-engine/Madar_Engine |
| Separate measurement tool | `63bbed8303bf8561084c5f82a3ebd52e2bf9e95d`, codex/phase02-bench-tools in phase02-bench-tools/Madar_Engine |

Adopted packages: application0.1.0-dev.3, data0.1.0-dev.2, domain0.1.0-dev.1, native adapter0.1.0-dev.1. Enforced offline lock resolution and the existing source checker passed without bypass. The parent runtime checkout remains exact ea9; the existing engine-tools-root option loads the separately reviewed host tool and records its identity independently. Other runtime/planning/design checkouts remain preserved.

Normal application behavior is unchanged since450f277; later app commits repair only native test harnesses and the opt-in benchmark target/runner. Mac generic native runs used cc0bb780; Android/iPhone and current picker runs used52ed120. Actual per-target build heads remain in receipts; source fingerprints establish the relevant unchanged native inputs. No old result was relabelled to the final benchmark source.

Candidate remains unreleased `0.0.0+1`; no delivered version/build/tag is claimed. Runtime and tool source are locally committed; current documentation/evidence changes are separate from uncommitted application or engine code.

## Tests and checks actually executed

Counts are scoped to their named suites and overlap; they are not a unique-test total. Red/green and failed attempts remain in the execution journal (local-only artifact `docs/log/phase-02-execution.md`, SHA-256 `d490433a2ead39ecf2f36721364cd1003b550152426fa7b98b90c3bb069c639c`) and worker fragments.

| Evidence | Actual result |
| --- | --- |
| Final app unit/widget aggregate | **462 non-golden tests passed** at final source; post-profile-full-non-golden.log |
| Final whole-app analysis | No issues; post-profile-whole-app-analyze.log |
| Existing golden contracts | 5 passed without updates; unchanged affected-source evidence reused |
| Focused persistence/UI/callback regressions | 24 passed; later native error-copy leaf7 passed |
| Codec/oracle | 271 tests;267 synthetic oracle cases,185 accepted/82 rejected |
| Frozen references |179 screenshots/9 source files/21 assets unchanged |
| Electron reference |140 passed after locked dependency install; initial missing-jsdom failure retained |
| Source/version helpers |28 passed; exact engine source checker passed |
| App benchmark runner |18 focused checks passed, including direct script discovery |
| Final opt-in producer |9 focused tests passed, including sanitization, real repaint count, matching/stale IDs and global timeout |
| Actual-adapter consumer scenarios |4 passed on reviewed runtime pin |
| Engine independent suites |data121/domain9/application9/native-adapter27 passed at ea9 |
| Measurement host |26 passed at63bbed, including the original19 unchanged |

Final aggregate/analysis receipts: post-profile checks (local-only artifact `outputs/phase02/post-profile-final-checks.json`, SHA-256 `e43b09830a91b99c29db2b0e3475effa1c714a5900c5cb6302538b221dcfe2b9`). Earlier failed SDK-close/preflight attempts remain failed history. Coordinated read-only primary preflight avoids constructing an undrainable owner for damaged/future primary state; arbitrary uncertain close still retains ownership and gates operations.

## Native and UI evidence

Each of macOS, Android emulator and iPhone Simulator passed: write, fresh-process read, specific expected wrong-nonce refusal, valid original-nonce read, previous-copy recovery and another-process recovered read. There are15 positive launches with distinct PIDs plus3 intended negative launches. Original fences/revisions/40 held states remain before recovery; recovery creates fresh identities, revision1 and empty current workspace. No uninstall/reset between stages. Native summary (local-only artifact `outputs/phase02/native-current/summary.json`, SHA-256 `c49d8942bb9b5ed7e7ad9a7109003f6e12a2386aa4b1af37b021329f3e33a404`).

Mac actual Open Cancel, Save Cancel and generated-file import/keyboard-confirmed replacement/previous recovery passed. iPhone Simulator actual Open/Save cancellation passed typed outcomes, source/account/workspace no-change assertions and framework invariants. Original failed semantic-baseline attempt remains failed; its public test-only fix preserves all framework leak checks and changes neither product semantics nor OS accessibility settings.

Android DocumentsUI opened, but CUA could not control the Qt window. Its Cancel/postcondition assertions did not complete; controlled owned-app/test stop exited79/completionfalse. Cancellation remains unverified, and Save Cancel was not redundantly attempted through the same unavailable control. Picker receipts (local-only artifact `outputs/phase02/picker/cancel-open-android.json`, SHA-256 `8cda025d07fb8a2826115b497a29f6397da9303ed08ecbf089856f809c196682`).

Mac Arabic/RTL dialogs and visible keyboard focus were observed. Live TalkBack/screen-reader verification is owner-excluded, never passed. Emulator/simulator evidence is not physical-device signing/install proof. Only task-started mobile targets were restored to stopped/shutdown; no reset or production-record testing.

## Per-operation baselines

**18 accepted cases ×20 independent iterations =360 samples**, on one final source/binary fingerprint, across six commands and three fixture profiles. See the [full metrics, fixtures and limits](02-performance.md). Every accepted result reports passed/confirmed cleanup/no diagnostics. The first medium-migration host attempt failed without samples; the accepted retry is explicit and its original cause remains unresolved. No reliability or performance-improvement claim follows from the retry.

Latency is command start through actual matching native rasterFinish, including a deliberate final repaint and excluding later timing-callback delivery. Resources are sampled absolute process RAM/aggregate CPU over the broader run window including reset/observation/cleanup. The largest account is20,759,123bytes/10,000 synthetic records; workspace is3,416bytes with active1/held40. No near-limit workspace or mobile-performance claim. Older source epochs, direct diagnostics and the obsolete-phase collector run remain preserved but excluded.

The accepted cohort's artifact/manifest hashes, quantiles, CPU arithmetic and identities were independently checked. Per-sample GPU-frame traces and periodic resource observations were not retained for independent reconstruction; reviewed producer/collector assertions enforce/derive those measurements.

## Review, limits and delivery

Source findings and the final native/measurement evidence findings are closed by independent reviewers. This clearance is not owner merge approval or whole-phase completion. One medium benchmark failure remains unexplained; Android native cancellation remains unverified. These remain visible follow-up limits.

No hosted CI, push, PR, merge, tag, release, deployment or production migration occurred. Phase02 remains VERIFYING, not DONE; integration/owner approval and applicable release/rollback gates remain separate. Original plans/references and all failed evidence are preserved.

Rollback for this preview: stop the isolated process, retain all account/source/previous/container artifacts and select reviewed compatible source. Do not open newer authority with unsupported old source or migrate installed restaurant accounts in place. Power-loss, key-loss, retention, deletion and broader financial/stock/cloud policies remain outside this bounded preview.

[Engine implementation](https://github.com/faroqomar/Madar_Engine/blob/a6a8ebdd8f68f5d603d56dc3f3d0f13cc3e38294/docs/reference/cap02-implementation.md), [source plan](02-implementation-plan.md), [Penpot package](02-penpot-design-review.md), running audit/time-cost review (local-only artifact `docs/log/phase-02-execution.md`, SHA-256 `d490433a2ead39ecf2f36721364cd1003b550152426fa7b98b90c3bb069c639c`).

Documentation link/state/whitespace checks passed for the owned records. Worktree milestone delivery status and source-hash proof are recorded in `outputs/memory/phase02-build-delivery.json`; this document does not infer completion from submission.
