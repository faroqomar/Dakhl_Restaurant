# C1 operation benchmark candidate

Date: 2026-11-08. Status: source and registration integrated; 17 fixture tests, 35 runner tests and targeted analysis pass. Independent review and native profile measurements remain pending. This document closes no C1/Q02 checklist row and sets no performance budget.

## Ownership and existing contracts

Dakhl_Restaurant owns [the C1 producer](../../lib/platform/c1_performance_main.dart), [its operation fixtures](../../lib/platform/c1_performance_scenarios.dart), application command boundaries and synthetic validation. Madar owns the existing [benchmark host/protocol](../../../Madar_Engine/tool/dev_benchmarks/README.md) and [workflow ledger](../../../Madar_Engine/tool/dev_workflow/README.md). Engine implementation/API: N/A; the candidate adds no shared rule or adapter. Consumed runtime source at preparation is `bb00ccdad8f6710ca1778260d42ed5584f26a86c`, application `0.1.0-dev.5`; the separate development-tooling pin remains authoritative for the host tools. Actual execution must check both pins rather than infer them from this dated record.

The candidate reuses `run_benchmarks.py` for source/resolution checks, macOS profile builds, exact binary provenance and Madar process/resource sampling. Its external registration patch reserves nine cases and C1 routing. The three existing files stayed untouched during the other worker's native pilot. After that pilot passed and released its window, the Lead authorized applying the reserved patch and running focused checks. The integrated patch also corrects the stale planned `catalog.add_item` reason: its form now exists, while its visible/raster benchmark remains unimplemented. All original 16 ready cases/results remain intact; nine additional cases bring the registry to 25 ready operations. Ready means measurable implementation, not a measurement or performance pass. Independent review is still required before a campaign.

## Workload and elapsed boundaries

`c1-operations-v1` contains 1,000 deterministic synthetic products in 10 groups and 1,200 stock entries. Each product has a 100-unit opening; product `c1-product-0001` has 200 further one-unit restocks, giving 201 history rows and 300 units. Every thirteenth product is archived; every fifth has a 150-unit low-stock threshold. The inventory page size is 50. This represents a bounded workload, not the maximum account or a capacity promise. There are no real accounts, invoices, customers or phone numbers.

Each measured fixture uses a new `Directory.systemTemp` directory and a real `PowerSyncLocalDocumentWorkspaceStore`, `AccountsRepository` and `CatalogViewModel`. No normal application entrypoint or native account-location factory runs. Setup captures immutable authority and builds an independently expected complete account outside elapsed timing. Each fixture runs once; a second invocation fails.

| Operation | Measured interval |
|---|---|
| `c1.catalog.lookup` | `CatalogViewModel.filter` through `inventoryAt`, including stock projection, immutable read-model construction and consumed exact-code result IDs. |
| `c1.catalog.filter` | Query/group/low-stock filter through stock projection, model construction and consumption of the first 50 matching IDs. |
| `c1.catalog.page` | Page selection through stock projection/query reconstruction and consumption of the second 50 active-product IDs. |
| `c1.product.create` | Actual photo-draft controller/ViewModel create with 6.25 opening units through one durable account acknowledgement. |
| `c1.product.edit` | Prepared metadata edit through controller/ViewModel validation, stock safeguards and durable acknowledgement. Field entry/form setup is outside timing. |
| `c1.product.photo_select_save` | Reference selection, `rootBundle.load` of the selected 58,554-byte WebP and save of its reference key through durable acknowledgement. Image decoding, layout and preview rasterization are excluded. |
| `c1.stock.post` | ViewModel restock of 2.5 exact units through validation, stock safeguards and durable acknowledgement. This measures restock; loss/adjustment branches need separate series if measured. |
| `c1.stock.reverse` | Reasoned inverse of one existing restock on its original date, preserving the original row, through durable acknowledgement. |
| `c1.stock.history` | Cold ViewModel history composition, 201 dated running balances/reversal flags and consumption of the second newest-first page. No precomputed history enters this interval. |

These are nonvisual API/command intervals. No mounted screen, actual image decode, widget layout, raster completion, native pointer/keyboard dispatch or phone performance is measured. C1 visible-frame and native interaction performance remain separate pending work. The existing `catalog.lookup` case remains a distinct prepared-read-model series: it excludes stock/model construction and uses `completion-v1`. Do not compare it as an unchanged baseline for this broader ViewModel case.

## Verification, reset and resources

Before `ready/start`, the producer runs one real unmeasured operation, verifies it, closes/reopens its store and removes its own directory. Every measured iteration then uses a separate fresh store. Warm-up state never becomes a measured mutable fixture; code, asset and OS caches may remain warm. `rootBundle.load` is a real bundled-asset request, not a guarantee of a cold physical disk read.

Elapsed time starts immediately before the actual command/query and stops after its result/acknowledgement checks. Outside that interval, verification compares the entire canonical expected account payload, exact revision increment (zero for queries, one for writes), unchanged fence and empty workspace. It checks exact consumed IDs, all history row balances, known stock totals and acknowledged photo state. A fresh store owner reopens the same directory and compares payload/revision/fence/write token before the sample is accepted. This same-process reopen is not an OS restart or power-loss proof. An extra mutation, unknown write or failed acknowledgement rejects the sample.

The existing Madar host derives p50/p95 from reported monotonic samples and samples direct-child RSS/CPU. The resource window includes inter-iteration fixture setup, expected-state construction, verification/reopen and teardown. It reports absolute resident peak, not heap growth or per-operation incremental memory; warm-up allocations may remain resident. Requested 20 ms sampling can miss shorter peaks. Child descendants, OS/GPU work, image decoding and native input costs are outside the declared case. The required 100 ms producer lifetime after the flushed `end` marker lies outside the operation/resource window. No artificial wait or loop pads either measured interval.

Only a real profile campaign can produce measurement results. Failed/unavailable host results retain null metrics; no placeholder p50/RAM/CPU result exists in this source delivery. No numeric budget or optimization claim has been accepted.

## Coordinated execution handoff

The Lead granted the exclusive unit-test window after the native pilot. These focused commands passed:

```sh
flutter test --no-pub test/platform/c1_performance_test.dart
/Library/Frameworks/Python.framework/Versions/3.13/bin/python3 -m unittest discover -s tool/dev_dashboard/tests -v
```

Then use the reviewed workflow preflight and one unique one-iteration pilot before any matrix. The existing runner selects `flutter build macos --profile --no-pub -t lib/platform/c1_performance_main.dart`; build/install remain outside measurement.

```sh
/Library/Frameworks/Python.framework/Versions/3.13/bin/python3 tool/dev_dashboard/run_benchmarks.py \
  --engine-tools-root /Users/eros/Dev/Eros_Projects/Madar_Engine \
  --case c1.catalog.lookup --iterations 1 \
  --output outputs/completion-review/c1-operation-benchmarks/pilot-1.json
```

This is a proposed command, not an execution record. Do not overwrite a prior output. After pilot review, use explicit case IDs and 20 independent fixtures per case. Avoid `all-ready`, which includes unrelated historical scenarios. The first valid result establishes a baseline under its actual app/engine/tool/fixture/hardware/OS/profile identity. Mobile sampling requires a qualified adapter; host results cannot substitute.

The first fixture run passed 16 cases and failed the reversal exact-payload assertion: the existing scale-three movement serializer retains a whole-unit negative quantity as JSON double `-1.0`, while the expected fixture used integer `-1`. The fixture now preserves that exact wire representation; the final 17 tests pass without weakening the full-state comparison or changing product/engine code. The retained failure is separate from the successful run.

Source/test status, hashes, registration before/after identities and storage evidence were recorded under `outputs/completion-review/c1-operation-benchmarks/`. The [repository cleanup record](../log/2026-11-28-public-repository-cleanup.md) gives the original revision and recovery command. Root owns integration, independent review, campaign ownership, memory closeout and checklist decisions.
