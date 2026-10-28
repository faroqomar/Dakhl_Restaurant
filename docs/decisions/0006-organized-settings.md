# 0006 — Sectioned settings and unified saving

Status: implementation decision within the owner's settings-redesign request of 2026-10-27; implemented in source, owner visual review remains open. This does not replace the account or persistence rules in earlier decisions.

## Decision and rationale

Divide settings into four in-page sections while preserving forms when switching. Saving restaurant preferences, order types and shortcuts together prevents losing another section's edits when a separate form save rerenders the page. Sales-card size remains a device-local preference under its previous key, with no account-schema change.

Show a receipt-identity preview alongside its fields. Separate export/import actions from restore choices, preserving confirmation, preview and a copy of current data in the existing desktop flows.

Evidence and limits are in the [implementation log](../log/2026-10-27-settings-redesign.md). Tests and preview do not establish an installed-app update or an actual restore of restaurant accounts.

## Owner follow-up — Type management, 2026-10-27

The owner requested replacing free text with a list supporting add, delete and disable. Active-type order stays in the current field; disabled names are an independent optional field for compatibility with older files and inclusion of disabled state in backups. Do not change the type names recorded in earlier sales. [Implementation outcome](../log/2026-10-27-order-type-manager.md).

## Display-option scope change — 2026-10-27

At the owner's request, remove product-card size from settings. It appears only on the sales screen and retains the same device preference. This direction supersedes its availability in the second section of the initial settings design; the rest of the decision continues.
