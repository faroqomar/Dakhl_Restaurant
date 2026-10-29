# Open and close the sidebar

Status: implemented and locally verified. Date: 2026-10-26. Source: the owner requested hiding/showing the sidebar to gain space. Version: 1.10.1.

Added a permanent menu button at the start of the shortcut bar; it fully hides the sidebar and restores it when pressed again. It updates `aria-expanded`, `aria-controls`, accessible name and keyboard access, and removes hidden menu items from focus. State is saved on this device in `localStorage`, outside accounts/backups. Toggling does not redraw the page form, so the active sale and its inputs survive.

Verification: `npm test` passed 93/93. An isolated Electron run confirmed a 224-pixel workspace increase, preservation of the ticket/note, shortcuts working with navigation closed, state restoration after reload and Enter-key operation. Widths 1440, 900 and 390 were checked with the sidebar open/closed, without page errors or window-width overflow. The closed-state screenshot `dist/commerce-qa/sidebar-collapsed.png` was visually reviewed using illustrative data only.

macOS ARM64 packaging succeeded with the existing icon warning. The release was installed at `/Users/eros/Applications/Daftar.app`, preserving the previous app beside it as `Daftar-1.10.0-before-sidebar-2026-10-26.app`. Accounts and schema 8 were unchanged by this request. Usage/application references were updated. Hindsight verification follows synchronization; submission alone is not success.

## Move the close button into navigation — 2026-10-26

At the owner's request, the hide button now appears next to Daftar's identity inside open navigation. The show button appears in the top bar only while navigation is closed. Exactly one button remains visible; focus moves to it after toggling to retain keyboard control. State storage/accounts were unchanged. `npm test` passed 96/96; syntax/diff checks passed. Refreshing the preview tab and checking the accessibility tree confirmed the close button inside main navigation and the absence of the top button while navigation is open.
