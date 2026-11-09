# 0003 — Apply the sales-design review feedback

Status: approved when the owner confirmed the four comments and order type; implemented in source and browser preview. Date: 2026-10-26. Source: exported design-review comments, then confirmation that the requested selector is order type (dine-in/takeaway/delivery). This decision supersedes decision 0002's requirement to enter cash received and preserves the inventory, daily-account and cashbox rules.

- Keep the sales page within the window. Search, top bar, total and complete-sale action remain fixed, with products scrolling inside their list. Ticket lines scroll for long orders so every line remains reachable without moving payment controls.
- Product cards show generated reference images stored locally, not photographs of the restaurant's actual products. A suitable image can be chosen while editing a product in inventory, or the product can remain without an image. Account data stores only the allowed image key. [Image sources and prompt set](../reference/product-photos.md).
- Completing a sale records payment of the exact net receipt value, without entering cash received. The discount remains a fixed amount. Do not automatically add the value to the cashbox. Earlier receipts preserve their recorded cash received and change.
- Replace the quick-sale note field with an order-type selector. Settings allow editing and ordering types: one name per line, from 1 to 20 types, without duplicates or empty names, with the first as default. A sale stores its type name at the time of sale, so changing settings does not change earlier receipts. Earlier notes remain accessible.
- Schema 9 adds order-type preferences, the image key and an optional receipt order type. Migration accepts schemas 1–8 and preserves previous records. An old receipt with no known order type is not automatically assigned a new type.

Source version is 1.11.0 and the browser preview is updated. The installed application remains 1.10.1 during this design-review round; restaurant accounts were neither opened nor populated with illustrative data.

Update, 2026-10-26: navigation, scrolling and draft-protection behavior are superseded by [decision 0004](0004-ux-popouts-and-recovery.md). Images, exact payment and order types remain approved.
