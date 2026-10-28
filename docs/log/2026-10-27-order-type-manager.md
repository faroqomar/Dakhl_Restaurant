# Order-type management list

Status: implemented and verified in source/preview. Date: 2026-10-27. Source: the owner's screenshot and request for a list with add, delete and disable controls.

## Implementation and rationale

Replaced the visible text area with an item list: add a name, disable/enable, delete and a default-selection dropdown. Changes remain part of unified settings save, rejecting duplicate names and deletion/disabling of the last enabled type. Historical sales are unchanged; only an empty ticket adopts the new default after save.

Disabled state is stored in preferences.disabledOrderTypes as an optional validated field. Old files without it remain valid and retain their values. Enabled types stay in preferences.orderTypes. No amounts, balances or restaurant file paths changed.

## Verification

npm test passed 120/120. New tests cover add/disable/re-enable/default, duplicates and last-enabled protection, deletion without historical-sale changes, disabled-state persistence across storage reopen/JSON, and rejection of a sale using a disabled type. The default test found an empty ticket retaining its previous type; this was fixed and the suite passed again.

Electron preview: four sections at 1512, 1024 and 390px, 12 cases without horizontal overflow. The browser's type list was visually inspected and left open for the user. Local image: outputs/layout-review/order-types-browser.png. All verification data was isolated or illustrative; restaurant accounts were unchanged and the installed application was not replaced.

## Memory and follow-up

project-daftar recall returned withdrawn historical sources; current source was authoritative. Next: owner review of the list in the browser. Synchronization result follows.

Ran sync then check: healthy service, no pending/failed operations, but sources=0; there is no proof that this run's documents were indexed in the bank.
