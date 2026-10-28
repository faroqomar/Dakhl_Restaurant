# 0013 — Preserve the legacy application in electron-reference

Status: owner-approved and implemented as folder organization; does not begin Flutter implementation. Date: 2026-10-28.

## Request and decision

The owner requested placing the existing project in a reference folder within the same project to begin the rebuild, explicitly keeping the plan and screenshots outside that folder.

Electron application files, assets, tests, package.json, dependency lockfile, node_modules and application tooling moved to `electron-reference/`. Project documentation, plan, screenshots, outputs, dist, design, Git and agent settings remained at the root. The original README was preserved in the reference, and the root README became the rebuild guide. Shared design context remains in root `.impeccable.md`, with its original copy in the reference.

Links named `docs/`, `outputs/`, `dist/` and `design/` inside the reference point to existing root folders so earlier instructions and preview tools remain usable without moving or duplicating images. There is no second `.git`.

## Consequences

Flutter uses the project root instead of the earlier proposed `flutter/` subfolder. This supersedes only the file-location recommendation in 0011; it changes neither platforms, features, design, accounting rules nor the 12-phase order in 0012.

Plan-building, reference-capture and memory tools remain in root `scripts/`. The capture tool was repaired to read from `electron-reference/` and write to the original screenshot path. Reference images and account files are not regenerated during relocation verification.

## Verification and limits

Moved-file and screenshot hashes were compared before/after relocation, and reference tests were run from the new location. Actual evidence is in the [relocation log](../log/2026-10-28-electron-reference-folder.md). This is neither a new application installation nor migration of restaurant accounts; the normal application and its account directory were not opened.
