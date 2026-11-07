# Supplier liability and ledger read model

Status: local nonvisual candidate; not posted accounting, integrated UI or approved release.

`SupplierLedgerQueries` reads immutable schema11 `AccountDocument` records. Supplier identity, saved invoice lines, payment allocations and date selection remain app-owned. Madar `CommerceCalculations` owns quantity/price calculations; `ExactMath.binary64IntegerSum` owns explicit source-compatible aggregation. No shared implementation is copied into the app.

Queries mirror frozen `electron-reference/app/ui/model.js`: invoice paid/due, date-limited available debt with excluded-payment support, total supplier liability, ordered ledger rows and balance before an event. Archived suppliers retain history. Missing invoice returns zero due; missing supplier does not suppress matching historical records. Legacy payments without allocation fields default according to invoice presence. Available debt date limits debt rows but subtracts all other payments, matching source; this is not a conventional date-as-of balance.

Aggregates preserve source expression grouping and binary64 rounding, including negative results. They return BigInt representations of the source integer values, so formatting does not truncate into native int. Individual invoice lines and totals retain source money/quantity limits. Carton/piece defaults remain independent and round separately; no conversion factor is introduced.

Ledger ordering REQUIRES an injected comparator reproducing the frozen runtime's localeCompare profile. There is no lexical fallback. Date, createdAt, payment-last and ID tie ordering match source; final ordinal preserves stable ties. `balanceBefore` deliberately uses source lexical date/time selection after event ordering. Production collation adapter remains an engine integration prerequisite, so full ledger parity is not claimed from fixture-only comparisons.

The synthetic oracle generator executes actual frozen model functions under installed Electron Node-only mode, records model SHA256, runtime and resolved collation options. Six scenarios cover mixed allocation/legacy payments, archived/missing suppliers, missing invoice, future debt, excluded payment, equal-time payment ordering, independent unit rounding and maximum money. A pure-Dart runner of those same test bodies passed6cases; targeted analysis passes. Flutter execution remains pending because shared machine disk exhausted during another focused suite. Five oracle inputs exercise raw query semantics directly; the sixth is validated first by frozen M.validate and then decoded through LegacyAccountCodec before all query assertions. This is not a complete import/migration validation corpus. Existing codec validation remains required before production use.

No storage writes, financial policy, journal mapping, UI, merge, build or production-record operation is introduced.
