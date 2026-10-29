# 0008 — Content-appropriate page widths in a full window

Status: implementation decision within the owner's request to review full screens and fix excessive stretching; implemented and verified. Date: 2026-10-27.

Limit work-page width to 1120px and sales to 1360px; panels remain centered and dates/filters do not automatically stretch across the row. On wide windows, the sales ticket has a relatively fixed width between 330 and 380px, adapting smaller to available space. These values replace the initial 1280/1440 limits in .impeccable.md and its [log](../log/2026-10-27-page-width.md).

Rationale: full-window screenshots showed excessive gaps between a small number of elements and unnecessarily wide date fields. Component width limits keep reading close to the content. A 280px flex basis was also removed; it created unnecessary vertical space when the page header stacked in a narrow window.

No application data, account or persistence-path change. [Verification and limits](../log/2026-10-27-fullscreen-layout-review.md).

## Superseded by owner direction

The owner rejected the large side margins caused by narrowing pages; [decision 0009](0009-fluid-aligned-workspace.md) supersedes the page and summary width limits above. The narrow-header height repair and order-detail density remain.
