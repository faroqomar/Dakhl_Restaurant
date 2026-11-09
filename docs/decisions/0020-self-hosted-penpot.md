# 0020 — Use self-hosted Penpot for current design work

Date: 2026-11-05. Status: accepted owner direction; setup and native design delivery require separate evidence.

## Context

The owner requested the Completion phase's design and wireframes. The existing cloud Penpot plugin was disconnected, the T3 browser reached external sign-in, and native desktop recovery was unavailable. The owner then explicitly requested self-hosted Penpot instead of the website and Penpot MCP server.

## Decision

Use a private local Penpot instance on the current Mac and its browser UI. This supersedes [0015](0015-penpot-design-workspace.md) only for the cloud-only destination and MCP connection path. Preserve the existing cloud project and local source/export provenance; do not delete, overwrite or relabel earlier work. Keep the same project/file/page naming in the local destination where feasible, and record actual new instance identities after creation.

Deploy the official Penpot container composition with pinned native ARM64 images, persistent database/assets and loopback-only access. Keep deployment secrets and local account credentials outside the repository in owner-only files. Disable remote telemetry and unnecessary external integrations. Do not expose a public/LAN endpoint or add an OS startup service by default. Root owns runtime/browser actions; the deployment specialist owns private compose files under `~/.local/share/penpot-selfhost/compose/`.

No local `.penpot` archive was found in the bounded project outputs, Downloads or installed bridge search. Recreating layered source artwork or importing existing exports is distinct from a complete native migration of the cloud file. Preserve that limitation until a native archive or equivalent verified migration exists; account/project naming alone does not prove continuity.

## Ownership and limits

This is consumer design tooling. Madar runtime/API/packages and engine Design are N/A. Offline single-restaurant Arabic RTL/IQD/history scope and shared-engine ownership remain unchanged. Existing accepted design scope does not expand merely because the host changes. Do not implement the app, invent features, infer design approval, merge or publish a product release.

The continuing Step 1.5 task must prove source-backed layered artwork through the local Penpot UI and native exports, preserve prior evidence, review state/responsive/accessibility coverage and present discrepancies for explicit owner approval. Local service readiness, successful import/export, complete design coverage and owner approval are separate gates.

## Verification

Record exact installed runtime/image revisions, compose checks, listener/persistence behavior, local browser identity and native import/export results in the [Step 1.5 record](../phases/completion-penpot-design-review.md) and ignored execution journal. Initial runtime installation/configuration is in progress; this decision is not a running-service or delivered-design claim.
