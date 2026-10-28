# 0018 — Develop the shared engine alongside Dakhl_Restaurant

Date:2026-10-28. Status: owner-directed separation implemented locally; remote delivery and phase completion remain pending. Design:N/A; no product UI changed. This updates the earlier phase00 dependency assumption in the rebuild plan and supplements0017.

## Direction and source ownership

The owner explicitly directed engine work alongside this project: read both documentation sets, implement reusable responsibilities in Madar_Engine, transfer shared code there and keep app code here. Madar's FULLSTACK, responsibility list and ADR0006 are authoritative for shared engine scope. Dakhl_Restaurant remains one restaurant, offline, Arabic RTL/IQD, with existing historical accounting meaning. Consuming the engine does not add cloud, login, multitenancy, migrations or new financial behavior.

| Code | Owner |
|---|---|
| Pure capability outcomes and byte/PDF handoff ports | Madar `packages/application` / `madar_application` |
| Generic file selection/export and native PDF share/print | Madar `packages/flutter_adapters` / `madar_flutter_adapters` |
| Synthetic schema/codec and4096-byte policy; development-only revision repository/legacy guards/nonce | App phase00 harness |
| UI, ViewModel, entrypoints, native identity/entitlements, Arabic PDF content/layout/font | App |
| Future shared business invariants and deliberate operations | Madar, implemented with app consumers after affected policies/contracts are explicit |

No financial/domain implementation existed in phase00 to transfer. Moving the synthetic repository into the engine as production persistence would misstate its role. Shared adapters contain no restaurant IDs, schema, widgets, PDF layouts or financial rules. App wrappers supply policy and schema validation, then delegate; extracted implementations are removed from app runtime source. Engine packages cannot depend on the app.

## Local integration and delivery

Canonical development layout uses sibling `Dakhl_Restaurant` and `Madar_Engine` checkouts. `pubspec.yaml`/lock contain relative paths, not this machine's absolute paths. The current nested Codex app worktree has an untracked sibling symlink to the canonical engine; no engine code is vendored in app Git. `engine-dependency.json` records the exact local engine commit and both preview package versions. Run `python3 scripts/check-engine.py` to reject an unintended commit/version change, dirty engine source or boundary violation.

App isolation branch: `codex/phase00-engine-split`, starting from `517c6a8` in the existing phase00 worktree. Madar local Git baseline: `a335bea`, branch `codex/restaurant-capability-extraction`. Neither branch is merged. No engine remote was created or package published. Preview packages are `0.1.0-dev.1`; production financial compatibility is not claimed.

Hosted CI checks out a separately published engine repository beside the app at its committed consumer SHA. It requires `MADAR_ENGINE_REPOSITORY` configuration and read access (`MADAR_ENGINE_READ_TOKEN` only when the default token cannot read that source). Source publication/read access is still pending, and the earlier app OAuth workflow-permission blocker remains. Local path success is not a hosted CI pass; missing source fails clearly. Permissions/credentials are not changed by this extraction.

## Verification and limits

Tests first: new app wiring checks failed before the dependency/wrapper existed; the adapter Worker recorded missing-source red before implementation. Final48 app tests and27 engine adapter tests pass. The separate-process app repository test now explicitly supplies the package config because its contracts come from a package; real process-restart behavior remains tested. Formatting/analysis and all3 debug builds pass. Dependency-boundary scanning confirms no Flutter/vendor imports in pure contracts, consumer policy in adapters, or copied generic implementations in app runtime code.

Previous native dialog evidence remains phase00 evidence, not a new certification of engine adapters. Native materialization/cache bounds, replacing existing external destinations, hardware output and physical iPhone signing remain unverified. Open financial/stock/lifecycle policies and both-domain engine release gates stay pending. Benchmarks:N/A. No next phase starts.
