# Build-first sales workflow candidate

Date: 2026-11-08. Status: implemented nonvisual candidate, small smoke check passed; independent review, broad tests, benchmarks and runtime/UI integration deferred under the current owner request.

## Scope and ownership

App owns `lib/sales/sales_operations_view_model.dart` and its new focused test. Madar implementation/API changes: N/A, because the existing reviewed sale coordinator, exact arithmetic, proposal/mapping and complete-state codec supply the required shared behavior. Engine pins, repository schema, active account paths, original draft controller and designs remain unchanged. The model requires an explicitly initialized portable snapshot. It never enrolls/migrates a live account or chooses opening values/date.

The model composes captured ticket checkout, history filters, original receipt snapshots, return history, refund/void intents and pure command previews. Submission uses the existing durable coordinator, accepts same-generation acknowledged snapshots and rejects unrelated account authority. Uncertain submission retains the exact immutable command for retry/replay; another command cannot replace it. The model avoids publishing after disposal and prevents listener reentry from dispatching a second write. These are implementation statements; only the focused scenario below has execution evidence.

## Execution and actual checks

- Read scoped Hindsight knowledge search and project-daftar CLI recall; checked relevant current contracts, source APIs, accounting rules and prevention entries. Memory provided historical boundaries; current source controlled implementation.
- Created the nonvisual model; formatter passed. Initial targeted analysis reported one `curly_braces_in_flow_control_structures` info; fixed it.
- Created a small synthetic test. First compilation failed because the fixture guessed a `lines` parameter on `mapVerifiedCutoverOpening`; corrected the fixture to the actual verified-opening API. This was an agent-caused fixture error, not a behavioral failure.
- `flutter test --no-pub test/sales/sales_operations_view_model_test.dart`: 1 scenario passed. It checks captured fractional quantity/price and Arabic discount checkout, receipt history, idempotent replay without a write, stale-snapshot refusal, full return with exact refunded net, and rejection of a void after return without a write.
- Targeted analysis of the model and test passed. After extending the scenario to return/void, the same smoke test passed again. No full suite, benchmark, native launch or independent review ran.

Tool-reported individual check durations were approximately 3–7 seconds; aggregate active effort/tokens/cost are unknown. Known rework: one lint correction and one fixture API correction. Avoid reusing guessed mapper signatures; inspect the method before writing fixture calls. Detailed controller journal remains the parent-owned phase log.

## Storage review

Baseline available disk: 95,499,396 KiB; final: 95,523,012 KiB (23,616 KiB more free). Sales folder: 44 to 56 KiB. Git objects: 4,638,100 to 4,638,244 KiB, a shared-workspace measurement; no cause attribution to this task. Final shared build directory: 2,145,076 KiB. No `tmp_objdir` path appeared in the bounded Git-object scan. New source/test total: 16,637 bytes; both are canonical retained implementation artifacts. No exports, archives, scratch fixture stores or screenshots were created. No obsolete task-owned output needed removal; cleanup reclaimed 0 bytes. Other agents may own active build artifacts, so this task did not remove shared compiler caches.

## Remaining integration

C2/C3 visual implementation awaits named design approval. The running schema-11 repository cannot mount this portable-state model until separately authorized/verified runtime composition; live cutover stays gated. The composition owner must publish acknowledged snapshots to other readers and reconcile finalized ticket workspace after checkout; the model does not clear drafts in a separate write or claim cross-document checkout/workspace atomicity. Full fault/restart/late-callback tests, benchmarks, native checks and independent review belong to the requested later verification stage. Parent coordinates Markdown memory synchronization; this log does not claim delivery completion.

Continuation: [sales session and approved C2 core UI](2026-11-08-build-first-sales-session-ui.md) records the later bounded owner approval and implementation. Earlier statements above describe the pre-approval checkpoint; live cutover and C3 gates remain.
