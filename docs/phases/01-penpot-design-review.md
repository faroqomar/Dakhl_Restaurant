# Phase 01 — Penpot designs and structural wireframes

Date: 2026-10-29. Status: design and wireframe set prepared and independently reviewed; explicit owner design approval pending. Step 1.5 authorizes phase-scoped design work, not UI implementation, a new financial policy, merge or deployment.

## Destination and ownership

Reuse the existing [Dakhl_Restaurant Penpot file/page](https://design.penpot.app/#/workspace?team-id=bfddaaba-4180-81d4-8008-db9f13093baa&file-id=122350ae-89ad-8027-8008-dba0bd5cf454&page-id=122350ae-89ad-8027-8008-dba0bd5cf455). Phase 01 boards are named `01 · Reference` or `01 · Proposal`, with Design/Wireframe and v1 suffixes. The eight preceding boards, including superseded Phase 00 work, are preserved. File/page IDs remain unchanged; no external project is renamed or replaced.

Dakhl_Restaurant owns this component/navigation/interaction design. Madar implementation/API/package/logger and engine Design are **N/A**: no shared capability changes are needed. Preserve reviewed engine source `784b139753a0e2a07d3f97eedb326debfe068395` and existing preview contracts. The [separate engine record](../../../../phase01-scope-engine/Madar_Engine/docs/log/2026-10-29-phase01-penpot-design.md) tracks that boundary without copying app design authority.

Use the existing `codex/phase01-scope` app documentation/design-preparation worktree. Step 1 evidence and unrelated dirty root work are retained. No application source, frozen source/screenshot, dependency pin, CI or restaurant account is edited. Dedicated implementation isolation and its approved base remain Step 2 work.

## Review set

The set contains eleven design/wireframe pairs, twenty-two boards. [Local approval gallery](../../outputs/penpot/phase01/review/index.html), [native exports](../../outputs/penpot/phase01/native-exports/) and [the final native manifest](../../outputs/penpot/phase01/native-exports/native-manifest.json) contain the reviewable evidence. See also the [native layer audit](../../outputs/penpot/phase01/native-exports/native-layer-audit.json) and [Penpot page proof](../../outputs/penpot/phase01/review/penpot-page-proof.png). Local filesystem and cross-worktree links depend on this machine's layout; they are not published portable URLs. Native in this record means Penpot's own exported artwork, not a native application/device run.

| Pair | Logical dimensions | Scope |
| --- | --- | --- |
| Frozen design inventory | 1440×1200 | Supplied palette, lettering, fields, buttons, table/totals and dimensions |
| Desktop navigation | 1440×1000 | Supplied grouped popover, scrim, active route and shortcuts |
| Desktop invoice dialog | 1440×1000 | Supplied wide dialog, supplier/date/number, visible fields, totals and actions |
| Narrow invoice dialog | 390×844 | Supplied narrow dialog and its original field limitations |
| Desktop sales | 1440×1000 | Supplied restored draft, catalog left, compact bill right and six shortcuts |
| Narrow sales | 390×844 | Supplied wrapped shortcuts, catalog, zero requested quantity and failed-save toast |
| Medium sales shell | 1024×768 | Frozen-source responsive reference, not an additional supplied same-size screenshot |
| Wide sales shell | 1920×1080 | Frozen-source responsive reference, not an additional supplied same-size screenshot |
| Component/state/interaction proposals | 1440×1200 | Focus/disabled/loading/empty/validation/save/failure/retry/cancel, dirty-form decision and font/focus comparison |
| Narrow keyboard proposal | 390×844 | Form scrolled beneath its header; focused material/quantity/price and save/cancel above an illustrative 276px keyboard region |
| Large-text proposal | 320×1100 content frame | Stacked metadata and enlarged text/actions; a scrollable content envelope, not a claim that 1100px fits one phone viewport |

Reference reproduction and proposed usability changes remain separate. The six supplied screenshot dimensions, original bytes and metadata remain in the [Step 1 record](01-scope-readiness.md). Additional responsive captures use the same synthetic source, not production data.

## Proposed differences requiring approval

1. **Typography:** Reference lettering follows the macOS screenshot fonts through vector outlines. Proposed state/adaptation boards use editable Amiri Regular and Latin Inter numerals. Amiri is an available licensed offline candidate, not approved Phase 01 typography or proof that Penpot and the app use byte-identical font versions. Compare shaping/metrics before implementation; record platform-specific goldens later.
2. **Narrow forms:** Supplier/date/number metadata stack at large text instead of squeezing the invoice-number field. In the keyboard example, earlier metadata is above the visible scroll position while supplier context remains in the header. The keyboard is an annotated occlusion example, not an OS keyboard recreation or native inset test.
3. **Actions:** Proposed touch targets are at least 44 logical px; large-text actions have enlarged labels and stack vertically. Existing compact reference targets are retained in baseline boards and remain accessibility concerns.
4. **Focus:** The proposal compares a stronger 3px `#28633F` outline with effective reference control focus `#92B976`. Calculated sRGB contrast against paper `#FEFEFA` is approximately 7.05:1 versus 2.20:1. These samples do not certify whole-app accessibility or runtime focus behavior.
5. **States:** New loading/empty/save/error/retry/dirty-form samples demonstrate the already scoped interaction shell. They do not add posting, purchasing, stock, account persistence or recovery policies. English notes are review annotations; Arabic labels remain the proposed runtime UI.

## Token reconciliation

Frozen stylesheet order is `styles.css` → `commerce.css` → `ux.css`. The board/JSON inventory is not a complete component/media specification. Preserve frozen evidence and use the effective source plus these recorded dispositions instead of silently changing a baseline.

| Role | Reconciled reference / disposition |
| --- | --- |
| Muted/panel radius | Later ux.css overrides produce `#4C6051` and 10px; old base `#647568`/16px is not the final global result |
| Gutters | 24px desktop; 14px narrow override, omitted from the single-value JSON inventory |
| Buttons | Base padding 10px 17px, minimum height 43px, radius 9px; header and sales-heading contexts override these. The blanket inventory padding 10px 12px is not the actual general button rule |
| Focus | Element-specific reference `:focus-visible` remains 3px `#92B976`; the generic later `--focus:#28633F` rule has lower specificity. The inventory's explicit `.focus` sample is a separate role |
| Inputs/dialogs/photos | Inputs radius 7px/minimum height 42px; dialog radius 14px and maxima 620/1060px; product card/photo radii 12px/8px. Generic panel values do not replace these roles |

An independently named Phase 01 Penpot token set records reference/proposal roles. Activating unique Phase 01 token names does not overwrite older token sets; proposal color bindings use that set. The documentation describes current source behavior and candidate differences, not a new app/engine API.

## Interaction and accessibility handoff

- Navigation remains a dismissible grouped popover, with six configurable shortcut slots, active state, scrim and save/error status. Escape/mobile back and outside dismissal return focus; hidden navigation cannot receive interaction. Unknown/retired routes fall back to Sales without exposing the retired worker screen.
- Tab/Shift+Tab are trapped only while a modal surface is open. Dirty-form discard is explicit; cancel keeps the current content. Navigation preserves the active ticket; session undo dispatch remains an app-shell responsibility.
- Loading, empty and failed-save states are compact and communicate through text as well as color. Retry retains input. Reduced-motion treatment avoids relying on animation. These are design requirements, not executed behaviors.
- Future native verification must cover semantic names/reading order, status announcements, actual keyboard and safe-area insets, scrolling to every action, back gestures, large text and focus restoration on macOS/Android/iPhone. Screenshots, vectors and annotations do not prove them.

## Extraction, editability and limitations

The design-only capture uses an isolated temporary profile and synthetic in-memory records; real I/O is canceled and renderer requests/navigation are constrained. The reviewed direct installed runtime avoids the legacy downloader/preview helper. Existing dependency advisories remain unresolved; bounded local-file reachability triage is not security certification or authorization for networked legacy reuse/release.

Source geometry, host-rendered glyph paths and frozen photos/icons create layered artwork. Native reference text is outlined and cannot be edited as ordinary text; original strings are retained in board metadata and extraction JSON. Proposed boards contain native editable text/shapes. No whole-screen raster substitutes for editable artwork. Cached discrete photos/markers are reused; the inventory's 240px photo family may use the existing 480px native fill, so sampling can differ. Tiny marker sampling, font hinting, shadows and source ICC/color handling can also differ; no pixel-identity or aggregate similarity threshold is invented.

Native inspection caught and corrected defects that source PNG parity alone missed: flat SVG paint order placed navigation behind main content; a zero-height drawer host hid fixed dialog descendants from extraction; overlapping native controls required owning-element/closed-details visibility checks. Small source pixel deltas also contained meaningful fixture differences: invoice footer 157,500 versus reference 137,500 and narrow-sales requested quantity 2 versus reference 0. Exact reference values are restored only in explicitly documented synthetic presentation fixtures; no accounting function, posted record or frozen source is changed. Final corrected exports were checked: all 22 export dimensions/hashes match the reviewed manifest, all six frozen reference hashes match, all eight prior-board properties are preserved, and the layer audit reports zero whole-screen raster fills. Five source captures match frozen PNGs; the narrow sales capture differs only in 368 photo/edge pixels (maximum RGB channel delta 7), with no text/count difference. Exact per-image comparison conditions/metrics are in the native manifest; native exports are not pixel-identical to the references.

Verification outcomes, native board IDs/hashes, independent review and memory delivery are recorded in the [dated task log](../log/2026-10-29-phase01-penpot-design.md) and native evidence. Runtime tests/builds/CI, benchmarks, migrations, release and rollback execution are N/A for this design-only task; none are relabeled passed.

## Approval and remaining gates

Explicit owner approval of this Phase 01 set remains pending. Phase 00/CAP-00 completion, including their separate design/native acceptance gates, is unchanged. Phase 01 implementation also requires its bounded plan and explicit approval. No UI code, next phase, merge, publication or deployment follows automatically from creating these boards.

Independent Reviewer phase01_docs_review visually reviewed all eleven designs and eleven matching wireframes and recomputed every PNG hash/dimension. It reported no actionable findings for manifest SHA-256 `7e5a9fcc7c5eded4a4fb16353229aa57cbf5ca1e3059fe37a1ad7282a122f1ae`. This is independent review, not owner approval or runtime acceptance.

## Owner approval — 2026-10-29

After the Step 3 request, the owner explicitly selected “Approve both existing design sets,” covering this Phase 01 design/wireframe set and its listed differences plus the existing Phase 00 set. The approved Phase 01 native manifest is unchanged. Earlier approval-pending statements above describe the delivered preapproval state and are superseded by this dated approval. Runtime/native acceptance, exact source revision review, merge and deployment remain separate. See `outputs/phase01-step3/approval-and-preflight.json` for the preannotation artifact hashes.
