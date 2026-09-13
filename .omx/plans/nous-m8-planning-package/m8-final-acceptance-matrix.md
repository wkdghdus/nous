# M8 Final Acceptance Matrix

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## Completion rule

Every row below is **NOT RUN** at planning time. A planning document, source inspection, screenshot or implementation-agent statement is not passing test evidence. To mark PASS, attach the release SHA, exact runtime/client/browser versions where relevant, test case IDs, commands, exit result, synthetic fixture identity and an independent verifier reference. FAILED and SKIPPED/UNAVAILABLE are not PASS.

A waiver requires explicit product-owner approval and a corresponding scope/contract change; the implementing agent cannot grant it. Inherited M7 safety and trust requirements must not be weakened by an M8 waiver. All H gates include the applicable earlier focused and legacy regressions again.

## Requirement-to-test traceability

| Requirement | Owning stage | Required behavior | Verification cases | Planning status |
| --- | --- | --- | --- | --- |
| FR-M8-001 | M8B | Open an existing valid vault through a human-selected capability; never initialize or repair during open/health. | [T-B01](test-spec-m8b-local-adapter-and-vault-session.md), [T-B03](test-spec-m8b-local-adapter-and-vault-session.md), [T-C01](test-spec-m8c-read-only-application-experience.md) | NOT RUN |
| FR-M8-002 | M8B | Expose health, schema compatibility, counts, warnings, write availability and recovery state without private paths. | [T-B03](test-spec-m8b-local-adapter-and-vault-session.md), [T-B04](test-spec-m8b-local-adapter-and-vault-session.md), [T-C01](test-spec-m8c-read-only-application-experience.md) | NOT RUN |
| FR-M8-003 | M8B | Support one active vault with explicit switching, epoch isolation and optional private recent-vault settings. | [T-B06](test-spec-m8b-local-adapter-and-vault-session.md), [T-C06](test-spec-m8c-read-only-application-experience.md), [T-H01](test-spec-m8h-launcher-recovery-and-release.md) | NOT RUN |
| FR-M8-004 | M8C | Browse all matching reviewed/canonical knowledge through deterministic bounded pagination and filters. | [T-B05](test-spec-m8b-local-adapter-and-vault-session.md), [T-C02](test-spec-m8c-read-only-application-experience.md) | NOT RUN |
| FR-M8-005 | M8C | Provide ID-based record/evidence detail with lifecycle, confidence, source metadata and safe local previews. | [T-B07](test-spec-m8b-local-adapter-and-vault-session.md), [T-C03](test-spec-m8c-read-only-application-experience.md), [T-C04](test-spec-m8c-read-only-application-experience.md) | NOT RUN |
| FR-M8-006 | M8C | Refresh external changes; distinguish missing, renamed, malformed and duplicate records without selecting a first match. | [T-B04](test-spec-m8b-local-adapter-and-vault-session.md), [T-B06](test-spec-m8b-local-adapter-and-vault-session.md), [T-C05](test-spec-m8c-read-only-application-experience.md), [T-E06](test-spec-m8e-human-review-workspace.md) | NOT RUN |
| FR-M8-007 | M8D | Capture confirmed verbatim text as raw evidence with correct app provenance and retry-safe identity. | [T-D01](test-spec-m8d-capture-import-and-retry-safety.md), [T-D02](test-spec-m8d-capture-import-and-retry-safety.md), [T-D05](test-spec-m8d-capture-import-and-retry-safety.md) | NOT RUN |
| FR-M8-008 | M8D | Import one human-selected allowlisted writing/image/project file, preserving original bytes and M6 draft semantics. | [T-D03](test-spec-m8d-capture-import-and-retry-safety.md), [T-D04](test-spec-m8d-capture-import-and-retry-safety.md) | NOT RUN |
| FR-M8-009 | M8D | Expose import progress, cancellation boundaries, collision results, checksums and safe uncertain-outcome recovery. | [T-D05](test-spec-m8d-capture-import-and-retry-safety.md), [T-D06](test-spec-m8d-capture-import-and-retry-safety.md), [T-D07](test-spec-m8d-capture-import-and-retry-safety.md), [T-D08](test-spec-m8d-capture-import-and-retry-safety.md) | NOT RUN |
| FR-M8-010 | M8E | Display pending notes/claims/relationships with filters, evidence and accurate decision metadata. | [T-E01](test-spec-m8e-human-review-workspace.md), [T-E09](test-spec-m8e-human-review-workspace.md) | NOT RUN |
| FR-M8-011 | M8E | Save a complete candidate body and candidate type with conditional version checks and no raw/frontmatter editor. | [T-E02](test-spec-m8e-human-review-workspace.md), [T-E06](test-spec-m8e-human-review-workspace.md) | NOT RUN |
| FR-M8-012 | M8E | Approve notes with explicit type routing and approve claims/relationships only through human actions. | [T-E03](test-spec-m8e-human-review-workspace.md), [T-E10](test-spec-m8e-human-review-workspace.md) | NOT RUN |
| FR-M8-013 | M8E | Reject/deprecate pending inbox items and merge their evidence into a validated accepted target with explicit confirmation. | [T-E05](test-spec-m8e-human-review-workspace.md), [T-E06](test-spec-m8e-human-review-workspace.md), [T-E08](test-spec-m8e-human-review-workspace.md) | NOT RUN |
| FR-M8-014 | M8E | Block relationship approval until both ordered endpoints are unique active exportable nodes. | [T-E04](test-spec-m8e-human-review-workspace.md), [T-F03](test-spec-m8f-report-and-read-only-graph.md), [T-H03](test-spec-m8h-launcher-recovery-and-release.md) | NOT RUN |
| FR-M8-015 | M8E | Record app review/edit audit events without inventing historical events for legacy records. | [T-E09](test-spec-m8e-human-review-workspace.md) | NOT RUN |
| FR-M8-016 | M8F | View and manually regenerate the existing reviewed-only Nous report with source navigation and freshness state. | [T-F01](test-spec-m8f-report-and-read-only-graph.md), [T-F05](test-spec-m8f-report-and-read-only-graph.md), [T-F06](test-spec-m8f-report-and-read-only-graph.md) | NOT RUN |
| FR-M8-017 | M8F | Provide a bounded read-only graph and accessible table, preserving the current export schema and edge direction. | [T-F03](test-spec-m8f-report-and-read-only-graph.md), [T-F04](test-spec-m8f-report-and-read-only-graph.md), [T-F07](test-spec-m8f-report-and-read-only-graph.md) | NOT RUN |
| FR-M8-018 | M8F | Use authoritative input/output fingerprints for derived freshness; missing metadata is unknown, not fresh. | [T-F02](test-spec-m8f-report-and-read-only-graph.md), [T-F05](test-spec-m8f-report-and-read-only-graph.md) | NOT RUN |
| FR-M8-019 | M8H | Start/reopen/quit the prepared local app without routine Ruby commands and recover backend failure honestly. | [T-H01](test-spec-m8h-launcher-recovery-and-release.md), [T-H02](test-spec-m8h-launcher-recovery-and-release.md), [T-H05](test-spec-m8h-launcher-recovery-and-release.md), [T-H08](test-spec-m8h-launcher-recovery-and-release.md) | NOT RUN |
| FR-M8-020 | M8H | Accept candidates from an external MCP client and expose the entire human review loop without embedding a provider. | [T-H03](test-spec-m8h-launcher-recovery-and-release.md), [T-H04](test-spec-m8h-launcher-recovery-and-release.md), [T-E10](test-spec-m8e-human-review-workspace.md) | NOT RUN |
| NFR-M8-001 | M8A | Preserve file authority, dependency-free core, CLI compatibility and exact MCP schemas/protocol. | [T-A02](test-spec-m8a-preflight-and-contract-freeze.md), [T-A03](test-spec-m8a-preflight-and-contract-freeze.md), [T-B09](test-spec-m8b-local-adapter-and-vault-session.md), [T-D02](test-spec-m8d-capture-import-and-retry-safety.md), [T-F06](test-spec-m8f-report-and-read-only-graph.md), [T-H09](test-spec-m8h-launcher-recovery-and-release.md) | NOT RUN |
| NFR-M8-002 | M8B | Authenticate private APIs, bind only loopback, validate host/origin and prevent cross-site mutations. | [T-B02](test-spec-m8b-local-adapter-and-vault-session.md), [T-B08](test-spec-m8b-local-adapter-and-vault-session.md), [T-H06](test-spec-m8h-launcher-recovery-and-release.md) | NOT RUN |
| NFR-M8-003 | M8B | No deterministic outbound data transfer, telemetry, secret leakage, sensitive browser persistence or raw HTML execution. | [T-B07](test-spec-m8b-local-adapter-and-vault-session.md), [T-B10](test-spec-m8b-local-adapter-and-vault-session.md), [T-C04](test-spec-m8c-read-only-application-experience.md), [T-C08](test-spec-m8c-read-only-application-experience.md), [T-D10](test-spec-m8d-capture-import-and-retry-safety.md), [T-H04](test-spec-m8h-launcher-recovery-and-release.md), [T-H06](test-spec-m8h-launcher-recovery-and-release.md) | NOT RUN |
| NFR-M8-004 | M8D | Share locks and no-overwrite finalization; persist app operation recovery/receipts before exposing writes. | [T-D06](test-spec-m8d-capture-import-and-retry-safety.md), [T-D07](test-spec-m8d-capture-import-and-retry-safety.md), [T-D08](test-spec-m8d-capture-import-and-retry-safety.md), [T-D09](test-spec-m8d-capture-import-and-retry-safety.md), [T-E08](test-spec-m8e-human-review-workspace.md) | NOT RUN |
| NFR-M8-005 | M8E | Reject known stale source/target edits under the write lock, preserving newer content and retry identity. | [T-E06](test-spec-m8e-human-review-workspace.md), [T-E07](test-spec-m8e-human-review-workspace.md), [T-E08](test-spec-m8e-human-review-workspace.md) | NOT RUN |
| NFR-M8-006 | M8H | Document and test handled failure, process death and unresolved external-conflict recovery boundaries. | [T-D07](test-spec-m8d-capture-import-and-retry-safety.md), [T-D08](test-spec-m8d-capture-import-and-retry-safety.md), [T-E08](test-spec-m8e-human-review-workspace.md), [T-H02](test-spec-m8h-launcher-recovery-and-release.md), [T-H05](test-spec-m8h-launcher-recovery-and-release.md) | NOT RUN |
| NFR-M8-007 | M8H | Retain M2-M7 regressions and use synthetic temporary vaults for all automated and recorded manual tests. | [T-A02](test-spec-m8a-preflight-and-contract-freeze.md), [T-D10](test-spec-m8d-capture-import-and-retry-safety.md), [T-H09](test-spec-m8h-launcher-recovery-and-release.md) | NOT RUN |
| NFR-M8-008 | M8H | Provide keyboard-complete core flows, usable focus/error states and measured bounded performance. | [T-C07](test-spec-m8c-read-only-application-experience.md), [T-F04](test-spec-m8f-report-and-read-only-graph.md), [T-H07](test-spec-m8h-launcher-recovery-and-release.md) | NOT RUN |
| NFR-M8-009 | M8A | Pin and verify the build/runtime dependency set; do not assert an untested installer/platform. | [T-A06](test-spec-m8a-preflight-and-contract-freeze.md), [T-A08](test-spec-m8a-preflight-and-contract-freeze.md), [T-H08](test-spec-m8h-launcher-recovery-and-release.md) | NOT RUN |
| NFR-M8-010 | M8C | Separate evidence, hypotheses, candidate status, human approval and confidence in every content view. | [T-C03](test-spec-m8c-read-only-application-experience.md), [T-E01](test-spec-m8e-human-review-workspace.md), [T-E09](test-spec-m8e-human-review-workspace.md), [T-F03](test-spec-m8f-report-and-read-only-graph.md) | NOT RUN |

## End-to-end release scenario (mandatory)

Use the built local preview, an explicit temporary synthetic vault, the real app adapter/core, a real stdio MCP server and the existing CLI. No model is needed for automated tool calls. Separately record the intended external-host integration from M7F and verify that M8 did not break it.

1. Launch, authorize and choose a valid empty vault. Inspect zero/presence counts without repairs.
2. Capture a synthetic reflection, verify exact raw source and correct app receipt/channel.
3. Import one writing and one project/image fixture across the full test set. Verify original digest and the three-output import result; inspect the deterministic draft.
4. Through real MCP calls, propose a note, claim and relationship from eligible evidence. The app sees them as candidates, not accepted knowledge.
5. Try relationship approval before endpoints are accepted. It must fail without changing files.
6. Inspect evidence/counterevidence, edit the full note body, save and explicitly approve the note with a supported type and the claim. Ensure editing alone did not approve.
7. Approve the now-ready relationship. Verify ordered endpoints and original generation metadata.
8. On separate candidates, exercise reject, deprecate and evidence-only merge; verify target body preservation, candidate retirement and known audit events.
9. Browse accepted knowledge and page/filter beyond 50 records in a separate seeded synthetic fixture. Pending and retired records remain excluded by default.
10. Manually regenerate the existing report and graph. Verify reviewed-only content, schema/byte compatibility, input/output freshness and source navigation. Check the accessible graph table.
11. Modify a fixture externally and attempt a stale edit/merge. Newer source/target bytes must survive. Regenerated views must show stale/unknown until reconciled.
12. Reconcile a lost response using the original request ID. No duplicate records or repeated decision occurs.
13. Repeat the approved process-death drills and explicit recovery checks for import/approve/merge. Updated interfaces do not consume half-finalized state; external divergence is preserved.
14. Use CLI/MCP to inspect the same final stable IDs and current paths, including original M7 request replay after app approval.
15. Quit, restart/re-authorize and reopen the vault. Persisted source/accepted knowledge remains; no claim is made to recover unsubmitted memory-only drafts.
16. Run without a provider and without outbound network after setup. Inspect interface bindings, headers, logs, browser storage and payload/runtime artifacts.
17. Remove only app settings/build/runtime artifacts according to documented uninstall instructions. The vault remains readable through CLI/MCP/Obsidian.
18. Run all existing and new tests after cleanup; independent verifier completes every matrix row at the final SHA.

## Final release evidence record

Required fields: release source SHA; artifact checksum; Mac hardware/OS; Ruby/Bundler/Node/npm versions; exact locked dependency identifiers; browser/client versions; fixture generator/version; focused/aggregate command outcomes; manual observations; privacy/network scan results; failed/skipped cases; independent verifier and date; owner acceptance reference. Store only synthetic/sanitized evidence.

Readiness remains **BLOCKED for implementation/release** until the verified prerequisites and explicit approvals exist. The draft itself is available for review now.
