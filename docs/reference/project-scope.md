# Dakhl_Restaurant scope — One restaurant

Status: owner-approved; future capabilities need further definition. Date: 2026-10-16. Source: owner direction in conversation and confirmation of ResturanetAccounting. Decision: [0001](../decisions/0001-single-restaurant-and-project-memory.md).

## Purpose

This project and application serve one restaurant only. Every invoice, campaign, idea and development activity here belongs to that same restaurant. No approved need exists for multiple restaurants, subscriptions or selling a general-purpose system. Scope changes require explicit direction and a documented decision.

The restaurant name supplied by the owner for the menu on 2026-10-16 is **Jannat Baghdad Restaurant**. The current project name is **Dakhl_Restaurant**, as directed on 2026-10-28. The reference Electron application's historical name is **Daftar**; preserve its technical identity, data and frozen screenshots. A restaurant-name change does not automatically change records.

## Areas of work and status

| Area | Actually available | Later definition or implementation |
| --- | --- | --- |
| Invoices | Daily-expense and supplier-invoice PDF export | Cash-sale receipt added by the 2026-10-26 request; [rules](../decisions/0002-sales-inventory-shortcuts.md) |
| Restaurant accounts | Expenses, daily balance, cashbox, suppliers, invoices, payments and debts | Report extensions require explicit financial meanings |
| Historical worker records | Worker-advance UI removed at owner request on 2026-10-27; records retained only for compatibility/backups | No operating UI; [decision 0007](../decisions/0007-retire-worker-savings.md) |
| Advertising campaigns | [Campaign documentation register](../planning/campaigns.md) | Creation/publishing/ad-platform integrations are not implemented in the application |
| Ideas | [Idea register](../planning/ideas.md) | Convert an idea into requirements, then implement when requested |
| Sales and inventory | Cash sales, history/PDF receipts, sellable inventory and custom shortcuts since 2026-10-26 | Ingredients, recipes and credit sales are outside current scope; returns/held orders belong to [MVP completion](../decisions/0010-mvp-returns-and-held-orders.md) |
| Dedicated application | Electron, Arabic RTL UI and local persistence | Flutter/Dart rebuild for macOS/Android/iPhone is selected/planned; [decision 0011](../decisions/0011-flutter-rebuild-baseline.md). The isolated phase00 technical baseline has started; product screens and migration are not implemented |
| Documentation and memory | Project documents and dedicated `project-daftar` Hindsight bank | Synchronization results are established in work logs, not inferred from configuration |

## Matters the owner has not yet defined

Official identity/logo, campaign platforms/budgets/success measures, additional invoice types, and the meaning of any additional application or future integration. Do not fill these gaps with assumptions. Multiple devices, branches or accounts are not automatic consequences of serving one restaurant; define them when needed.

## Limits of this clarification

The 2026-10-16 request establishes scope, documentation, follow-up and memory. It does not authorize creating/publishing an actual advertisement or changing accounts or application technology. Verification reference: application files in the [application reference](application.md). Current financial decisions are in the [accounting rules](accounting-rules.md).
