# Penpot editor response-text diagnosis

Recorded UTC: 2026-11-08T03:06:22.662418+00:00. App-owned local design-tooling diagnosis; engine implementation/API N/A. Runtime app code, engine pins, service configuration and saved design data remain unchanged.

The source review found resolve_file expects a decoded map and native Response.text feeds the text decoder. Empty file-ID logging alone does not prove a bad route or empty whole response. The served shared.js is20438277bytes, SHA485a1bbcaddc24cf4aac1ada95d51a82371d2d2fc8a554e759bd4a252447c0ac. The frontend access log recorded HTTP200/upstream200 and139684482compressed bodybytes at02:50:46UTC; backend restartcount0.

Root inspected one natural load: encoded139314223bytes, decoded539321811bytes, HTTP200, editorabsent. ResourceTiming reported normalized application/json, but a cache-only header read returned actual application/transit+json and gzip. Root cancelled that unread body; no network fallback, clone or parse.

Root then installed a self-restoring observer around Response.prototype.text on the dashboard and double-clicked the actual file tile. During that normal editor load, the native text promise fulfilled a string with UTF16length0, despite HTTP200 and correct Transit header. The observer returned the same value and added no body read. Root restored the descriptor and closed its own tab; preview status confirms no tab. Runtime: T3Nightly0.1.8-nightly.20261107.4327, Electron44.10.1, Chrome152.0.7977.169.

This proves the empty text fulfillment occurs before Penpot's Transit decoder. A string-size limit remains a hypothesis: the reference Electron44.5.1 reports MAX_STRING_LENGTH536870888codeunits, but539321811UTF8bytes do not establish UTF16 length, and the exact T3runtime constant was not queried. No large string allocation or second body parse was performed. File loss/corruption and a route defect remain unproven.

Next: read-only investigation of supported lossless load-size mechanisms and their migration/approval risks. No service restart, source patch, board deletion, new design file or data migration has occurred. C3 native import remains stopped at zero mutations. Evidence: outputs/penpot/completion/c3-positive-native-qualification/root-response-metadata.json and root-native-text-observation.json. Source/approved designs and canonical exports remain preserved.

Audit: root initially printed a full preview_snapshot with duplicated diagnostics; later reads select structured metadata only. Persistent timer remains in coordination; this is not measured active effort. Storage closeout follows in the phase journal.


## Safari read-only pilot and pointer limits (2026-11-08T03:29:07.728183+00:00)

The installed Penpot pointer feature groups complete pages/components; the frontend resolves page pointers eagerly. The giant canonical page could remain one giant fragment, and feature activation can persist file/team metadata. Root did not enable flags or repartition data. Source hashes and references remain in safari-readonly-pilot.json.

Installed Safari27.2 and JavaScriptCore share build22625.2.8.11.9. Penpot's official [browser guidance](https://help.penpot.app/user-guide/first-steps/cloud-selfhost/) supports WebKit; upstream [JSString source](https://github.com/WebKit/WebKit/blob/main/Source/JavaScriptCore/runtime/JSString.h) defines a larger bound. This justified one nondestructive client pilot, not an exact installed-limit or memory guarantee.

Initial CUA getApp timed out10005 but inventory showed the launch completed; one changed-state read succeeded. Root opened its own new canonical-file tab, observed the local sign-in form and closed that tab. No authentication, design edits, imports, exports or service changes occurred. Existing private local credential metadata exists; values were not read or logged. The authenticated Safari file load remains unverified, not a successful remedy. Root will continue independent implementation/review while this access path remains unresolved.
