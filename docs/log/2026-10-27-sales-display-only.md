# Card-size control on Sales only

Status: implemented. Date: 2026-10-27. Request: remove sales-product display settings from Settings and keep the control on Sales only.

Change: removed the dropdown/description from Settings and removed settings-save dependence on it. The original Sales control and local preference storage remain unchanged. Accounts/data schema were untouched. Rationale: follow the owner's requested placement and avoid duplicate controls.

Verification: browser preview confirms the control is absent from Settings. The existing compact-product display test covers Sales behavior while preserving photos. Suite results follow completion. Local image: outputs/layout-review/settings-density-removed.png. Installed application was not replaced.

npm test passed 120/120. Recall returned withdrawn historical sources, so current files were used. The previous memory check had no pending/failed operations but sources=0. Sync/check run for this round without treating absent sources as indexing proof.
