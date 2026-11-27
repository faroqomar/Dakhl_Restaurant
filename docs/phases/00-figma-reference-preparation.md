# Figma reference recreation — access blocked

> Superseded as the active tool prerequisite: the owner selected Penpot on 2026-10-28. Preserve this as historical access evidence. See [current Penpot scope](00-penpot-reference-recreation.md).

Date: 2026-10-28 (Asia/Baghdad). Owner request: recreate the existing design in Figma before proceeding. Status: BLOCKED; no new Figma design or validation produced. This adds a reference-preparation prerequisite to the phase 00 kickoff; it does not start phase 01 or product implementation.

## Live evidence

- Destination: [existing Dakhl_Restaurant file](https://www.figma.com/design/kLJU2TbqeTqKoWrUYKSoKG), preserving the partial transfer.
- New task session: `64fe741d-7d09-4d7a-bd38-851fbde666ef`.
- `get_metadata` and read-only `use_figma` both rejected with: "You've reached the Figma MCP tool call limit on the Starter plan."
- `whoami` confirmed the connected team has a Full seat on Starter. No billing or subscription changes made.
- Figma supplied this [team upgrade/access link](https://www.figma.com/files/team/1420402375308544208/all-projects?upgrade=mcp_rate_limit_paywall).
- No existing canvas could be inspected, no layers changed, no Figma screenshots obtained and no accessibility/design approval claimed. Prior defects remain historical local findings until the canvas can be checked.

## UX Agent preparation

UX `phase00_ux` prepared the following matrix from the [design contract](../planning/flutter-rebuild/design-system.md), [capture guide](../planning/flutter-rebuild/capture-guide.md), [manifest](../planning/flutter-rebuild/screenshot-manifest.json) and transfer recovery record. This is a validation plan, not passed validation.

| Area | Recreation and acceptance scope |
| --- | --- |
| Foundation | Extracted design board/tokens/CSS; Arabic RTL, full-width gutters, compact controls, popover navigation, existing icons and page-specific green accents. |
| Sales | Desktop sales/cart/compact/scroll references; catalog left, bill right, correct product order, plus/count controls, totals and reachable checkout. |
| Expenses | Desktop expenses and lower-page reference; daily ledger, compact cashbox context and funding-source separation. |
| Settings/data | Current data/backup controls and lower-page actions. |
| States | Existing empty sales/expenses, no-results, expense form/edit, validation and simulated save-error references. Inspect source for applicable saving/loading/success/retry/cancel/dirty-form states; do not invent features or infer real fault handling from a simulated capture. |
| Responsive/accessibility | Existing 390×844 phone views plus 320-wide, 1024×768 and 1920×1080 checks. Annotate RTL reading order, labels, focus/keyboard traversal, dialog trap/return, Escape/back, contrast, large text, reduced motion and target sizes. Runtime screen readers, native safe areas/keyboards/fonts/dialogs need later device tests. |

Match the source at equal logical size and scale: desktop 1440×1000 (2880×2000 PNG); phone 390×844 (780×1688 PNG). A whole-screen raster is not an editable recreation. Reuse existing components/tokens and inspect layer structure, discrete image assets and font families before taking comparable composition screenshots.

## Resume once access is restored

1. Reuse this session for this task; inspect current pages and existing content before changing anything. Historical page IDs: system `0:1`, screens `2:32`, popups `20:2`.
2. Preserve existing captures/assembly. Reuse the 74 recorded source cases and mappings instead of duplicating completed imports.
3. Repair verified RTL/product-order issues and recreate/validate the priority sales, expenses and settings/data views with relevant states. Record font discrepancies explicitly; do not silently accept an unapproved fallback.
4. Save exact frame links, editable-layer evidence, comparable Figma screenshots and accessibility notes. Present the result to the owner and stop for design approval before implementation.

Required external action: restore Figma MCP quota/access for the connected team. No background retries or automatic continuation scheduled. Phase 01 remains TODO; no app/account changes, Flutter tests or release actions performed.
