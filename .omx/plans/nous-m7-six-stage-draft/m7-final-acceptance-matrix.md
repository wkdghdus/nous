# M7 Final Acceptance Matrix

Status: Draft traceability contract

Date: 2026-08-08

Umbrella PRD: `prd-m7-agent-ready-core-and-mcp.md`

## 1. Purpose

This matrix assigns every M7 functional/non-functional requirement to the stage that establishes it and the later stage that releases or revalidates it. No requirement is considered complete merely because one focused test passes; the final M7 gate includes all prior regression and end-to-end checks.

## 2. Functional Requirement Traceability

| Requirement | Primary stage | Supporting stage(s) | Main verification |
| --- | --- | --- | --- |
| FR-M7-001 Reusable core operations | M7B | M7C-M7E | `test-spec-m7b` core isolation/equivalence; later direct operation suites. |
| FR-M7-002 Vault confinement | M7C | M7D-M7F | PATH-C, SOURCE-D, MCP security/path tests. |
| FR-M7-003 Stable record lookup | M7D | M7B, M7E | INDEX-D and duplicate/replay tests. |
| FR-M7-004 Deterministic lexical retrieval | M7D | M7F | QUERY-D and MCP list mapping tests. |
| FR-M7-005 Bounded record reading | M7D | M7F | RECORD-D and MCP read-record output/bounds. |
| FR-M7-006 Bounded source-text reading | M7D | M7F | SOURCE-D and MCP source-read mapping/security. |
| FR-M7-007 Verbatim user-text capture | M7E | M7F | CAP-E and MCP capture representative call. |
| FR-M7-008 Candidate note proposal | M7E | M7F | NOTE-E, rendering/evidence/review tests, MCP mapping. |
| FR-M7-009 Candidate claim proposal | M7E | M7F | CLAIM-E and MCP mapping. |
| FR-M7-010 Candidate relationship proposal | M7E | M7C, M7F | REL-E, relationship approval gate, MCP mapping. |
| FR-M7-011 Idempotent agent mutations | M7E | M7C, M7F | IDEM-E, CONC-E, MCP replay/conflict. |
| FR-M7-012 Coordinated write locking | M7C | M7E-F | LOCK-C, TX-C, concurrent candidate/MCP-CLI tests. |
| FR-M7-013 Relationship approval integrity | M7C | M7E-F | REL-C, REL-E progressive lifecycle, graph defense. |
| FR-M7-014 MCP protocol compliance | M7F | M7A | SDK preflight, schema/stdout/client tests. |
| FR-M7-015 Exact MCP tool surface | M7F | PRD/shared contract | SCHEMA-F exact tool/no-dangerous-tool tests. |
| FR-M7-016 Agent behavior contract | M7E | M7F | Archivist contract review plus MCP descriptions/setup. |
| FR-M7-017 Backward compatibility | M7A | M7B-F | Characterization and every stage's M2-M6 regression/byte comparisons. |

## 3. Non-Functional Requirement Traceability

| Requirement | Primary stage | Evidence |
| --- | --- | --- |
| NFR-M7-001 Local-first/offline | M7F | No listener/API key/network tests; stdio-only capability; dependency audit. |
| NFR-M7-002 Privacy | All | Temporary synthetic fixtures, redaction, log tests, worktree/vault leak scans. |
| NFR-M7-003 Security | M7C-M7F | Path/symlink, bounds, safe renderer, no shell, strict MCP schemas. |
| NFR-M7-004 Reliability | M7B-M7E | Determinism, locks, atomicity, rollback, duplicate checks, idempotency. |
| NFR-M7-005 Performance | M7D/F | 10k-record/startup local smoke targets. |
| NFR-M7-006 Maintainability | M7B/F | Core/adapter separation, no MCP dependency in core, locked official SDK. |
| NFR-M7-007 Explainability | M7D/E/F | Lifecycle/content labels, evidence IDs, basis/confidence, replay/review result fields. |

## 4. Stage Exit Matrix

| Stage | Must prove | Must remain absent |
| --- | --- | --- |
| M7A | Existing behavior explicit and green; SDK/stdio feasible. | Core, locks, candidates, MCP product server/dependency. |
| M7B | Side-effect-free read/domain core; exact graph/report/review-read compatibility. | Mutation extraction, agent ops, MCP. |
| M7C | All current writes safe/atomic/locked; relationship gate. | Agent read/write surface, idempotency, MCP. |
| M7D | Deterministic bounded ID-based reads; path/source safety. | Candidate writes, MCP, semantic index. |
| M7E | Candidate-only evidence-grounded idempotent writes; review integration. | MCP adapter, agent approval, frontend/model. |
| M7F | Exact protocol adapter and verified client lifecycle release. | Extra tools/capabilities, HTTP, frontend/model authority. |

## 5. Exact Final Tool Matrix

| Tool | Core owner | Default trust scope | Writes | Human review required |
| --- | --- | --- | --- | --- |
| `nous_status` | M7D | counts only | No | No |
| `nous_list_records` | M7D | reviewed + canonical | No | No |
| `nous_read_record` | M7D | explicit stable ID | No | No |
| `nous_read_source_text` | M7D | validated artifact ID | No | No |
| `nous_capture_user_text` | M7E | confirmed user text | Raw artifact only | Artifact remains source evidence/needs review as designed |
| `nous_propose_note` | M7E | eligible evidence | Inbox note only | Yes |
| `nous_propose_claim` | M7E | eligible evidence | Inbox claim only | Yes |
| `nous_propose_relationship` | M7E | eligible evidence/endpoints | Inbox relationship only | Yes; endpoint ordering enforced |

## 6. Forbidden Capability Matrix

These must be absent from implementation and tool discovery:

| Capability | Reason |
| --- | --- |
| Approve/reject/deprecate/merge via MCP | Agent cannot establish truth about itself. |
| Delete/canonicalize/edit reviewed via MCP | Destructive/canonical authority remains human. |
| Arbitrary file/path read/import | Prevent workstation data escape. |
| Shell/command/eval | No execution surface. |
| HTTP/remote transport | M7 local stdio only. |
| Model calls/sampling | Agent remains external. |
| Semantic/vector database | M7 deterministic lexical/file-first. |
| Frontend | Separate M8 adapter/application surface. |
| Voice/OCR/EXIF/image interpretation | Existing MVP guardrails/out of scope. |

## 7. Data Integrity Matrix

| Integrity rule | Established | Revalidated |
| --- | --- | --- |
| External source unchanged | M2/M6 baseline + M7C | M7F end-to-end |
| Vault-relative portable provenance | M6 + M7C | M7D/E/F |
| No overwrite | M2/M6 + M7C | Candidate/MCP concurrency |
| Atomic single writes | M7C | M7E/F |
| Coordinated M6 rollback | M7C | Full regression |
| Duplicate ID failure | M7B/D | M7E/F |
| Idempotent agent write | M7E | M7F protocol retries |
| Pending excluded from outputs | Existing M4/M5 + M7E | M7F lifecycle |
| Canonical edge endpoints valid | M7C | M7E/F + graph defense |

## 8. Privacy Matrix

| Surface | Required protection | Test owner |
| --- | --- | --- |
| Test fixtures | Temporary synthetic only | Every stage |
| Core errors | No body/secret/external path/backtrace | M7B-D |
| Candidate rendering | Secret-shaped text stored only where supplied, not logged | M7E |
| MCP stdout | Protocol only | M7F |
| MCP stderr | Tool/request/duration/code only | M7F |
| Tool outputs | No external absolute path; bounded content | M7D-F |
| Worktree/vault | No fixture/private/temp/lock/config leak | Every stage/final verifier |
| Dependencies | No telemetry/network runtime | M7F |

## 9. Final End-to-End Requirement Coverage

The final release scenario must demonstrate:

1. **Local startup:** stdio server initializes with exact tools.
2. **Empty status:** bounded counts, no path leak.
3. **Source capture:** confirmed user text becomes one raw artifact.
4. **Source read:** artifact-ID-based bounded text works.
5. **Candidate generation:** note, claim, relationship remain inbox-only.
6. **Trust boundary:** report/graph exclude candidates.
7. **Human review:** existing CLI approves note and claim.
8. **Relationship ordering:** edge approval blocked until both endpoints exportable.
9. **Accepted outputs:** report/graph include reviewed nodes/claim/edge.
10. **Retry safety:** original request IDs replay moved records, no duplicates.
11. **Privacy:** logs/stdout/outputs/worktree contain no prohibited data.
12. **Compatibility:** all M2-M6 commands/tests still pass.

## 10. Required Automated Test Programs at M7 Completion

```text
scripts/test_cli_contracts.rb                 (when M7A creates it)
scripts/test_nous_read_core.rb
scripts/test_nous_mutation_core.rb
scripts/test_nous_agent_reads.rb
scripts/test_nous_candidate_writes.rb
scripts/test_nous_mcp.rb
scripts/test_ingest_text.rb
scripts/test_ingest_artifact.rb
scripts/test_review_queue.rb
scripts/test_export_graph.rb
scripts/test_generate_nous_report.rb
```

`make test` must execute every applicable program.

## 11. Final Manual/Independent Checks

- MCP Inspector using recorded version/date.
- Codex CLI using recorded version/date.
- No network listener/outbound application call.
- Two-process lock/idempotency smoke.
- Forced rollback smoke.
- Manual record/frontmatter/provenance inspection.
- Full lifecycle smoke.
- Dependency/license/tree inspection.
- README/architecture accuracy review.
- `git diff --check`.
- `git status --short`.
- tracked/untracked private/temp/secret/path scan.
- independent verifier approval.
- changed-files-only cleanup and second full regression.

## 12. M7 Completion Rule

M7 is not complete when “the server starts” or “Codex sees tools.” It is complete only when the core, filesystem safety, read boundary, candidate write boundary, protocol mapping, human review lifecycle, privacy, compatibility, and intended client integration all pass their assigned gates.
