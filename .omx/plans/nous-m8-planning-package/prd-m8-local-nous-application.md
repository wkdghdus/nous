# PRD: M8 Local Nous Application

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## 1. Product objective

Turn the existing file-first Nous pipeline into a daily-use local application. After one-time developer setup, the owner can open a launcher, choose an existing vault, capture or import evidence, review candidates, browse accepted self-knowledge and regenerate its report/graph without memorizing Ruby commands or manually editing vault files.

The product is the trusted archive and review loop, not a chatbot or a visual graph. The app must work without an external agent. Agent assistance remains outside Nous and may supply candidates through the unchanged M7 MCP interface.

## 2. Release definition

**Proposed M8 decision:** a macOS Apple Silicon local-browser developer preview, with a static React/TypeScript interface built with Vite and a Ruby loopback app adapter. A prepared developer environment is required initially. A launcher is required; a self-contained signed desktop installer is not promised. The preview must be usable with Obsidian closed.

The architecture is provisional until M8A preflight passes and the owner approves it. M7F completion is a hard implementation-entry gate, not a feature to hide inside frontend work.

## 3. Actors and primary loop

The vault owner and human reviewer are the same person. The external archivist is a separate actor with candidate-only write authority. The app does not acquire approval authority on behalf of that agent.

```text
Open launcher -> select/validate vault -> capture/import source
             -> optional external-agent proposal
             -> inspect inbox evidence -> edit/approve/merge/reject
             -> browse accepted records -> refresh report/graph
```

Direct text capture stores raw evidence only. Existing M6 artifact import also creates its deterministic inbox draft; the UI must disclose that draft rather than call it an LLM interpretation. Both paths leave acceptance to human review.

## 4. Required capability scope

- **FR-M8-001** (M8B): Open an existing valid vault through a human-selected capability; never initialize or repair during open/health.
- **FR-M8-002** (M8B): Expose health, schema compatibility, counts, warnings, write availability and recovery state without private paths.
- **FR-M8-003** (M8B): Support one active vault with explicit switching, epoch isolation and optional private recent-vault settings.
- **FR-M8-004** (M8C): Browse all matching reviewed/canonical knowledge through deterministic bounded pagination and filters.
- **FR-M8-005** (M8C): Provide ID-based record/evidence detail with lifecycle, confidence, source metadata and safe local previews.
- **FR-M8-006** (M8C): Refresh external changes; distinguish missing, renamed, malformed and duplicate records without selecting a first match.
- **FR-M8-007** (M8D): Capture confirmed verbatim text as raw evidence with correct app provenance and retry-safe identity.
- **FR-M8-008** (M8D): Import one human-selected allowlisted writing/image/project file, preserving original bytes and M6 draft semantics.
- **FR-M8-009** (M8D): Expose import progress, cancellation boundaries, collision results, checksums and safe uncertain-outcome recovery.
- **FR-M8-010** (M8E): Display pending notes/claims/relationships with filters, evidence and accurate decision metadata.
- **FR-M8-011** (M8E): Save a complete candidate body and candidate type with conditional version checks and no raw/frontmatter editor.
- **FR-M8-012** (M8E): Approve notes with explicit type routing and approve claims/relationships only through human actions.
- **FR-M8-013** (M8E): Reject/deprecate pending inbox items and merge their evidence into a validated accepted target with explicit confirmation.
- **FR-M8-014** (M8E): Block relationship approval until both ordered endpoints are unique active exportable nodes.
- **FR-M8-015** (M8E): Record app review/edit audit events without inventing historical events for legacy records.
- **FR-M8-016** (M8F): View and manually regenerate the existing reviewed-only Nous report with source navigation and freshness state.
- **FR-M8-017** (M8F): Provide a bounded read-only graph and accessible table, preserving the current export schema and edge direction.
- **FR-M8-018** (M8F): Use authoritative input/output fingerprints for derived freshness; missing metadata is unknown, not fresh.
- **FR-M8-019** (M8H): Start/reopen/quit the prepared local app without routine Ruby commands and recover backend failure honestly.
- **FR-M8-020** (M8H): Accept candidates from an external MCP client and expose the entire human review loop without embedding a provider.

## 5. Non-functional requirements

- **NFR-M8-001** (M8A): Preserve file authority, dependency-free core, CLI compatibility and exact MCP schemas/protocol.
- **NFR-M8-002** (M8B): Authenticate private APIs, bind only loopback, validate host/origin and prevent cross-site mutations.
- **NFR-M8-003** (M8B): No deterministic outbound data transfer, telemetry, secret leakage, sensitive browser persistence or raw HTML execution.
- **NFR-M8-004** (M8D): Share locks and no-overwrite finalization; persist app operation recovery/receipts before exposing writes.
- **NFR-M8-005** (M8E): Reject known stale source/target edits under the write lock, preserving newer content and retry identity.
- **NFR-M8-006** (M8H): Document and test handled failure, process death and unresolved external-conflict recovery boundaries.
- **NFR-M8-007** (M8H): Retain M2-M7 regressions and use synthetic temporary vaults for all automated and recorded manual tests.
- **NFR-M8-008** (M8H): Provide keyboard-complete core flows, usable focus/error states and measured bounded performance.
- **NFR-M8-009** (M8A): Pin and verify the build/runtime dependency set; do not assert an untested installer/platform.
- **NFR-M8-010** (M8C): Separate evidence, hypotheses, candidate status, human approval and confidence in every content view.

## 6. Explicit non-goals

No cloud sync, public/LAN deployment, accounts, multiple users, friend portal, mobile app, voice/audio/dictation/transcripts, OCR/EXIF/facial or image interpretation, background autonomous ingestion, semantic/vector search, authoritative database, agent approval, remote MCP transport, browser extension, batch import or provider credentials in Nous. No direct raw-payload or generated-output editor. No general reviewed-record editor. No graph editing independent of Markdown. No desktop-framework adoption or installer promise before a separate packaging proof.

**Deferred future scope:** M9 may evaluate integrated archivist chat, conversation persistence and provider credentials. M8 does not implement a fake chat panel, stub provider API or hidden launch-agent backend. External MCP documentation and cross-interface tests are in M8H, not integrated chat.

## 7. Trust and lifecycle presentation

Source evidence, agent candidate, human reviewed, canonical, derived and retired are different states. A confidence number never substitutes for approval. `needs_review` on a raw capture does not place it in the generated-note approval queue. Reviewed/canonical views exclude pending and retired records by default. Explicit source/inbox/retired screens have persistent scope labels.

Nine existing approval types are supported: memory, value, belief, project, pattern, decision, person, question and contradiction. Do not add identity approval because a broader schema lists identity. Claims and relationships use their existing canonical routes.

## 8. Success criteria and release evidence

Success requires an observed human-operated end-to-end scenario on a synthetic vault, not only component snapshots. It must include absent-agent use, real MCP-produced candidates, source preservation, conditional edits, endpoint ordering, CLI/MCP state agreement, restart, crash/retry and privacy checks. All requirements must map to tests in the final acceptance matrix.

Initial performance budgets are proposals to measure, not current facts: on the recorded target Mac, interactive feedback appears within 150 ms; status/list/detail p95 is at most 1 second for a 1,000-record synthetic vault and 3 seconds for 10,000 records; installed cold launch to selectable vault is at most 5 seconds excluding the OS chooser. Record dataset size, storage, hardware and warm/cold conditions. Imports above normal interactive duration show truthful phases, not a fabricated percentage. Graph rendering is bounded to 500 nodes and 1,000 edges; larger exports use filters/table rather than silently truncating accepted data.

## 9. Authority and approval

All novel runtime, transport, optional metadata, recovery and packaging choices are **Proposed M8 decisions**. Approving this PRD does not automatically authorize all stages or a default-branch merge. Start one stage only after its entry gate and explicit execution authorization. No plan can waive an inherited M7 test to obtain a green result.

## 10. Related artifacts

Read `m8-verified-state.md`, `m8-shared-contract.md`, `m8-architecture-decision.md`, `m8-app-adapter-contract.md`, `m8-ux-and-user-flows.md` and `m8-execution-map.md` before selecting a stage. Requirement ownership and evidence are in `m8-final-acceptance-matrix.md`.

Sources: H01, R01-R08, R13, R22-R27. New product choices above are proposals, not repository implementation claims.
