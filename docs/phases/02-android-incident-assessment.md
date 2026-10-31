# Phase02 Android installation incident — bounded impact assessment

Date:2026-10-31. **Historical installation preservation failed. Known impact is development-fixture loss; no recorded business-account exposure was found.** This is not a retention/restoration pass and does not erase the failed installation evidence.

## What the evidence establishes

The confirmed missing picker folder is a marked synthetic fixture, positively identified in the preincident runtime log and absent in the postincident inventory. Earlier installed development builds used Phase00 capability probes and Phase01 UI preferences. Phase01 normal main composed preferences only; normal account-store composition first appears in commit `e572af5` at2026-10-30 07:28:53UTC.

All seven recorded preincident Phase02 Android launches at immutable source `52ed12052c34508f42cd3dd8fe34038c06d5e65e` target integration tests: six persistence/restart/recovery stages08:11–08:15UTC, followed by the picker stage08:26–08:29. Both entrypoints inject marked synthetic stores. Neither imports `lib/main.dart` nor invokes `AppAccountsStore.native()`. Normal account storage is separately composed under `files/dakhl_restaurant_phase01_shell/accounts-phase02`; no recorded entrypoint accessed it. The native operational audit records mobile shutdown08:41 and Mac-only continuation; its line106 states no normal-account location or production-account data was changed. The11:24/11:31 discovery attempts produced no build/install/native execution;11:35 retry2 is the first evidenced destructive install transition.

Known removable development data therefore includes the synthetic picker fixture and development probe/preferences scope. The inventory does not establish which individual prior preference bytes were erased, so this record does not claim every preference was observed lost.

## Remaining uncertainty

No complete pre-install directory/APK/signing inventory or validated matching preincident disk restore point was captured. Curated execution records cannot prove absence of unrecorded installs or manual activity. Historical private bytes and storage-authority identities have not been restored. Neither “all previous data preserved” nor “restaurant records were lost” is supported. The affected original AVD remains untouched and retained; regenerated test fixtures are replacement verification, not historical restoration.

## Independent disposition

A read-only planner traced the source/installation timeline. A separate independent reviewer matched all five artifact hashes, checked the immutable harness entrypoints and earlier Phase01 source, and accepted this bounded classification: **confirmed development-fixture loss, no recorded business-account exposure, residual unknown for unrecorded activity**. That residual is non-blocking for development-preview source integration after the remaining current guarded Android acceptance gates pass. No historical byte-retention test is labelled passed, and no production-release/data-recovery guarantee is made. Discovery of business-record exposure would reopen the assessment.

The owner has explicitly requested the in-scope fixes, verification and paired merge. This assessment is evidence-based impact classification, not a waiver inferred from that authorization. Native Android dialogs, the API37.2 readiness failure and the strengthened real-time test boundary remain separate gates until verified.

## Ownership and prevention

The failure came from Flutter host installation fallback after a signer mismatch. Madar runtimea6/shared persistence contracts are unchanged; no adapter data defect was demonstrated. App-owned guarded fixture installation now refuses normal packages and unknown/incompatible conditions, performs one verified prebuilt update, requires marked preservation evidence for existing fixtures and has no uninstall/clear/reinstall fallback. Current guard37/full65 script checks pass. Failed attempts remain separate from later exact-artifact/no-install continuations.

Preserve single-restaurant/offline/Arabic RTL/IQD/history constraints, original evidence and signing material. Test only marked isolated fixtures. No deployment or next phase is authorized by this incident classification.

## Immutable source anchors

At52ed120: normal factory `lib/main.dart:14`; native injected store/root/app `integration_test/phase02_accounts_native_test.dart:42,181,216,227`; picker root/store `integration_test/phase02_file_picker_test.dart:49,63,78,81`; normal child `lib/app/accounts_store.dart:24` and directory leaf `lib/platform/shell_preferences_directory.dart:14`. These are immutable-source line anchors; current files may differ. The sanitized manifest records the five local evidence hashes without copying payloads or full journals.
