# Penpot whole-workflow delay audit

Date: 2026-11-06. Scope: owner-requested read-only audit of the Consolidate Remaining Phases thread and its existing receipts. Snapshot cutoff: approximately 19:11 UTC. No messages or changes to the referenced thread, services, artwork, app or engine. Madar runtime/API/packages/Design: N/A. This follows the narrower [source investigation](2026-11-06-penpot-performance-findings.md).

## Corrected conclusion

The earlier answer extrapolated a synthetic filtering-step saving into about one minute per100 equivalent calls. That calculation concerns one helper, not total delivery time. It does not answer the owner's concern about a day of unfinished work. The evidence supports a broader diagnosis: first-time installation, late discovery of transfer/content defects, repeated browser/save recovery, delayed backend-error classification, and a serial native-delivery stage while parallel agents prepared more sources.

## Measured chronology and limits

- Local setup began after the owner's13:20UTC instruction on November5; the native pilot handoff completed17:42UTC. Two sequential setup timer windows classify2h47m11s as download/image waits. Transport helper accounting/retry bugs, logger ownership repair, partial-download recovery and pilot/photo repairs consumed additional time without exclusive attribution. Source: `outputs/penpot/completion/selfhost-time-review.json` and original setup child messages.
- The first broad design segment ran from17:45November5 to09:33November6 in wall time. Its timer records15.81wall hours and5.00observed monotonic hours, including10.81hours of unexplained clock-gap excess. Activity in that gap remains unknown. Do not call it productive work, idle time or continuous rendering. Source: `outputs/penpot/completion/package-heartbeat.json` and `package-current-checkpoint.md`.
- The fresh restart/exporter repair occupied the subsequent checkpoint-to-resume window. The agent also mislabeled a T3 host restart as an owner stop; the Lead corrected it and resumed from the saved wireframe.
- From10:28:32 to17:38:29November6, the timer records7h9m57s elapsed. Export coverage increased from68 to111pairs. The timer's empty wait breakdown combines tool waits, review, documentation and coordination; it does not measure active effort. Source: `export-recovery/time-cost-review.json`.
- A more revealing subinterval is12:56–17:38: paired exports increased110→111 while detail review, repair exports and save failures continued. This4h42m interval was not idle: the action journal records repeated correction exports, and content qualification grew. The slow net coverage increase exposes the cost of rework rather than the cost of one filter function.
- The19:11 qualification-register snapshot records131paired exports and77content-qualified proposals out of165required new pairs. Exporting and qualification are separate. No new owner approval follows from either count.

## Specific avoidable causes

1. Early overview checks missed visible checkbox/select states. Detail checks at13:15 retracted affected qualifications, leaving three qualified pairs at that moment. Later correction required native import/export and another review. At18:56, independent review found87,500 in prepared artwork where the frozen reference showed67,500; the source reviewer had dismissed the digit-region difference as antialiasing. These are content failures, not harmless pixel differences.
2. The initial successful pilot did not establish compatibility for all later atlas transforms. Later native outputs showed blank translated photos and wrong full-capture origins. The old child paused after discovering these defects at20:45November5 and performed transform/origin repairs. Reusing an unchanged zero-origin success did not prove the changed transfer condition.
3. Agents tried smaller units, root moves, renderer changes and repeated saved-state reconciliation before the Lead classified backend heap exhaustion. Logs later established25heap errors during15:20–16:40; classification happened17:43. Earlier safe backend-log classification after repeated update-file failures was a missed opportunity, although its time saving is unmeasured.
4. Preparation grew to104supplemental source scenes, and the global269-scene marker audit consumed32.61minutes. The Lead froze further broad expansion. The104scenes are inventory, not104mandatory new boards. Additional source preparation did not clear the native queue.
5. Ten Gemini source-check reports supplied no native exports. One browser controller still performed import, placement, naming, preset setup, save, reopen and export. Parallel immutable native reviews began later. The correct improvement is earlier short feedback cycles and parallel review of finished native batches, while retaining one live writer.
6. Logs record repeated output truncation, lost timer handles, an unsupported owner-stop claim, premature orchestration termination, an avoidable route404 and a premature renderer-pilot success statement. Written prevention guidance alone did not prevent these recurring errors.

The independent read-only reviewer confirmed these findings and their source locations in `docs/log/phase-completion-execution.md`, notably lines130–136,174,183,191–194,238–240,284,314–316 and324–330 at review time. Ongoing appends may move later entries. This audit did not rerun the archive analysis, app tests, source benchmarks or service recovery.

## Repair priorities

1. Use a short batch as the delivery unit: prepare, import, save, export and inspect critical amounts, controls, photos and origins before expanding that transfer method. Reuse validated unchanged sources. Review immutable completed batches in parallel while the single writer continues.
2. Escalate a repeated server failure signature across distinct units to the Lead's bounded backend diagnosis. Do not let each smaller unit reset a campaign-wide failure budget. Keep productive read-only review separate from failed writes.
3. Freeze broad source/cosmetic expansion and use exact remaining/repair receipts. A fresh export does not equal a content-qualified pair. Close blocking content defects before adding more candidates that depend on the same method.
4. Source-level investment should target a resumable visible native batch workflow and the costly large-document load/save path. The small subtree-first patch remains useful but cannot fix orchestration, data fidelity or repeated UI round trips. New batch tooling is a proposal, not an implemented capability or authorization to bypass the owner's browser workflow.
5. Establish an ETA from completed, content-qualified batches per elapsed hour under stable conditions, including recovery and review. Existing records do not justify a promised percentage reduction or a precise completion time. A smaller active document may help, but the current canonical-page rule and preservation obligations prevent unilateral reorganization.

All elapsed categories overlap unless their explicit intervals are disjoint. Do not add parent and child run times, source-review times or marker-audit time into a fabricated total. The practical savings target is multi-hour rework and blocked delivery; the amount achievable remains unmeasured.

## Audit execution

Read parent message history in three pages, both design children in bounded pages, focused current-turn Hindsight and the relevant journal/receipt sections. Some initial combined reads again exceeded the output bound, an avoidable investigation cost; subsequent reads used stored structured results and selected excerpts. An independent reviewer inspected existing records without rerunning campaigns. No billing/active-effort estimate is available. Reference thread remains read-only. Sanitized Markdown is the durable record; no raw thread transcript or private payload is retained.
