# Portfolio README refresh

Date: 2026-11-12. Scope: documentation and media only. Status: local edits prepared; independent parent review and delivery remain separate.

## Request and changes

The owner requested concise portfolio READMEs, screenshots, GIFs and useful run instructions across five projects. The restaurant README now explains the offline Arabic RTL/IQD purpose, the preserved Electron application, current Flutter rebuild, sibling Madar dependency, setup, verification commands and remaining activation/release gates. It omits family details and contract/cost figures supplied as background.

The root's former Oct 30/31 status snapshots remain in `docs/reference/readme-before-portfolio-2026-11-12.md` with links adjusted to their original targets. The archive has `hindsight:ignore` to avoid promoting stale status as current knowledge. PHASES.md retains status authority and was not changed.

The screenshot uses the canonical tracked synthetic Electron sales PNG. `docs/media/reference-tour.gif` is a captioned nine-second screenshot slideshow of sales, inventory and expenses, not current Flutter runtime or a recorded interaction. Its source-hash manifest and media README retain provenance. No new UI capture, production data, design modification or runtime behavior change occurred.

## Ownership and source authority

App responsibility: reader-facing documentation and restaurant media. Engine runtime/API changes: N/A, because the existing capabilities and dependency remain unchanged. Contract: `engine-dependency.json` still selects Madar `d3d1ba1f6a5082f4ecc5a03ce677792f898269cf`, application dev.7, domain dev.5, data dev.2, Flutter adapters dev.3 and ICU dev.2. Local-only counterpart: `Madar_Engine/docs/log/2026-11-12-portfolio-readme.md`; this app PR does not publish or certify that separate engine documentation. No copied engine implementation, repin, phase advancement, financial activation, publication, merge or release.

Focused project-daftar Hindsight recall succeeded; current source and the Nov 9 local closeout supersede stale historical scope/status. Both repositories' rules, plans, trackers, prompts and relevant scope/setup contracts informed the rewrite. The project-local documentation-and-adrs skill governs this app; SLine-specific docs-sync targets do not apply.

## Verification

- `python3 scripts/check-engine.py`: pass. Exact revision, resolved sources, package versions, source purity and consumer boundaries match.
- Setup commands checked against `.fvmrc`, `pubspec.yaml`, reference `package.json` and CI configuration. Node 24.19.0 matches reference CI. Native ICU qualification needs generated artifacts and stays explicit.
- Fresh installation, app launch and native interactions: not rerun for this documentation change. The normal entrypoint retains existing account composition and live financial cutover remains gated. Full application tests/builds/benchmarks: N/A for behavior changes.
- FFprobe: GIF 1080 × 840, nine seconds, 418,110 bytes. Source PNGs match their canonical capture manifest. Frame text labels Electron/reference/synthetic/screenshot-tour provenance.
- Root README, media guide, task log and historical copy: 47 local links resolve. Three source PNG hashes match the canonical capture manifest. Extracted GIF frame inspected with visible provenance labels.

## Problems and prevention

Broad combined rule reads and generated HTML search returned truncated output. Follow-up reads used focused slices and canonical source files. Guessed optional paths and unmatched zsh globs failed read-only inspection. Pillow was unavailable; FFmpeg already installed and completed media assembly without adding dependencies. A broad dependency search was interrupted when it proved unnecessary. These attempts changed no runtime sources or data. The prevention catalog records bounded output, exact path discovery and renderer preflight.

## Storage

Baseline: project 26,787,252 KiB including hidden Git; free disk 78,347,024 KiB. Preserve existing uncommitted prevention and Nov 10 launch/cleanup records. Task media totals about 420 KiB, with no copied PNGs, build caches or runtime bundles. Canonical historical captures and current build/account/recovery evidence remain. Final measurements and memory receipt follow after checks.

Final storage sample: project26,787,756KiB, delta+504KiB; free disk78,086,556KiB. `.git`16,550,032KiB, build2,015,100KiB, `.dart_tool`36,412KiB and outputs8,080,208KiB. No Git temporary object directories were found. Task-owned media and Markdown explain the small project delta; shared-host free-space changes have other producers and are not attributed to this lane. The 418,110-byte GIF, its compact provenance and the historical README are retained for the requested presentation/history. Canonical PNGs are reused, with no copied screenshots. Removed the temporary extracted GIF frame and successful-recall scratch after inspection; raw logs/account data were not added. Reclaimed task scratch is below1MiB; no uncertain shared cache or unique recovery evidence was deleted.

Memory sync submitted the three changed allowlisted documents. Initial project-scoped check: API healthy,400sources,README/prevention/task-log pending,zero failed. Queue acceptance is not completed ingestion. Parent receives the final source delivery verdict separately so this log does not trigger repeated self-documentation ingestion.
