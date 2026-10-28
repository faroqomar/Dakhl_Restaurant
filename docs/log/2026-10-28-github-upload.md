# GitHub repository rename and project upload

Date: 2026-10-28 (Asia/Baghdad). Scope: repository publication chore; no phase implementation or merge approval.

Request: push the current project to GitHub and rename its repository to `Dakhl_Restaurant`.

Changes: renamed the existing private repository from `faroqomar/ResturanetAccounting` to `faroqomar/Dakhl_Restaurant`, preserving its history and visibility, and updated `origin`. Prepared `codex/project-baseline-upload` to publish the existing Electron reference, project documentation, frozen planning references, skills and kickoff records together as an explicit project snapshot. The pre-existing `codex/phase-00-baseline` branch remains preserved; the upload branch is separate from future phase implementation.

Privacy: excluded local preview browser profiles/caches alongside existing account-file, backup, environment-secret, dependency and build exclusions. Curated reference images and synthetic verification artifacts remain part of the project snapshot. No restaurant account files were opened or modified.

Verification: `npm --prefix electron-reference test` passed all 140 tests with zero failures or skips. These verify the Electron reference, not Flutter phases. GitHub confirmed the renamed repository remains private. Publication review, final staged-file checks, upload and remote revision verification are recorded below when complete.

Publication checks: independent read-only review identified five local Chromium profile directories; all are excluded. The staged tree contains zero account/private files or profile paths, and the text scan found no private-key/token candidates. Screenshot checks verified all 179 frozen SHA-256 hashes. The full staged whitespace check reports existing trailing whitespace in imported rules/source records and generated evidence; preserved those files rather than rewriting historical sources. No other diff-check diagnostic type was reported.

Upload result: snapshot commit `d242ef1` was pushed to `origin/codex/project-baseline-upload`; `git ls-remote` matched the local revision. Draft [PR #1](https://github.com/faroqomar/Dakhl_Restaurant/pull/1) provides the review record. No merge performed. Phase documents changed concurrently after staging; those later working-tree edits were left untouched and are outside the uploaded snapshot.

Memory delivery: an initial sync/check completed with zero pending or failed documents. Subsequent documentation updates and concurrent phase edits were queued; the latest check reports pending documents and no failures. Queue acceptance is not completed delivery. Final publication-note delivery remains pending.

Limits: no application installation, real-data migration, Flutter implementation, phase completion, design approval or merge is implied. Existing historical documentation remains a record of its original task; current execution status remains in PHASES.md.
