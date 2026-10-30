# Phase 02 — bounded implementation plan

Date: 2026-10-29. Status: **STEP3 BUILD AUTHORIZED; IMPLEMENTING; no publication or merge**. Active phase inferred from the ongoing Phase02 work, not a new phase. [Scope](02-scope-readiness.md), [Penpot approval set](02-penpot-design-review.md), [engine contract/implementation plan](../../../../phase02-scope-engine/Madar_Engine/docs/reference/cap02-account-workspace-plan.md), [proposed storage ADR](../../../../phase02-scope-engine/Madar_Engine/docs/decisions/0010-local-account-workspace-snapshots.md), [audit](../log/phase-02-execution.md).


## Step3 owner build instruction — 2026-10-30

The owner invoked Step3 to implement the presented Phase02 outcome and instructed the Lead to resolve remaining in-scope choices without questions. This is the build authorization for the reviewed plan, technical ADR0010, PREF-01,20MiB workspace profile and presented six-pair Penpot set. Status: IMPLEMENTING in dedicated codex/phase02-build trees; the prior Step1–2 descriptions below remain historical. No merge/publication, production-record rehearsal, broader policy approval or supported release is implied. Engine source must pass independent review before consumer pin adoption; unreviewed isolated development tests do not constitute that adoption.

## Outcome and hard scope

Save, reopen, migrate and explicitly recover one restaurant's accounts offline while preserving supported records/IDs/history. Provide safe account/workspace foundations and only approved persistence/recovery UI. Keep ArabicRTL, integerIQD, three-decimal quantity semantics,20MiB account/import boundary and legacy source behavior. No cloud/auth/multitenancy, normalized ledger/posting, new money/stock/restaurant policy, production-account access or later operational features.

Current Phase01 approved preview is DONE; Phase00 technical prerequisite verified, historical closure separate. The six Phase02 Penpot pairs are independently reviewed but **not owner-approved**. Step2 invocation does not approve them or authorize a build. Live TalkBack/reader testing is owner-excluded/not passed; keyboard/focus/semantics/large-text safeguards remain required.

## Existing isolation and dependency revision

Reuse app codex/phase02-scope at /Users/eros/.codex/worktrees/phase02-scope-app/Dakhl_Restaurant (base2e4bbbfef5baba9122748ea16f25addabe13663f) and engine counterpart /Users/eros/.codex/worktrees/phase02-scope-engine/Madar_Engine (baseb1b4d6ec128e79d6dccb4849e5f9c561c219843c). These are documentation-only isolated branches with Step1/1.5 work preserved. Remote main was checked as app00b5bbae8be5ebb1bd2f98471b006dec8778f258/engine06e69f2da330bcce2250e22e743391fbdabb39bf. No publication or new implementation checkout created by this plan.

Current engine pin6d4ae39f35b005dfa1123a82c6df316901e1e1e4 and application0.1.0-dev.2/data+native0.1.0-dev.1 stay unchanged. New CAP-02 revision is pending implementation and independent review. After approvals, Lead establishes clean phase-only implementation branches/checkouts and actual sibling engine resolution. Existing scripts/check-engine.py requires exact reviewed engine HEAD, clean packages/tool, actual package_config/lock resolution and boundaries; no dirty-source bypass or automatic pin advance. Preserve existing runtime checkout and planning/design evidence; include only owned phase changes in future linked PRs.

## Recommended architecture — unapproved

Keep schema-versioned restaurant JSON as compatibility/import/export data; use a new **Madar local-only SQLite/PowerSync complete-document/workspace adapter**, plus an independently readable previous-copy recovery envelope outside the database. Do not repurpose CAP-01's16KiB preferences or build app-owned file/SQL algorithms. Internal recovery-envelope JSON is engine format, not Electron accounts.json; portable JSON encoding remains app-owned. The engine plan/ADR defines publication order, uncertain outcomes and fresh-container recovery. This explicitly supersedes the old JSON-primary proposal only if approved; FULLSTACK is not silently amended.

| Responsibility | Deliverable |
| --- | --- |
| Madar pure core/application | Explicit-policy exact values/date/ID/validation; generic snapshot/revision/generation/outcome contracts |
| Madar optional data adapter | One coordinated writer, local-only transaction storage, bounded independent backup, protected corruption/future formats, recovery pointer and safe diagnostics |
| App models/codecs | Typed schema1–11 validation/migrations, record/relationship/history preservation, restaurant-specific field meanings |
| App repositories/ViewModels | Account/device/workspace composition, startup gating, translated errors, retained input, generation guards and approved confirmations |
| App UI | Phase02 save/read/import/recovery states from owner-approved Penpot; existing shell/components preserved |

## Account, device and workspace proposal (PREF-01)

Recommended for explicit approval: when a valid account is active, its imported account preferences (including legacy shortcut configuration) are authoritative, preserving legacy import behavior. Last route stays device-local. Existing Phase01 six-slot device payload is preserved as startup/failure fallback/cache; it is not a second account authority and is never overwritten by import before success. Account save succeeds before any best-effort compatible cache refresh; cache failure must not falsify account success or rewrite account data. Startup resolves effective account settings before relevant actions become enabled. Corrupt/unsupported account state stays visibly protected, not silently Saved through cache fallback.

For restart and editing, both current six slots and last route must still restore as required. All changes to account preference precedence, fallback/cache updates and protected old payload handling need unit/native conformance; existing Phase01 contract/UI safeguards remain. An alternative device-always-wins policy would preserve different visible import semantics and needs owner selection instead. No new Apply-imported-settings feature is invented. **PREF-01 is a proposal, not an existing decision.**

Workspace persists active/held payload and schema separately from portable account JSON; current reference limit40held orders is preserved. Phase02 builds serialization/read/write/fencing, not operational hold/resume/post-sale workflows (Phase04). Proposed engineering ceiling20MiB per workspace snapshot needs approval and valid-capacity proof; larger source input is never truncated. Account replacement commits new generation before old drafts become inaccessible; known failure retains current input/account/workspace. Physical cleanup is deferred to approved retention rules. Late writes/responses from old generations cannot reappear. Every document/workspace result, mutating request and ViewModel guard carries an opaque store/container-identity plus generation tuple, not just a revision. Recovery generates both identities fresh, never restores them from an older backup or resets/recycles them; a new-container revision reset cannot pass an old callback guard.

## Deliverables and execution slices after approval

| Slice | Result and dependency |
| --- | --- |
| P02-A Contract/fixtures | Approve engine ADR/bounded local-only allocation and PREF-01/workspace budget; freeze schema1–11 synthetic corpus and oracle provenance before behavior changes |
| P02-B Pure foundation | Madar exact primitives/validation with independent generic tests/examples; preserve input bounds rather than silently widening JavaScript-safe acceptance |
| P02-C Durable adapter | Madar document/workspace/independent-backup/recovery ownership and real fault/process tests; source independently reviewed and committed before app pin adoption |
| P02-D Consumer models/integration | Typed account model/codecs, read-only legacy import/migrations, isolated repository composition and separate settings/workspace handling; no copied storage implementation |
| P02-E Approved UI/performance | ViewModels drive only approved load/save/failure/import/recovery flows; native target conformance and real separate operation fixtures/measurements |
| P02-F Review/delivery | Independent engine+app review and fixes, existing CI/build/native gates, exact revisions/version candidate/docs/rollback and separate memory delivery; PR/merge only when separately authorized |

Lead chooses staffing/sequencing; independent engine/app work may run in parallel only with non-overlapping ownership. Planner remains read-only; Workers do not self-approve. Interface changes require review before dependent work, not a new financial policy. A failed capability proof stops dependent implementation and triggers a reviewed plan amendment.

## Schema/validation and startup behavior

Use current frozen model.validate as schema1–11 oracle, normalized schema11 output and all supported entities: categories/days/expenses/chicken/balances/snapshots/corrections; transactions/transfers; suppliers/materials/invoices/payments/allocations/debts; compatibility workers/savingsEntries; products/stock/sales/returns; preferences. Preserve IDs, dates, historical prices and correction/reversal relationships, not merely totals. Unknown arbitrary keys are not promised. Earlier archived definitions/fixtures provide provenance where available; synthetic fixtures are not production migration rehearsal.

WholeIQD magnitude≤10^12, quantity magnitude≤10^9/up to3decimals, Arabic/Persian digit normalization, source sign/positive rules and JavaScript-safe intermediate/rounding rejection remain the consumer profile. Exact generic arithmetic does not automatically accept previously rejected larger inputs. Calendar validation follows the source's four-digit date/dateKey round-trip, not timezone conversion. Include exponent-form JSON numbers, negative-zero/precision/invalid Unicode boundaries where reachable; no binary floating-point monetary calculations or silent string/ID normalization. Original legacy files stay read-only, original selected bytes preserved and canonical output validated before writing to isolated new storage. The import validation inventory assigns generic money/allocation/quantity invariants to Madar and only restaurant format/reference/migration meaning to app codecs; no shared financial backend is copied into the app. Port only validators needed for accepted imports, not later operational workflows. Any validation requiring an unresolved policy stops affected work for an explicit plan amendment.

Bootstrap must distinguish loading, true absence, valid state, corrupt/unavailable and unsupported/future state. No financial command is enabled against unvalidated account data. Never convert errors to an empty account or overwrite future data. Disposed/stale async reads and failed writes cannot replace newer state or clear forms. Native picker cancel does not mutate data.20MiB is checked on incoming bytes and encoded output; accepted-byte checks do not claim a provider cannot materialize a larger file before handoff.

## Meaningful test plan (test-first)

| Layer | Acceptance evidence |
| --- | --- |
| Pure app parity | Each schema1–11 plus canonical11; every supported record type, optional/legacy settings, stable IDs/order/history and all source rejections; deterministic JS/Dart corpus comparison |
| Generated properties | Normalization idempotence, accepted canonical round-trip, independent invariants and oracle parity with fixed recorded seeds/failing input; existing test tools, no unapproved PBT dependency/shrinking claim |
| Engine real storage | Independent generic conformance, stale/overlapping writes, second-process ownership,20MiB/internal-envelope limits, workspace capacity, checksum/corrupt/future protection, zero upload and safe/failing diagnostics |
| Fault/recovery | Every backup-write/publication, transaction, acknowledgement and container/pointer boundary; ordinary interrupted writes reopen prior valid or complete new authority. Corrupt-primary recovery remains protected with intact original referenced container/source/backup until confirmed pointer switch, or activates verified complete new state. Do not relocate the referenced DB/WAL/SHM before activation; test pointer publication faults/unknown acknowledgement and reopen for healthy and corrupt starting states |
| App repositories/ViewModels | No writes on invalid/future/canceled import; failed save retains form; commit_unknown readback before retry; failed replacement leaves current account/drafts; successful generation fences late old writes; recovery from older backup while primary had advanced rejects late primary results/writes (ABA); PREF-01/cache failure precedence |
| Widget/interaction | ArabicRTL and approved reference sizes, all approved statuses/errors/retry/cancel; keyboard/focus/Escape/back, large text/action reachability and semantics. Reader live check excluded, not passed |
| Real consumer/native | Fresh nonce/PID write-stop-read on macOS, Android emulator and iPhone Simulator; wrong-nonce negative case; native selection cancellation and actual file/recovery handoff; no uninstall/stale-fixture false pass |

Fixtures/temp stores only; never launch against installed Electron accounts or use private records to generate corpus/performance data. Restore prior target settings and clean only task-created fixtures. Existing140Electron reference tests and frozen179screenshot/9source/21asset integrity gates retain their current dated scope; future required runs attach actual results rather than copy passes from history.

## Per-feature performance, CI and versioning

Register these proposed cases only when real workflows exist: accounts.open, accounts.save, accounts.migrate_legacy, accounts.replace, accounts.recover_previous and workspace.save_restore. Keep all planned/unavailable until implementation plus correctness evidence. Each case measures its own p50/p95 elapsed, sampled peak RAM and CPU through existing reviewed Madar host tooling, with app/engine/tool/fixture/scenario/SDK/hardware/OS/mode/sample provenance. Real boundary ends after acknowledged repository/ViewModel outcome and rendered protected/success state; migration/storage substage measurements are separately named, not substituted for end-to-end behavior.

Proposed minimum20independent measured iterations per operation/fixture variant, each reset outside timing; failed/unavailable run has no invented measurements. Fixture manifest records exact entities/bytes/schema and cold/reopened conditions: small10representative records, medium1000valid representative records, and largest valid bounded fixture near20MiB (or documented source-entity-limit maximum). Counts are synthetic workload choices, not capacity promises. Workspace covers active+40held fixtures. Include backup/envelope overhead in real save/recovery measurements. First comparable successful run is baseline; no arbitrary latency/RAM/CPU pass target or optimization claim. Mobile measurements require their own supported adapter/evidence; macOS numbers cannot stand in. No timings were measured in Step2.

Extend existing engine.yml and consumer flutter.yml/electron-reference.yml proportionately: pure/data/adapter/boundary/examples, app unit/widget/property corpus, source-resolution/version/runner checks and macOS/Android/iOS builds. Do not weaken mandatory checks or add a duplicate whole pipeline. Platform/process fixtures belong to appropriate existing jobs; actual native acceptance and per-operation profiles are separate evidence, not inferred from build success. Engine/package lock/SDK pins stay explicit. New runtime package/pin requires independent source review; no broad secret/access changes.

Candidate remains0.0.0+1 now. During later authorized PR/binary preparation select MAJOR.MINOR.PATCH+BUILD under versioning-and-performance rules, record actual prior delivered version and monotonic delivered build, source fingerprint/engine/tool revisions and measurements. No claimed delivered version, bump/tag/push/PR/merge/release occurs in planning. Design-only docs do not force a runtime version change.

## Risks, gates and completion

Before build: approve this plan/ADR (including bounded preview allocation, backup ordering, workspace ceiling), select/approve PREF-01 and explicitly approve the Phase02 Penpot set. Unresolved financial/posting/currency-market/stock/lifecycle/cloud/security/recovery-retention/key-loss/power-loss/compatibility-window policies remain open and block only work that actually depends on them. This snapshot preview does not promise production onboarding, arbitrary multi-process safety or a supported engine business release.

Primary risks:20MiB snapshot/base64 memory+I/O cost; native writer/rename/SDK semantics; independent-backup versus primary commit interval; active-pointer publication; stale generations; cache/account precedence; legacy number/date/Unicode preservation; future formats and disk exhaustion. Required tests/measurements must establish these before adoption. No silent backend switch, data deletion, retry/reset fallback or scope expansion if a proof fails.

Completion requires all meaningful tests/CI/analyses/builds, independent engine+consumer/native/recovery evidence, per-feature performance baselines, closed review findings and accurate package/API/setup/examples/limits/upgrade/rollback docs. Downgrade must preserve new containers/unknown formats; documented source rollback is not a recovery rehearsal. Production migration/install/release and broader retention/key recovery stay separate, with N/A justified for a preview-only source delivery. Exact compatible revisions, owner approval, authorized merged PRs and applicable release/rollback evidence are required before Phase02 DONE. Separate project memory checks and worktree-source delivery must complete. Stop for plan/design approval; do not implement or advance phases.

## Independent planning review closeout —2026-10-30 Asia/Baghdad

Planning began2026-10-29; this is a next-local-day closeout, with UTC timings in the audit. Independent Reviewer phase02_docs_review reported no remaining actionable plan findings after two contract repairs: fresh store/generation fences prevent older-backup recovery from accepting late prior writes/results; pointer-referenced containers stay intact in place until activation, and fault expectations distinguish valid-primary writes from already-corrupt recovery. Nine plan links and tracked whitespace were independently checked; Lead checked180app/58engine owned links plus new Markdown/source boundaries. No runtime tests, spikes, builds or native/design rechecks executed. Plan/ADR/PREF-01/workspace-budget and design approvals remain pending.


## Reviewed implementation refinement —2026-10-30

Independent adapter review found interrupted-first-creation and activation-acknowledgement gaps. Add explicit resumeInitialCreation(payload,writeToken), requiring the original canonical payload match a bounded versioned initial intent, no active pointer/previous backup and a verified owned candidate/source-artifact inventory. Preserve all candidates and publish a fresh verified container pointer last; never treat staged account containers as absence or build defaults. On restart the app may reselect/validate the original file and explicitly confirm the resume; different content cannot replace the protected intent. Fully validated source archives alone are non-authority and can coexist with true absence; partial/corrupt/future artifacts remain protected. Uncertain activation reads cannot return absent; workspace mutation must validate the existing row's fence before CAS. These technical corrections complete the selected failure/retry guarantees, without adding financial/retention policy, automatic reset or a release promise. Initiative kp-b51b041397b441c1a69bdbea5c0a95d7 updated before this contract amendment.
