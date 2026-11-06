# Typed ticket workspace lifecycle

Date: 2026-11-07. Status: implemented nonvisual candidate; independent review and approved UI integration pending. Draft operations do not post sales, stock, cash or journals.

## Models and encoding

`TicketDraft` retains identity, date, order type, raw discount text, note, held label and immutable line snapshots. Each `TicketLine` stores product identity, positive exact thousandths (at most10^12 units) and whole-IQD saved price (0..10^12), with at most200lines. Values use existing Madar date/exact parsing. No live product-price lookup or arithmetic occurs. Invalid draft values reject without writes.

The existing `WorkspaceDocument` version1 envelope remains unchanged. Its active map stores `ticketVersion: "1"` and a JSON `payload`; held maps use the same tagged encoding for held ID, label, timestamp and draft. Quantity units serialize as decimal strings. Form maps remain intact. Typed payloads reject extra/missing fields, unsupported tags, malformed records, duplicate held/draft identities and more than40held records. An empty active/held envelope initializes from an explicitly supplied fresh draft. Nonempty legacy presentation maps fail closed as `unsupported_ticket_workspace`; no migration/discard is inferred. Future migration needs explicit mapping and preservation evidence.

## Transitions and authority

`TicketWorkspaceController` composes the existing `AccountsRepository` only. `load` reads the fenced envelope and retains its own generation and workspace revision. Hold appends the full current draft and opens an explicitly supplied empty fresh draft. Resume atomically removes the selected held record and, when active lines exist, stores the previous active ticket in the vacated slot; it therefore works at the40-held limit. Delete changes only the named held record. Labels follow trimmed/80-UTF16-unit source behavior for holding; localized swap label/time and IDs come from the caller, avoiding hidden clocks or ID policy.

Each transition writes one envelope with repository revision compare-and-swap. The controller checks its own captured revision synchronously before calling the repository; two controllers sharing one repository cannot use a newly updated repository revision to overwrite stale local state. The repository's read-only workspace snapshot getter supplies that check. The adapter still enforces CAS for concurrent in-flight writes. A returned success is accepted only while generation and canonical payload still match and no active/held identity has become a saved sale during the await. No local active/held update precedes durable confirmation.

Definite failure preserves both tickets. Unknown acknowledgement preserves displayed prior state, blocks further writes through repository pending authority, and requires `reconcile` followed by actual payload readback. No retry or synthetic acknowledgement clears uncertainty. Failed loads clear the controller's usable state; unknown legacy data never becomes an empty workspace. Saved sale identities, including voided sales, cannot revive as active/held drafts; they produce `finalized_ticket` rather than silently deleting workspace records. The eventual checkout recovery flow must explicitly reconcile that condition. If a same-generation account save finalizes a ticket while workspace acknowledgement is pending, the controller returns `finalized_ticket` and preserves its prior displayed state. The workspace may already contain the rejected draft; this check does not roll back storage. Reload fails closed until an explicit recovery flow resolves it. Cross-process atomic coordination between checkout and workspace writes remains separate work; the controller guard only observes the current repository account snapshot.

Source behavior: frozen `ux.js`60–73 and `commerce.js`193–208. This implementation preserves core hold/swap/delete and identity rules while adding explicit typed payload validation and the reviewed repository's failure/fence handling. It does not claim compatibility with external Electron localStorage blobs; those are protected, not auto-migrated.

## Actual checks

Tests preceded implementation and observed missing library/getter failures. A later finalized-sale-ID test failed before its guard was added. Twelve focused tests pass: immutable snapshot/form preservation and restart, definite failure/retry, unknown commit/readback, stale shared-repository controllers, simultaneous CAS conflict, generation replacement, legacy protection,40-limit/swap/delete, finalized-sale protection before write and after delayed acknowledgement, and actual local PowerSync adapter close/reopen in a disposable synthetic directory. Account document revision remains unchanged by workspace operations.

First focused analysis found18brace-style findings; bounded `dart fix` repaired only this owned file. Final analysis outcome is in the parent handoff. No full native/device/build/CI/benchmark pass, independent review, checkout effects or UI completion follows from these tests. Test logs: /tmp/ticket-red.log, /tmp/ticket-finalized-red.log, /tmp/ticket-final.log. The root owns the repository getter and integration review.

## Independent review correction

The reviewer found that the finalized-ID check ran only before awaiting persistence. A controlled test delayed workspace acknowledgement after commit, saved a same-generation account containing that draft ID, then released acknowledgement. The original controller incorrectly returned success (`/tmp/ticket-race-red.log`). The post-acknowledgement identity check now rejects publication; the test also confirms persisted data remains present and reload refuses the finalized draft. All12workspace tests passed (`/tmp/ticket-race-final.log`), and focused analysis reported no issues (`/tmp/ticket-race-analysis.log`). Independent re-verification remains the reviewer’s responsibility.

## Integration checkpoint

The [restarted Step3 build record](../log/2026-11-07-completion-step3-restarted-build.md) supersedes earlier pending integration statements with exact current evidence. The app adopts reviewed engine7b1866fb8c9a40345c9d67b455c40053178fcb44. The independently reviewed [nonvisual baseline](completion-benchmarks.md) exercises real isolated storage for the relevant implemented commands; it does not establish UI, installed-device, financial posting or full phase acceptance.
