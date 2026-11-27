# Phase02 Android installation preservation incident

Date: 2026-10-30. Status: **CONFIRMED preservation failure; Android acceptance blocked. Prior installed-app data retention is unverified.** This is an avoidable Lead/agent execution failure. No owner approval, restoration or successful Android verification is inferred.

## Request and boundary

Step4 required independent verification with existing work preserved, no reset/uninstall/production-record testing, and no invented pass. Candidate app62edbf788/runtimea6a8ebdd had independently reviewed source and520 passing app tests. Existing task AVD Flutter_API_37_2 was cold-booted without wiping or loading/saving a snapshot; prior app installation was to remain intact. Test code intended only marked synthetic fixture roots.

## What happened

1. Two Android test attempts stalled before launch because installed Flutter3.47.8 queried an unresponsive iOS provider even with the explicit Android device. A temporary per-command configuration disabled iOS workflow support, but this simulator discovery path ignored that gate. Both interrupted commands returned0 while lacking completion/expected-outcome evidence; both were correctly rejected.
2. An existing Command Line Tools context selected only for the Android process made unrequested iOS tools genuinely unavailable. A bounded Flutter device preflight then found the real emulator. Global Flutter settings, HOME/CODEX_HOME, Xcode selection and SDK source were not edited.
3. The task-local configuration directory also acquired a new `.android/debug.keystore`. The next real Android build used that signing certificate. No installed-versus-candidate signing-certificate preflight or pre-install data inventory/backup was captured.
4. Installation reported `INSTALL_FAILED_UPDATE_INCOMPATIBLE`. Despite explicit `--no-uninstall`, Flutter announced uninstall, removed the existing package and installed the newly signed APK. The native WRITE test then ran and asserted success. Containment did not prevent completion of this fallback.

Pinned SDK source explains the flag: `test.dart:309–313` controls post-test cleanup, while `android_device.dart:410–427` retries a failed install through unconditional `uninstallApp`; `:487–508` invokes adb uninstall without keep-data. The Lead incorrectly relied on the flag as an installation-preservation safeguard.

## Verified impact and limits

Read-only package evidence confirms a fresh install/update at device14:35:00, equivalent to UTC11:35:00 under the verified Baghdad timezone. Installed and built APK hashes match. A read-only public-certificate check confirms the newly generated task debug store signed that replacement APK; the key file was unchanged by inspection and no private key/raw certificate-tool output was exported, printed, copied or indexed. The previous installed signer was not recorded, so its exact identity is unknown.

The old known picker fixture directory is absent. A new generic synthetic fixture root exists after the raw WRITE. No normal account payload was read during impact checks. Prior installed-app data retention cannot be certified; uninstall/reinstall and missing old fixture data are not described as a successful restoration or harmless operation. The raw WRITE/PID18745 is excluded from acceptance because the preservation precondition was breached.

Project source worktrees and retained host test/review evidence remain preserved. This does not establish retention of the emulator's previous app data. No data recovery, snapshot restore or further install was attempted. Backup availability for prior target state was not established by this attempt.

## Containment

All owned test/install descendants ended. The task-started emulator was shut down without wipe/reset/snapshot restore; serial disappearance and owned PID termination were verified. Only the original power state was restored; app data was not restored. Android installation and cancellation verification stopped. No further Android mutation is authorized by this record.

Original global settings hash is unchanged. The task-local signing directory is intentionally preserved in place because it contains signing material; it was not blindly deleted as routine temporary cleanup. Private signing material must not be copied into Git, project knowledge, logs or ordinary evidence artifacts. The public-only receipt and file-name/hash inventory are retained separately.

Independent review verified the source/log chain, rejected receipts, certificate binding, shutdown and claim limits. Mac six-stage results remain accepted and separate; isolated Mac measurements may proceed with normal user/Apple context. Current iOS verification and hosted CI remain pending. Overall Phase02 is **NOT READY for full approval**.

## Prevention and next action

Before any future installation, a fail-closed preflight must establish the exact installed package/signers, candidate APK signers, build/signing-store provenance and authorized preservation/backup conditions. Unknown or incompatible signatures must stop before invoking Flutter installation. A prebuilt verified artifact should prevent a later rebuild from silently changing identity. Do not trust `--no-uninstall` to prevent failure fallback. Configuration isolation must account for transitive signing-store locations, not just unchanged settings files.

A reusable guard and a separately isolated test namespace are future proposals requiring appropriate project ownership/review; neither is silently implemented here. Missing/changed certificates must be exercised as refusal cases without a real uninstall. Prior-data assessment/restoration requires actual evidence and authorization; do not invent recovery or overwrite target state. Android acceptance stays blocked.

## Evidence

- Native index (local-only artifact `outputs/phase02/step4-native/summary.md`, SHA-256 `98267335276517fec240970d8104c34a8fc5b786e5ebc5d13b62c603ca0e86a1`) preserves all three Android attempts and current Mac proof.
- Read-only impact (local-only artifact `outputs/phase02/step4-android-install-impact-readonly.json`, SHA-256 `d569fcec01dd848b58e295c2bdf62855b53853a0359ea1cac6cede00e120e7e3`), clock mapping (local-only artifact `outputs/phase02/step4-android-impact-clock.json`, SHA-256 `fb7086cb85e5a0a7dabf1a4619fd6af68e4e7dc7b17a2c9735f31772afd593a0`).
- Public certificate binding (local-only artifact `outputs/phase02/step4-android-debug-certificate-binding.json`, SHA-256 `f88b3a9e3c44e25820e3709e95b79d764fca988f1241a2864341b708175aaf8a`), preserved task-directory inventory (local-only artifact `outputs/phase02/step4-android-task-config-inventory.json`, SHA-256 `57896eb3e1fb5c14119ba7d8e9a297d3fe0df9036287050fd7e6356ac177f5ca`).
- Independent incident/native review, native audit (local-only artifact `outputs/phase02/step4-native-audit.md`, SHA-256 `2c04a3b1940c11a6d41fbdc93ffb8148a13b6fda6b3d9368aa905c8436ed7963`).
- [Current Phase02 review](../phases/02-step4-review.md), running execution audit (local-only artifact `docs/log/phase-02-execution.md`, SHA-256 `d490433a2ead39ecf2f36721364cd1003b550152426fa7b98b90c3bb069c639c`).
