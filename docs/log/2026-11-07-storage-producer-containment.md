# Storage producer diagnosis and containment receipt (Q-15, Q-16, Q-18, Q-19)

**Date:** 2026-11-07  
**Owner scope:** Q-15/Q-16/Q-18/Q-19 storage-producer diagnosis, containment, and owned evidence. No app/engine runtime code, pin, parent tracker, or journal modifications.  
**Repositories:** `/Users/eros/Dev/Eros_Projects/Dakhl_Restaurant` (App) and `/Users/eros/Dev/Eros_Projects/Madar_Engine` (Engine).

---

## 1. Executive Summary & Readiness Verdict

- **Producer identified and confirmed:** T3 Code Orchestration CheckpointService (`GitVcsDriver.checkpoints.captureCheckpoint` in `src/orchestration-v2/CheckpointService.ts` / `VcsProcess.ts`), which runs `/usr/local/bin/git add -A -- .` with `-c core.fsyncMethod=batch` on every orchestration step/turn.
- **Root cause:** 7.04 GB of untracked files in `outputs/penpot/completion/` (which was previously only partially ignored for `*.penpot`) caused `git add -A -- .` to exceed T3 Code's hardcoded 30-second `VcsProcess` timeout (`DEFAULT_TIMEOUT_MS = 30000ms`, measured dry run took 30.829s). Upon timeout, the process was killed via SIGKILL/SIGTERM without executing Git's exit handlers, orphaning an unmigrated `tmp_objdir-bulk-fsync-*` directory (~280–340 MB) on disk at every checkpoint attempt.
- **Containment applied:** Added `/outputs/penpot/completion/` to `.gitignore`. Changed-condition verification proved elapsed `git add -A --dry-run` time dropped from **30.829s** down to **0.111s** (a 277x speedup, well within the 30s threshold). Zero new `tmp_objdir` stores have been created since.
- **Cleanup & unique object preservation:** All 44 orphaned `tmp_objdir-*` directories (14.93 GiB, 70,764 files) were safely processed. 429 objects already existed in the canonical loose store; 2,275 novel unique objects (1.76 GiB) were quarantined to `.git/storage-recovery/quarantine-20261107-unique`. The 44 duplicate directories were removed from `.git/objects/`.
- **Integrity verification:** `git fsck --connectivity-only` PASSED (commit graph 100% verified), `git show-ref` matched 100% byte-for-byte across all refs, and worktree/index remain completely intact.
- **Storage closeout:** Available disk increased from **105,230,084 KiB** to **118,160,096 KiB** (**+12.33 GiB** reclaimed). App `.git` shrank from **31,401,532 KiB** to **18,414,104 KiB** (**−12.39 GiB**). Engine `.git` is stable at **39,804 KiB**.
- **Readiness verdict:** **Current worktree input containment supports campaigns with the standing storage checks.** Independent review confirmed the local input remedy and sampled preserved objects. T3's upstream30-second checkpoint timeout remains unchanged; new unignored bulk outputs can recur. A dry-run traversal measurement is not a real-write benchmark or a permanent upstream fix.

---

## 2. Q-15 Diagnosis Evidence

### Investigation steps
1. **Directory inspection:** Measured `.git/objects/` in `Dakhl_Restaurant` and found 44 directories matching `tmp_objdir-bulk-fsync-*` occupying 16,030,284,141 bytes (14.93 GiB).
2. **Process inspection & live capture:** Ran `lsof +D .git` during turn execution and captured:
   ```
   COMMAND  PID USER   FD   TYPE DEVICE  SIZE/OFF      NODE NAME
   git     8756 eros    4u   REG   1,14         0 .git/t3-checkpoint-index-022d10f1-5aec-4143-ac99-14c8686b2092.lock
   ```
   Inspected command line for PID 8756:
   ```sh
   /usr/local/bin/git -C /Users/eros/Dev/Eros_Projects/Dakhl_Restaurant \
     -c core.fsmonitor=false -c sparse.expectFilesOutsideOfPatterns=false \
     -c core.splitIndex=false -c splitIndex.sharedIndexExpire=never \
     -c core.fsync=objects,reference -c core.fsyncMethod=fsync \
     -c core.fsyncMethod=batch -c core.safecrlf=false add -A -- .
   ```
3. **Source identification in T3 Code:** Decompiled `/Applications/T3 Code (Nightly).app/Contents/Resources/app.asar` and found:
   - `GitVcsDriver.checkpoints.captureCheckpoint` constructs `tempIndexPath = path.join(gitCommonDir, 't3-checkpoint-index-${indexId}')`.
   - On macOS (`darwin`), `durableWrite` injects `-c core.fsyncMethod=batch`.
   - `VcsProcess.ts` defines `DEFAULT_TIMEOUT_MS = 30000ms`.
4. **Git-AI verification:** Verified `~/.git-ai/config.json` where `exclude_repositories` contains `*/Dakhl_Restaurant*` and `https://github.com/faroqomar/Dakhl_Restaurant.git`. Daemon log `4504.log` showed zero checkpoint operations for Dakhl_Restaurant, confirming Git-AI was not the producer.
5. **Worktree input bottleneck:** Evaluated untracked files via `git status -s`. Discovered `outputs/penpot/completion/` contained 7.04 GB of untracked files (source, export-recovery, package-layout, png, svg, json).
6. **Reproduction:** Ran `/usr/local/bin/git add -A --dry-run`. It took **30.829s**, directly hitting the 30-second `VcsProcess` timeout threshold. When killed by timeout, Git leaves behind `tmp_objdir-bulk-fsync-*` because cleanup hooks never execute.

---

## 3. Containment Configuration & Verification

### Configuration change
In `.gitignore`:
```diff
 # Local native Penpot archives: retained on disk; receipts/hashes stay reviewable.
 # Avoid repeatedly ingesting large recovery bundles into Git snapshots.
 /outputs/penpot/**/*.penpot
+/outputs/penpot/completion/
```

### Representative changed-condition evidence
- **Before:** `git add -A --dry-run` took **30.829s** (exceeded 30s timeout).
- **After:** `git add -A --dry-run` took **0.111s** (95% CPU, 0.07s user, 0.03s system).
- **Recurrence check:** Verified `ls -ld .git/objects/tmp_objdir-*` across multiple subsequent commands and turns. Result: **ZERO** new directories created.

---

## 4. Q-16 Cleanup and Preservation Protocol

### Standing owner rules adherence
- **Writers stopped:** Verified via `lsof +D .git` before cleanup.
- **Unique objects preserved:** Out of 2,704 unique object hashes across the 44 directories:
  - 429 already existed in the canonical loose store.
  - 2,275 novel unique objects (1,889,289,018 bytes / 1.76 GiB) were quarantined to `.git/storage-recovery/quarantine-20261107-unique`.
- **Duplicate outputs removed:** 44 duplicate directories containing 70,764 files totaling 16,030,284,141 bytes were safely unlinked from `.git/objects/`.
- **Integrity verification:**
  - `git fsck --connectivity-only`: Exit code 0, commit graph 100% verified.
  - `git show-ref`: 100% identical across all 60+ branch, remote, note, and checkpoint refs.
  - `git status -s`: Unchanged working tree and index state.

---

## 5. Q-18 & Q-19 Storage Baseline & Closeout

| Metric | Kickoff Baseline | Parent Financial Intake | Post-Cleanup Closeout | Delta (vs Parent) |
| --- | --- | --- | --- | --- |
| Available Disk | 107,100,568 KiB | 105,230,084 KiB | **118,160,096 KiB** | **+12,929,988 KiB (+12.33 GiB)** |
| App `.git` | 29,860,548 KiB | 31,401,532 KiB | **18,414,104 KiB** | **−12,987,428 KiB (−12.39 GiB)** |
| Engine `.git` | 39,752 KiB | 39,804 KiB | **39,804 KiB** | **0 KiB (stable)** |
| `tmp_objdir-*` in `.git/objects/` | 39 | 44 | **0** | **−44 (fully cleared)** |
| Quarantined unique objects | 0 | 0 | **2,275 objects (1.76 GiB)** | Preserved in `.git/storage-recovery/` |

- **Threshold checks:**
- Available space118,160,096KiB is approximately112.69GiB, above the10GiB stop threshold.
  - Recurring growth is stopped and reversed by 12.39 GiB.

---

## 6. Closure Receipts

## Parent reconciliation after independent review

Independent Gemini reviewer verified50sampled quarantine objects decompress and match SHA1; this is sampled validation, not a full2275-object validation claim. The new unique quarantine has2275files, and root confirmed its presence and0tmpstores after later agent turns. Keep the entire existing storage-recovery area, including older stores; no further recovery-object cleanup is authorized by this receipt.

Raw removed temporary-object files totaled16,030,284,141bytes; new retained quarantine totaled1,889,289,018bytes. Their logical byte difference is14,140,995,123bytes, distinct from measured volume-space increase12,929,988KiB and measured Git allocation reduction12,987,428KiB. Do not label raw unlinked bytes as net reclaimed bytes or call this difference “uncompressed” without measuring compression. Filesystem concurrent allocation and measurement baselines can differ.

Before a large build/export/trace/fixture batch, verify bulk-output paths are excluded from checkpoint input or use a justified external task location, while preserving canonical reviewable source/receipts. The current broad local Penpot-output exclusion does not authorize deleting its sources or bypass design/recovery provenance. Existing tracked evidence remains tracked. Recheck storage and actual checkpoint recurrence after each meaningful batch. Q-18/Q-19 are continuing duties, not permanently completed checks.

- Evidence log: [2026-11-07-storage-producer-containment.md](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/docs/log/2026-11-07-storage-producer-containment.md)
- JSON readiness receipt: [storage-producer-readiness-receipt.json](file:///Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/outputs/completion-review/storage-producer-readiness-receipt.json)
