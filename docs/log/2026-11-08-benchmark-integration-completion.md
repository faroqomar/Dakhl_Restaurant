# Completion benchmark integration and sales catalog parity

Date: 2026-11-08. Actor: `visible_benchmark_integration`. Status: source frozen; root owns native measurements, aggregate review, tracker and memory delivery. No native latency, RAM, CPU or physical-device result is claimed here.

## Scope and ownership

The app owns the retained workflow fixtures, native producer routing, registry and presentation. Madar owns the reused storage/capability contracts and generic host measurement protocol. Engine implementation/API/pin changes are N/A for this worker: it consumes the parent-adopted revision and copies no engine implementation. No live account, cutover, merge, publication or release action occurred.

Four visible cases now route to `visible_performance_main.dart`: `orders.process`, `catalog.add_item`, `sales.add_item` and `visible.suppliers.ledger`. Each uses the existing real surface/controller and fresh isolated adapter, a fixed800×600logical viewport at2×DPR, one unmeasured warm-up and20default samples. Native viewport/DPR proof remains with root. The elapsed scope stops at completed native raster, excludes typing and input dispatch, and excludes the checkout confirmation dialog. Broad sampled RAM/CPU still includes between-sample fixture preparation, verification and teardown; it is not a per-command isolated resource sample. Registry readiness means implemented measurement source, not a measured result.

The workload fingerprint for these four cases includes framed bytes from both `visible_performance_scenarios.dart` and the reused `review_performance_scenarios.dart`, plus case and scenario version. Tests prove that seed-only, UI-workload, case and version changes invalidate the key. Existing nonvisible fixture hash behavior remains unchanged. The profile timeout is900seconds for this harness.

The new `review.suppliers.opening_write` case captures the approved synthetic0→1000IQD amendment before timing and measures only submission to durable acknowledgement. Verification checks the immutable original opening, linked cutover-date difference, committed receipt, required feature marker, recognized supplier opening, retained lineage/cutover/provenance, exact account change and native store reopen. It rejects missing receipt proof and unexpected cash changes. It does not choose actual opening values or activate live cutover. The registry contains65ready cases:36review and4visible cases among the existing harnesses.

## Retained Phase04 presentation gap

Frozen `electron-reference/app/ui/commerce.js` defines group counts across all unarchived products, independently of search and pagination, and shows in-cart quantities for untracked products. The app now exposes an immutable readonly `SalesViewModel.groupCounts` projection through `SalesWorkflowSession`; the surface renders those counts and the untracked cart quantity. Stock eligibility and write semantics are unchanged. A90-product widget fixture covers pagination, archived exclusion, ungrouped inclusion, unavailable tracked-product inclusion and stable counts through group/search changes. A second widget test uses real add buttons and checks the untracked card quantity changes1→2.

## Executed checks and attempts

Canonical evidence lives under `outputs/completion-review/remaining-completion-001/`:

- `benchmark-integration-python-001.log`:39Python checks pass, including routing, explicit ready-set integrity and shared-seed workload identity.
- `benchmark-integration-flutter-001.log`:49fixture checks pass:42review checks including opening positive/negative cases, plus7visible checks at800×600widget viewport. Widget execution does not qualify native raster/DPR timing.
- `benchmark-integration-analysis-001.log`: scoped analysis reports0issues. An earlier analyzer call found one missing-braces style info in the new opening verifier; the worker added braces and the recorded successor passes. Formatting reported0changes before that final run.
- `sales-catalog-parity-red-001.log`: both new presentation checks fail against the prior UI, establishing the missing count and untracked quantity behavior.
- `sales-catalog-parity-green-001.log`:32sales surface/model/session and visible-fixture checks pass after the presentation change, including the7visible cases at800×600.
- `sales-catalog-parity-analysis-001.log`:0issues. Format completed before this successor test run.

The compiler window was released after each completed batch. No Flutter/native worker process remains owned by this worker. Initial intake used an oversized combined documentation read; the useful source inspection afterward stayed bounded. That avoidable output did not substitute for source verification. Overall task start/elapsed was not separately sampled; root's persistent campaign timer owns timing. The runners reported12seconds for the49check batch,7seconds for the32check batch and0.103seconds for Python. These are runner durations, not feature benchmarks.

## Storage and handoff

[Source hashes, check state and storage receipt](../../outputs/completion-review/remaining-completion-001/benchmark-integration-handoff.json) freezes11owned source files plus3unchanged visible harness inputs. Canonical check logs and one receipt remain; passing fixtures asserted their temporary directories were removed. No exports, native app copies or uncertain recovery files were created/deleted by this worker.

Baseline: free84,381,356KiB; app Git18,525,496KiB/build3,658,864KiB/outputs7,743,032KiB. Handoff sample: free82,286,692KiB; Git18,525,496KiB unchanged/build3,632,856KiB/outputs7,743,380KiB. `.dart_tool` measured2,587,016KiB; engine ICU output measured1,596,808KiB. No Git temporary object directories were present. Concurrent parent native/cache work prevents attribution of the nearly2GiB free-space fall to this worker; root received the measurements for campaign diagnosis. This worker reclaimed0bytes and preserved shared caches because ownership/active use was not established.

Root must run native pilots/matrix from the frozen successor, obtain independent review, update trackers and include this compact log in separate app memory synchronization/check. No review or native result is inferred from readiness or fixture passes.
