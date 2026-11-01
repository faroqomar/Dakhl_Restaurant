# Phase 02 native timer correction

Date: 2026-10-31T20:18:33.617132+00:00

Hosted app candidate5c8d3cf failed its quality job: 569 tests passed and one picker test measured59.980ms against its unchanged60ms lower bound. Dependent native builds were skipped, not passed. The two frozen-reference checks passed separately. The failed run41236147068 is preserved as historical evidence.

Both test-only readiness helpers used a Timer callback to finish immediately, even if their own monotonic clock had not reached the deadline. Deterministic tests delivered that callback early: the picker regression failed at14.342ms against60ms and the app-readiness regression at16.835ms against40ms. The fix treats a timer callback as a wakeup, checks the same monotonic expiry predicate, and rearms the remaining time with a one-millisecond floor to avoid a zero-delay loop. Late success is still rejected. No lower-bound assertion, maximum bound, test tag or CI check was relaxed;45-second app readiness,120-second picker waits and existing outer bounds remain unchanged.

Independent review verified both initial failures and final results:24 focused tests,572 non-golden tests, clean analysis and formatting. Only the two test-only helper files and their regression tests change. Production libraries, the reviewed engine899, guard and native entrypoints are unchanged. Existing five golden checks,67 script tests and30 dashboard tests retain their unchanged-source scope; no new optimization or performance claim.

The new candidate requires fresh hosted CI and current native artifacts bound to both updated helper hashes. Earlier native WRITE attempts passed functional assertions but failed host cleanup verification; those receipts remain failed. A separately reviewed observation-only process cleanup fix waits within the original five-second bound for a fresh empty process group and reaped leader, never signals unknown members, and retains prior failures. New verification uses separate source-epoch ledgers and fresh fixture identities. No historical retention, native acceptance, merge, supported release or deployment is claimed here.
