# Phase 00 — iPhone Simulator native acceptance

Current clarification, 2026-10-29: the owner approved the existing Phase 00 design set and independent review closed its iPhone technical prerequisite. Earlier pending statements below are historical. This closes the technical prerequisite only; it does not assert overall Phase 00 DONE or a production release.

Date: 2026-10-29. Required native flows observed successfully; independent evidence review pending. Owner explicitly approved the existing Phase 00 and Phase 01 Penpot sets and requested Step 3. Physical iPhone/signing stays deferred under the existing Simulator direction.

## Corrected environment and source

Interactive app is **Device Hub 27.1**, `/Applications/Xcode.app/Contents/Applications/DeviceHub.app`, bundle `com.apple.dt.Devices`. The earlier conclusion that old Simulator.app absence meant no interactive access was incorrect and is superseded. Reused booted iPhone 18 Pro/iOS 27.0; no erase, uninstall, new harness or permission changes.

The preinstalled executable differed from the retained build artifact, so exploratory first open/export cancellations were not treated as exact-source acceptance. Rebuilt/relaunched the approved Phase 00 runtime from the preserved `phase00-penpot` worktree using `flutter run --no-pub --no-resident -d <existing target> -t lib/platform/probe_main.dart`; exit 0. No runtime source changes relative to approved app `00baa5731776ecb7b0fe91911892cd5006d421f4`; only engine-dependency status-description text differs, not the immutable engine pin. `scripts/check-engine.py` passed resolved source/version/boundary verification at `784b139753a0e2a07d3f97eedb326debfe068395`. Installed rebuilt executable SHA matched the newly retained artifact. Exact provenance and launch log.

## Observed results

| Required flow | Result / evidence |
| --- | --- |
| Native open/cancel | Document picker appeared; X cancellation returned Arabic canceled status with controls restored. Known-source picker. |
| Native export/cancel | Save-location picker appeared; return to Browse root then X returned canceled status. An attempted sheet drag did not dismiss and is not a pass. Canceled result. |
| Export/reopen | Saved a new 112-byte synthetic JSON into previously empty On My iPhone. Reopened that newly created file through native Recents; success. Export, reopen. |
| Offline Arabic PDF/share | Generated PDF; native sheet showed the synthetic PDF. Dismissed using exposed Cancel with no recipient/app selected. Plugin returned success/handoff; independently observed dismissal does not imply delivery or a reliable plugin cancellation classification. Share sheet. |
| Native print/cancel | Options/Arabic preview appeared, no printer selected; X closed it, app returned canceled. No job submitted. Preview, canceled. |
| Recovery / preserved source | PDF generation succeeded again after cancellations. Three retained synthetic export/cache files were each 112 bytes, expected format/message/sequence1 and identical SHA-256 `857bf114be7b70a0608a623a39310df746ed1cc125657f4929b58c152d1f6f12`. Integrity record. |

Controls were operated through Device Hub using native accessibility indexes where exposed. Embedded file-picker/chrome controls missing from its tree used coordinates from current screenshots; no invisible control guessing. The owner changed the window to compact mode at the end; refreshed the tree before continuing and preserved that preference.

Acceptance manifest records artifact hashes. Preliminary mismatched-binary/exploratory evidence is preserved and superseded by known-source results; it is not silently relabeled as acceptance. No restaurant account/backup/invoice was read or overwritten. The new synthetic file remains disposable test evidence; no broad cleanup was performed.

## Limits and phase handoff

This closes the specifically outstanding Simulator chooser/export/reopen/share-dismiss/print-cancel observations, subject to independent evidence review. Reuse unchanged Phase 00 unit/build/CI/other-platform evidence; no blanket suite rerun was needed. Native denied writes, external existing-destination rollback, provider cache limits, interrupted picker recovery, physical printing/hardware/accessibility and signing remain their previously recorded limits, not newly passed claims. No new financial/recovery policy or supported release is established.

Phase 00 source was already owner-approved and merged; design approval is now recorded. Evidence documentation remains local and requires its own integration approval. Do not label unmerged evidence changes DONE or merge them automatically. Record technical dependency closure separately so the owner-authorized Phase 01 implementation can proceed once the focused review confirms this missing acceptance evidence. No Phase 01 runtime code was added by these checks.

## Independent focused review

Reviewer `phase01_docs_review` found no material blocker to closing this technical prerequisite. It independently inspected native screenshots/results, recomputed 16/16 artifact hashes, read all three synthetic specimens and checked the empty runtime-source diff against the approved head. With owner design/plan/Step 3 authorization, Phase 01 implementation may proceed; no additional documentation-merge prerequisite is invented. Evidence integration, overall DONE, supported release and deployment remain separate. No broad test/build/design reruns were performed by the reviewer.
