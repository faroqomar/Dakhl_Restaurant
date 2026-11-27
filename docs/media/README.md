# Dakhl_Restaurant README media

## Flutter cash sale on macOS

The [desktop GIF](desktop-cash-sale.gif) shows the native macOS app adding an item to the ticket and confirming a 1,000 IQD cash sale. The [sales catalog](desktop-sales-catalog.png) and [saved receipt](desktop-cash-sale-receipt.png) show the same session. The app saved receipt `S-000005` to its isolated synthetic account.

The 10.55-second GIF shows only the app window. The receipt still crops to the dialog and omits the fixture profile header. The [capture record](../log/2026-11-27-readme-live-demo.md#macos-follow-up) identifies the reused debug bundle, fixture, and capture checks.

## Flutter cash sale on iPhone Simulator

The [cash-sale GIF](cash-sale.gif) records a cash checkout in the running Flutter app on an iPhone 18 Pro Simulator with iOS 27.2. The [catalog](sales-catalog.png) and [saved receipt](cash-sale-receipt.png) are stills from the same session. Receipt `S-000001` contains one synthetic item and totals 1,000 IQD.

The app ran the [synthetic acceptance entry point](../../lib/platform/completion_acceptance_main.dart) with a fresh demo identity. It generated the products and stored the sale under that identity. The 14.45-second GIF crops the simulator status bar, trims pauses, and marks the recorded taps. See the [capture record](../log/2026-11-27-readme-live-demo.md) for the build revision and verification.

## Archived Electron references

`reference-tour.gif` is a nine-second slideshow assembled from preserved Electron screenshots of sales, inventory and daily expenses. The source harness used synthetic in-memory accounts and an isolated profile. This is a screenshot tour, not a recorded interaction or current Flutter demonstration. Each frame states that boundary.

The [archived gallery](../planning/flutter-rebuild/gallery.html) references the canonical PNGs. Source capture metadata and hashes remain in [the manifest](../planning/flutter-rebuild/screenshot-manifest.json). See the [capture guide](../planning/flutter-rebuild/capture-guide.md). FFmpeg scales each screenshot to fit a 1080 × 840 canvas, adds English captions and holds each for three seconds.

See [the documentation receipt](../log/2026-11-12-portfolio-readme.md) for checks and limits.

The owner retired the Electron application and capture tooling on 2026-11-12. These archived screenshot pixels and source-hash manifests remain canonical; no runnable Electron source is required to display this media. [Retirement decision](../decisions/0022-retire-electron-reference.md).
