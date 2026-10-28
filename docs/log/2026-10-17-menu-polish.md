# 2026-10-17 — Organize and correct the menu layout

Status: implemented v3 draft, not published. Date: 2026-10-17. Owner: Jannat Baghdad restaurant owner. Source: attached menu screenshot and request to organize it and correct all errors.

## Change and rationale

Reduced empty space in the header and enlarged names and important details. Removed ellipses from the title to avoid directional ambiguity. Replaced repeated Dulaimiya entries with a clear table: 3/4/6-portion rows and Dulaimiya-only/half-chicken/whole-chicken columns. Separated meat kebab from chicken kebab/tikka, retaining 100% Iraqi meat in its group heading and samoon/double-skewer details on relevant items. The chicken section became independent, with its accompaniments under the heading. Old-price X marks remain thinner to preserve numeral readability; new prices remain larger and yellow.

Current output: [Canva v3](https://www.canva.com/d/xrVGV1ZUBZBOh1b), ID `DAHYPUZ0O9k`, with sources/PNG under `outputs/campaigns/CAM-0001/v3/`. Previous versions remain preserved. The used font files and license instructions accompany the output. No application prices or financial data changed, and no previous prices were invented.

## Verification

Comparing v3 data with v2 confirmed identical sections and prices for all 18 items, with restaurant name and delivery number retained. The 3×3 Dulaimiya table matched all nine tray prices in the v2 source. Extracted Canva text matched the three price rows, seven kebab items, whole-chicken reduction from 12,000 to 10,000, half-chicken price of 5,000 and section accompaniments. Canva has one 1080×1440 page. The design was inspected in the Canva editor, exported as a 1080×1440 PNG to `jannat-baghdad-menu-v3-canva.png` and the final image actually reviewed, including prices, delivery number and Arabic typography. The local 2160×2880 draft uses a substitute font in its renderer; the Canva export is therefore the approved delivery image. Local-generation text-position checking rejects text outside the post bounds.

Local-file links and `git diff --check` were checked; synchronization and completion checks occur before delivery. Final evidence consists of this session's verification responses. No new application tests were needed for design/documentation-only changes; no publication or spending occurred. Design materials containing the delivery number are outside the memory indexing allowlist.
