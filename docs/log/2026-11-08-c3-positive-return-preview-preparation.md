# C3 positive return preview design preparation

Status: source-content independently reviewed; native qualification and named owner UI approval remain pending. No app or engine production code, drawings, trackers, or approval records modified. App owns the presentation packet; Madar runtime/API/Design: N/A because existing reviewed contract revision `d316fd6076375daa3f412889f73eaebfeeb5d4d4` is unchanged. One restaurant, offline, Arabic RTL, IQD and preserved history apply. C1 only is approved; C2/C3 owner proposal is pending; C4 remains separate.

## Objective and scope

Supply the missing positive partial and full calculated cash-refund preview states for C3 owner review, using the frozen Electron source and isolated synthetic fixtures.
- Objective met: generated 6 bounded desktop + phone presentation states (partial 11,769 IQD, full 39,230 IQD) with visible computed amounts, active confirmation checkboxes, and enabled submit actions.
- Preserved assets: existing quantity-zero references (`desktop-sale-return`, `phone-sale-return`, `phone-sale-return-bottom`) and repaired C3 native pairs remain unchanged as baseline zero-input references.
- Owned new outputs:
  - `outputs/penpot/completion/source/positive-return-preview/`
  - `outputs/completion-review/c3-positive-return-preview-proposal.json`
  - `outputs/completion-review/c3-positive-return-preview.html`
  - `docs/log/2026-11-08-c3-positive-return-preview-preparation.md`

## Audit and execution trace

- Initial preflight (2026-11-07T21:55:10Z to 2026-11-07T21:55:40Z):
  - Consulted mandatory Hindsight memory banks separately:
    - `python3 /Users/eros/Dev/Eros_Projects/Hindsight/bin/memory.py recall --project daftar --query 'completion c3 return preview positive refund cash calculated state'`
    - `python3 /Users/eros/Dev/Eros_Projects/Hindsight/bin/memory.py recall --project madar --query 'completion c3 return preview positive refund cash calculated state'`
    Both recall queries returned historical records and confirmed project memory health.
  - Read Penpot guidelines (`/Users/eros/.codex/skills/penpot/SKILL.md`), project `AGENTS.md`, `PLANS.md`, `PHASES.md`, `PROMPTS.md`.
  - Inspected existing proposal `outputs/completion-review/c2-c3-design-approval-proposal.json`, specifically acknowledging item `positive-refund-preview` (lines 4539–4545: "Selected return references show quantity 0 and unchecked cash confirmation. No positive partial/full calculated refund preview or checked-confirmation native pair is selected; layout/control visibility does not prove that state.").
  - Inspected reviewed sales contract `docs/phases/completion-durable-sales-contract.md` (4,068 bytes, SHA-256 `744954e11ba76c720c9882534ed1026775e0d3d5fa7fcaadde29b4acbd5aa1b6`).

- Storage baseline (2026-11-07T22:04:25Z):
  - Filesystem available: 110,753,304 KiB (~105.6 GiB free)
  - Project `.git`: 18,423,680 KiB
  - `outputs/penpot/completion`: 7,064,948 KiB
  - `outputs/completion-review`: 8,064 KiB
  - Zero temporary Git stores (`tmp_objdir`).

- Frozen Electron source capture execution (2026-11-07T22:07:00Z to 2026-11-07T22:09:20Z):
  - Created isolated capture script `outputs/penpot/completion/source/positive-return-preview/capture.cjs`.
  - Executed headless Electron via `env -u ELECTRON_RUN_AS_NODE ./electron-reference/node_modules/electron/dist/Electron.app/Contents/MacOS/Electron outputs/penpot/completion/source/positive-return-preview/capture.cjs`.
  - Failed attempt 1: initial script threw `SyntaxError: Identifier 'inputs' has already been declared` when transitioning from partial to full setup in top-level script scope.
  - Remedy 1: wrapped each setup script block in local block scope `{ ... }`. Rerun succeeded completely.
  - Runtime note: Electron background task completed all 6 scene exports in 8 seconds, but kept its Node.js event loop active until the 600s harness timeout with the cause attributed by the worker to a pending CDP session handle; that cause is not independently verified. Added explicit `process.exit(0)` after `app.quit()` as a proposed remedy; no rerun verifies termination yet.
  - Captured 6 positive refund scenes with actual DOM layouts, text metrics, and 2x Retina PNG screenshots:
    1. `desktop-sale-return-partial`: 1440×1000 logical, 2880×2000 physical (254 nodes, 92 texts)
    2. `desktop-sale-return-full`: 1440×1000 logical, 2880×2000 physical (254 nodes, 92 texts)
    3. `phone-sale-return-partial-bottom`: 390×844 logical, 780×1688 physical (147 nodes, 50 texts)
    4. `phone-sale-return-full-bottom`: 390×844 logical, 780×1688 physical (147 nodes, 50 texts)
    5. `phone-sale-return-partial`: 390×844 logical, 780×1688 physical (146 nodes, 50 texts)
    6. `phone-sale-return-full`: 390×844 logical, 780×1688 physical (146 nodes, 50 texts)

- Native CoreText text outlines generation (2026-11-07T22:09:35Z to 2026-11-07T22:09:39Z):
  - Invoked `swift outputs/penpot/completion/source/reference-data/text-outlines.swift outputs/penpot/completion/source/positive-return-preview/reference-data <screens>`.
  - Converted all visible text runs and shadow-control runs into native CoreText glyph outline paths; 0 canvas fallbacks; max advance error 7.57px on Arabic complex cursive runs, median 0.004px.

- Layered SVG artwork generation (2026-11-07T22:09:50Z to 2026-11-07T22:10:05Z):
  - Created `outputs/penpot/completion/source/positive-return-preview/build-artwork-runner.py`.
  - Reused unchanged reviewed artwork builder `outputs/penpot/completion/source/package-prep/build-artwork.py` (SHA-256 `7bf4fff748dde3afb8fddd023ffb7d4b86b48e700b88af26204db52049b13913`).
  - Generated 12 layered SVG files (6 design SVGs + 6 wireframe SVGs) with discrete native checkbox and select arrow crops, plus 6 sidecar JSON metadata files and `artwork-manifest.json`.

- Proposal JSON and gallery HTML generation (2026-11-07T22:11:40Z to 2026-11-07T22:11:57Z):
  - Created and executed `outputs/penpot/completion/source/positive-return-preview/generate-proposal.py`.
  - Generated `outputs/completion-review/c3-positive-return-preview-proposal.json` (31,771 bytes).
  - Generated `outputs/completion-review/c3-positive-return-preview.html` (19,333 bytes) with absolute local image links, arithmetic proof cards, and PNG/Design/Wireframe toggles.

## Arithmetic lineage and proof

The numbers are derived strictly from the frozen Electron model (`electron-reference/app/ui/model.js` `M.returnQuote`):
- Invoice `sale` (`S-000001`):
  - Line 0: `p0` (كباب لحم), quantity 3, unit price 12,000 IQD, line total = 36,000 IQD
  - Line 1: `p1` (كباب دجاج), quantity 2, unit price 8,000 IQD, line total = 16,000 IQD
  - Subtotal = 52,000 IQD
  - Discount = 1,001 IQD
  - Original net paid = 50,999 IQD
- Prior recorded return on fixture:
  - 1 piece of `p0` returned on 2026-10-27
  - Prior refund amount = 11,769 IQD
  - Remaining returnable: `p0` = 2 pieces, `p1` = 2 pieces. Net remaining eligible = 39,230 IQD.
- Partial positive refund state:
  - Input: 1 piece of `p0`, restock checked.
  - Formula: `Budget(p0) * (1 + 1)/3 - Budget(p0) * 1/3 = 35,307 * 2/3 - 35,307 * 1/3 = 23,538 - 11,769 = 11,769 IQD`.
  - Preview displays: `المبلغ المطلوب رده 11,769 د.ع`.
  - Checked confirmation: `أؤكد رد المبلغ الظاهر للزبون من نقد اليومي` checked.
  - Submit button: enabled.
- Full positive refund state:
  - Input: 2 pieces of `p0` (restock checked), 2 pieces of `p1` (restock checked).
  - Formula:
    `p0: 35,307 * 3/3 - 35,307 * 1/3 = 35,307 - 11,769 = 23,538 IQD`
    `p1: 15,692 * 2/2 - 0 = 15,692 IQD`
    `Total: 23,538 + 15,692 = 39,230 IQD`.
  - Cumulative sum proof: `11,769 (prior) + 39,230 (full remaining) = 50,999 IQD` (exactly equals original net paid, 0 rounding remainder).
  - Preview displays: `المبلغ المطلوب رده 39,230 د.ع`.
  - Checked confirmation: `أؤكد رد المبلغ الظاهر للزبون من نقد اليومي` checked.
  - Submit button: enabled.

## Deliverable manifest

| File | Bytes | SHA-256 | Description |
| --- | --- | --- | --- |
| `outputs/completion-review/c3-positive-return-preview-proposal.json` | 31,771 | `825703b50c7ce56eae5dce4fda3e3deff6ca3a21624b00a732f85440b8158075` | Canonical proposal manifest with arithmetic proofs and metadata |
| `outputs/completion-review/c3-positive-return-preview.html` | 19,333 | `2d522b325de030f8925ebc7df1e54533ef375c50508319e0af304b4d550b61f1` | Interactive review gallery with absolute local image links |
| `outputs/penpot/completion/source/positive-return-preview/reference-data/desktop-sale-return-partial.png` | 367,641 | `5d33a019916b42fc5d66b532718c1c77994d8bccb5b6e5c323c7afc2462528b6` | Desktop partial refund (11,769 IQD) 2880×2000 retina capture |
| `outputs/penpot/completion/source/positive-return-preview/reference-data/desktop-sale-return-full.png` | 369,743 | `aad11074eb620cbf776fa6da19e9a2596f28b8a5a148070523aea1c2c5e35b14` | Desktop full refund (39,230 IQD) 2880×2000 retina capture |
| `outputs/penpot/completion/source/positive-return-preview/reference-data/phone-sale-return-partial-bottom.png` | 112,771 | `0fa32ccd0c7476fcab560b0be868e58c5f63f12d4a4bda1f08faafffa5e252a1` | Phone partial refund (11,769 IQD) lower controls 780×1688 capture |
| `outputs/penpot/completion/source/positive-return-preview/reference-data/phone-sale-return-full-bottom.png` | 114,763 | `aee1f8744e729d4476eb74265ec78d552507800880e973c961ad94d8d0aded9b` | Phone full refund (39,230 IQD) lower controls 780×1688 capture |
| `outputs/penpot/completion/source/positive-return-preview/reference-data/phone-sale-return-partial.png` | 118,383 | `f54d67ee855b07f17c28529cb16e0ba3aada3b94dbb5730405f06a08592f7113` | Phone partial refund form upper rows 780×1688 capture |
| `outputs/penpot/completion/source/positive-return-preview/reference-data/phone-sale-return-full.png` | 120,195 | `d03e22708c2a501ed6e0f042c79c55db412a1953de9ef6718b155990b5093476` | Phone full refund form upper rows 780×1688 capture |
| `outputs/penpot/completion/source/positive-return-preview/artwork/desktop-sale-return-partial-design.svg` | 1,014,721 | `435b9c05c5b9dbbb5dd565b01c9285e4140dea6fdb07820dca9162c4033c522c` | Layered vector design SVG for desktop partial refund |
| `outputs/penpot/completion/source/positive-return-preview/artwork/desktop-sale-return-partial-wireframe.svg` | 1,009,374 | `e4630e87f66e1371e5492bcdfd88bc725d4c8eedc41c92a24553a889ba747b16` | Structural wireframe SVG for desktop partial refund |
| `outputs/penpot/completion/source/positive-return-preview/artwork/desktop-sale-return-full-design.svg` | 1,016,181 | `d4d403f93d23c9857d006e21103921df2a9189950bc33d0e618bfd1e40b55db1` | Layered vector design SVG for desktop full refund |
| `outputs/penpot/completion/source/positive-return-preview/artwork/desktop-sale-return-full-wireframe.svg` | 1,010,786 | `5eade72524f68bbe430f7d2af94d7a971747922becddb8576398ab83ffce9d40` | Structural wireframe SVG for desktop full refund |
| `outputs/penpot/completion/source/positive-return-preview/artwork/phone-sale-return-partial-bottom-design.svg` | 598,716 | `5aff7c62020ea23aa890d69d9f9d70bdb11c9c8d93e9b3de8b061f360a4e82e3` | Layered vector design SVG for phone partial refund lower controls |
| `outputs/penpot/completion/source/positive-return-preview/artwork/phone-sale-return-partial-bottom-wireframe.svg` | 593,665 | `bc64e0a748df0596ad2706447aa0d617bb5f45823235642051bced430cad5aab` | Structural wireframe SVG for phone partial refund lower controls |
| `outputs/penpot/completion/source/positive-return-preview/artwork/phone-sale-return-full-bottom-design.svg` | 600,085 | `a53a5a545eaa9dd02b981c1f0f6929c249b662686b3ab86ae62de69b84f590e4` | Layered vector design SVG for phone full refund lower controls |
| `outputs/penpot/completion/source/positive-return-preview/artwork/phone-sale-return-full-bottom-wireframe.svg` | 594,946 | `71a3fc32d09dac5ae9711629d06e67c0999f95476a02c9c782a4fc7a065a65d4` | Structural wireframe SVG for phone full refund lower controls |
| `outputs/penpot/completion/source/positive-return-preview/artwork/phone-sale-return-partial-design.svg` | 623,918 | `dcd2a52a67187c084f755050893ec415d166b0075de6bc2159bb38512d74a2cb` | Layered vector design SVG for phone partial refund upper form |
| `outputs/penpot/completion/source/positive-return-preview/artwork/phone-sale-return-partial-wireframe.svg` | 619,709 | `446e3bd5dbaacc887beca880e0de136d65d638fe2a26eac001db0b9f842908c9` | Structural wireframe SVG for phone partial refund upper form |
| `outputs/penpot/completion/source/positive-return-preview/artwork/phone-sale-return-full-design.svg` | 625,578 | `839c64c67fb5b968f70d4aa19f40548c9db71e1db1fa283294fd921c7d3e86f2` | Layered vector design SVG for phone full refund upper form |
| `outputs/penpot/completion/source/positive-return-preview/artwork/phone-sale-return-full-wireframe.svg` | 621,273 | `3d50c687cd2b5ba42242e3f3203ce74da674547a33777c936c22d1a9753a2c5b` | Structural wireframe SVG for phone full refund upper form |

## Storage closeout

- Filesystem available: 110,696,280 KiB (baseline 110,753,304 KiB; delta -57,024 KiB during task).
- Project `.git`: 18,428,044 KiB (stable, no tmp_objdir temporary stores).
- `outputs/penpot/completion`: 7,098,104 KiB (+33,156 KiB; includes all reference PNGs, DOM JSONs, text outlines, and layered SVGs).
- `outputs/completion-review`: 8,204 KiB (+140 KiB; includes proposal JSON and gallery HTML).
- Cleanup correction: independent inspection found zero matching temporary profiles and capture processes. The script has no `os.tmpdir()` cleanup handler, so the prior cleanup-mechanism attribution was unsupported.
- Safety check: free space remains >105 GiB (>10 GiB floor); project growth within bounded limit (<2 GiB).

## Remaining qualification and approval gates

1. Root independent packet review: inspection of proposal structure, arithmetic proofs, and file integrity.
2. Owner design decision: explicit owner review of candidate positive refund preview presentation states.
3. Native Penpot board qualification: if imported into the local native Penpot workspace, separate native layer verification and export proof must bind the result.
4. Flutter UI implementation and runtime acceptance: remains pending until owner approval is granted.


## Root correction after independent source review

2026-11-07T22:27:54.964278+00:00: Source-content review passed all44current manifest bindings and six PNG/twelve SVG states. Corrected 18stale size/hash entries above from actual current bytes. The original proposal manifest remains825703b50c7ce56eae5dce4fda3e3deff6ca3a21624b00a732f85440b8158075. Source arithmetic/controls qualify for native-design preparation; no separate owner approval is required merely to perform that already-authorized qualification. Owner approval remains mandatory before Flutter UI implementation. See successor v2proposal and root independent receipt.
