# Current phase-00 Penpot review set

Current canonical page: [Dakhl_Restaurant designs and wireframes](https://design.penpot.app/#/workspace?team-id=bfddaaba-4180-81d4-8008-db9f13093baa&file-id=122350ae-89ad-8027-8008-dba0bd5cf454&page-id=122350ae-89ad-8027-8008-dba0bd5cf455).

Three designs (sales, daily expenses, settings/data) and three matching wireframes. Native board IDs are in `*-penpot.json`; native layer/image counts and source-text metadata were audited in `native-structure-audit.json`. Each board is 1440×1000. The saved native exports are `*-penpot.png`, at scale2/2880×2000. `penpot-review-overview.png` combines those exports for review.

`*-design.svg` and `*-wireframe.svg` are measured source artwork. Native import requires flattening nested icon SVG transforms and transferring clipped photos to native image fills with `keepAspectRatio:true`; the SVG image masks alone did not render in Penpot. No whole-screen UI raster replaces editable artwork. Lettering is outlined; original strings are retained in `../reference-data/*.json` and board plugin metadata.

`native-pixel-comparison.json` reports actual native-export differences from the originals, using color-managed source decoding. These are not pixel-identical PNGs: glyph rasterization/hinting, image sampling, color-profile/compositing and shadow rendering retain small differences. The source Electron recaptures themselves are byte-identical; that does not make the Penpot exports byte-identical. See the independent UX review for the checked visible content and original accessibility limits.

Earlier files one directory above (blank-shell `review.png`, `states.png`, create-design script and their audit) are superseded drafts and are not this approval set. Their Penpot boards are retained away from the current review grid.

Owner design approval remains pending. No Flutter implementation or next phase starts from these artifacts.
