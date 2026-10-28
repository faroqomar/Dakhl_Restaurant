# Phase 00 native capability evidence

These are development-only probes. Default `lib/main.dart` stays blank; no product navigation or restaurant accounts are connected. Candidate package support is provisional until each actual target passes. Do not treat an unsigned build, a fake-service test or an iPhone simulator as physical iPhone installation evidence.

## Automatic checks, without dialogs

With the intended macOS, Android or iOS target selected, generate a fresh non-secret run nonce and run the write stage. `PHASE00_RUN_NONCE` is required: 16–64 ASCII letters, digits, underscores or hyphens; missing or malformed tokens fail before accessing native storage. Reuse this exact token only for its paired read stage; generate a new token for every new write/read evidence pair:

```sh
phase00_run_nonce="$(uuidgen)"
flutter test integration_test/native_capabilities_test.dart -d <device> --no-uninstall --dart-define=PHASE00_RESTART_STAGE=write --dart-define=PHASE00_RUN_NONCE="$phase00_run_nonce"
```

**Keep `--no-uninstall` on every write, read, negative and recovery invocation.** The pinned Flutter integration runner defaults to uninstalling the development app at test teardown, which deletes its application data on mobile targets. Without this flag, a second process cannot establish persistence. Terminate the process between stages without uninstalling or clearing the app.

This invokes native application-support resolution, initializes the marked development child `dakhl_restaurant_phase00_devprobe`, saves a synthetic payload containing that run nonce and its deterministic sequence, reopens it using a new repository instance, generates the Arabic PDF using the bundled Amiri font, and renders its first page through the native PDF renderer. It retains synthetic PDF/PNG evidence in a new `pdf-evidence-*` folder and prints that path. Inspect the rendered PNG for joined Arabic, RTL order, and Latin `123` numerals. No chooser or print job opens.

For actual process-restart evidence, terminate the development process after the write stage, record that termination, then run a new process on the same target:

```sh
flutter test integration_test/native_capabilities_test.dart -d <device> --no-uninstall --dart-define=PHASE00_RESTART_STAGE=read --dart-define=PHASE00_RUN_NONCE="$phase00_run_nonce"
```

The read stage does not write the repository specimen. It requires the exact same nonce-bearing message and sequence as the paired write and must fail for stale data from a previous run. A successful read with a different nonce is never accepted. The read check preserves existing committed data on mismatch. For negative evidence, run a read with a fresh different valid nonce: it must fail without clearing the earlier payload; reading again with the original token must pass. Both stages retain fresh PDF/PNG evidence. Record whether the runner reinstalled or cleared the app; a data-clearing reinstall invalidates the restart precondition. This is process-restart persistence evidence, not power-loss/fsync durability.

For negative and recovery evidence, retain the original `phase00_run_nonce` variable. The first command below is expected to fail with `run_nonce_mismatch`; the second must recover successfully with the original token. Both preserve installation data:

```sh
phase00_wrong_nonce="$(uuidgen)"
flutter test integration_test/native_capabilities_test.dart -d <device> --no-uninstall --dart-define=PHASE00_RESTART_STAGE=read --dart-define=PHASE00_RUN_NONCE="$phase00_wrong_nonce"
flutter test integration_test/native_capabilities_test.dart -d <device> --no-uninstall --dart-define=PHASE00_RESTART_STAGE=read --dart-define=PHASE00_RUN_NONCE="$phase00_run_nonce"
```

## Explicit native-dialog checks

Only when approved for native UI operation, launch the separate opt-in harness:

```sh
flutter run -d <device> -t lib/platform/probe_main.dart
```

1. Confirm the title identifies "Technical probe — test data only" (English translation of the Arabic UI title), the app ID is `com.eros.dakhlrestaurant.phase00`, and the display name is the development app. All controls remain reachable by scroll and desktop keyboard.
2. Export the synthetic specimen to a new disposable destination. Never choose a restaurant account, backup, invoice or an existing important file as the destination. Reopen only that synthetic export and confirm success.
3. Open the file chooser then cancel. Open export then cancel. Record cancellation distinctly from denial/plugin failure. A fake adapter exception is automated boundary evidence only, not an observed native denied write.
4. Generate the Arabic PDF offline. Open sharing and dismiss without selecting a recipient/app. The plugin returns a handoff boolean and cannot reliably distinguish share dismissal on every platform. `share_unconfirmed` is explicitly inconclusive; success does not prove delivery, and cancellation requires independently observed native UI evidence.
5. Open the system print chooser, inspect then cancel without submitting a job. False from `Printing.layoutPdf` is classified as cancellation per its API; exceptions stay failure. Success is native handoff only and does not certify a physical print.
6. Preserve source bytes and repeat after a canceled/failed operation to verify recovery. Do not change permissions or target settings just to create artificial denial evidence. Record inaccessible failure paths as pending.
7. For Android provider/activity destruction and iOS process termination during a chooser, operation recovery remains unverified. The current probe does not restore an in-flight native picker operation. Later production import needs its own recovery policy.

Record target/model, OS, architecture, build mode, app identifier, package lock revision, entrypoint, result and evidence path separately for each flow. Simulator/emulator results do not certify physical hardware or signing. Native accessibility (VoiceOver/TalkBack, focus and native dialogs), native cancellation/failure and real iPhone installation remain pending until executed and observed.

## Package rationale and limits

- `file_picker 13.3.0`: byte-based native open/save candidate for all three targets; unlike `file_selector`, its published save-file API includes mobile. The Dart stream reader and returned synthetic payload enforce a 4096-byte validation limit and never write the selected source. This limit does not bound the whole native selection operation: Android's candidate provider copies the entire selected document into cache before Dart reads it, and iOS uses copy-based document selection. Native provider cache/materialization size behavior remains pending; this is not a production bounded-import guarantee. Only validated synthetic schema is exportable. The native provider writes the selected external destination directly: the wrapper preserves source bytes, but cannot certify rollback or preservation of an existing selected destination if the provider fails midway. Use only new disposable destinations; safe replacement of existing external documents remains pending production design/verification. Source: [package](https://pub.dev/packages/file_picker), [saveFile API](https://pub.dev/documentation/file_picker/13.3.0/file_picker/FilePicker/saveFile.html).
- `path_provider 2.1.6`, `path 1.9.1`: native app-support root with a fixed development child, legacy-name and symlink checks; repository adds ownership-marker protection. Source: [path_provider](https://pub.dev/packages/path_provider).
- `pdf 3.13.1`, `printing 5.15.1`: offline TrueType embedding, RTL PDF layout, native raster/share/print candidates. No network fonts or HTML conversion. Native share completion is not reliable delivery/cancellation evidence. Source: [pdf](https://pub.dev/packages/pdf), [printing](https://pub.dev/packages/printing).
- Font: unmodified static Amiri Regular, OFL1.1. Complete copyright/license, immutable source commit and SHA-256 are under `assets/fonts/`. This technical font probe does not establish phase01 visual typography approval.

Minimums are the scaffold's Android API24, iOS15 and macOS12; actual package compatibility still requires target builds/runtime. Mac printing and user-selected file read/write entitlements are owned by the scaffold. Native plugin registration/build evidence alone does not prove any dialog's behavior. No release signing, publishing or real app installation is performed by this harness.
