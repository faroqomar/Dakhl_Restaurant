<!-- hindsight:ignore -->
# Phase02 Step4 — independent second-pass timestamp port review

Reviewer `step4_app`; start2026-10-30T11:12:26Z; completed2026-10-30T11:17:47.228066+00:00. App base69fef624; eight owned compatibility files remain uncommitted. No implementation authorship, app/engine source edits, commit, pin change, new approval or native/Flutter/profile work by reviewer. Main audit/tracker belongs to Lead. Original blocking reports and failed repairs remain unchanged.

## Verdict: clear within this correction scope

**APP-P2-01 is closed on the exact final hashes below. No remaining actionable finding was established.** The private token/ES5-fallback/day/time/zone adaptation addresses the known source-accepted legacy forms; it preserves each original string. This clears the app timestamp correction for the Lead's remaining full-source verification. It is not whole-phase completion, owner approval or proof over every possible Date.parse spelling/host timezone/future V8 version.

| Reviewed file | SHA256 |
| --- | --- |
| `lib/accounts/legacy_account_codec.dart` | `fe6ca843767e84091c2aaeee9d33867faf65909b7ab82de38419981bbcf577bd` |
| `lib/accounts/legacy_v8_timestamp.dart` | `4f7ac2f32cd665d15094293f694ffde61cc35e98f5313ebb894b66031c414f63` |
| `lib/accounts/legacy_v8_timestamp.LICENSE` | `81680185f0cb339021e3b73714499264de72f33b17cfdb0c14f400de6d95cf0e` |

The paired JSON (local-only artifact `outputs/phase02/step4-codec-port-review.json`, SHA-256 `4d66b1915fbedfc18b6cc76673a21e8918e96e2cd81604ee8455056cd76832a8`) stores all eight final source hashes, all16 independently verified source/evidence-receipt hashes, exact independent probe programs/cases/outcomes and audit. Worker final receipt: [step4-v8-composer-result.json](step4-v8-composer-result.json). Source-specific parser remains private app compatibility code; no shared Madar rule or backend was copied. Engine a6a8 consumption was Lead-owned and is not independently sourcechecked again here.

## Fresh independent verification

- 410 independently chosen cases×UTC/AsiaBaghdad/AmericaNewYork = **1230 comparisons,0 mismatches**. Coverage includes expanded/negative-zero years, Unicode whitespace/line/format/surrogate cases, comments/NUL/prefixes, exact public40UTF16 boundary, deterministic inserted-token mutations and strict ISO rejection controls.
- 305 additional extreme-year/unsigned32/timezone cases×UTC/AsiaBaghdad = **610 comparisons,0 mismatches**. Source-valid `Jan 1 275800 GMT+400000:00`, `+596523:00` and `+123456789:00` are accepted despite their intermediate unadjusted calendar year exceeding direct TimeClip range. Every accepted result was encoded/reopened and its original timestamp compared exactly.
- Independent fresh fetch/hash of pinned Nodev22.22.1 V8 dateparser-inl.h/dateparser.h/dateparser.cc/date.cc/LICENSE matched all five documented hashes. Full local BSD notice is byte-identical; pinnedNode22 V8version and pointer-compression/31bit-Smi override flags0/0 were checked.
- Independent final worker-receipt verification recomputed **16source/evidence hashes, all match**. Owned tracked whitespace check passed. Final privatepart differs from the independently probed ae397219 semantic source only by two brace-only style fixes, inspected directly in nested-comment and short-year blocks; current4f7ac2f3 matches receipt. No redundant fullsuite was needed for that equivalent change.

## Source and safety review

The [pinned parser](https://github.com/nodejs/node/blob/v22.22.1/deps/v8/src/date/dateparser-inl.h) supplies token dispatch/ES5 fallback; [composers](https://github.com/nodejs/node/blob/v22.22.1/deps/v8/src/date/dateparser.cc) supply date/time/offset interpretation. The adaptation preserves their branch behavior, bounded date/time components, month/AMPM/zone handling and source-specific ignored tokens. Source text is validated rather than rewritten. Financial date-only validation remains the unchanged DateOnly path; no financial primitive or policy changed.

Public/private timestamp entry limits are40UTF16 units, including bytes after embeddedNUL. Scanner loops advance over bounded input; composers hold3date/4time values. Numerals cap significant digits; unsigned32 offset masking and signed32 result bound match the pinned build. Preconstruction absolute-year bound275830 is conservative: TimeClip maxyear275760 plus fewer than70years of maximum signed32-second offset. This avoids host microsecond wrap while retaining recoverable instants; final TimeClip remains. The independent overflow matrix confirms both signs and large wrapped-offset behavior. No unbounded loop, source-triggered storage/network operation, payload log or runtimeJS dependency was introduced.

[Attribution/limits documentation](../../docs/reference/legacy-v8-timestamp-compatibility.md) records versioned primary URLs/hashes and the full [BSD notice](../../lib/accounts/legacy_v8_timestamp.LICENSE), including source/binary redistribution obligations. No supported-binary delivery is claimed by source clearance.

## Reused worker evidence and remaining gates

Actual logs/receipt inspected: **355 accounts tests passed**, including329codec tests; the compact timestamp test checks4127actual source-backed cases alongside324normal schema/history cases. Source oracle checks pass inUTC andAsiaBaghdad; targeted analysis reports no issues. Original125mismatchRED and extra2host-wrapRED logs remain failed historical evidence. These are worker checks reused by exact hashes, not a second reviewer Flutter run.

Lead still owns current fullapp/analysis/native/build/performance and delivery evidence. No missingAndroid/native/CI/signing/release check is passed here. Owner-excluded live reader verification remains excluded/notpassed. No merge, phaseDONE or broader engine release disposition follows.

## Audit/time-cost notes

Detailed action outcomes are in pairedJSON. First explicit clock11:12:26Z; completion above. Active effort, tokens and cost unknown. Toolwalls4.8seconds for1230comparisons and2.6seconds for610comparisons are separate observations, not total effort. Initial urllib hash fetch failed local certificate verification; existingcurl with defaultTLS succeeded (0.5second failedbatch/0.7second retrybatch). No TLS bypass or settings change. Initial reads preceded worker creation of the provenance doc; several guessed optional log/glob names failed harmlessly and were corrected via finalreceipt. One requested30000ms collaborationwait returned a worker handoff early; actual elapsed unknown. These failed/avoidable actions are preserved rather than passed.

Prevention candidate: a reusable bounded differential runner that captures version/hash/timezone/UTF16length/exactroundtrip and emits all failures before approval. The worker's compact regression corpus is implemented; a general runner is proposed, not authored by reviewer. Existing output-path discovery and certificate-capable CLI prevent avoidable read/hash rework. No billable savings estimated.
