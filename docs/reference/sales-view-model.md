# Nonvisual sales ViewModel

Status: implemented nonvisual candidate; initial independent review and focused fractional-plus recheck passed. The running sales route still uses the existing example surface. No checkout or receipt persistence is implemented by this model.

## Ownership and lifetime

`SalesViewModel` composes the app-owned `TicketWorkspaceController`, `CatalogReadModel` and `RestaurantStockProjection`. Shared exact values and quote calculations come from public Madar packages at the app runtime pin `d316fd6076375daa3f412889f73eaebfeeb5d4d4`. Engine changes are N/A for this slice.

Construct the model after the account repository has an initialized document and snapshot. The model captures one `StorageFence` and privately constructs its workspace controller for the same repository. Dispose and recreate it after account/generation replacement; `refresh()` re-evaluates the current catalog and quote, but does not retarget, reload or repair the workspace. Existing workspace readback owns uncertain-write resolution. Draft operations do not change the portable account, stock, cash, journals or saved sale records.

## API and binding

| Surface | Behavior |
| --- | --- |
| `load(TicketDraft initial)` | Load the existing typed workspace or use the caller's validated initial draft through the existing controller. |
| `active`, `held`, `loaded` | Immutable typed draft state exposed only while the bound account authority remains current. |
| `busy`, `errorCode`, `needsReadback` | Observe submission, stable failure code and protected workspace uncertainty. |
| `filter(query:, group:)`, `selectPage(page)` | Source-compatible catalog projection with80-item pages; changing filters resets the page. |
| `catalog`, `groups`, `orderTypes` | Current account/catalog presentation, dated stock and available order types. |
| `quote` | Captured-price subtotal/discount/net and current eligibility; eligibility is not permission to post a sale. |
| `addProduct(id)` | Default plus adds at most one unit, capped at dated stock remaining after that ticket line; exhausted stock keeps the ticket unchanged. |
| `addProduct(id, quantityUnits:)` | Explicit exact scaled addition; invalid or unavailable requested amounts reject without clamping. |
| `setQuantity(id, text)`, `removeProduct(id)` | Validated exact quantity replacement or line removal. |
| `updateDetails(date:, orderType:, discount:, note:)` | Persist a validated typed edit while retaining captured prices and other fields. |
| `hold(...)`, `resume(...)`, `deleteHeld(id)` | Existing single-workspace transitions; caller supplies identities, labels and timestamps. Resume can swap the current active ticket. |
| `reconcile()` | Existing workspace readback; do not repeat the uncertain mutation. |

Quantities use scale3; IQD uses scale0. `setQuantity` accepts supported Arabic digits, grouping and Arabic decimal input, and rejects exponent syntax. Public Madar `CommerceCalculations` performs quote arithmetic with the existing source-compatible rounding policy. Catalog price changes do not rewrite first-add prices. Missing/archived products and insufficient dated stock make the ticket ineligible; users can retain/recover its other fields. Nonempty held tickets remain subject to the existing40-ticket limit and controller validation.

The model freezes complete candidate submissions before listener notifications. It blocks overlapping writes, rejects stale generation use and suppresses publication after disposal. UI owners must listen to the model and recreate it after workspace replacement rather than retaining callbacks into the old instance. The controller preserves unrelated workspace form values; this model adds no durable raw-field form-edit API.

## Verification and remaining work

The candidate has20focused ViewModel cases and48sales tests passing after the fractional-plus repair; two-file static analysis is clean. Initial worker evidence includes140frozen Electron reference tests. See `outputs/completion-review/sales-view-model/` for original and repaired source identities, retained red runs and review dispositions. These are host tests with isolated fixtures, not native acceptance.

At this nonvisual checkpoint, C2 UI design approval and route binding remained pending. Later approved implementation binds the model through `_bindSales` and `SalesSurface`; see the [current successor closeout](../log/2026-11-08-remaining-completion-closeout.md). The following exclusions describe the original nonvisual slice. This model supplies neither operational checkout, debounced widget autosave, receipt numbering/actions, financial journal posting, schema12 activation, live cutover nor delivery approval. The schema11 account runtime and isolated schema12 journal command candidate remain separate.

Contract: [Completion sales ViewModel](../phases/completion-sales-view-model-contract.md).
