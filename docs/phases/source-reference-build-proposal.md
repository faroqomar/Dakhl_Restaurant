# Source-reference implementation decision

Status: proposed, not approved. Date: 2026-11-08.

Requested scope: implement remaining held forms and computed states from the frozen Electron behavior and the existing source references below during build-first. Defer Penpot/native visual qualification and final visual acceptance to the later verification stage. This changes the order of the design gate for this task only; it does not claim those designs qualified or visually accepted.

This covers the 29 held base references, source-only positive refund/name previews and source-defined empty-held/delete/eligibility/unknown-save/narrow/keyboard states using the already approved shared form/recovery patterns. Preserve source behavior and current accepted financial contracts. No invented accounting rule, missing-posting exception, default opening/counteraccount, actual live migration, merge or release. Financial/runtime approval gates remain separate.

## Held base source references

| Reference | Existing source | SHA256 |
| --- | --- | --- |
| desktop-expenses | [desktop-expenses.png](../../docs/planning/flutter-rebuild/screenshots/desktop-expenses.png) | `f89ba2a8e05956d79a7f8bd3041cfb61c9a31efafad5ebb4d7d3e97099cfdee5` |
| desktop-cash | [desktop-cash.png](../../docs/planning/flutter-rebuild/screenshots/desktop-cash.png) | `8cd3105d728e5268e7cb2cade38a9b4964803715a4bfa4016a14125b8d1301a9` |
| desktop-expense-new | [desktop-expense-new.png](../../docs/planning/flutter-rebuild/screenshots/desktop-expense-new.png) | `c8ae4c14196ecb2f9ff8e62e85874ad62ac8bcec9aecf52dbf3cfaaef78887d4` |
| desktop-expense-edit | [desktop-expense-edit.png](../../docs/planning/flutter-rebuild/screenshots/desktop-expense-edit.png) | `99081dcbd9fcc654dc08cdf9eec7bf37c1295ef2420fd993568ec11b6708fbb3` |
| desktop-total | [desktop-total.png](../../docs/planning/flutter-rebuild/screenshots/desktop-total.png) | `e52b2f4a0f9f5deea086632f8f5dace1450d3f34a33123dd3cb231742a3f006e` |
| desktop-balance | [desktop-balance.png](../../docs/planning/flutter-rebuild/screenshots/desktop-balance.png) | `f09f77a7ef00640c2dc282361d4465b96863348f03e118f9eefe3b205cbb6836` |
| desktop-day-date | [desktop-day-date.png](../../docs/planning/flutter-rebuild/screenshots/desktop-day-date.png) | `4e84f0457a9d491b335072f1d5c018c17838b647d6dc470ec257e56469001254` |
| desktop-cash-edit | [desktop-cash-edit.png](../../docs/planning/flutter-rebuild/screenshots/desktop-cash-edit.png) | `652b6ce48b33018b27c7a645f6343f0c1512654e8cd88dcebd934150d515355b` |
| phone-cash | [phone-cash.png](../../docs/planning/flutter-rebuild/screenshots/phone-cash.png) | `3acdff6b01270ede690d193908690260b1a7af29a9fb2db5d0d8b2a9a57799eb` |
| desktop-expense-edit-bottom | [desktop-expense-edit-bottom.png](../../docs/planning/flutter-rebuild/screenshots/desktop-expense-edit-bottom.png) | `2262891661d3c9d50361ce9cd9f826d365eda27e5d4b48b8ddb8af56ec0b49b5` |
| desktop-cash-edit-bottom | [desktop-cash-edit-bottom.png](../../docs/planning/flutter-rebuild/screenshots/desktop-cash-edit-bottom.png) | `b2062e655b6cea46c35ac1be3eab6f55d94c154d11e1a158d94ad46febca39a5` |
| phone-cash-bottom | [phone-cash-bottom.png](../../docs/planning/flutter-rebuild/screenshots/phone-cash-bottom.png) | `47bf69fbb0bd097a15e66cac565e361fb134fb20175b4e1acfe3b493ff883812` |
| phone-expense-new | [phone-expense-new.png](../../docs/planning/flutter-rebuild/screenshots/phone-expense-new.png) | `a2ea55cd9c3b4511a4a823427e900f927ef0a17e334f54c4bf2a9b6110d59ff2` |
| phone-expense-new-bottom | [phone-expense-new-bottom.png](../../docs/planning/flutter-rebuild/screenshots/phone-expense-new-bottom.png) | `90966c637a1ea8d212ce218b165eaf2a286a2187dc5a6e84a86bb66283c23471` |
| full-phone-cash | [full-phone-cash.png](../../docs/planning/flutter-rebuild/screenshots/full-phone-cash.png) | `5f018527b991c545d2af63ba770b3fcb732a988438e3410a165d3d867009f0fe` |
| desktop-payment-new | [desktop-payment-new.png](../../docs/planning/flutter-rebuild/screenshots/desktop-payment-new.png) | `8c3d30699a0ea38bcddac5deb7aeee7955c0a147577ac1160ba993fa43603a7c` |
| phone-payment-new | [phone-payment-new.png](../../docs/planning/flutter-rebuild/screenshots/phone-payment-new.png) | `aeb6cea5314cae7397c404d0fc5e91b700a6b9588e6c884a87b69f2ff737c0db` |
| desktop-invoice-cartons | [desktop-invoice-cartons.png](../../docs/planning/flutter-rebuild/screenshots/desktop-invoice-cartons.png) | `3f2ff5408efe90457fbf8621ab4ea391dc6796fd7c29bc6da672274b7e8b6136` |
| phone-invoices | [phone-invoices.png](../../docs/planning/flutter-rebuild/screenshots/phone-invoices.png) | `0994bcb36918d635a576c1a2cec742448daded08b011f63e46862830b0a8f5a2` |
| phone-invoices-bottom | [phone-invoices-bottom.png](../../docs/planning/flutter-rebuild/screenshots/phone-invoices-bottom.png) | `8af93b41ce42b7402dd73c79b1fc68e454673eda0a6e289eb0e9545feb1d9f16` |
| desktop-settings-data | [desktop-settings-data.png](../../docs/planning/flutter-rebuild/screenshots/desktop-settings-data.png) | `78bbbe0b0a642209995b6b4d0f9e3854e367f7904689fe0733022f8c06443daf` |
| desktop-settings-restaurant | [desktop-settings-restaurant.png](../../docs/planning/flutter-rebuild/screenshots/desktop-settings-restaurant.png) | `ad7ae271e998bb704a4ab7e2a81fb8958579f573d1b9bf10caf70b682de8c4fa` |
| desktop-settings-restaurant-bottom | [desktop-settings-restaurant-bottom.png](../../docs/planning/flutter-rebuild/screenshots/desktop-settings-restaurant-bottom.png) | `a76d962c5906337371e4e1beecf407f2ba795eec90cab2d9463bfe1c3e3a8201` |
| desktop-settings-about-bottom | [desktop-settings-about-bottom.png](../../docs/planning/flutter-rebuild/screenshots/desktop-settings-about-bottom.png) | `fbbe03ec458ace6e146f4efb919be191a4b4309d6f4dd891c7e988ff55aba40f` |
| empty-settings | [empty-settings.png](../../docs/planning/flutter-rebuild/screenshots/empty-settings.png) | `fbbe03ec458ace6e146f4efb919be191a4b4309d6f4dd891c7e988ff55aba40f` |
| phone-settings | [phone-settings.png](../../docs/planning/flutter-rebuild/screenshots/phone-settings.png) | `3f1297dbbfe6d333d1d2872516b9badcccdc8d31b6b5aaa1acb6c9bb499ccf38` |
| phone-settings-workflow-bottom | [phone-settings-workflow-bottom.png](../../docs/planning/flutter-rebuild/screenshots/phone-settings-workflow-bottom.png) | `837599345e28440d4c46f17ba97e12839e44ede169b631882ab3b58d43002e88` |
| phone-settings-about | [phone-settings-about.png](../../docs/planning/flutter-rebuild/screenshots/phone-settings-about.png) | `9ea19e11c338c7e541c49a02f305d3f0644d24be124b532d66e5da40b02a2d4a` |
| full-phone-settings | [full-phone-settings.png](../../docs/planning/flutter-rebuild/screenshots/full-phone-settings.png) | `3b8c82d214ff0baad7ef6f84cb11456f978c102be59c125d434af3424c156c6c` |

## Existing supplemental references

[Positive refund source proposal v2](../../outputs/completion-review/c3-positive-return-preview-proposal-v2.json) and [typed held-name source proposal](../../outputs/completion-review/c2-held-positive-proposal.json) retain their prior qualification limits. These sources are implementation inputs under the requested decision, not native design evidence.

- `state-held-name-positive`: [source PNG](../../outputs/penpot/completion/source/c2-held-positive-states/reference-data/state-held-name-positive.png), SHA256 `e2dbf5620f47f2498c4ac445f42ce124a16d91f50b15c0d9a27bfb0098bbf4ec`.
- `desktop-sale-return-partial`: [source PNG](../../outputs/penpot/completion/source/positive-return-preview/reference-data/desktop-sale-return-partial.png), SHA256 `5d33a019916b42fc5d66b532718c1c77994d8bccb5b6e5c323c7afc2462528b6`.
- `desktop-sale-return-full`: [source PNG](../../outputs/penpot/completion/source/positive-return-preview/reference-data/desktop-sale-return-full.png), SHA256 `aad11074eb620cbf776fa6da19e9a2596f28b8a5a148070523aea1c2c5e35b14`.
- `phone-sale-return-partial-bottom`: [source PNG](../../outputs/penpot/completion/source/positive-return-preview/reference-data/phone-sale-return-partial-bottom.png), SHA256 `0fa32ccd0c7476fcab560b0be868e58c5f63f12d4a4bda1f08faafffa5e252a1`.
- `phone-sale-return-full-bottom`: [source PNG](../../outputs/penpot/completion/source/positive-return-preview/reference-data/phone-sale-return-full-bottom.png), SHA256 `aee1f8744e729d4476eb74265ec78d552507800880e973c961ad94d8d0aded9b`.
- `phone-sale-return-partial`: [source PNG](../../outputs/penpot/completion/source/positive-return-preview/reference-data/phone-sale-return-partial.png), SHA256 `f54d67ee855b07f17c28529cb16e0ba3aada3b94dbb5730405f06a08592f7113`.
- `phone-sale-return-full`: [source PNG](../../outputs/penpot/completion/source/positive-return-preview/reference-data/phone-sale-return-full.png), SHA256 `d03e22708c2a501ed6e0f042c79c55db412a1953de9ef6718b155990b5093476`.

Source-defined remaining interactions retain authority in `electron-reference/app/ui/commerce.js`, `renderer.js` and `model.js`. No source file, new artwork/export, browser session, independent review or runtime test was created by this proposal.

Madar implementation/API/design N/A for this scope decision; app presentation and safeguards only, existing reviewed package contracts apply.

Named requested response: **Approve source-reference build; defer visual qualification**.

## Owner decision — 2026-11-08

Approved: "Approve source-reference build; defer visual qualification". [Approval receipt](source-reference-build-approval.md). Earlier proposal/held statements retain history; implementation now authorized under this source-reference scope.
