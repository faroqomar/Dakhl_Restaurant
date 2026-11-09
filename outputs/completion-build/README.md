# Completion build evidence

Captured command logs are losslessly compressed as `.log.gz`. `log-archives.json` records both original-content and archive hashes; decompression reproduces exact output, including tool-emitted trailing spaces. The verification manifest preserves original log-content hashes. No test output was edited to change results.

Campaign001 retains unavailable resource measurements. Campaign002 contains the corrected producer, both pilots and seven20-sample baselines. Source/engine/tool identities and dirty fingerprints belong to each receipt; later commits do not rewrite those historical identities. Platform receipts distinguish compilation from installed/runtime acceptance; iOS remains blocked by disk space.
