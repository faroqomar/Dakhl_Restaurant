# Development campaign preflight

Use `scripts/phase_preflight.py` before timed native dialogs or final delivery preparation. It composes Dakhl-specific safeguards; reusable campaign sequencing and timing belong to Madar's `tool/dev_workflow`. No engine implementation is copied here. The existing runtime pin and native 45/120-second bounds remain unchanged.

## Interface

Python API:

```python
receipt = run_preflight(spec, app_root)
write_receipt(output_path, receipt)
```

`PreflightError.code` is a fixed diagnostic. CLI exit 0 means the requested preflight observations passed; exit 2 means refusal. The CLI prints only status and receipt hash, or a fixed refusal code. It does not print raw command output, account payloads, credentials or source paths. Receipts use atomic exclusive publication and refuse an existing destination.

```sh
python3 scripts/phase_preflight.py --spec /absolute/preflight.json --root /absolute/Dakhl_Restaurant --output /absolute/new-receipt.json
python3 -m unittest discover -s scripts/tests -p test_phase_preflight.py -v
```

The trusted local specification has these fields:

| Field | Contract |
| --- | --- |
| `schema` | Integer 1 |
| `platform` | `host`, `macos`, `android` or `ios`; default `host` |
| `targetId` | Concrete target ID; mobile must equal `device.id` |
| `fixtureId` | Exact SHA-256 equal to `fixture.sha256` |
| `appRevision`, `runtimeRevision` | Exact lowercase 40-character Git revisions |
| `inputs` | Explicit map of tracked relative input paths to SHA-256; include `engine-dependency.json` |
| `fixture` | `{root, path, sha256}` for one isolated synthetic payload |
| `device` | Required for Android/iOS; context and recent Device tool observation described below |
| `android` | Required for Android; existing installation-guard `Config` fields, with `execute` absent or false |
| `delivery` | Optional `{repository: "owner/repository", workflowChanges: true/false}` |

The tool reads actual Git HEAD, confirms each selected file is tracked, hashes its current bytes and checks the consumer's runtime pin. `sourceCoverage` states that the caller selected the tracked inputs; this is not proof that every build dependency was selected. The campaign wrapper must bind the returned app/runtime revisions, platform, fixture hash and device ID to the campaign identity before recording a pass.

## Isolated fixture scope

Create a dedicated descendant of the OS temporary directory or `outputs/preflight-fixtures/`. Put `.dakhl-synthetic-fixture` there with exactly `dakhl-phase-preflight-v1` followed by a newline. The payload and observation artifacts must remain beneath that marked root. Do not place real account files, invoices or backups there. The marker records explicit synthetic provenance; it cannot inspect whether the payload is semantically synthetic. Payloads are limited to 2 MiB; observation images to 16 MiB. Final symlinks, descendant symlinks, non-regular files and multiply linked files refuse. OS `/tmp` and `/var` aliases are normalized without resolving caller-controlled descendants.

## Device readiness observation

Use the current T3 Device tools: `device_list`, `device_open` with exact host/device IDs, and `device_screenshot`. Prepare the fixture picker and handoff before starting a timed case. No device launch, input, installation, settings change or SDK replacement occurs in this preflight.

`device` contains `hostId`, `id`, `sessionId`, `maxAgeSeconds` (integer 1–300), and `observation: {path, sha256}`. The hash-bound JSON observation must contain exactly:

```json
{
  "schema": 1,
  "tool": "device_open",
  "hostId": "host-id",
  "deviceId": "device-id",
  "sessionId": "session-id",
  "observedAt": "2026-11-04T12:00:00+00:00",
  "controlReady": true,
  "fixtureReady": true,
  "evidence": [{"path": "/absolute/marked-fixture/screen.png", "sha256": "64-lowercase-hex-characters"}]
}
```

An observation from the future or beyond its age bound refuses. Host, device and session must match; evidence must exist and match its hash. The receipt labels this `operator-observation` and `liveStateProven: false`. It binds the retained observation without claiming an authenticated live Device API query. A screenshot or boolean alone does not prove the complete native behavior. The campaign's real pilot supplies that behavior evidence.

## Android installation safeguard

The `android` object uses the existing `android_install_guard.Config` field names: `apk`, `sha256`, `package`, `signer_sha256`, `serial`, `avd_name`, `mode`, `fixture_id`, `source_revision`, `runtime_revision`, `fixture_only`; optional tool paths and `preservation_receipt` retain the existing guard contract. Copy the exact APK and any preservation receipt into the marked synthetic fixture root before checking. `fixture_only` must be true, source/runtime revisions must match the preflight and `serial` must match `device.id`.

The preflight calls the actual existing guard with `execute=False`; it does not accept an arbitrary saved success object as signer proof. The guard reads current target/package/signer state and retains its existing preservation checks. It may pull an APK into its own temporary directory, but it never dispatches installation in this path. The emitted guard receipt retains `source_provenance: caller-attested`; a valid signer does not prove source-to-binary correspondence. Actual later installation must call the same guard again with its full checks and explicit execution; this observation does not authorize a direct Flutter installer or bypass its revalidation.

## Delivery observations

Optional delivery checks use read-only `gh api --include user` and `gh api repos/owner/repository`. They require repository push permission; workflow-changing delivery also requires an observed `workflow` OAuth scope. Missing/unknown scope refuses the requested workflow check, including tokens that omit OAuth scope headers. The tool does not change credentials, permissions or repository rules and never tests access by pushing.

The result says `permissions-observed`, with `writePermissionProven: false`. Server-side rules, token restrictions, a later permission change or expired credentials can still reject a push. An unknown scope is a blocker requiring the appropriate authorized credential route, not proof that a token lacks all write capability.

## Verification boundary

Device-free tests cover changed/untracked source, pin mismatch, fixture scope and symlinks, stale/mismatched Device evidence, artifact tampering, Android guard refusal before install, delivery scope/permission refusal, safe error output and exclusive receipts. Existing installation-guard tests remain authoritative for its signer/retention cases. This tooling test result establishes neither mobile acceptance nor historical fixture restoration, release, merge approval or a phase-completion result.
