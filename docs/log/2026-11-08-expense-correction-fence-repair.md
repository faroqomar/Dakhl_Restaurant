# Expense correction history after authority replacement

Recorded: 2026-11-08T08:39:47.941186+00:00. App-owned isolated correction-family repair; engine runtime/API changes: N/A. The owner-accepted section F requires preserving old receipt fence provenance while new commands use the active authority.

Independent review found a P2 regression: the family compared committed revisions globally. A structurally valid complete account with old-fence history and a new authority could therefore reject valid edit/delete commands with `corrupt_state`. Three actual probes reproduced pure history rejection and real PowerSync edit/delete rejection after same-account portable restoration. Earlier probe compile/setup errors remain separate review overhead in the retained evidence; they do not count as product defects.

Root removed the redundant global revision comparison. The immutable `PortableJournalState` constructor already validates all receipt revisions per fence; the family uses durable sequence for cross-fence order. Permanent regressions retain the three cases and prove that a non-increasing revision within the same fence still fails closed. No financial mapping, identity, authority or rejection policy changed.

All35 new correction tests pass after the fix, including the three restoration regressions; targeted analysis is clean. The earlier72 spending regression passes retain their unchanged source scope. [Repair source/result packet](../../outputs/completion-review/durable-expense-corrections/fence-revision-repair/review-inputs.json). Independent focused recheck remains pending; no candidate approval, UI, live activation, benchmark, merge or release follows from these results.

The restore fixtures preserve account lineage and full portable payload into a fresh store with a new fence/revision1. They do not assert that `replaceGeneration` itself resets revision; existing same-container replacement increments its own counter. No real accounts or app runtime bootstrap were touched. Test fixtures close/delete their owned roots; final storage and normal separate-bank memory delivery follow the batch.
