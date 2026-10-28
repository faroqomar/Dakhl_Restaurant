# Preserved Electron reference

Created by moving the existing working tree here on 2026-10-28, at the owner’s request. This is the old implementation to consult during the Flutter rebuild, not the destination for new Flutter features.

- app/, assets/, tests/, package.json and package-lock.json are preserved with their original contents.
- node_modules/ and the app-specific scripts moved with the implementation, so its tests remain runnable.
- README.md and .impeccable.md preserve the existing app instructions and design context. The original README includes historical installed-version statements; verify the installed app separately before relying on them.
- docs/, outputs/, dist/ and design/ are **links to the unchanged shared folders at the parent root**, not relocated copies. All plan/screenshots remain outside this reference folder.
- Git history and shared agent/configuration instructions remain at the parent root. No installed app or restaurant account data was moved or opened.

From the project root:

```sh
npm --prefix electron-reference test
```

Use synthetic fixtures for previews and accounting verification. The ordinary start command uses the original application’s local-data behavior and may open real accounts. Do not use it as a smoke test for this folder move.

The shared capture tool remains at ../scripts/capture-flutter-reference.cjs and now resolves this folder’s source and dependencies. Do not regenerate or replace the frozen screenshot baseline without an intentional reference revision.
