# 0011 — Rebuild Daftar with Flutter and Dart

Status: the owner approved the rebuild scope; the implementation plan is proposed and detailed, and Flutter implementation has not started. Date: 2026-10-27. Source: the owner's request and answers during this task.

## Confirmed decision

- Rebuild Daftar with Flutter and Dart, with an MVP on macOS, Android and iPhone.
- Run locally without internet; device data is independent, with export/import for backups and manual transfer. No automatic synchronization or merging between devices.
- Reproduce the current design and functions as they stand. The owner decides changes when each phase is reached; do not invent edits in advance.
- Export/share PDFs and use normal system printing; thermal-printer integration is outside the current request.
- Preserve the single-restaurant scope, financial rules, historical records and older backups, including historical worker records without restoring the removed worker UI.

## Rationale

The owner wants a complete feature-based plan with reference images for every phase, so the rebuild delivers a usable MVP preserving the application's design and behavior rather than disconnected screens without persistence or verification.

## Deliverables and status

> Later update on the same date: [decision 0012](0012-merge-flutter-rebuild-phases.md) superseded only the original phase breakdown, making the current plan 12 phases. This decision's scope, platforms, design and persistence choices remain in force. The 19-phase description below records the original deliverable before consolidation.

The [master plan](../planning/flutter-rebuild/README.md) contains 19 phases, 00–18, with separate files, screen/form/state images, a design reference, a financial-parity contract and an MVP acceptance checklist. Images were captured from the current source with isolated illustrative data; they are neither Flutter screenshots nor restaurant data.

A separate `flutter/` directory, presentation/domain/persistence layers and starting with compatible local JSON are implementation recommendations requiring proof and confirmation in phases 00 and 02, not approval of libraries, a database or another project's architecture. Distribution/signing, the Arabic font and physical devices are early verification points, not assumed ready.

## Relationship to earlier decisions

This adds rebuild scope to [0001](0001-single-restaurant-and-project-memory.md) without increasing the restaurant count. Preserve [0007](0007-retire-worker-savings.md) for worker-UI removal, [0009](0009-fluid-aligned-workspace.md) for fluid layout and [0010](0010-mvp-returns-and-held-orders.md) for returns, held orders and receipts. The existing application remains Electron until its replacement is implemented and verified; this document establishes neither an existing Flutter application nor an installed update.

## Verification

The capture guide and source/image hashes are in the [screenshot manifest](../planning/flutter-rebuild/screenshot-manifest.json), and task results are in the [work log](../log/2026-10-27-flutter-rebuild-plan.md). Flutter tests and native device parity remain future work.
