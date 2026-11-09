# Phase 02 delay remedies — implemented locally

Date:2026-11-04. Owner authorized implementation after the eight-item remediation table. Scope is development tooling maintenance; no new product phase, UI, financial policy, account migration, deployment, publication or merge. Design/runtime package changes: N/A.

## Delivered behavior

- Composed preflight binds source/runtime/target/platform/fixture identity, checks a marked isolated synthetic fixture and, for mobile, a recent hash-bound Device-session observation. Android invokes the existing strict installation guard with execute=False, never an installer. Delivery preflight checks read-only permission/scope metadata without claiming proven push access. Existing guard and45/120-second native helpers remain unchanged.
- The consumer wrapper imports committed SHA-256-pinned Madar workflow APIv1 at `cb44a994f7af69cd562f2d14b44f7c70cc30a5b9` via dev-tooling-dependency.json. Runtime engine899 remains unchanged. No shared implementation was copied into the app.
- Campaigns require preflight then representative pilot before cases. Complete plan/source/tool/runtime/target/platform/fixture identities prevent stale receipt reuse. Generated ignored build files and Python bytecode caches do not change source identity; non-ignored untracked source does.
- Failed/unavailable attempts and incomplete cleanup block progression. A failed composed preflight gets its own immutable artifact and attempt. Explicit bounded retry metadata must validate before more work begins; successful retries preserve old failures. One owner continues already-authorized stages without extra per-stage approvals.
- Receipt-derived summaries report pending/blocked/ready_for_review, current identity and missing stages. They grant no approval, merge or DONE. Persistent engine timer measures one process's UTC/monotonic heartbeats, waits, pauses and unknown interruptions; active effort remains unknown.

Setup/examples/contracts/limits: [campaign guide](../how-to/development-campaigns.md), [preflight guide](../how-to/task-preflight.md), engine `tool/dev_workflow/README.md`. Task branches: codex/phase02-tooling-hardening-app and codex/phase02-tooling-hardening-engine in the paired tooling-hardening workspace.

## Verification

Final109 app script tests pass in14.072s, including29 preflight,13 consumer workflow and39 unchanged Android guard tests. Engine24 workflow tests pass (latest0.486s), including a second generic consumer and real timer processes; all29 existing benchmark-host contracts pass in9.468s. Consumer composition tests exercise actual engine API and marked synthetic host fixtures, pilot gating, exact resume refusal, cleanup failure, failed preflight preservation and justified retry. No native device test or installation was needed for these host controls. Existing runtime/Flutter source and native helpers remain unchanged.

Independent review found four blockers, all closed after reproduction and regression tests: unrecorded/unusable preflight retries, receipts migrating across campaign/consumer/plan, interrupted exclusive writes and deep JSON escaping safe diagnostics. Forced normal bytecode generation exposed a further input-fingerprint instability in the composition regression; the reviewer independently verified the production cache filter and failure/retry path. Engine/consumer workflow YAML parses; existing quality jobs include new tests and a separate development-tool checkout. Hosted CI has not run, and its checkout requires the local engine commit to be published through an authorized delivery later. No remote permission was changed.

## Limits and timing

This fixes campaign controls and repeatable tooling failure modes. Unknown historical Mac lifecycle variance, Android graphics crash cause, missing final iOS acceptance, lost fixture bytes without backup and the historical six-hour interruption remain unresolved. No retention/restoration/reliability or measured speed improvement is claimed. Native UI must use current Device tools; the ledger checks caller evidence integrity but cannot establish whether a producer assertion is truthful.

First persisted task UTC15:32:21.399666. The later persistent timer began partway through implementation; worker windows7m31s and5m56s overlap Lead work and cannot be summed. At15:55:09UTC, observed full task window was22m47.861s, including analysis/search/edit/review/tools; active effort and exact per-cause attribution remain unknown before the persistent timer. Final timing suffix/closeout follows in detailed ignored journal, with remaining documentation/Git/memory overhead counted there. No benchmark target or savings percentage was invented.

Detailed action/failure journal: docs/log/tooling-hardening-execution.md, excluded from memory. Sanitized app/engine outcome digests use separate bank/source provenance; queue acceptance is not delivery completion.
