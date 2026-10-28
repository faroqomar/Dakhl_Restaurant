# 2026-10-16 — Jannat Baghdad restaurant post

Status: implemented draft, with content and appearance reviewed; not published. Date: 2026-10-16. Owner: restaurant owner. Source: request for a black post containing ten items and their prices, followed by the restaurant name, delivery number and an X over old prices.

## Result

Produced the [final editable Canva menu](https://www.canva.com/d/qyaWxnRjvxd7fkY), a 2160×2880 PNG, and SVG/HTML sources, data and a reproduction command under `outputs/campaigns/CAM-0001/`. Old prices are small and gray with two crossing lines; new prices are larger and yellow. The page is 1080×1440, a 3:4 ratio, with all ten items on one page, the Jannat Baghdad restaurant name and the supplied delivery number. The phone number is not copied into memory.

## Implementation and verification

The first Canva generation omitted every old price and misspelled the tray label; it was rejected as a final version. The MCP transaction opened for review was cancelled without saving changes. Browser-draft editing attempts did not modify the intended elements, so all five changes were undone and the return to a single page was confirmed.

The complete layout was built with explicit text and imported into Canva as HTML, without relying on price regeneration. The final design ID is `DAHYM9U935U`; the initial `DAHYM4OMBbI` version is not approved for delivery. Import succeeded as one page. Extracted text from the final design was compared with all ten items, their old/new prices, the name and delivery number: every comparison passed. The PNG was reviewed locally, then the final page was visually inspected in the Canva editor through the native Chrome application. The black background, twenty prices, crossing marks, name and delivery number appeared without overlap.

Interpreting `20,00` as 20,000 for a kilogram of meat kebab was disclosed in the response; the owner has not independently confirmed that correction. No Daftar accounts or application source changed, and no advertisement was published or budget spent. Application tests were not rerun because this task produced design and documentation only.

## Documentation and memory

The project scope was updated with the restaurant name, and IDEA-0001/CAM-0001 moved from research to an implemented draft. Local links, `git diff --check` and Hindsight synchronization are checked before delivery. Synchronization completion is established by this session's check, not by an item being queued. Materials and sources containing the delivery phone number remain in the outputs folder outside the memory indexing allowlist.
