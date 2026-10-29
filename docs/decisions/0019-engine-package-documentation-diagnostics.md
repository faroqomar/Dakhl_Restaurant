# ADR0019 — One shared engine, documented packages and terminal diagnostics

Date: 2026-10-28. Status: accepted owner instruction; runtime logger adoption is pending an appropriate authorized code change.

The owner reaffirmed shared implementation once in Madar, with this app consuming reviewed packages and retaining UI/industry behavior. Each new phase explicitly allocates engine/app work and its public contract. The engine is a reusable foundation, not a second separately maintained copy of the app backend. This supplements [ADR0018](0018-madar-engine-boundary.md); engine ADR0008 and its delivery standards own the shared architecture.

The owner requires engine-capability documentation, suitable Dart/Flutter packages when a concrete need exists, useful structured terminal logging and previously agreed meaningful tests. [Consumer obligations](../how-to/engine-consumer-contract.md) preserve pure-core/Flutter-adapter separation, offline behavior, private-record protection and independent engine/consumer verification. No unused package or concrete logging backend is added now.

English-only documentation and Hindsight memory were explicitly confirmed. Existing Arabic prose is translated while preserving dates, technical/accounting meaning, amounts, source identifiers and actual verification status. Arabic executable UI/test/capture data and frozen screenshots/source remain unchanged. Canonical memory banks remain separate; current source/fact content is migrated without clearing banks or altering unrelated projects.

This documentation task does not implement logging, approve designs, resolve financial policies, change the engine pin, mark phase00 DONE or start another phase. Runtime tests/builds/benchmarks are N/A; documentation/translation, protected-source and scoped memory checks apply.
