# Historical Phase 02 performance — readable companion

This index presents the existing **18 cases / 360 samples** at **app 5a11 / runtime a6 / tool 63**. It is a historical descriptive baseline, not performance evidence for the new candidate, a before/after optimization result, a reliability claim or mobile measurement. New app library/engine/tool revisions need their own applicable verification; these samples are not relabelled.

Values below are rounded for display; the linked immutable JSON retains exact values and source metadata. Each case has 20 samples. Elapsed samples end at the actual requested raster completion; the broader host RAM/CPU window includes inter-iteration fixture reset, teardown and rendering setup. CPU is normalized to one logical core, so a peak above 100 percent can represent multiple-core activity. Resource values are not per-sample isolated.

| Profile | Operation | Samples | Median ms | p95 ms | Peak RSS MB | CPU average % | CPU peak % | Exact source |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| largest | accounts.migrate_legacy | 20 | 3188.01 | 3242.81 | 739.459 | 99.537 | 217.977 | JSON |
| largest | accounts.open | 20 | 1656.21 | 1657.36 | 717.128 | 101.189 | 187.621 | JSON |
| largest | accounts.recover_previous | 20 | 7273.33 | 7339.7 | 843.842 | 103.481 | 212.208 | JSON |
| largest | accounts.replace | 20 | 5723.1 | 5750.24 | 818.332 | 103.241 | 208.863 | JSON |
| largest | accounts.save | 20 | 3748.99 | 3814.72 | 716.112 | 102.458 | 190.237 | JSON |
| largest | workspace.save_restore | 20 | 1306.54 | 1319.04 | 741.409 | 102.274 | 192.169 | JSON |
| medium | accounts.migrate_legacy | 20 | 73.466 | 75.338 | 190.956 | 48.8979 | 178.812 | JSON |
| medium | accounts.open | 20 | 40.1415 | 48.38 | 174.424 | 66.4986 | 160.055 | JSON |
| medium | accounts.recover_previous | 20 | 115.047 | 123.083 | 193.954 | 105.026 | 182.13 | JSON |
| medium | accounts.replace | 20 | 81.955 | 88.684 | 192.643 | 86.3493 | 174.413 | JSON |
| medium | accounts.save | 20 | 56.8925 | 63.161 | 191.922 | 73.9199 | 165.3 | JSON |
| medium | workspace.save_restore | 20 | 27.7515 | 33.533 | 190.824 | 60.0632 | 179.005 | JSON |
| small | accounts.migrate_legacy | 20 | 31.295 | 32.733 | 173.015 | 25.0058 | 131.276 | JSON |
| small | accounts.open | 20 | 15.23 | 17.074 | 158.417 | 26.1156 | 106.275 | JSON |
| small | accounts.recover_previous | 20 | 23.686 | 25.456 | 174.67 | 29.2038 | 110.589 | JSON |
| small | accounts.replace | 20 | 15.307 | 16.999 | 176.488 | 24.4163 | 105.913 | JSON |
| small | accounts.save | 20 | 7.6515 | 16.045 | 172.098 | 20.6427 | 106.297 | JSON |
| small | workspace.save_restore | 20 | 7.002 | 9.112 | 167.936 | 19.2905 | 106.438 | JSON |

## Evidence availability

The original JSON, original performance summary and independent review are frozen proof artifacts; this companion does not rewrite them for spacing or local-path portability. Referenced raw fixture manifests, diagnostic/audit JSON companions and full logs are not necessarily included in the publication checkout. A recorded path or hash alone does not make a missing artifact accessible or independently reproduce its contents. The publication evidence index records these availability limits. Synthetic source/code proofs may be exported separately after validation; private payloads, keys and VM URLs must not be published.
