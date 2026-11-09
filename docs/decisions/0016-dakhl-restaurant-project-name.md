# 0016 — Canonical project name: Dakhl_Restaurant

Status: accepted by explicit owner correction. Date:2026-10-28.

## Context and decision

The owner confirmed that this project was renamed from Daftar to **Dakhl_Restaurant**, and requested a search and correction of old project naming. Use **Dakhl_Restaurant** in current project titles, workflow/agent instructions, current planning pages, design workspace names and project-specific skill guidance.

The current folder already has the correct name. The active worktree remains isolated on `codex/phase00-penpot`; no unrelated root-checkout edits are reset or overwritten.

The existing Penpot project/file/page are renamed in place, retaining their IDs and all boards:

- Project: **Dakhl_Restaurant**.
- File: **Dakhl_Restaurant · Phase designs & wireframes**.
- Page: **Dakhl_Restaurant · Designs & Wireframes / Designs**.

This updates the names in [0015](0015-penpot-design-workspace.md), not the destination or approval gate. Hindsight's existing bank display name is **Dakhl_Restaurant**; its bank ID remains `project-daftar` so the existing knowledge stays accessible.

## Deliberately retained legacy names

A project-label correction is not a storage migration or a revision of the frozen app reference. Retain:

- The preserved `electron-reference/` implementation, its `Daftar` application/data-directory/bundle/icon/package names, `window.daftar`, `DaftarModel`, `DaftarNumbers`, draft/preferences keys and matched tests.
- Frozen screenshots, source/screenshot manifests and hashes, historical captures/design artifacts, provenance source copies, archived plans, prior decisions and logs. Historical UI labels inside screenshot-reproduction boards remain reference content.
- Infrastructure keys `daftar`, `project-daftar` and `daftar_memory`. They are compatibility aliases, not current project display names. Do not silently recreate/rename the bank ID or point at an empty bank.
- Other projects and the owner's external Vault sources.

These exceptions prevent stranded restaurant accounts/drafts, broken imports/interfaces, lost knowledge and invalidated reference evidence. There is no change to account data, accounting behavior, design geometry, owner approval or Flutter phase status.

## Validation

Search active project labels for remaining old names; independently review substitutions; verify protected Electron/provenance/screenshot files stay unchanged; validate documentation links and skill/config syntax. Record the actual checks and external rename evidence in [the task log](../log/2026-10-28-project-name.md). No normal application launch or Flutter tests/builds are needed for this naming-only change.

Documentation-language note, 2026-10-28: workspace labels above are rendered in English; the canonical page identifier is unchanged. This translation does not rename the actual Penpot page.
