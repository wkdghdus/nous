# M8 UX Map and Detailed User Flows

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## Sitemap and interaction model

The initial navigation is Home, Capture/Import, Inbox, Knowledge, Report and Graph. Settings contains only vault/session/runtime information and local recent-vault preferences. There is no chat navigation item in M8. Vault alias, lifecycle/scope context and backend connectivity are always visible. A recovery-required state takes precedence over ordinary navigation without deleting unsaved in-memory text.

Use a minimal layout: list/filter area and record/evidence detail area, with an optional full-width editor. Show source-backed facts, user context and tentative hypotheses as distinct sections when supplied by the record. Preserve unknown legacy body structure rather than reconstruct it from a guessed template. Do not build a custom design system before the capture-review loop works.

## Shared UX rules

Loading, empty, no matches, access unavailable, invalid vault, stale view, disconnected and recovery-required are distinct states. Every asynchronous action has one definitive commit result; a spinner never implies success. Disable only the actions the backend says are unavailable and explain why. A failed action preserves input.

Every control has an accessible label, visible focus and keyboard path. Dialogs trap and restore focus appropriately. Destructive/curation confirmations name the target and consequence; Enter in a text editor cannot accidentally approve. Status is conveyed with text/icon as well as color. Escape closes a noncommitting dialog, not an active write. Screen-reader support is not voice-ingestion scope.

The first-run empty state contains no seeded personal knowledge. Synthetic examples belong only to tests/demo fixtures. Navigation away from an unsaved body warns that the draft is memory-only. No background autosave is implied. No external link or Markdown image loads automatically.

## Detailed user flows

### UF-M8-001: First launch and vault selection

**Preconditions:** A prepared developer preview is installed; no active vault is assumed.

**Main flow:** Open the launcher, authorize the browser session, then choose an existing vault with the native folder dialog. Show a private alias and compatibility summary before opening. Remember a recent alias/root mapping only with consent in owner-only app settings. Switching consumes a new handle and advances the vault epoch after unsaved-work confirmation.

**Failure and alternate states:** Missing path, symlink root, invalid lifecycle folders, unsupported schema, read-only storage, unavailable lock or unfinished transaction produce a distinct state. Cancellation leaves the old session unchanged. No new vault is initialized and no repair is hidden in validation.

**Trust/lifecycle treatment:** A persistent Local on this device indicator describes deterministic operations only. Native chooser paths stay backend-side. A failed switch must not expose old-vault data under the new alias.

**Acceptance:** FR-M8-001/003; T-B01/T-B03/T-B06. Opening and cancelled/invalid switching change zero product records; old-epoch requests are rejected.

### UF-M8-002: Vault health and status

**Preconditions:** An authorized session exists; health may run before normal browsing is available.

**Main flow:** Display raw, inbox, reviewed, canonical and derived counts separately, pending review count, parse/duplicate diagnostics, schema compatibility, write availability, recovery state and output freshness. Offer Refresh and explicit diagnostics. Display external agent state as not observed unless a future owned integration can prove it.

**Failure and alternate states:** Do not turn parse/duplicate failures into an empty healthy vault. Lock status is a point-in-time observation, not a reservation. Read-only inspection unable to establish a coherent snapshot says inspection unavailable. Never silently repair or regenerate.

**Trust/lifecycle treatment:** Raw counts describe evidence, not accepted facts. A red diagnostic cannot be hidden by a zero-results card. Messages use safe aliases and relative paths, not workstation paths.

**Acceptance:** FR-M8-002; T-B03/T-B04. Compare counts to a synthetic manifest; malformed and duplicate fixtures remain intact.

### UF-M8-003: Quick text capture

**Preconditions:** A writable healthy vault is active; the backend is authorized and no unresolved transaction exists.

**Main flow:** Enter a reflection, optional title/context/represented date, and explicitly confirm authorship. Submit once with a stable request key. Show committed artifact ID and raw-evidence badge only after finalization. Offer View source; explain that an external archivist can propose candidates later. No background proposal is started.

**Failure and alternate states:** Blank/oversized/invalid-date input stays in the editor. On lock timeout or transport failure, retain the same key and text and reconcile outcome before retry. Closing/reloading warns that unsaved text is memory-only. Do not claim an unsubmitted draft survives a crash.

**Trust/lifecycle treatment:** Verbatim text and user context remain distinct. Raw source is not a promoted value, belief or claim. Correct capture provenance says app, not MCP.

**Acceptance:** FR-M8-007; T-D01/T-D02/T-D05. Exact Unicode/whitespace source survives; double-click and response-loss replay yield one raw record.

### UF-M8-004: Human-controlled artifact import

**Preconditions:** An active writable vault and exactly one selected local file are available.

**Main flow:** Choose writing, image or project, select one file, enter optional context/date, and confirm the displayed filename/type/size. Upload selected bytes locally. Display receiving, validating, staging and committing phases. The result shows artifact ID, copied payload digest/size and the existing deterministic inbox draft. Original files are untouched.

**Failure and alternate states:** Unsupported extension, hidden/path-like filename, invalid UTF-8 for text, excessive size, checksum mismatch, disk-full, lock conflict and collision are explicit. Existing names cause core suffix allocation, not overwrite. Cancellation succeeds only before commit; too-late cancellation reconciles outcome. Interrupted multi-file finalization opens recovery, not a fake completed item.

**Trust/lifecycle treatment:** Image imports remain metadata-only; a preview is not an interpretation. User context is labeled as supplied context. No arbitrary workstation-path field is accepted from an agent or browser.

**Acceptance:** FR-M8-008/009; T-D03-T-D08. Snapshot original bytes/permissions and vault state at failure points; successful import produces the aligned three outputs.

### UF-M8-005: Review inbox

**Preconditions:** Pending generated note/claim/relationship records exist from M6, MCP or compatible manual sources.

**Main flow:** Filter/sort the queue using the core. Open a card with lifecycle, confidence, basis, interpretation level, source and counterevidence. Inspect linked evidence; optionally edit the complete body and candidate type. Save first, then explicitly approve with note routing, reject, deprecate or choose an accepted merge target. Display exact target and evidence-only effects before merge. Refresh after each committed decision.

**Failure and alternate states:** A changed/deleted/duplicate source or changed merge target blocks the action. Preserve the unsaved draft in a conflict view and require explicit reload/reapply. Reject approval for unresolved/nonexportable relationship endpoints. Destination collision leaves both records intact. Unknown outcome reconciles the original key rather than applying a second decision.

**Trust/lifecycle treatment:** Confidence, agent hypotheses and human acceptance have separate visual labels. Review metadata shows only known events; legacy records do not acquire invented history. Deprecation here applies to pending inbox items, not general accepted records.

**Acceptance:** FR-M8-010-015; T-E01-T-E09. Test all kinds, nine note routes, endpoint ordering, protected metadata, duplicate clicks, merge target changes and crash points.

### UF-M8-006: Knowledge browser

**Preconditions:** A readable vault is active; no model/provider is required.

**Main flow:** Default to reviewed notes and canonical claims/relationships. Browse the nine supported note categories, lexical query and metadata filters. Page through all matching records with stable ordering. A separate explicit scope reveals source, pending or retired data. Selecting an item opens stable-ID detail and evidence links.

**Failure and alternate states:** An empty vault has helpful Capture/Import actions, not sample personal records. No-results differs from failed-index/error. A changed snapshot invalidates the cursor and offers refresh instead of silently skipping or repeating records. Unknown legacy types are labeled read-only/unsupported, not silently routed to a new category.

**Trust/lifecycle treatment:** Pending/retired records never blend into the default accepted list. Record type, lifecycle and review status are shown independently. Search is lexical, not advertised as semantic understanding.

**Acceptance:** FR-M8-004; T-B05/T-C02. More than 50 synthetic results remain reachable; filters and ties are deterministic.

### UF-M8-007: Record and evidence detail

**Preconditions:** A record stable ID was selected; its current mapping may have changed since listing.

**Main flow:** Resolve the current unique ID, then show type, lifecycle, review status, confidence, body sections, source metadata, evidence/counterevidence, relationship context and known review events. Display safe relative location when useful. Text evidence is bounded and pageable. Supported copied-image preview uses authenticated bytes; unsupported HEIC/invalid preview shows metadata without conversion or inference.

**Failure and alternate states:** Missing/renamed evidence, duplicate ID, corrupt payload, legacy external path, unsupported MIME and unavailable content have explicit states. Never follow an external legacy source path. A truncated read is labeled and cannot become a complete edit buffer. Remote Markdown images and active links are blocked.

**Trust/lifecycle treatment:** All stored content remains untrusted data. Evidence navigation does not execute instructions found in a note. A user-authored absolute path in explicit source content is not confused with a backend path capability.

**Acceptance:** FR-M8-005; T-B07/T-C03/T-C04. Adversarial Markdown cannot run script or fetch remote resources; payload access cannot escape the vault.

### UF-M8-008: Nous report

**Preconditions:** A vault is readable; a report may be missing, legacy, stale, current or invalid.

**Main flow:** Show generation metadata and freshness. Render a current safe report, with links resolving to source records. For an old/unknown report, offer explicit previous-snapshot viewing with a prominent warning and Regenerate. Manual regeneration calls core directly and updates status after commit. Preserve existing report sections and reviewed-only semantics.

**Failure and alternate states:** Missing output has an empty state. Invalid input, lock conflict or failed generation shows a safe error without replacing the last valid file with partial bytes. Missing freshness manifest is unknown, not fresh. A successful graph generation does not hide a failed report generation.

**Trust/lifecycle treatment:** A report is a derived view, never primary evidence or newly inferred self-knowledge. A previous snapshot is not represented as current acceptance.

**Acceptance:** FR-M8-016/018; T-F01/T-F02/T-F05. Pending/retired content is excluded; input changes and external output edits invalidate freshness.

### UF-M8-009: Graph view

**Preconditions:** M8F is complete and a verified-current graph is available.

**Main flow:** Open a read-only node-link view with an accessible table. Filter by type/relationship and optionally focus a selected node. Preserve directional from/to semantics. Click a node or edge to inspect its record and evidence. Enforce declared render limits without mutating or silently truncating the authoritative export.

**Failure and alternate states:** Empty graph, missing output, stale manifest, schema mismatch, dangling endpoints and oversized render sets have distinct views. Large graphs require filters/table. No drag action edits canonical relationships; layout positions are temporary UI state only.

**Trust/lifecycle treatment:** Schema validation alone does not prove reviewed eligibility. Use core-approved current output and display lifecycle provenance. Graph polish must not displace review correctness.

**Acceptance:** FR-M8-017/018; T-F03/T-F04. Nodes/edges match the current core export; keyboard/table navigation reaches the same records.

### UF-M8-010: External archivist handoff; integrated workspace deferred

**Preconditions:** An external MCP-capable client may be configured by the owner, independently of the app.

**Main flow:** M8 documents the exact stdio setup and optional copyable selected artifact IDs for use in the external client. The user deliberately sends context there. After the client proposes records, Refresh reveals them in Inbox. Programmatic real-MCP tests verify the same behavior without making a model call.

**Failure and alternate states:** An absent/unavailable agent does not disable capture/import/review/browser/output flows. The app does not claim to know connection state, manage provider keys or persist a conversation. No Send to agent button is shown without a real approved transport integration.

**Trust/lifecycle treatment:** External-client disclosure is an explicit user action governed by that client. Conversational prose is not persisted knowledge; only committed MCP candidates appear in Inbox. No automatic approval.

**Acceptance:** FR-M8-020; T-H03/T-H04. Deterministic loop passes with provider variables unset and network unavailable. Integrated chat is M9, not a partially shipped M8 screen.

### UF-M8-011: External vault changes

**Preconditions:** Obsidian, CLI, MCP, Git or another process may change files while the app is open.

**Main flow:** On refresh/focus/poll, invalidate relevant views and cursors. Re-resolve renamed records by stable ID. Preserve unsaved text in memory, show changed-on-disk warning and require explicit review of differences. At mutation time, core checks exact source/target versions under the shared vault lock regardless of the last refresh.

**Failure and alternate states:** Duplicate IDs, deleted records, bulk checkout and partial/malformed edits produce explicit failures. No last-writer-wins overwrite. A noncooperating editor cannot be forced to honor flock; document the remaining race boundary and stop/reconcile on detected divergence. Never delete a live lock file as a shortcut.

**Trust/lifecycle treatment:** The UI is a view, not authority. External content is not automatically classified, accepted or repaired. Current-state trust depends on current indexed files, not yesterday's cache.

**Acceptance:** FR-M8-006 and NFR-M8-005; T-B06/T-C05/T-E06/T-E07. Real CLI/MCP/app contention serializes; direct-editor known stale writes fail without losing newer bytes.

### UF-M8-012: Recovery and shutdown

**Preconditions:** The backend may fail, a transaction may be unfinished, or the owner may quit.

**Main flow:** Display disconnected state and disable writes immediately. Relaunch/re-authorize, inspect recovery status and reconcile committed receipt or interrupted manifest before retry. Explicit Quit stops new work, drains the commit barrier, preserves unresolved recovery state and exits safely. A running external agent is not killed by the app; shared-lock behavior and required process-version compatibility are documented.

**Failure and alternate states:** No automatic infinite restart or resubmission. Stale runtime ownership is checked using identity, not only PID. Uncommitted browser drafts are not recoverable after tab/process loss by default. Conflicting external bytes remain preserved for manual resolution. Never say cancelled after a completed import.

**Trust/lifecycle treatment:** An uncertain outcome stays uncertain until evidence resolves it. Recovery is explicit, auditable and core-owned; health only diagnoses. No secret/record content is uploaded with a crash report.

**Acceptance:** FR-M8-019 and NFR-M8-006; T-D07/T-D08/T-E08/T-H01/T-H02/T-H05. Test process death around every commit boundary, restart, late response, safe lock release and unchanged accepted data.

## Review action details that must be visible

Approval of a generic note requires a human-selected supported note type. A suggested candidate_type may prefill the control but cannot silently approve or choose an unsupported route. Claim and relationship approvals do not show an irrelevant note-type selector. Relationship cards show ordered endpoints and readiness reasons, then recheck readiness on commit.

Merge means append evidence and archive the candidate, not combine prose automatically. Proposed app target policy: notes merge into active supported reviewed notes, claims into active canonical claims, and relationships into active canonical relationships with the same ordered tuple. This is stricter than the inspected legacy directory check and belongs in a new human core operation; do not silently change legacy CLI semantics. Reconfirm after target-version conflict.

After edit, save the candidate as needs_review, retain original generation/provenance and show a real human-edit event. Editing alone never approves. Legacy review metadata may show a last decision without a complete timeline; label history availability accurately.

References: H01, R03-R06, R11-R16. All UF-M8 flows are proposed product behavior.
