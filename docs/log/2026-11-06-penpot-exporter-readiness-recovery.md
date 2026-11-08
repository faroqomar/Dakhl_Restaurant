# Penpot export readiness recovery

The native exporter now completes two previously blocked saved boards. Step1.5 remains incomplete; no new design/wireframe pair or approval is claimed.

## Cause and evidence

The installed2.18.5-RC1 exporter hard-codes a10,000ms default locator readiness wait. PNG and SVG both use `#screenshot-<board-id>`. A direct local render-page observation measured supplier get-page12,904.9ms; the correct1440×1000 element appeared afterward. Changing output size or SVG format does not address this readiness mismatch.

Lead preserved the original bundle, changed one exact readiness default to45,000ms and restarted only the exporter. The current image, database and saved designs remain intact. This private patch lives in the current container writable layer, so exporter recreation loses it; inspect exact bundle identity before reapplying. Original backup, receipt and rollback instructions are private under `/Users/eros/.local/share/penpot-selfhost/compose/overrides/exporter-readiness/`. No app/engine source change.

## Actual native outputs

- Supplier design1x:1440×1000,94,990bytes, completed10:08:29.819UTC. Lead viewed the Arabic form, amounts, fields and controls.
- Saved full-sales design2x:3200×2320,1,806,442bytes, completed10:10:51.264UTC. Lead viewed discrete food photos, Arabic labels and controls. Source-origin/dimension qualification remains pending.

Exact hashes, IDs, artifacts and patch fingerprints: `outputs/penpot/completion/export-recovery/`. The coverage ledger retains both original pairs and the recovered candidate.68existing pairs still need applicable content qualification;97complete pairs remain missing, including the supplier's missing wireframe. Seven required state/responsive patterns remain in scope;104supplemental captures remain source inventory.

## Prevention and next work

Use tab-specific browser status for completed downloads. A board-id URL can retain the previous selection; verify the checked layer ID before requesting export. Keep dense layer trees collapsed and reconcile Saved/errors before another import. Reuse prepared sources and actual native IDs; repair missing photos/origins/semantic controls only. No global marker re-audit, whole-corpus rebuild, new serializer, cloud/MCP, blind unchanged retry or speculative OOM diagnosis. The45second readiness bound remains finite and does not waive visual qualification.

One design controller continues Step1.5, then drafts Step2. Parent performs independent aggregate review before owner presentation. Engine runtime/API/Design N/A; reviewed app package pin unchanged. No app implementation, merge, release or design/plan approval.
