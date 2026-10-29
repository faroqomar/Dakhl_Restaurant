# Update the Mac application

Date: 2026-10-27. Status: built, installed, opened and verified.

- Request: update the Mac application to the project's latest version.
- Change: packaged source 1.12.0 and installed it over 1.10.1 at `/Users/eros/Applications/Daftar.app`, including the sales redesign. The application was closed normally; the previous bundle and a private backup of its data directory were preserved outside the repository before replacement.
- Verification: all 114 source tests passed in the preceding design task. `npm run package` succeeded; the packager's `.icon` format warning was optional. Sales/model files inside `app.asar` match source. The installed bundle reports 1.12.0; it was actually opened from the installation path and displayed the new Sales screen. Comparing accounts after validation/model migration with the previous copy passed. No real movement was added/edited and no illustrative data saved.
- Limits: local macOS ARM64 update only, without publication or Git push. No sale was performed against real accounts for verification.
- Memory: sync/check ran; service healthy, no pending/failed operations, but source count zero, so document indexing was not established.
