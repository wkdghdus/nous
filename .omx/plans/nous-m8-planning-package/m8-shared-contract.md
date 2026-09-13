# M8 Shared Contract

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## 1. Authority and vocabulary

This is a proposed cross-stage contract. The inherited rules identified below are binding now; new interfaces/metadata become binding only after product-owner approval. No stage may relax a rule to make tests pass. The source register distinguishes inspected code from design proposals. Complete source review and M7F verification remain entry gates.

**SC-01 | Binding inherited contract: vault authority.** Markdown/YAML records and preserved payloads remain authoritative. The app can be removed without losing usable evidence, accepted knowledge or provenance. UI caches, cursors, health results and generated graphs are disposable. A transaction recovery manifest is temporary correctness state, not a second model of accepted knowledge.

**SC-02 | Binding inherited contract: core authority.** Core owns IDs, record discovery, eligibility, parsing/rendering, review routes, references, confinement, locks, collision allocation, write finalization and replay. The app adapter owns HTTP/session/OS-picker concerns and maps structured inputs to core operations. The frontend owns presentation, temporary draft text and interaction. No frontend filesystem writes, CLI subprocess business wrappers, domain validation copies or arbitrary output-path fields.

**SC-03 | Binding inherited contract: agent boundary.** The exact eight M7 tools and `2025-11-25` handshake remain unchanged. An external agent can write only raw evidence or inbox proposals. Human actions use a separate application adapter directly over core. The app never delegates approve/merge/reject/deprecate to an LLM or adds a hidden MCP review tool.

**SC-04 | Binding inherited contract: trust.** Directory and frontmatter determine lifecycle together. Candidate confidence does not establish truth. Raw evidence is not necessarily an accepted current belief. Default knowledge retrieval is reviewed/canonical; explicit source, candidate and retired views stay labeled. Report/graph retain current reviewed-only eligibility and independent endpoint validation.

## 2. Proposed application boundary

**SC-05 | Proposed M8 decision: local-only transport.** Serve static UI and private API from one Ruby-owned origin bound explicitly to `127.0.0.1` and an assigned port. IPv6 is not enabled implicitly; any later `::1` support needs matching tests. Never bind `0.0.0.0`, `::` or a LAN interface. M7 MCP remains stdio, not HTTP.

All private routes require a fresh per-launch capability. Validate exact Host, request framing, content type, size and allowed methods. Mutations require exact same Origin and bearer authorization. For GETs, absent Origin is permitted only with authorization and the expected Host; supplied foreign/null Origin or cross-site Fetch Metadata is rejected. No wildcard CORS, JSONP, arbitrary proxying or credential-bearing query strings.

The public static shell contains no vault path, record, token, user setting or health data. A launcher-issued, one-use bootstrap nonce is carried in the URL fragment, exchanged locally, immediately removed from history and never logged. The resulting bearer token remains in memory. Refresh/reopen reauthorization uses the launcher, not an unauthenticated token endpoint. Test fragment/history/referrer behavior; do not claim the OS/browser cannot retain any local launch trace. The threat model excludes a malicious same-user process or privileged extension already able to read the vault.

**SC-06 | Proposed M8 decision: session identity.** Every content request carries an opaque session ID and vault epoch. One backend has one active vault. Switch is refused while a write or unreconciled transaction is active. On successful switch, invalidate cursors, in-memory bodies, edit buffers, preview URLs and selection capabilities across tabs. A late response from the previous epoch cannot update the UI; a late mutation is rejected before acquiring its target operation context.

**SC-07 | Proposed M8 decision: choosing paths.** Native vault selection is a trusted adapter action producing a short-lived opaque selection handle. The resolved directory stays in the backend. A fixed OS picker helper may launch as an adapter concern, with argument arrays and no interpolated user script. It must not execute Ruby business CLIs. Browser file import transmits selected bytes and an untrusted basename, not `C:\fakepath` or a client-provided absolute path. The core validates the selected vault and every internal destination after resolution. Inherited symlink-root/component rejection stays intact.

## 3. Data, mutation and retry rules

**SC-08 | Proposed M8 decision: full edit data.** Never initialize a save editor from M7's abbreviated record response. A human edit envelope contains complete body text, protected metadata, editability reason, stable ID and a hash of exact stored record bytes. A body over the supported edit limit is read-only with a truthful explanation; it cannot be truncated and saved. Human editing is limited to pending candidate body and proposed note type. IDs, raw source, original generation, evidence references, review status and relationship tuple are protected in M8.

**SC-09 | Binding inherited + proposed extension: serialization.** All cooperating interfaces use the same vault lock. Coherent reads use shared access; writes and build-plus-replace use exclusive access with a bounded timeout. Do not hold a lock while awaiting user input, network upload or a model. Avoid nested public lock acquisition. The app has one mutation worker per active vault; validate the server's thread behavior and actual OS lock semantics.

New app preconditions are checked inside the exclusive transaction context: current unique source ID, source bytes/hash, target bytes/hash when merging, pending status, current schema, endpoint readiness and destination availability. A failure changes no product record. The UI shows success only after core commit finalization, never merely on button click or upload completion.

**SC-10 | Proposed M8 decision: retries.** Every app mutation has `(app-v1, request_id)` and an operation/input digest. A timeout or disconnected tab is not proof of failure. Retry only the identical request/key, or query outcome. Same key with different normalized input fails. Committed results are replayed using current stable-ID locations. Do not create a fresh key automatically to bypass a conflict. A deliberate new user action gets a new key. The existing MCP generation namespace, normalization and replay contract remain untouched.

**SC-11 | Proposed M8 decision: recovery.** Implement the narrow receipt/journal rules in `m8-core-gap-register.md` before enabling affected writes. All participating updated core read/write entrypoints fail closed on unfinished multi-file app transactions, except health and explicit recovery inspection/actions. Display an interrupted-operation banner rather than partial accepted knowledge. An old already-running CLI/MCP process may lack these guards: supported concurrent use requires adapters from the same release, and the launcher/setup documentation must require restarting older processes before enabling app writes.

Recovery only modifies bytes proven to belong to the interrupted operation. External divergence requires human resolution and preserves copies. Never remove `.nous.lock` to break a lock: ownership is OS-backed, and deleting a live lock pathname can split coordination. Do not recursively delete staging-looking files without verified manifest ownership.

**SC-12 | Honest limitation: external editors.** Obsidian, Git and generic editors do not necessarily honor Nous locks. Full hashes, re-indexing and final precondition checks reject detected stale writes, but no portable advisory-lock design guarantees exclusion of every noncooperating writer in the last instruction window. The preview supports conflict detection and recovery, not a claim of perfect serializability with arbitrary direct file writes. Pause Git checkout/bulk editing during mutation; invalidate views and stop on divergence. Do not weaken supported CLI/MCP/app concurrency guarantees by citing this limitation.

## 4. Preservation and provenance

**SC-13 | Binding inherited contract: originals and imports.** Original selected files remain unchanged. Import copies preserve bytes, digest and original basename; they never become references to ephemeral upload spool names. The app shares M6 allowlists, conservative extraction and three-output collision behavior. Its size limits are additional app input bounds, not silent changes to legacy CLI allowlists.

**SC-14 | Proposed M8 decision: optional metadata.** Add only the approved optional app receipt/history fields and `capture_channel: app`; retain schema version compatibility and old M7 fields. No vault-wide rewrite. Preserve unknown optional frontmatter when editing supported candidates; do not drop metadata by rebuilding from a UI whitelist. Editing the candidate body must not allow frontmatter injection. Record only audit events actually observed after adoption.

**SC-15 | Proposed M8 decision: human merge.** The app's merge is the inherited evidence-append operation, not prose synthesis or target-body replacement. A core human operation validates an active reviewed/canonical target, checks both versions, shows target and source effects and archives the candidate. Do not silently claim reviewed-record deprecation or general editing: current operations require a pending inbox source. General curation of accepted records is deferred.

## 5. Privacy and rendering

**SC-16 | Binding inherited contract: local privacy.** No analytics, telemetry, model SDK, crash uploads or deterministic outbound content requests. Dependency installation is a distinct developer action and may need the network; using the prepared deterministic app does not. Provider credentials remain with external clients. No personal data in fixtures or recorded test media.

**SC-17 | Proposed M8 decision: storage.** Record bodies, user search text, drafts and source previews exist only in frontend memory by default. No localStorage, sessionStorage, IndexedDB, service worker, browser application cache or third-party crash capture of personal content. Sensitive responses use `Cache-Control: no-store`. Static hashed assets may be cached because they contain no personal data. Closing/reloading a tab can lose unsaved text; warn clearly. Do not invent autosave or claim crash recovery of a never-submitted draft.

Recent-vault aliases and actual directories may be stored only in owner-only application settings outside the repository/vault, after consent. Transient launcher rendezvous information uses private local runtime storage, validates process identity and expires; it contains no record bodies. Clearing recent settings never deletes a vault.

**SC-18 | Proposed M8 decision: safe display.** Render Markdown with raw HTML disabled and an allowlisted sanitizer. Block scripts, iframes, active embeds, SVG/HTML payloads, executable URL schemes and automatic external images. Internal links resolve through stable-ID/core reference mapping. External navigation requires an explicit user action and safe scheme; set no opener/referrer. Evidence payloads use authenticated core-owned reads, byte/MIME bounds and `nosniff`; they are not exposed through a static vault mount.

**SC-19 | Binding inherited + clarification: redaction.** Normal logs contain random correlation IDs, operation names, durations and sanitized codes, not bodies, titles, semantic IDs, query text, paths or secrets. Structured legacy external source paths are redacted and never followed. Verbatim user-authored content may itself contain a path; do not alter that explicitly requested evidence under a blanket string scrubber. Test path redaction in metadata/errors separately from exact source preservation.

## 6. Refresh, derived outputs and compatibility

**SC-20 | Proposed M8 decision: invalidation only.** Begin with explicit refresh, focus refresh and bounded polling while a tab is visible. A proposed five-second poll rechecks known record directories; measure its cost in preflight. No autonomous interpretation, folder ingestion or model call. Bulk changes reset cursors and preserve unsaved text in a conflict panel. Authoritative validation occurs again on action, regardless of polling freshness.

**SC-21 | Proposed M8 decision: output freshness.** Generation is manual and each output commits atomically. A separate derived manifest records source-input fingerprint, generator identity, output digest and timestamp without changing the existing graph schema or report bytes. Missing/inconsistent metadata means unknown or stale. Health never regenerates. Graph defaults do not render unverified/stale active knowledge. The report can expose an explicitly labeled previous snapshot, separate from current accepted views.

**SC-22 | Binding inherited contract: compatibility.** Preserve current CLI commands/options/output bytes for unchanged inputs and fixed clocks, M7 exact schemas/limits and Obsidian-readable files. Newly added optional metadata and recovery-required errors must be documented as intentional extensions, not hidden test exceptions. A default root package prohibition may be replaced only by an approved, scoped frontend-manifest policy; placing a nested package to evade the old check is not adoption.

## 7. Verification and stop rules

Every stage runs its focused tests, affected legacy tests and the full available regression both before and after changed-files-only cleanup. Tests use synthetic temporary vaults and fixed clocks. Real core and real server processes must appear in integration tests. Mocks are acceptable for isolated UI tests, not the only release evidence.

Stop on unexplained baseline failure, missing authority, active overlapping Gajae work, privacy leakage, ambiguous duplicate IDs, unsupported source migration, unproved runtime dependency, unsafe path, weakened tests or required scope beyond the selected stage. A report of skipped checks is mandatory. An implementation agent cannot approve its own acceptance waiver or merge to main without permission.

Sources: H01 and R01/R04-R27. New mechanisms and limits are proposals for M8 approval.
