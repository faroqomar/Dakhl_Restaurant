# C1 API baseline independent acceptance

Recorded: 2026-11-08T07:12:10.968161+00:00. Root accepts the bounded independent baseline review. [Disposition](../../outputs/completion-review/c1-operation-benchmarks/api-baseline-50-1/independent-review.json), [aggregate data](../../outputs/completion-review/c1-operation-benchmarks/api-baseline-50-1/aggregate-result.json), [execution log](2026-11-08-c1-api-baseline-50.md).

Nine operations each retain 50 chronological latency samples: 450 samples total. Independent review matched 108 input bindings, 326 frozen consumer inputs, 55 stage-evidence bindings and ten passed chained workflow stages, then recomputed all p50/p95 values and CPU-average arithmetic. All 7,236 reported OS observations reconcile. Raw periodic OS traces are unavailable, so sampled peaks cannot be reconstructed independently.

| Operation | p50 ms | p95 ms |
| --- | ---: | ---: |
| Product create | 183.859 | 192.642 |
| Product edit | 185.208 | 195.295 |
| Bundled photo select/save | 184.1855 | 197.794 |
| Stock post | 186.246 | 199.416 |
| Stock reversal | 188.902 | 211.382 |
| Stock history | 0.6605 | 0.751 |
| Catalog lookup | 49.098 | 49.938 |
| Catalog filter | 45.224 | 46.448 |
| Catalog page | 48.217 | 49.605 |

The producer performs verified warm-up before timing, uses fresh fixtures and validates complete expected state plus reopen/cleanup. Elapsed excludes setup/validation/cleanup. Resource markers cover the broader direct-child process window, including inter-iteration work; they do not isolate incremental CPU/RAM per command. Native binary/cache hashes match the earlier pilot: no profile rebuild or measurement retry occurred. Metadata-only timer/path/stream failures remain in the execution record.

App owns synthetic catalog scenarios; reviewed Madar owns workflow/measurement tools. Runtime source, pins and producer stayed unchanged through measurement release. The later new shared engine race-test file is outside the 326 consumer inputs and requires its own review/adoption continuity. No real accounts, production code changes or remote action occurred.

This establishes a macOS PROFILE API baseline. It does not establish optimization, performance budgets, frame/UI/mobile acceptance or release readiness, and it does not close global Q-02 for other major features. App memory delivery remains pending the final normal project-scoped sync/check batch.

Review storage: free 97,167,852→97,145,312 KiB; Git/evidence unchanged, temporary Git stores zero. Worker removed 40,460 bytes of duplicate stdout and nine empty stderr logs after preserving exact content/hash reconstruction; all owned fixtures were removed. Canonical native cache and source/evidence remain retained.
