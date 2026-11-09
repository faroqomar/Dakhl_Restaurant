# Isolated interactive UI QA

Build explicitly with `flutter build macos --debug -t lib/platform/ui_qa_main.dart`.
Open `build/macos/Build/Products/Debug/Dakhl_Restaurant Dev.app` using computer use
only after confirming the build used this entrypoint. This overwrites the local
development build artifact, not installed restaurant data.

Each process creates a fresh `dakhl-ui-qa-*` directory beneath system temporary
storage and logs its canonical path as `ui_qa_storage`. Account and shell stores
use the real engine adapters inside that root. Normal application-support paths
are never selected. No file import/export capability is supplied. Startup failure
shows an error and never falls back to normal storage.

Use synthetic UI input only. The directory remains after exit for inspection;
this entrypoint performs no automatic deletion. Relaunch begins a different empty
fixture and does not establish restart/recovery verification. Normal `lib/main.dart`
is unchanged. This harness exposes existing screens; it does not integrate the
nonvisual Completion commands or establish full-product acceptance.
