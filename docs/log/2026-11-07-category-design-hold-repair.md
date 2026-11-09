# C4 Category Design & Wireframe Hold Repairs (2026-11-07)

## Executive Summary

As the design sub-agent, the five held C4 category design and wireframe pairs were repaired directly within the canonical self-hosted Penpot workspace to match frozen source screenshots:
1. `desktop-categories` (1440×1000)
2. `desktop-category-edit` (1440×1000)
3. `phone-categories` (390×844)
4. `phone-categories-bottom` (390×844)
5. `full-phone-categories` (390×865)

All repairs were executed strictly via the local browser UI on `http://localhost:9001` (Team `5b438bb7-7d89-81bf-8008-e66cac635d85`, File `5b438bb7-7d89-81bf-8008-e66cde6075af`, Page `5b438bb7-7d89-81bf-8008-e66cde6075b0`), with no Penpot MCP writes, no cloud/API writes, and no SDK bridge.

C1 (15 pairs) remains fully preserved. C4 Flutter UI is NOT approved, and no owner approval was requested. Existing parent tranche receipts remain root-owned; this sub-agent provides the patch manifest and crop verification receipt so root can conduct independent review and update aggregate records.

---

## Workspace & Identity Verification

Live workspace identities and board placements were verified live before mutations:
- **Design Board**: `a06ebf34-7758-80cb-8008-e69adcdf0389` ("Completion · 06 Daily records cashbox and categories · Part 1 · Design") at world (60000, 7000), dimensions 3900×5572.
- **Wireframe Board**: `40a6df26-d27d-8012-8008-e69c55b58ca1` ("Completion · 06 Daily records cashbox and categories · Part 1 · Wireframe") at world (66000, 7000), dimensions 3900×5572.
- **Design Root Group**: `a06ebf34-7758-80cb-8008-e69af76e08ca` ("Completion-wp06-01-design-v4").
- **Wireframe Root Group**: `40a6df26-d27d-8012-8008-e69ca5a69f4e` ("Completion-wp06-01-wireframe-v4").

### Board-Relative Panel Coordinates
All coordinates match paper rectangles from `continuation-native-layer-audit-165.json`:
- `desktop-categories`: x=1520, y=3240, 1440×1000 (pixelCrop: 3040, 6480, 2880, 2000)
- `desktop-category-edit`: x=1520, y=4320, 1440×1000 (pixelCrop: 3040, 8640, 2880, 2000)
- `phone-categories`: x=3510, y=924, 390×844 (pixelCrop: 7020, 1848, 780, 1688)
- `phone-categories-bottom`: x=3510, y=1848, 390×844 (pixelCrop: 7020, 3696, 780, 1688)
- `full-phone-categories`: x=3040, y=3714, 390×865 (pixelCrop: 6080, 7428, 780, 1730)

---

## Pilot Execution & Verification

A single representative pilot repair was conducted on `phone-categories` (design):
1. Overlay SVG `phone-categories-design-overlay.svg` generated from exact source marker assets (`control-raster-{5..9}.png`) with bounding box 390×844.
2. Canvas viewport centered on `phone-categories` paper rectangle (`a06ebf34-7758-80cb-8008-e69af9348d86`) via `Shift+2`.
3. Board `a06ebf34-7758-80cb-8008-e69adcdf0389` selected and overlay uploaded via `#image-upload`.
4. Layer `002514bb-1797-8060-8008-e919aaa0c5e9` created inside `children-a06ebf34-7758-80cb-8008-e69adcdf0389` at exact coordinates x=3510, y=924.
5. Autosave verified (`title="Saved"`).
6. Affected board exported at 2x PNG (3,837,020 bytes).
7. Panel cropped via `native-pixels crop`.
8. Comparison via `compare-review-images` against frozen screenshot `docs/planning/flutter-rebuild/screenshots/phone-categories.png` demonstrated:
   - RGB MAE dropped from 1.183597 to 1.165725 (-0.017873).
   - `ratioMaxRGBDeltaOver32` dropped from 0.011112 to 0.011053.
   - CoreGraphics pixel inspection confirmed marker patches dropped error from ~22–25 down to ~7.2, confirming visible restoration of select chevrons.

---

## Full Expansion Across All 10 Panels

Following successful pilot verification, repairs were expanded to the remaining 4 design panels on board `a06ebf34-7758-80cb-8008-e69adcdf0389` and all 5 wireframe panels on board `40a6df26-d27d-8012-8008-e69c55b58ca1`.

### Live Penpot Native Layer Manifest

#### Design Board (`a06ebf34-7758-80cb-8008-e69adcdf0389`)
- `phone-categories`: layer `002514bb-1797-8060-8008-e919aaa0c5e9`, board pos (3510, 924), size 390×844
- `phone-categories-bottom`: layer `002514bb-1797-8060-8008-e91bfc525c97`, board pos (3510, 1848), size 390×844
- `full-phone-categories`: layer `002514bb-1797-8060-8008-e91c5379d075`, board pos (3040, 3714), size 390×865
- `desktop-categories`: layer `002514bb-1797-8060-8008-e91c83025656`, board pos (1520, 3240), size 1440×1000
- `desktop-category-edit`: layer `002514bb-1797-8060-8008-e91cbaf9046f`, board pos (1520, 4320), size 1440×1000
  - Restored 4 select markers (7, 10, 11, 12), checkbox (13), and text selection highlight rect `(964.5, 434.0, 24.5, 23.5)` in `#D8D9D7` with foreground text "الغاز".

#### Wireframe Board (`40a6df26-d27d-8012-8008-e69c55b58ca1`)
- `phone-categories`: layer `002514bb-1797-8060-8008-e91deaa9b66e`, board pos (3510, 924), size 390×844
- `phone-categories-bottom`: layer `002514bb-1797-8060-8008-e91e140ef574`, board pos (3510, 1848), size 390×844
- `full-phone-categories`: layer `002514bb-1797-8060-8008-e91e3da37cd4`, board pos (3040, 3714), size 390×865
- `desktop-categories`: layer `002514bb-1797-8060-8008-e91e7c4286d2`, board pos (1520, 3240), size 1440×1000
- `desktop-category-edit`: layer `002514bb-1797-8060-8008-e91eabf4b7ff`, board pos (1520, 4320), size 1440×1000
  - Restored 4 gray select markers (7, 10, 11, 12), checkbox (13), and text selection highlight rect `(964.5, 434.0, 24.5, 23.5)` in `#D8D8D8` with foreground text "الغاز".

---

## Comparison Results Against Frozen References

All 10 panels show systematic RGB Mean Absolute Error (MAE) improvements against frozen reference screenshots:

| Panel | Kind | Pre-Repair MAE | Post-Repair MAE | MAE Delta | Pre over32 | Post over32 |
|---|---|---|---|---|---|---|
| `desktop-categories` | Design | 0.201098 | 0.197186 | **-0.003911** | 0.002223 | 0.002210 |
| `desktop-category-edit` | Design | 1.216517 | 1.199791 | **-0.016726** | 0.003076 | 0.003003 |
| `phone-categories` | Design | 1.183597 | 1.165725 | **-0.017873** | 0.011112 | 0.011053 |
| `phone-categories-bottom` | Design | 1.187994 | 1.170882 | **-0.017112** | 0.011136 | 0.011079 |
| `full-phone-categories` | Design | 0.830163 | 0.813466 | **-0.016696** | 0.009518 | 0.009463 |
| `desktop-categories` | Wireframe | 1.920535 | 1.916463 | **-0.004072** | 0.005839 | 0.005851 |
| `desktop-category-edit` | Wireframe | 5.087236 | 5.070619 | **-0.016617** | 0.021326 | 0.021297 |
| `phone-categories` | Wireframe | 4.404237 | 4.385915 | **-0.018322** | 0.063256 | 0.063309 |
| `phone-categories-bottom` | Wireframe | 4.411079 | 4.393265 | **-0.017814** | 0.063336 | 0.063389 |
| `full-phone-categories` | Wireframe | 2.826898 | 2.809516 | **-0.017382** | 0.024901 | 0.024953 |

---

## Resource & Storage Verification

- **Free Disk**:
  - Baseline: 115,198,424 KiB
  - Post-Repair: 111,157,912 KiB (>106 GiB free; well above 10 GiB safety floor)
- **Dakhl_Restaurant App Directory**:
  - Baseline: 26,751,464 KiB
  - Post-Repair: 27,051,780 KiB (growth: ~300 MiB; well below 2 GiB limit)
- **Madar Engine Directory**:
  - Baseline: 1,243,656 KiB
  - Post-Repair: 1,247,440 KiB (growth: ~3.7 MiB; well below 2 GiB limit)
- **Git Repositories**: Untouched, no commits, no worktrees, no branches created.
- **Preview Browser**: Sole controller tab `tab_6_0c0bdcf2-f140-407a-95ce-bf3acac454c6` cleanly closed via `t3_preview_close`.

---

## Artifact & Receipt Links

- **Repair Receipt**: [`outputs/completion-review/category-design-repair-receipt.json`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/outputs/completion-review/category-design-repair-receipt.json)
- **Overlays and Cropped Panels Directory**: [`outputs/penpot/completion/category-hold-repair/`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/outputs/penpot/completion/category-hold-repair/)
- **Crop Receipts**:
  - [`all-design-categories-crop-receipt.json`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/outputs/penpot/completion/category-hold-repair/all-design-categories-crop-receipt.json)
  - [`all-wireframe-categories-crop-receipt.json`](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/outputs/penpot/completion/category-hold-repair/all-wireframe-categories-crop-receipt.json)
