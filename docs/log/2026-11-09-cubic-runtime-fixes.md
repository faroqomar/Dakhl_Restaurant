# Cubic runtime review fixes

Date: 2026-11-09. App-owned safeguard and presentation changes; shared engine implementation/API changes N/A. The existing borrowed repository and financial undo contracts remain authoritative.

| Review comment | Disposition | Verification |
| --- | --- | --- |
|4508133020 (21)|Valid. Refresh daily metadata controller pending ownership after any repository readback result; stale revision now releases the unresolved-write lock without acknowledging the attempted save.|Controller test simulates an unknown committed chicken write followed by a different authority; stale result releases the pending flag.|
|4508133045 (30)|Valid. Additional-debt compensation stores the same Arabic reason as other financial undo adapters.|Saved durable undo intent reason asserted after compensation; existing debt history/replay tests retained.|
|4508133055 (32)|Valid. Map failed metadata compensation readback to commit_unknown whenever the repository retains an unknown write, preserving the exact captured attempt.|Transient unavailable readback keeps the undo attempt and pending token; later success confirms the existing revision without another compensation.|
|4508133058 (33)|Valid. Blocked chicken Save now displays an Arabic explanation.|Widget clicks Save while canWrite is false, observes the message, and verifies no write.|
|4508133063 (34)|Valid, same root cause as21. Once stale readback resolves repository pending state, the chicken editor offers Cancel and can close without claiming successful save.|Widget performs unknown save, swaps authority, verifies stale readback, sees failure feedback and closes.|

Verification: `flutter test --no-pub test/accounting/daily_metadata_controller_test.dart test/accounts/metadata_session_undo_test.dart test/parties/additional_debt_controller_test.dart` passes16tests. Targeted analysis of the four owned source files and three tests reports zero issues in3.3seconds. Format and scoped diff whitespace checks pass. Compiler window released.

[Canonical test, analyzer and source hashes](../../outputs/completion-review/cubic-runtime-20261109/receipt.json). Adjacent text receipts retain logs. The first red attempt exposed the metadata retry defect and an agent-caused fixture mismatch: the original categories fixture lacked unknown-commit support. The test now reuses the existing account fixture with those faults; no fixture implementation duplication. The first green run passed16tests; the final run repeats only after adding the durable Arabic reason assertion. No full-suite/native/benchmark campaign was repeated for these bounded fixes.

Storage: lane-specific start usage was not measured; parent owns the campaign baseline. Final free disk and compact artifact size are in receipt.json. No uncertain cache, source, account data or recovery file was deleted. Receipt logs are small; shared compiler caches remain in place.
