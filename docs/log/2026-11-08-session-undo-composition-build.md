# Session undo composition build

Status: implementation in progress; final small checks and remaining restoration adapters pending. Full tests, benchmarks, independent review and visual qualification remain deferred by owner direction.

The app registers acknowledged changes in a session-local stack with a maximum of 30 entries. Sales/returns and account generation replacement reset the stack. Financial undo appends eligible inverse/replacement operations and retained receipts. It does not replace an old envelope or erase historical journals. Root suppresses registration while an undo owns its compensation and synchronization.

Root mounted portable metadata/stock/spending adapters in the settings undo action and shell shortcut. One assembled widget passed: checkout, category creation, settings undo, preserved sale/journals/receipt count. Register/date and parties adapters now dispatch by their retained canonical intent types; their successor checks and financial delete restoration extensions are in progress.

Normal schema11 composition also has a separate source-only session controller. It uses the same metadata whitelist/patch planner and existing inventory reversal command, honors generation/CAS/reconciliation, retains unknown commands and refuses unsupported financial changes or unsupported stock reversal chains. It creates no fabricated portable history. Root observes actual source ViewModel notifications and successful settings/chicken saves. Three focused tests passed for metadata restoration, exact unknown readback and refusal after an unobserved newer edit. Initial fixture failures came from untyped nested maps; the corrected fixtures assert their intended source change before exercising undo.

Engine implementation N/A: all new code is restaurant source history, presentation and composition over existing reviewed packages. No engine copy, pin, normal bootstrap, real-account data, policy, opening/counteraccount default, merge or release change.

Use the detailed phase execution journal and worker logs for actual attempts and storage receipts. No new native exports or duplicate build artifacts in this batch. Final root storage closeout remains pending while implementation continues.

Root successor eight-case batch passed: stock four (standalone inverse, negative-history refusal, atomic new product/opening reversal+archive, atomic negative-history refusal), normal/portable assembled metadata undo two, register/date screen composition two. Root added a non-dirty settings refresh after other normal metadata commits; dirty editor input stays captured and cannot overwrite newer source. Its two-action normal UI successor is prepared.

Storage review sample at 2026-11-08T14:17:06Z: free 96,055,300 KiB; `.git` 18,439,356 KiB; `build` 2,122,080 KiB; `outputs` 7,398,508 KiB. Git/outputs unchanged from the earlier source batch; build cache is 50,492 KiB smaller. No Git temporary object directories observed or task-owned disposable outputs identified. Unique sources, canonical debug artifact and recovery evidence retained.
