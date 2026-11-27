# README refresh and Flutter cash-sale capture

The owner requested a rewritten README, a recording of the running app, and screenshots. The README now opens with a cash sale and gives first-run steps for the isolated demo. The archived Electron tour remains in the [media guide](../media/README.md). Madar runtime, API, and dependency changes are N/A because this task documents and exercises the app's existing consumer workflow. Phase and release evidence remains in [the tracker](../../PHASES.md).

## Build and observed outcome

- App source `84878943dc4098e1daeb5dbc0b29a2de85093f50`. Madar source `d3d1ba1f6a5082f4ecc5a03ce677792f898269cf`.
- Flutter 3.47.8 and Dart 3.13.7. Locked dependency resolution and the Madar source checker passed in the existing checkout. Both repository remotes responded with the workspace credentials. Validation used the existing checkouts.
- The debug build used [the synthetic acceptance entry point](../../lib/platform/completion_acceptance_main.dart) and demo ID `readme-demo-20261127`. T3 Device installed and reopened it on the iPhone 18 Pro Simulator with iOS 27.2. The build, install, and launch ran as separate steps.
- The app opened Sales with 20 synthetic products. The recording adds one `Synthetic item 0`, scrolls to the 1,000 IQD checkout, confirms payment, and opens saved receipt `S-000001`. The session used the marked synthetic store and left the receipt open for inspection. This run exercises the sale and saved receipt on the simulator.

## README media

| File | Dimensions | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| [Cash sale GIF](../media/cash-sale.gif) | 560 × 1134 | 319,110 | `fbd3004aa84e2f3c5cda5cb718eccc5a5f15b54c100135b064151c33953b4bd3` |
| [Catalog PNG](../media/sales-catalog.png) | 804 × 1628 | 160,945 | `7ca96806a34af28e64bb8f69940f221b314255ec3b159b82d203c8a850e57fdd` |
| [Saved receipt PNG](../media/cash-sale-receipt.png) | 804 × 1628 | 129,545 | `e89976f41523e12bcc82bb999b9af6d03b4b6f63951ff4c4d25bc2a9c32d75db` |

The device recorder exported a 125.91-second source video. ImageIO encoded an 84-frame, 14.45-second loop after trimming idle time and cropping the system status bar. Tap markers use the recorded input locations. Sampled GIF frames show product selection, the 1,000 IQD ticket, the paid confirmation, and the saved receipt. Both PNGs were opened and inspected. An independent reviewer checked setup, scope, links, the engine pin, and the stills. Local Markdown rendering, link checks, and whitespace checks covered the final README.

## Storage closeout

Free space was 14,645,524 KiB at intake and 8,956,752 KiB at closeout. The app checkout grew from 14,171,284 to 14,180,224 KiB. Its build directory grew from 1,905,128 to 1,909,208 KiB and its Dart cache from 38,612 to 42,868 KiB. The Git directory stayed at 4,108,656 KiB. The canonical installed build, its staged simulator bundle, the marked demo account, and the three README assets remain available.

Cleanup removed 823,756 KiB of duplicate bundles, task-created compiler outputs and capture scratch, plus the 4,055,039-byte incomplete SDK fetch pack. The duplicate app bundle matched the retained bundle file for file. The retained executable, asset hashes, and links checked out after cleanup. No app or engine temporary Git object store was present. Shared-volume usage moved by more than the app checkout delta. The source of that change remains unresolved, and capture and build work ended below the 10 GiB threshold.

## macOS follow-up

The owner asked to add the desktop app to the same README. The macOS GIF sits above the iPhone recording. Madar package, contract, and runtime work is N/A because this follow-up captures an app workflow using the existing engine pin.

The native run used the existing November 10 macOS ARM64 debug bundle on macOS 27.2.1. Deep, strict code-signature verification passed. The bundle enables App Sandbox and its Dart kernel contains `completion_acceptance_main.dart` and the synthetic acceptance marker. The tracked app runtime source, assets, macOS project files, Flutter lockfile, and engine pin match the November 9 baseline `fb7037a`. Kernel SHA-256 is `fd3a4a3684eee9a0d9c33d79a5b5a594127bb6abbaa51d9b1ca9cc1c5b664a64`.

The running process acknowledged the marked macOS fixture `remaining-20261108-v1`. Its revision advanced from 16 to 17 when one `Synthetic item 0` sold for 1,000 IQD. The app acknowledged one cash sale and opened saved receipt `S-000005`. The desktop app remains open on that receipt.

ScreenCaptureKit recorded 42.25 seconds of the target window. The GIF trims idle time and shows product selection, the populated ticket, and the cash-sale confirmation. ImageIO decoded every frame of the finished 10.55-second loop. The receipt still crops to the dialog and omits the fixture's profile header. Both screenshots and the GIF were visually checked. A separate reviewer confirmed the workflow, legibility, and README placement.

| Desktop file | Dimensions | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| [Cash sale GIF](../media/desktop-cash-sale.gif) | 1280 × 804 | 1,194,577 | `1048b8118f9f56f8c4a1c71262a17176d4d3b21cd9dc093f48aa0c88c76f5cc4` |
| [Catalog PNG](../media/desktop-sales-catalog.png) | 1280 × 804 | 876,937 | `dfae064dc09d2762a2c8f7f9ee6c5a55d9fc96a23e104596e8b494f8693e1dc4` |
| [Saved receipt PNG](../media/desktop-cash-sale-receipt.png) | 529 × 753 | 246,298 | `d61ba165a738652db2d143edbbdd37e7cc781c9177c43c2e2aa3e88a5fe4e37d` |

Free space started at 6,187,988 KiB and fell to 114,148 KiB during preflight. Capture paused and resumed at 13,482,524 KiB. Workspace output changes occurred during the interval. The cause of shared-volume fluctuations remains unresolved. At closeout, free space was 12,973,252 KiB, the app checkout measured 6,144,556 KiB, Git measured 4,109,352 KiB, and the build directory measured 1,905,136 KiB. Cleanup removed 6,656 KiB of raw captures and temporary tools. The three final media files total 2,317,812 bytes. The existing app bundle and synthetic fixture remain available for inspection.
