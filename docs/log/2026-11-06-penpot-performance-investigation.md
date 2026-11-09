# Local Penpot performance investigation

<!-- hindsight:ignore -->

Owner request: investigate the delay while existing agents continue, including source-level remedies if warranted. Started in T3 Code at approximately 2026-11-06T18:21:31Z; first diagnostic command timing is tool-reported. Active effort, tokens and monetary cost are unknown. This is consumer design tooling; Madar runtime/API/packages/Design N/A, app runtime and engine pin unchanged. No new phase, design approval, merge or deployment.

## Ownership

The existing design controller retains exclusive browser/file-write ownership. This investigation reads runtime/source/receipts and writes only its own diagnostics and this log. Preserve live services and design data; do not raise limits or restart services without measured need and coordination. Project Markdown/current source govern historical memory.

## Attempts and observations

- Preflight: read stop-slop, T3 Hindsight and Penpot skills; searched project knowledge pages and personal memory registry. Knowledge pages are old Phase 00 material and do not diagnose current performance. Current-turn Hindsight hook covers recent failures. Read both project rules/plans/trackers and Madar ownership sources; large combined output exceeded the output bound, an avoidable context cost. Subsequent reads are targeted.
- Read running thread statuses and recent messages. Parent has ten Gemini source-check agents and a sole Codex Penpot operator; preserve ownership. Current operator reports two saved/reopened artwork exports after heap adjustment.
- First Docker command used host default context and failed because Docker Desktop socket is absent. Existing runtime uses explicit colima-penpot; corrected read-only commands succeed. Prevent by reading private runtime README and always naming context.
- A guessed self-hosting guide path does not exist. Decision 0020 points to private compose README; no retry of nonexistent path.
- Read exact runtime: five ARM64 services, Penpot image tags 2.18.5, reported application 2.18.5-RC1, Colima 4 vCPU/6 GiB on 16 GiB host. Backend current JAVA_TOOL_OPTIONS=-Xms512m -Xmx3g.
- Read existing receipts: exporter 10 s readiness default failed after measured 12.9 s get-page; private current-container patch raises to45 s. Backend prior1.44 GiB maximum logged25 Java heap errors in15:20–16:40UTC; existing lead changed to3 GiB. These are already-applied fixes, not changes made by this investigation.
- Initial current snapshot: backend115.24%CPU,3.625GiB RSS/cgroup memory, exporter idle, VM available1,225,008KiB. JVM used heap1,665,251KiB with1GiB humongous regions; six full GCs and52.5s cumulative GC since backend restart, not proof of a continuous GC stall. No cgroup OOM kills.
- Official GitHub tree web fetch failed; use exact pinned primary-source files instead of guessing another tag.

## Handoff

Trace whole-file load/save/export costs at installed revision f44566963daf61fce4d8608e7c5e8c27c5853a88. Distinguish active editor/import/export time, full-file archive audit, recovery and preparation/review overhead. Preserve private raw logs and record sanitized measurements only.

## Further diagnostic batches through 2026-11-06T18:37 UTC

- Copied the installed backend JAR outside the runtime and extracted eight relevant source modules. Downloaded exact pinned primary files; installed files.clj and files_update.clj hashes match upstream. One guessed frontend persistence source returned404; stopped that unrelated path. Official upstream issue12602 describes broader save work, but installedsource already includes affected-page validation, so no missing-backport claim.
- Read sanitized recent service-log classifications privately: frontend2026-11-06T18:14:17–18:28:06 had one get-file response101,241,481bytes, one get-page953,442bytes,15update-file responses all200, and no backendheap/error lines in captured15m. Access log lacks request duration: no inferred HTTP timings. Private logs mode0600; no raw payloads or credentials in repository.
- Source-level trace: get-page loads permittedfile/page then applies prune-thumbnails to allobjects before subtreepruning. ObjectsMap supports lazyper-entrydecode; fulltraversal defeats that selectivity. Proposed order change keeps permissions/schema/loading untouched. Saving source has separate locks/load/change/persiststeps; patch does notfix saveheap.
- Parent coordination steer returned thread_not_sendable (no running turn); no restart or retry of parent. Later delivered a narrow findings steer to the alreadyrunning solecontroller; its work continues.
- Prepared exact3-line get-page patch, original/patchedsources, pureClojuretests, and provenance. First test failed atline60 because extra parentheses closed let scopeearly; preserved output, fixed only syntax and added nativeObjectsMap/absent-thumbnailcoverage. One orchestration call abortedbeforedispatch; reissued confirmedundispatched patch. Successfulrun:4tests25assertions0fail/errors. Reviewer independentlyreran same suite and found no blocking patchissue.
- Original plainmapmicrobenchmark30alternating samples,89735objects/400selection: p508.187→0.466ms,p9513.269→1.601ms. Independentreviewer8.93→0.51msmedian. Additional diagnostic using fresh actualserializedObjectsMapdecoder caches15samples: p50586.918→2.973ms,p951013.470→33.197ms. Process21.67s,maximumRSS502,611,968bytes; entireprocessmemory includes fixturegeneration, tests and benchmarks. No liveHTTP/save/renderlatency improvement measured.
- Read frozenarchive111b once locally in13.024s:89,735shapes,66frames,40,260groups,42,890paths,6,401rects,83svg-raw,35circles,85hidden. Onepage;562MBuncompressed/184MBZIP;pathshapeJSON441.6MB. These are archivecounts, notcurrentlivecounts or permissiontodelete.
- All diagnostic files are ownedscope. Existingdirtywork, image/compose/services/database/account/application/pins arepreserved. Sourcepatchproductionnamespacebuild, representativeactualnativeexports and customimage deploymentremainunverified.

## Waste and automation review

Measured fullarchiveanalysis13.024s and standaloneObjectsMap diagnostic21.67s; tool walltimes recorded in session. Threadwalltime includes source reads/review/documentation; activeeffort/token/cost unavailable. Avoidablecost: initialunboundedcombineddocumentationoutput, defaultDockercontext, guessedguide/frontendpaths and testscopeparenthesiserror. No redundant service restart, wholecorpus rebuild or realaccounts access.

Prioritized backlog: (1) fingerprinted persistentexporter override and readinesscheck so containerrecreation cannot silentlylose45sfix; acceptance exactsourcehash,positive/negativepatchcheck,recreationtest,rollback. (2) safe per-stage requesttiming/decode metrics, no payloads,secrets or broadDEBUG; acceptance correlate one representative save/export with JVM+DB+browser timing. (3) evaluatedget-pagepatch in clonedprivatefixturewith identical IDs/layers/PNG/SVG/crop output; acceptance 4conformance testsplusrepresentativeactualexports and capacitycomparison; noincreasewaits merelytomaskfailure. (4) preserveallhistoricalboards but evaluate slimmeractivepage/retiredartifactarrangement or reviewedpathdedup withoutlosingfrozenappearance. Canonicalpage rule prevents unilateralreorganization; authorizesno deletion. Benefits beyondmicrobenchmarkremainhypotheses.

## Closeout verification

- Read the project documentation skill and checked the findings against source, evidence and approval limits. All relative findings links exist; artifact hashes match the diagnostic receipt. No ADR is needed for a proposed, unapplied dependency optimization.
- The first patch dry-run used the app root, where the upstream backend path does not exist, and skipped its hunk with exit1. It changed no files. Corrected the dry-run to name files.original.clj directly inside the diagnostic directory; the hunk checks successfully. This was avoidable verification setup overhead.
- Added exact Java version/command,384-MiB heap argument, JAR SHA256 and independent review limits to the receipt. Follow-up reviewer confirmed separate empty ObjectsMap decode caches; its15-samplep95 is the largest sample.
- Final service check confirms all five original services remain running. No application tests/builds were run because no app/engine code changed. Production Penpot namespace/build and live export parity remain pending.
- Updated the existing prevention catalog by append, preserving other threads' edits. Ran project-scoped memory sync/check; the check is authoritative for delivery, with pending states reported rather than treated as complete. The CLI accepts --path syntactically but sync scans all allowlisted sources, so do not claim isolated source synchronization. Detailed journal stays excluded; sanitized findings enter project-daftar.
