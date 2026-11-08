# Restarted Completion draft delivery

Status: BLOCKED for merge approval. Step5 authorizes paired draft delivery; no merge, release or reduced Completion scope.

[App PR11](https://github.com/faroqomar/Dakhl_Restaurant/pull/11) depends on [engine PR9](https://github.com/faroqomar/Madar_Engine/pull/9). Runtime pin `97a5a6f4003a7084304d87e1b9554397f9bd7ac8` is a documentation-only successor of independently reviewed engine source `bc4e8fc63a18fd9c985cf475110d3624c8c8a97f`; package source is identical, domain0.1.0-dev.3. Development tooling remains separately pinned at `f7f68988561d25cc93eb28c0ec989847526b2df9`. Publish engine first; eventual approved integration order is engine then app with exact final compatibility checks.

The app diff implements nonvisual catalog read models, inventory commands, held ticket persistence, settings and supplier/material commands with ViewModels, account safeguards, tests and operation benchmark harness. Shared stock/commerce/journal/Unicode rules live only in engine packages. No new UI or report candidate is shipped. Untracked report, design and unrelated documentation work remains local and excluded.

[Independent Step4 evidence](2026-11-07-completion-step4-restarted-review.md):49engine tests, analyzer/boundaries,15independent catalog source cases, exact pin/source checks and28focused Flutter tests passed. The28include untracked incomplete report tests and are working-tree evidence, not a committed-only test count. Earlier637tests similarly included5untracked report tests;45engine tests,109Python checks,5goldens and native build results are historical Step3 source evidence. Later compatibility fixes require full final-source validation. Exact logs are preserved under outputs/completion-review/step4-restarted and outputs/completion-build.

Benchmarks: seven real-adapter operations,20samples each, at the Step3 fingerprint; see [Completion benchmarks](../phases/completion-benchmarks.md) and `outputs/completion-build`. No optimization comparison or speedup claim; no final-source rerun. CPU/RAM windows include inter-iteration preparation/readback/cleanup; elapsed covers operation markers. Final candidate performance remains pending where required.

Blocking gates: report collation/aggregate compatibility; approved remaining UI; financial account/opening/correction/migration mappings and durable journal/effect workflows; full final-source tests/native builds/CI; installed updates, recovery/rollback, cross-target portability, signing/system-service evidence. iOS earlier compilation failed ENOSPC. Earlier Android/macOS binaries lack complete final-source provenance. These are blockers, not non-blocking risks.

Hosted checks start on publication; old-head successes do not certify final heads. Both PRs remain drafts and no merge approval is requested while these gates remain unresolved. Memory synchronization is separate and pending until project checks confirm delivery.
