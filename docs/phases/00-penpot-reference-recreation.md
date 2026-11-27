# Phase 00 — Penpot screenshot recreation

Current clarification, 2026-10-29: the owner approved the existing Phase 00 design set and independent review closed its iPhone technical prerequisite. Earlier pending statements below are historical. This closes the technical prerequisite only; it does not assert overall Phase 00 DONE or a production release.

Date: 2026-10-28. Status: DESIGN; owner approval pending. [Tracker](../../PHASES.md). [Tool/location decision](../decisions/0015-penpot-design-workspace.md).

## Scope and destination

The owner replaced Figma with Penpot and requested phase-only designs plus wireframes matching the screenshots exactly. This supersedes the earlier blank-shell interpretation. Only the three phase-00 references are in this review set:

- [Sales](../planning/flutter-rebuild/screenshots/desktop-sales.png).
- [Daily expenses](../planning/flutter-rebuild/screenshots/desktop-expenses.png).
- [Settings/data](../planning/flutter-rebuild/screenshots/desktop-settings-data.png).

Each source PNG is 2880×2000 at device scale 2, representing 1440×1000 logical pixels. Every design and wireframe uses that logical viewport and crop. Wireframes retain the same wording, amounts, geometry and order; photos become placeholders and colors become grayscale.

Canonical [Penpot project/file/page](https://design.penpot.app/#/workspace?team-id=bfddaaba-4180-81d4-8008-db9f13093baa&file-id=122350ae-89ad-8027-8008-dba0bd5cf454&page-id=122350ae-89ad-8027-8008-dba0bd5cf455). Reuse it for future project design requests.

## Isolation and authorship

Worktree: `/Users/eros/.codex/worktrees/phase00-penpot/Dakhl_Restaurant`; branch `codex/phase00-penpot`, base `ecf692b`. The root checkout's concurrent unrelated work was preserved.

Lead owns Penpot integration and evidence. UX independently inspected all three originals and defined the acceptance checklist. Reference-export Worker owns the synthetic DOM/source renderer extraction. Font-outline Worker owns measured vector lettering. No Worker self-approves the design. Flutter implementation and phase 01 are untouched.

The source renderer uses the frozen synthetic fixture and temporary development storage. It does not read restaurant accounts. Source scripts and renderer assets remain unchanged. All three regenerated source PNGs compare byte for byte with their frozen originals, with zero changed pixels. That establishes source parity only; final Penpot exports require a separate comparison.

## Editable artwork

Measured DOM geometry supplies panels, borders, spacing, clipped regions and controls. Icons and host-rendered macOS glyphs are imported as editable vectors. Product photos and the tiny native select indicator remain discrete raster assets. No whole-screen raster is used inside the editable design. Original strings remain in extraction JSON and Penpot board metadata because glyph outlines cannot be edited as normal text.

## Tool setup and recovery

No Penpot plugin was available in the connected Codex plugin catalogue. Installed official `@penpot/mcp@2.15.4` from npm under `/Users/eros/.local/share/penpot-mcp`, registered the local MCP endpoint, and installed its compiled plugin in Penpot. Services bind only to `127.0.0.1`: plugin manifest port 4400, MCP HTTP 4401 and plugin bridge 4402. User LaunchAgents keep those local services available. The plugin serves only its compiled distribution folder.

Codex MCP name: `penpot`, endpoint `http://localhost:4401/mcp`. Penpot plugin manifest: `http://127.0.0.1:4400/manifest.json`. In Penpot, open **Plugins → Penpot MCP Plugin → Connect MCP Server**. Keep that plugin open while using MCP. The current session uses the official SDK client until the newly registered tool is loaded in a fresh Codex session.

Plugin/server version 2.15.4 warns that cloud Penpot is 2.18.5. Record successful operations individually; do not infer complete compatibility from installation. Native creation and PNG export have been exercised. Future failures should first check the plugin's connection and the local service logs.

## Validation and approval boundary

Source pixel parity is verified. Penpot visual comparison, structural audit and independent UX findings are recorded below with the exported review artifacts. Owner design approval remains pending. There is no claim of Flutter tests/builds, device validation, signing, deployment, migration, CI completion or phase completion.

The three screenshot states are the scope of exact recreation. They do not authorize new modal, phone, loading or error designs. Existing visible restore/draft, saved, unexported-backup and disabled-save states are preserved. Keyboard behavior, screen-reader labels, focus, text scaling and native dialogs require runtime validation during their implementation phases. Contrast/target findings must be recorded without silently changing the supplied reference.

## Final exported evidence

The six native Penpot boards have been exported at scale2/2880×2000 and independently inspected. The transfer defects found in the first exports—missing photo rendering, misplaced icons, hidden restore content, disclosure markers and the ready-status dot—were corrected and re-verified. [Independent UX report](00-penpot-ux-review.md).

- Native export overview.
- Native structure/image audit: six1440×1000 boards; editable native vectors; eighteen discrete product-photo fills and tiny native control markers; no whole-screen image fills.
- Pixel comparison: native exports are **not byte/pixel identical**. Color-managed mean absolute RGB error (0–255) is sales1.527, expenses0.826 and settings0.719. Nonzero pixels include font hinting/rasterization, photo sampling, source ICC/color compositing and shadow differences. No visual-difference pass threshold was invented.
- The matching wireframes preserve the screenshot geometry, wording, amounts, ordering and crop, using grayscale and photo placeholders. These are structural references, not a claim of equal colors/photos.

The independent review identifies no remaining blocking content/layout transfer defect. Original small contrast and compact-control findings remain documented; there is no runtime accessibility or responsive-device pass claim. All owner approval fields remain pending. Phase00 remains DESIGN, phases01–11 TODO.

## Owner approval — 2026-10-29

The owner explicitly approved both existing Phase 00 and Phase 01 design sets after requesting Step 3. This approves the existing Phase 00 reproductions/wireframes; it does not waive the still-outstanding iPhone Simulator native acceptance or certify Phase 00 DONE. Preannotation report hash is retained in `outputs/phase01-step3/approval-and-preflight.json`.
