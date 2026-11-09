# Browser preview and design feedback

Status: implemented and open for review. Date: 2026-10-26. Source: the owner requested opening the system in a browser to identify unwanted design/layout areas.

`node scripts/preview-design.cjs` serves the current application UI at `http://127.0.0.1:4317/` using illustrative data only; it does not open restaurant accounts. The extra toolbar is preview-only: Highlight & comment selects an area by dragging/clicking and adds a comment; Comments reviews feedback; Export downloads a text list. Owner comments are saved locally in `outputs/design-review/comments.json` and are excluded from project-memory indexing and restaurant data. Application pages remain navigable, and sales can be tried with separate browser-storage data.

Verification: opened the sales page in the Codex browser with sample products and review controls, checked saving and reading a synthetic comment from the comments file, then removed that test record only. The server contains no real accounts, and the installed application was unchanged. The server binds to loopback only and validates comment size/input and request origin. This is a design preview; actual PDF export and backups remain in Daftar.

## Remove selection tools — 2026-10-26

At the owner's request, loading `review.js` and `review.css` was removed from the preview, removing the comments/selection toolbar and colored overlays. Previous feedback remains saved locally. The preview server was restarted and the browser tab refreshed; the sales screen appeared without review tools. Server syntax and `git diff --check` passed. Neither the application nor its data changed.
