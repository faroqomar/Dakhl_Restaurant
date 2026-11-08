# C2 core design approval proposal

Prepared: 2026-11-07T21:59:34.985768+00:00. Status: **awaiting root review and named owner approval**.

## Requested decision

Approve the15named core references below (13Completion native pairs and2historical Phase01 reuses), plus the five displayed Phase02 pattern reuses, for bounded C2 core UI implementation. Accept the disclosed source/visual discrepancies while holding the unqualified feature states listed below. This proposal records no approval.

The scope permits the named desktop/phone catalog, cart, compact/search/empty-product views, captured ticket controls, optional-name hold modal, populated held list and paid-confirmation presentation. The app may compose reviewed shared contracts without changing financial policy or activating schema12. Whole-C2 coverage and completion remain open.

[Interactive review gallery](../../outputs/completion-review/c2-design-review.html) · [Exact manifest](../../outputs/completion-review/c2-design-approval-proposal.json) · [C2 independent review](../../outputs/completion-review/c2-design-independent-review.json) · [Final localized repair review](../../outputs/completion-review/c2-c3-control-repair-independent-review.json).

## Named core references

| Reference ID | Evidence class | Logical size |
|---|---|---|
| desktop-sales | Phase01 reuse | 1440 × 1000 |
| desktop-hold-order | Completion native pair | 1440 × 1000 |
| desktop-sales-cart | Completion native pair | 1440 × 1000 |
| desktop-sales-compact | Completion native pair | 1440 × 1000 |
| desktop-sales-catalog-bottom | Completion native pair | 1440 × 1000 |
| desktop-sales-no-results | Completion native pair | 1440 × 1000 |
| desktop-sale-paid | Completion native pair | 1440 × 1000 |
| phone-sales | Phase01 reuse | 390 × 844 |
| desktop-held-orders | Completion native pair | 1440 × 1000 |
| empty-sales | Completion native pair | 1440 × 1000 |
| phone-sales-bottom | Completion native pair | 390 × 844 |
| phone-sales-cart | Completion native pair | 390 × 844 |
| phone-sales-cart-bottom | Completion native pair | 390 × 844 |
| full-phone-sales | Completion native pair | 390 × 4940 |
| full-sales | Completion native pair | 1440 × 1000 |

The desktop-held-orders selection uses the repaired design/WF crops whose hashes match the new independent review. That review verified the source chevron repair on both sides and zero changed pixels outside the bounded repair regions. Prior joint packet/crops remain historical and unchanged. The other12Completion pairs use the exact previously reviewed native crops. Phase01 desktop-sales/phone-sales are historical cloud exports proposed for C2 reuse, not new local exports or proof of full migration.

## Proposed Phase02 pattern reuse

| Pattern | Proposed C2 use |
|---|---|
| A-status | Saving/pending/confirmed-save presentation |
| B-file-errors | Retained-input validation and capability error presentation |
| C-recovery | Retry/cancel/discard recovery presentation |
| E-narrow-recovery | Keyboard-aware recovery/action layout pattern |
| F-large-text | Large-text and narrow-layout pattern |

Pattern reuse requires explicit C2 approval. It supplies a presentation pattern, not exhaustive feature-specific failure or adaptive state proof.

## Held layouts and dependencies

- **held-empty-name** (C2-12, C2-20): Empty held-ticket list and typed/editable-name states remain source-only.
- **held-delete-confirmation** (C2-20): Held-ticket delete confirmation/cancel has no qualified named pair.
- **specific-failure-eligibility** (C2-05, C2-08, C2-09, C2-12, C2-13, C2-16): 40/41held limit, stale swap, invalid discount/archive/stock/date and protected unknown-checkout presentation need scoped design/state validation; generic pattern reuse alone is not exhaustive coverage.
- **checkout-narrow-adaptations** (C2-01, C2-03, C2-18): Feature-specific320px/200%text and keyboard/safe-area SVG proposals remain source-only. Source amount extends14.140625px beyond320px; proposed reflow remains unapproved.
- **saved-receipt-C3** (C2-10, C2-19): Paid confirmation belongs to this packet. Detailed saved receipt, details/PDF/system-print UI and downstream C3 states are outside this C2-only approval.
- **native-service-outcomes** (C2-19): PDF/print cancel/denied/no-printer/failure/retry require runtime acceptance; static designs do not establish it.

A bounded named core approval can unblock those core views while these layouts stay held. It cannot authorize implementation of the held layouts or satisfy the whole20-item C2 acceptance set. C2-10/C2-19 also require the separately gated detailed C3 saved receipt; a paid-confirmation image does not cover that receipt. No owner approval, native run, benchmark, CI, cutover, merge or release follows from this packet.

## Disclosures

- Outlined glyph hinting/antialias and image sampling can differ; no pixel-identity or100%vector-fidelity assertion.
- Flatter modal/card shadows and corner/lower-edge paint differences remain in named pairs.
- Source full-document clipping and inherited retained-draft toast can cover content; preserve source behavior and disclose its limits.
- Hold dialog uses optional order name and hold-and-open-new-order. Earlier reason/confirm-hold prose is superseded by current pixel/source evidence.
- Native export is not app execution, adaptive text/keyboard validation, screen-reader execution or financial/persistence proof.

## Ownership and verification

Dakhl_Restaurant owns the static presentation references, UI/workflows and safeguards. Madar implementation/API/Design: **N/A for this packet**; no shared capability, engine source, package, contract or pin changed. Existing reviewed runtime revision remains `d316fd6076375daa3f412889f73eaebfeeb5d4d4`.

Selected source/native/pattern asset SHA-256 values and sizes were checked from disk; exact native IDs/URLs and qualification chain are retained in the manifest. Its20C2 checklist mappings preserve the original required-work/acceptance texts. This task created no artwork, native export, archive, browser/server session, application code or test result. Root must inspect/render the gallery and obtain the named decision.

## Owner approval — 2026-11-08

The owner approved this exact packet: "Approve C2 and C4 packets". See [approval receipt](c2-c4-owner-approval.md). Earlier pending statements above retain proposal history. Scope exclusions remain.
