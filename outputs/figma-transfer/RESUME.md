> Historical transfer only. On 2026-11-12 the owner removed the superseded 74 HTML cases and obsolete server/export helpers. Recover the former files from Git revision `433ee33f1b2811687cc8b23af2c5c9014786de5d`; use current local Penpot sources. The dated blocked-transfer record below is historical and its server commands no longer run.

# Daftar Figma transfer — partial, blocked

File: https://www.figma.com/design/kLJU2TbqeTqKoWrUYKSoKG
Session: 8b7a2933-581b-49df-9603-c661e0bee812

Do not claim completion. Starter MCP quota blocked writes during visual QA. Current editable assembly has known RTL direction and product-order defects. See docs/log/2026-10-27-figma-transfer.md.

Permanent pages: system 0:1; screens 2:32; popups 20:2.
Reference capture roots: 3:2 (screens0), 6:2 (screens1), 10:2 (settings), 8:2/9:2/11:2/13:2/12:2 (popups0–4), 14:2 (empty states), 17:2 (responsive).
Final assembled first batch: assembled-0.json. Component index: source-masters.json. Tokens/styles: foundations.json. All 74 local source cases: inventory.json.

Inspect existing canvas before retry. Assembly source: assemble.js; CONFIG and masterData must be prepended. It is a starting point with known defects, not a verified final conversion. Preserve instance constraints/layoutPositioning when replacing controls. Diagnose horizontal RTL order from source rather than blindly reversing all nodes, especially wrapping grids. Do not re-capture already completed capture IDs.

Local sample gallery server: node outputs/figma-transfer/server.cjs on 127.0.0.1:4320. Capture script injected into exported samples only; product files unchanged. A new capture is needed only for truly missing cases. Browser preview at4317 has user samples and must not be cleared.
