# 0005 — Redesign sales using the owner's reference

Status: owner request approved; implemented in source and visually reviewed with isolated data. Date: 2026-10-27.

Source: the Nook screenshot supplied by the owner with a request to use it as inspiration for the sales screen.

Use a calm ivory surface, image cards with a clear add action, group tabs showing product counts, and a white ticket on the right with its total and confirmation at the bottom. Preserve Arabic RTL within both panels and the products-left/ticket-right arrangement. On phones, stack the panels and allow page scrolling. Do not copy unapproved reference features such as taxes, held orders or customer linking.

This is a visual refinement of decisions [0003](0003-sales-layout-review.md) and [0004](0004-ux-popouts-and-recovery.md), not a replacement of exact payment, fixed discount, order type, draft protection or popout navigation. Local images are references. No change to the data format or calculations.

Verification: [implementation log](../log/2026-10-27-sales-reference-redesign.md). The installed application was not updated by this task.

## Card-layout follow-up — 2026-10-27

At the owner's request, replace the wide add label with a plus in the image corner, reducing image height, spacing and card size. The whole card remains an add target, the count stays in the opposite corner, and product information and price remain visible. This supersedes the "Add +" row below the card; the rest of the decision continues. [Verification log](../log/2026-10-27-compact-sales-cards.md).
