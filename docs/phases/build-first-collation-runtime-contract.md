# Build-first source collation runtime contract

Status: local development integration candidate under the owner's build-first direction. Independent capability/app review, mobile support, native app acceptance and delivery remain pending. This is not a supported release or universal Electron parity claim.

## Ownership and source identity

Madar owns the existing ICU algorithm, pure collation port, native bindings, version/host checks and session disposal. Dakhl_Restaurant consumes `madar_icu_collation` 0.1.0-dev.1 from the same explicit engine revision `ac8b4edc2c915ed22c0991685c33967b3360e7fa`; no engine pin or runtime Dart/C source changed. The optional package README still describes the capability as a bounded candidate. A reviewed source revision does not establish independent acceptance of this capability or its app integration.

New engine-owned candidate packaging tooling preserves the already qualified binary bytes and loader-relative topology. Its tool digests, source identities, qualification limits, relocation smoke and storage record live in [the engine bundle receipt](../../../Madar_Engine/docs/log/2026-11-08-icu-runtime-bundle-build.md) and [setup guide](../../../Madar_Engine/docs/how-to/icu-runtime-bundling.md). The app owns copying that generated runtime into its development app and opening explicit sessions. No engine source is copied into the app.

## Source profiles and lifecycle

- Temporal/event ordering uses an explicit en-US standard session, matching the observed reference host's default locale. It does not infer every historical machine's default locale.
- The frozen invoice material-name chooser explicitly uses Arabic; the app opens a separate `ar` standard session for it. An Arabic UI does not change event collation to Arabic.
- Normal startup opens the bundled runtime on supported macOS ARM64 and passes the two capabilities through operational screens and report composition. App disposal closes the owning adapter and both sessions. Portable hosts accept caller-owned event/material comparators and retain caller ownership.
- Missing native payloads, unsupported hosts and invalid native versions expose no comparator. They never select lexical or host-locale fallback. Dependent UI and exports show an unavailable state.

## Packaging

The canonical engine runtime is `../Madar_Engine/outputs/icu-runtime/macos-arm64`. It retains the bridge, three ICU78.2 dylibs, license, symlinks and a hashed manifest. The app's `scripts/embed_icu_macos.py` validates the generated payload and copies it into `Contents/Frameworks/MadarIcu` before app signing. The native C and Dart algorithms remain in the engine. An identical existing bundle is reused; temporary staging is removed after installation.

Clean checkouts do not contain this ignored native artifact. Follow the engine preparation guide; do not download/rebuild ICU merely to reproduce this app build. An optional build without a prepared bundle explicitly reports unavailable sorting. Set `MADAR_REQUIRE_ICU_RUNTIME=1` for the local candidate build that must include it.

## Actual evidence and limits

The optional-package offline resolution added only that committed path package; all prior lock entries, package versions and checksums stayed unchanged. Consumer source/pin/boundary preflight passed after the addition. The engine's bounded load/lifecycle and fresh-process relocation checks passed. Two app consumer checks passed: absent library supplies no fallback; the real generated runtime provides distinct profiles, canonical-equivalence/NUL behavior and parent disposal of both sessions. These are finite checks with synthetic strings, not native app launch, mobile qualification, full source-order acceptance or a benchmark campaign.

Final app analysis/build receipts follow in the root build-first closeout. Full tests, benchmarks and independent review remain the next owner-directed stage.
