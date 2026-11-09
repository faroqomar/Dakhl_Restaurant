# Transfer Daftar design to Figma — 2026-10-27

Status: **partially implemented and stopped by the Figma Starter-plan tool limit; incomplete and not visually approved.**

## Request

Transfer all screens, the design system and pop-ups into editable Figma layers/components. The owner explicitly chose editable layers, not Code Layer.

## Current output

- [Figma file](https://www.figma.com/design/kLJU2TbqeTqKoWrUYKSoKG).
- Figma session: `8b7a2933-581b-49df-9603-c661e0bee812`.
- 74 isolated source states documented in `outputs/figma-transfer/inventory.json`: screens, sizes, settings, dialogs and empty states. All data is illustrative; no real accounts.
- 10 reference captures, including dialogs, completed as native editable layers. The first reference contained 1038 text layers, not a flattened screenshot.
- Foundations: 3 variable collections; 10 primitive colors, 10 linked semantic colors, 5 measurements and 7 text styles. Colors/measurements come from current CSS.
- Initial library of 16 families and more precise source components: 203 components comprising 8 icon buttons, 134 button shapes, 32 fields and 29 product cards, with 1102 control/component relationships. The library needs organization, deduplication and better naming before approval.
- The first 10 screens were assembled using component instances. Remaining states are capture references without completed final assembly.

## Inspection and open defects

Figma inspection of Sales/Expenses showed that converting some horizontal containers did not preserve RTL: page headings, navigation and some columns reversed. The first product card's order needs diagnosis. Editable layers do not establish visual fidelity.

Application fonts Geeza Pro and Tahoma are unavailable in the remote Figma editor; loading Tahoma actually failed. Components/assemblies use Noto Sans Arabic as a documented substitute. The application font was unchanged. Raw references may retain unavailable font names until final cleanup.

Starter allows three pages, so the structure is three pages: system/guide, screens/sizes, and dialogs/states. Figma stopped `use_figma` with `You've reached the Figma MCP tool call limit on the Starter plan`. `whoami` confirmed the current plan. The response provided no confirmed reset time.

## Required continuation

1. Read `outputs/figma-transfer/session.json`, `foundations.json`, `source-masters.json`, `assembled-0.json` and `captures.json`, then inspect the current file before editing.
2. Correct horizontal-container direction and text alignment against the source; diagnose product ordering before applying a general change. Recheck Sales/Expenses.
3. Complete instance assembly for the remaining 64 states and screen sizes, bind tokens/text styles, and improve library and image-component naming.
4. Complete the inventory for the pop-up menu, supplier selection, original confirmation messages, import/restore and save/error states. Document system dialogs as behavioral specifications rather than claiming macOS emulation.
5. Visually/structurally review every group, fix clipping/alignment, add traceable flow/coverage maps, and remove temporary capture references only after final versions are complete and verified.
6. Initial setup and backup reminders remain deferred by owner instruction; do not present them as implemented features.

This task changes no accounts, application logic or installed build. Verification concerns the design file; unchanged application tests need not run again.
