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


## Phase01 preferences and native UI

The default app now composes the real reviewed Madar preferences adapter, not the Phase00 probe repository. `shell_preferences_test.dart` is a two-launch conformance harness. Choose one actual development target from `flutter devices`; use a new UUID for each write/read pair and keep it the same within the pair. Keep `--no-uninstall` so the tool does not remove the isolated development database between launches.

```sh
flutter test --no-pub --no-uninstall integration_test/shell_preferences_test.dart -d macos --dart-define=PHASE01_RESTART_STAGE=write --dart-define=PHASE01_RUN_NONCE=<new-uuid>
flutter test --no-pub --no-uninstall integration_test/shell_preferences_test.dart -d macos --dart-define=PHASE01_RESTART_STAGE=read --dart-define=PHASE01_RUN_NONCE=<same-uuid>
```

The runner exits the writer process. On iPhone/Android, explicitly terminate only `com.eros.dakhlrestaurant.phase00` between commands through the target lifecycle tool; a no-process result on iPhone means the writer had already exited. The reader independently asserts a different PID, persisted nonce, same revision, Inventory and exact slots `[settings, empty, sales, cash, sales, materials]`; only the permitted schema fields persist. A macOS read with a different UUID must fail, followed by the valid UUID recovery read. Never relabel an old successful run with a later source hash.

`phase01_native_ui_test.dart` runs the actual native root, uses real view metrics/IME insets, opens only a synthetic invoice draft, proves save/cancel remain reachable and retain-edit behavior, discards its fixture and restores the original route/six slots. It never submits a domain Save. Run on the existing development Android target:

```sh
flutter test --no-pub --no-uninstall integration_test/phase01_native_ui_test.dart -d emulator-5554 --reporter expanded
```

After any diagnostic/integration entrypoint, rebuild/relaunch the ordinary main app before showing it as the deliverable. Keep initial splash images labeled separately from loaded-shell proof. Current commands/results, hashes, source-delta reuse and native keyboard/back/screen-reader limits are in [Phase01 evidence](../docs/phases/01-build-evidence.md). Device Hub is the installed iPhone GUI; do not search for or install the absent old Simulator.app.


## Phase02 Android installation safeguard

`--no-uninstall` controls Flutter test cleanup; it does **not** prevent Flutter's
install-failure fallback from uninstalling an incompatible package. Do not use a
Flutter install/test command as an Android preservation guard. The earlier
commands above retain their historical provenance; apply the safeguard below
before any future authorized Android installation.

`scripts/android_install_guard.py` accepts a prebuilt APK, expected SHA-256,
package, public signer SHA-256, exact emulator serial/AVD, fixture identity and
source/runtime revision attestations. It supports only a monolithic, single-signer
APK under `com.eros.dakhlrestaurant.phase02.verify.<fixture_suffix>` and an emulator
with one owner user. Production/normal app identities, unknown/multiple signers,
split installed APKs, other users and ambiguous state are refused. The app owns
this verification safeguard; no engine source, runtime package or adapter changes.

Use `python3 scripts/android_install_guard.py --help` for required options. Select
`--mode new-isolated-fixture --fixture-only` only for a newly authorized, absent
fixture package on the explicitly named task emulator. A `--fixture-id` is 16–64
lowercase hexadecimal characters. Preflight is read-only by default. Add
`--execute` only when installation is authorized: the guard privately snapshots
and verifies the exact bytes, rechecks the target/state, then makes one
`adb -s <serial> install -r <private-copy.apk>` call. It never invokes Flutter,
uninstall, data clearing, reset or an install-failure fallback. Tool paths can be
specified with `--adb`, `--aapt2` and `--apksigner`. It confirms the installed APK
hash afterwards; an unconfirmed postcondition fails without destructive recovery.

An existing fixture update additionally requires
`--mode existing-fixture --preservation-receipt <json-path>` and an already-owned
`files/dakhl_phase02_fixture_id` containing the same fixture ID. The receipt has
exactly these fields:

```json
{
  "schema": 1,
  "serial": "emulator-5582",
  "package": "com.eros.dakhlrestaurant.phase02.verify.fixture1234",
  "fixture_id": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "installed_apk_sha256": "<64 lowercase hexadecimal characters>",
  "backup_path": "<absolute path to the authorized fixture backup>",
  "backup_sha256": "<64 lowercase hexadecimal characters>"
}
```

The guard verifies receipt identity, installed APK identity/signature and the
backup file hash before updating, then checks fixture-marker retention. Backup
coverage, historical data retention and source-to-binary provenance still require
the caller's actual evidence. The revision fields are explicitly reported as
caller-attested; this tool cannot reconstruct missing prior data or establish a
historical backup's completeness. Signer rotation, physical devices, split APKs,
normal-app migration and hostile concurrent same-user mutation are unsupported.
The caller must also verify real synthetic payload retention and cleanup; a
passing installation receipt is not a native workflow acceptance result.


### Android execution after the preservation incident

All earlier Android Flutter integration command examples in this document are
historical evidence and **must not be executed for future Android stages**.
Running a guard before a later Flutter build/test/drive command does not protect
that later command: Flutter may rebuild with another signer and invoke its own
install-failure uninstall fallback. `--no-uninstall` does not prevent that path.

For future authorized Android verification, build a fixture APK first, verify and
install those exact bytes through the guard, then attach the Dart host
`integration_test` driver directly to that already-running app's forwarded VM
service. The host driver must perform no build or installation. Keep the VM
service authentication URL only in live memory/environment, redact it from logs,
and remove only the forwarding owned by that run. Root's task-owned stage helper
records source/resolved-engine checks, actual driver outcomes, and independent
cleanup attempts. Failed infrastructure/connection results cannot substitute for
the expected wrong-nonce negative response. Native dialog interaction still
requires actual device evidence; installation alone is not acceptance.


The shared guard signer-report parser accepts either the legacy single
`Signer #1 certificate SHA-256 digest` report or SDK37's single
`V2 Signer: certificate SHA-256 digest` report. The V2 form additionally requires
exactly one `Number of signers: 1` line. Public-key digests do not substitute for
the certificate digest. Mixed, duplicate, conflicting, unknown, malformed or
rotation/lineage reports remain refused. The task stage helper imports this same
reviewed parser instead of maintaining a second acceptance grammar. Successful
`apksigner verify` is still required before parsing; parsing text alone is not APK
signature verification.


## Manual native picker wait boundary — 2026-10-31

`phase02_file_picker_test.dart` now imports test-only `support/native_picker_wait.dart`. Native Activities can pause Flutter frames, so an awaited tester pump is not a cancellable timeout boundary. The scoped helper uses real monotonic timing and timers, rejects observed late success, and confirms a scheduled framework frame without starting a pending pump. It temporarily enables fullyLive rendering and device pointer propagation for actual manual confirmation taps, restoring exact prior values on success, error and timeout. It retains120s per wait plus the existing bounded host/whole-test deadline; a suspended process cannot guarantee returning at an exact wall instant.

Bind both the entrypoint and support-file hashes to each rebuilt APK/IOS build. Earlier long functional cases do not establish the new deadline, and old native receipts are not new-harness evidence. Revalidate all three picker scenarios on Android and iOS. Actual native pointer/Back gestures must reach the owned target; IDE AX toolbar activation alone is not proof of device input. Use only marked synthetic fixture namespaces and the guarded prebuilt Android installation path described above.
