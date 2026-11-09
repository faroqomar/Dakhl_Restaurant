# Benchmark aggregate evidence review

Date:2026-11-08. Reviewer: independent read-only benchmark coverage/recheck agent. Status: **pilot and60-case native macOS matrix accepted within their stated scopes**.

## Boundary and source

Madar owns the existing generic measurement/protocol/resource tooling; Dakhl owns scenarios, synthetic fixtures and composition. No engine implementation change is required for this evidence review. Current consumed engine is `f30827df9fe3c4d2ef6d7d31b53bb0125eea82ec`; package source is clean and resolved runtime identity matches the pilot. No release, mobile performance or opening-debt authorization follows.

## Pilot review

Reviewed `outputs/completion-review/review-stage-001/benchmark-pilot-001.json`, SHA256 `dfff4e635a871e259c815bad952fa6a4483e1acc7d69f94f91a6020001dfcdc9`.

- Actual native macOS profile `review.sales.checkout`: status passed, one requested/accepted sample,33.434ms. Median and p95 coincide because there is only one sample; this establishes runner viability, not a distribution baseline.
- Current app fingerprint independently recomputed as `3a7e05889811c91e82ceed3909e59d84b47a3726991f62c344ce1d709447d8d8`, matching the pilot; app remains dirty at `cc91fae438101fce7ff4729e12bf3c2b64dacd70`, unreleased0.0.0+1.
- Receipt includes runtime package/resolution fingerprint, source and tooling hashes, AppleM1Pro/8logical CPUs, macOS27.2, Flutter3.47.8/Dart3.13.7, Xcode27.2 and20ms sampler interval. Runtime identity matches current consumed package source.
- RAM139.313152MB and CPU99.993867% average are sampled direct-child host-window measurements. Four resource reads over~52.3ms provide limited resolution; the host window includes verification/reopen/cleanup and between-sample setup. These are neither per-command RAM/CPU nor a speedup/latency-budget pass. One logical core equals100%; no total-machine CPU interpretation.
- Scenario source awaits durable acknowledgement inside the stopwatch; fresh adapter preparation, validation, exact reopen and cleanup occur outside elapsed. Samples are emitted only after durable verification. The unmeasured warm-up completes verification/cleanup before the first start marker. Cleanup is confirmed in the receipt.

No pilot blocking finding. The current registry contains60ready cases and3planned visible timing series. Expand only with the same source/tool/fixture provenance and retain failed attempts.

## Coverage disposition

The three new representative cases for additional debt, external deposit and category save passed scoped independent source recheck: real controller/store work, explicit synthetic financial counteraccounts, saved source/journal/receipt validation where applicable and native-store reopen. The negative missing-debt-receipt test rejects incomplete proof. Root owns focused test/analyzer receipts and native measurements.

Visible `orders.process`, `catalog.add_item` and `sales.add_item` remain planned. Supplier-ledger query is nonvisual; Q-05 ledger rendering remains pending. Q-06 actual native save/share/print interaction latency remains pending. No available-case aggregate should silently close those requirements. Existing ready cases must be measured or retain explicit separate dated evidence; new report/command cases do not certify unrelated old series.

## Matrix aggregate review

Reviewed `outputs/completion-review/review-stage-001/benchmark-matrix-001.json`, SHA256 `b70c5865165458beef77c76c32c91273a4b281e6574337c3c5af8fbc09665e54`. Producer interval:2026-11-08T18:25:32.946811Z through18:32:02.578021Z. This is an observed native baseline, not a performance-budget pass or improvement comparison.

-60unique operation IDs exactly match the current60ready registry IDs. All60results report passed,20requested/accepted finite positive timing samples each,1200samples total; all cleanup flags are true and diagnostics empty. The3planned visible cases do not appear.
- Independently re-ran the existing reviewed result validator without launching producers. Recomputed each median, nearest-rank p95, min/max, comparability key and fixture fingerprint. All match. All source fingerprints equal current `3a7e0588...47d8d8`; current runtime package/resolution identity matches each result. One hardware ID and identical tool/runtime/SDK/OS environment apply across the matrix.
- Coverage comprises9Phase01/02 cases,7completion nonvisual cases,9C1 operation cases and35review operation cases. The six Phase02 fixture manifests exist at their recorded canonical paths, their bytes match recorded hashes and JSON, and each is explicitly the small10-record profile. This matrix does not certify the medium/near20MiB profiles.
- The shortest aggregate resource window is~0.892seconds with at least41resource samples in a result. Resource figures remain aggregate sampled direct-child measurements, including each producer's disclosed between-sample work. Submillisecond query/report timings do not imply per-command resource precision. OS cache state is uncontrolled; CPU uses one-logical-core100% normalization. Startup records20fresh-process launches; the operation producers retain their established unmeasured warm-up semantics.
- Example acknowledged workflow p50/p95: checkout33.3785/34.748ms; additional debt42.472/44.379ms; external deposit33.6705/35.017ms; category save32.977/33.916ms. These examples have distinct scenario/fixture meanings and should not be ranked as equivalent workloads.

No blocking aggregate evidence findings. No test/native/benchmark rerun was needed. Keep the pending visible/ledger-render/native-dialog/mobile-performance and capacity-budget requirements above explicit; these results do not close them.

## Storage and review limits

This reviewer ran no compiler, native campaign, measurement producer or tests and changed only this compact document. Temporary read-only required-document scratch was removed. Free disk at the pilot review sample:89,240,428KiB; matrix review sample89,361,160KiB. Shared root campaigns are active, so global differences are not attributable to this document. No artifact copies or cleanup of shared evidence were performed. Canonical result/manifest retention is justified by source-bound raw evidence; no duplicate result export was created. Reclaimed0bytes; no task-owned obsolete artifact remains.
