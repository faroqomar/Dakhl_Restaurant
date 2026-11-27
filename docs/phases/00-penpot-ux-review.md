# Phase 00 — independent Penpot reference review

Date: 2026-10-28 (Asia/Baghdad). Reviewer: UX agent, independent of artwork creation. Owner design approval: **pending**.

## Scope and authority

The owner's latest instruction requires the design and wireframe to match the three actual phase 00 screenshot references. It supersedes the earlier blank-shell interpretation. The blank-shell boards and their earlier readiness assessment are rejected/superseded; they are not evidence for this review.

Review exactly six 1440×1000 logical-pixel boards: design and grayscale wireframe for `desktop-sales`, `desktop-expenses`, and `desktop-settings-data`. Wireframes preserve geometry, labels, data, hierarchy and viewport cropping; product photographs become placeholders. Do not add other screens, phone designs or application implementation.

Sources: [phase scope](../planning/flutter-rebuild/phases/00.md), [design contract](../planning/flutter-rebuild/design-system.md), [capture guide](../planning/flutter-rebuild/capture-guide.md), [frozen screenshots](../planning/flutter-rebuild/screenshots/), reference extraction, Penpot exports.

## Initial exported-board review — repairs required

Inspected all six actual `*-penpot.png` exports, 2880×2000 physical pixels, generated during this run. A locally correct SVG/preview does not establish a correct Penpot board.

| Finding | Observed evidence | Required re-verification |
| --- | --- | --- |
| Blocking: photographs missing | Sales design shows empty soft-green photo rectangles, despite the artwork manifest listing 18 images. | Restore the actual 18 visible/cropped product photos as image assets; re-export and inspect the native board. Wireframe placeholders remain appropriate. |
| Blocking: icons misplaced/missing | All six native exports show a cluster of icons at the canvas's top-left. Intended hamburger, settings, calendar, export/import/folder, edit, product plus and bill removal icons are absent at their reference positions. | Repair nested SVG/path positioning and transforms; inspect all intended icon positions and verify no origin cluster remains. |
| Blocking: collapsed settings state differs | Settings design and wireframe include the hidden restore explanatory paragraph under the collapsed control; the reference excludes it. The disclosure triangle is absent. The lead/exporter already identified this issue. | Keep the exact collapsed state, remove hidden content from the artwork, restore the triangle and export again. |

No approval-ready claim is made for these initial exports. Repeat review after the repairs; retain the findings as historical evidence.

## Content and composition checked

- Sales: six-column catalog on the left, compact bill on the right; first row right-to-left kebab meat, kebab chicken, grilled chicken, chicken rice dish, red rice, appetizer plate. Visible cart quantities/totals remain 2/24,000 and 1/2,000; subtotal 26,000, discount 1,000, total 25,000; date 2026/10/27 and order type dine-in. The lower product row retains the captured viewport crop. Typography is connected Arabic and visually close because the artwork uses source-derived outlines, rather than claiming an arbitrary font substitution is identical.
- Expenses: main daily ledger on the right and cashbox rail on the left. Daily rows remain 15,000; 20,000; 15,000. Shared-funding captions retain daily/cashbox amounts 20,000/10,000 and 15,000/5,000. Cashbox rows remain 10,000; 10,000; 5,000, totaling 25,000; daily spent 50,000, daily balance 150,000, remaining balance 80,000 and net collection 49,230 remain distinct.
- Settings: the data tab is active, status card is right, export/import card left, data-location panel below and saved/disabled savebar at the bottom. The literal synthetic location text is retained. The extra collapsed restore paragraph and missing icons are the exceptions listed above.
- Wireframes: the same major geometry, labels, financial values and visible crop are retained, with grayscale styling and crossed photo placeholders. They share the icon-positioning/settings-state regressions and therefore also require re-verification.

## Accessibility observations from the original reference

These are reference limitations to record for owner review, not permission to redesign the reproduction:

- The sales eyebrow "Current invoice" (translated UI label) uses 10px text with color #6A8074 on white: calculated contrast approximately 4.24:1.
- The active group count `33` uses white 12px text over a 15% white layer on #078657: composited contrast approximately 3.59:1.
- Source geometry records sales cart removal/stepper buttons at 28×30 logical pixels and quantity fields at 36×30; expense rail edit controls are 32×36. These are compact reference targets. No invisible hit padding or runtime target behavior is established by the artwork.
- The source reference includes low-stock color and supporting stock text; preserve the wording as well as its visual state. Do not rely on a grayscale wireframe to prove color contrast.

This is a bounded visual/content audit. Penpot vectors/text outlines do not establish screen-reader labels, focus order, keyboard operation, Arabic input normalization, native font licensing, accessible hit areas or runtime behavior. No hardware, native dialogs, migration or real restaurant accounts were exercised. Application accessibility/device validation remains pending.

## Approval boundary

Resolve the blocking transfer regressions, inspect the repaired native exports against the original three PNGs, record remaining differences, then present the concrete six boards for the owner's explicit design approval. No approval has been given by this reviewer. No Flutter implementation, merge or phase 01 work is authorized by this review.

## Repair re-verification — current findings

The subsequent native Penpot exports show the product photographs restored, including the visible 18-photo/cropped-row composition, and the intended icons restored to their original positions. The top-left icon cluster is gone in the re-exported sales/expenses designs and wireframes and the settings design. The settings design now correctly excludes the hidden restore paragraph and includes its disclosure triangle. Sales order, cart quantities/amounts, daily/cashbox funding captions and totals remain faithful to the reference during this recheck.

At the first repair recheck, two items remained before final review disposition:

1. Sales design and wireframe still omit the reference's ready-status dot. Source `.pos-status:before` defines a 7×7 circle, #159C68, located at logical x=1279.765625, y=135.1953125 in the frozen viewport. Restore it as a native ellipse (grayscale in the wireframe) and inspect a new native export. The explanatory status text is present; do not move it.
2. The settings wireframe export inspected at this recheck is still the earlier unrepaired file. Re-export the repaired native settings wireframe and inspect it independently before treating the fix as verified for both variants.

This recheck does not claim pixel identity. Source collection parity and a structurally valid SVG are distinct from native Penpot rendering; the initial asset/icon failures demonstrate why actual exported-board inspection is required. Owner approval remains pending.

The refreshed settings wireframe was then independently inspected: its intended icons and collapsed restore state are correct, the stray paragraph is absent, and the origin cluster is gone. Item 2 is resolved. The sales ready-status dot remains the only specific outstanding reproduction finding from this review.

## Final visual disposition — ready for owner review

The latest sales design and wireframe exports were independently inspected again. Their ready-status dots are now present at the reference position, green in the design and gray in the wireframe. Item 1 is resolved. All specific reproduction findings raised by this reviewer have now been repaired and visually re-verified in actual native Penpot exports.

The final six-board set is ready to present for the owner's design review: three screenshot-matching designs and their three grayscale wireframes. Arabic glyphs, visible content/order, financial values and funding captions, photographs/placeholders, icon positions, collapsed settings state and viewport composition were inspected. No additional blocking visual/content finding was identified in this bounded review. This is not a pixel-identity claim, a comprehensive accessibility certification, or owner approval.

Reviewed export SHA-256 values, relative to `outputs/penpot/phase00/screenshot-recreation/`:

| Native export | SHA-256 |
| --- | --- |
| desktop-sales-design-penpot.png | d693085be4bf8cf7f572d436e46cfa9fed01f9c39ebdbb7ef0ed7ae4f7752d17 |
| desktop-sales-wireframe-penpot.png | 009bde888f34592fd9df26512fa92aa1f377a853e551b273da73220ccf8866a0 |
| desktop-expenses-design-penpot.png | beb197b74ef925692fc56a0f0d91204b9311f1da6fdc6dd15144636dcd938eba |
| desktop-expenses-wireframe-penpot.png | 68af6b0ef7510a38ee583af68d4de2c4a61afe3c64155500fe020e945fe5600d |
| desktop-settings-data-design-penpot.png | 4d825e0d1426437f58211d6f2842110f21adb86cf76c167521a2fb98967b51de |
| desktop-settings-data-wireframe-penpot.png | ab53909f725cdec2563e849ef31c1c21d619114d3a086b75f7334577d18f1973 |

The original-reference contrast/target observations above remain unchanged and disclosed. Native text outlines preserve the reference appearance but do not prove text accessibility or runtime semantics. **Owner approval is still pending; stop before Flutter implementation.** Phase completion, merge, hardware/runtime verification and phase 01 remain outside this visual disposition.
