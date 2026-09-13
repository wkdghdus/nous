# Test Specification: M7E Agent Candidate Writes and Idempotency

Status: Draft verification contract

Date: 2026-08-08

Plan: `m7e-agent-candidate-writes-and-idempotency-plan.md`

Depends on: M7A-M7D green

## 1. Test Strategy

Call the four candidate operations directly through core. Verify exact destinations and metadata, idempotent replay/conflict/crash recovery, evidence eligibility, injection resistance, concurrency, review integration, and accepted-output exclusion.

## 2. Required Test Program

Add:

```sh
ruby scripts/test_nous_candidate_writes.rb
```

## 3. Common Fixture Rules

- Temporary synthetic vault only.
- Fixed generation/review/graph/report times.
- Seed eligible raw artifacts, reviewed notes, and canonical claims.
- Seed ineligible pending/retired/relationship/derived records.
- Capture full vault manifest/bytes before failure calls.
- Use process-based concurrency tests.
- No MCP classes/gem in tests.

## 4. Schema Compatibility Tests

### SCHEMA-E-001: Existing records remain valid

All M1-M6 fixture shapes parse/validate without new fields.

### SCHEMA-E-002: Candidate note metadata

`candidate_type`, `basis`, and `generation` valid only in documented shape.

### SCHEMA-E-003: Generation digest

Exactly 64 lowercase hex.

### SCHEMA-E-004: Request ID pattern

Valid boundary values and invalid characters.

### SCHEMA-E-005: Capture metadata

`authorship: user`, `capture_channel: mcp`, compatible extraction method.

### SCHEMA-E-006: Identity candidate rejected

No unsupported review route introduced.

### SCHEMA-E-007: Unknown generation fields

Rejected or ignored according to schema policy; implementation never writes them.

## 5. Idempotency Tests

### IDEM-E-001: Capture same request/input

One artifact; second result same ID/path, `replayed: true`, original `generated_at` unchanged.

### IDEM-E-002: Note same request/input

One file/replay.

### IDEM-E-003: Claim same request/input

One file/replay.

### IDEM-E-004: Relationship same request/input

One file/replay.

### IDEM-E-005: Changed text

Conflict; original unchanged; no new file.

### IDEM-E-006: Changed title

Conflict.

### IDEM-E-007: Changed evidence order

Conflict because order is preserved/meaningful.

### IDEM-E-008: Changed evidence member

Conflict.

### IDEM-E-009: Cross-operation reuse

Capture request reused for note/claim/relationship conflicts.

### IDEM-E-010: Invalid request IDs

Empty, overlong, whitespace, slash, backslash, newline, control, Unicode rejected.

### IDEM-E-011: Request ID absent from filename/ID/body

Valid punctuation remains metadata only.

### IDEM-E-012: Digest stable across processes

Same normalized input produces same digest.

### IDEM-E-013: Digest excludes generation time

Same input/time change replays rather than conflicts.

### IDEM-E-014: Digest excludes request ID

Different request IDs with same input produce distinct records, each with same input digest where expected.

### IDEM-E-015: Finalize-before-response

Simulate finalized record/no response; retry replays.

### IDEM-E-016: Approved/moved replay

After approval, retry returns current reviewed/canonical path and no duplicate.

### IDEM-E-017: Retired replay

After rejection/deprecation, retry returns existing retired lifecycle and no duplicate.

### IDEM-E-018: Duplicate generation request metadata

Stable corruption error; no write.

### IDEM-E-019: Existing metadata missing required digest/operation

Stable parse/corruption error; do not create duplicate.

### IDEM-E-020: Concurrent identical request

Two processes: one create, one replay; exactly one file.

### IDEM-E-021: Concurrent different requests same title

Both succeed with collision-safe distinct IDs/paths.

## 6. User Text Capture Tests

### CAP-E-001: Valid capture

Exactly one raw artifact, no inbox note.

### CAP-E-002: Verbatim observed content

User text preserved byte/character-for-character after line-ending policy; YAML-like/body headings remain content.

### CAP-E-003: Context separation

Only under user-provided context.

### CAP-E-004: Interpretation boundary

`interpretation_level: none`, no facts/hypotheses/claim/relationship.

### CAP-E-005: Authorship confirmation false/missing

Rejected before write.

### CAP-E-006: Blank text

Rejected.

### CAP-E-007: Invalid UTF-8

Rejected.

### CAP-E-008: Size boundary

1 MiB accepted; larger rejected without partial file.

### CAP-E-009: Title normalization

Newline/path/control content cannot escape filename/heading.

### CAP-E-010: Missing title fallback

Deterministic safe slug/title.

### CAP-E-011: Represented date

Stored separately; invalid date rejected.

### CAP-E-012: Source path

Safe artifact self-path; no external absolute path.

### CAP-E-013: Generation metadata

Operation, interface, request, digest, generated time.

### CAP-E-014: Result envelope

Correct lifecycle, replay false, review state, `interpretation_created: false`.

### CAP-E-015: Existing `ingest_text` unchanged

Still creates artifact + generic draft with current behavior.

## 7. Evidence Resolver Tests

### EVID-E-001: Raw artifact eligible

Resolves ID/path.

### EVID-E-002: Active reviewed note eligible

Resolves.

### EVID-E-003: Active canonical claim eligible

Resolves.

### EVID-E-004: Pending note ineligible

Rejected.

### EVID-E-005: Pending claim ineligible

Rejected.

### EVID-E-006: Pending relationship ineligible

Rejected.

### EVID-E-007: Canonical relationship ineligible

Rejected as evidence record kind.

### EVID-E-008: Derived output ineligible

Cannot be addressed as record/evidence.

### EVID-E-009: Retired record ineligible

Rejected.

### EVID-E-010: Missing ID

Rejected.

### EVID-E-011: Duplicate ID

Rejected.

### EVID-E-012: Primary not in evidence list

Rejected.

### EVID-E-013: Duplicate evidence IDs

Rejected.

### EVID-E-014: Evidence/counterevidence overlap

Rejected.

### EVID-E-015: Caller-supplied path impossible

Public method has no path argument; persisted path comes from index.

## 8. Candidate Note Tests

### NOTE-E-001: Every allowed candidate type

Memory, value, belief, project, pattern, decision, person, question, contradiction.

### NOTE-E-002: Identity rejected

Stable invalid input.

### NOTE-E-003: Persisted generic type

`type: note`, separate `candidate_type`.

### NOTE-E-004: Destination/lifecycle

Inbox notes only, draft/agent-generated.

### NOTE-E-005: Required fields and bounds

Title/facts/context/hypotheses/tags/confidence arrays.

### NOTE-E-006: Basis interpretation mapping

User asserted/extractive low; agent inferred medium and requires hypothesis.

### NOTE-E-007: Fact/context/hypothesis separation

Exact sections.

### NOTE-E-008: No empty fact list

Rejected.

### NOTE-E-009: Safe title

Cannot create extra heading/path.

### NOTE-E-010: Safe list item

Strings containing `##`, `---`, fences, list markers, HTML, links remain inside intended item.

### NOTE-E-011: NUL/control

Rejected.

### NOTE-E-012: Markdown parses

Rendered frontmatter/body valid and fixed headings occur exactly once.

### NOTE-E-013: Evidence paths

Server-generated, ordered, correct.

### NOTE-E-014: Result envelope

ID, candidate type, path, evidence IDs, lifecycle, replay, review required.

### NOTE-E-015: Graph/report exclusion

Pending absent.

### NOTE-E-016: Review approval explicit mapping

Current `--as TYPE` still required; correct approval succeeds and retains generation metadata.

## 9. Candidate Claim Tests

### CLAIM-E-001: Valid claim

Inbox destination and fixed sections.

### CLAIM-E-002: Blank/overlong statement

Rejected.

### CLAIM-E-003: Boundaries separate

Not appended to statement.

### CLAIM-E-004: Counterevidence paths

Resolved and ordered.

### CLAIM-E-005: Basis/interpretation

Correct.

### CLAIM-E-006: No canonical write

Pending only.

### CLAIM-E-007: Injection resistance

Statement/boundaries cannot create frontmatter/sections.

### CLAIM-E-008: Graph/report exclusion

Pending absent.

### CLAIM-E-009: Approval and replay

Approve to canonical; retry returns moved record.

### CLAIM-E-010: Reject and replay

No duplicate.

## 10. Candidate Relationship Tests

### REL-E-001: Every current relationship enum

Valid endpoint/evidence fixture.

### REL-E-002: Unsupported type

Rejected.

### REL-E-003: Self-loop

Rejected.

### REL-E-004: Missing/duplicate endpoint

Rejected.

### REL-E-005: Artifact endpoint

Rejected.

### REL-E-006: Relationship endpoint

Rejected.

### REL-E-007: Retired endpoint

Rejected.

### REL-E-008: Reviewed note to canonical claim

Valid and approval-ready.

### REL-E-009: Pending note to pending claim

Valid proposal, not approval-ready.

### REL-E-010: Pending to reviewed

Valid proposal, not ready.

### REL-E-011: Evidence independent

No implicit endpoint-as-evidence unless explicitly included and eligible (pending endpoint cannot be eligible evidence).

### REL-E-012: Statement/rationale bounds/injection

Safe renderer.

### REL-E-013: Endpoint lifecycle result

Exact current lifecycle and readiness.

### REL-E-014: Approval blocked pending

M7C gate.

### REL-E-015: Progressive endpoint approval

Blocked until both approved.

### REL-E-016: Endpoint retired after proposal

Approval blocked.

### REL-E-017: Pending graph/report exclusion

Absent.

### REL-E-018: Approved graph edge

After endpoint and relationship approval, graph contains edge.

## 11. Rendering and Injection Tests

### RENDER-E-001: YAML frontmatter delimiter in every text field

Cannot escape body into frontmatter.

### RENDER-E-002: Markdown heading in every scalar/list field

Cannot create sibling fixed section.

### RENDER-E-003: Fence/backtick/HTML

Remains inert Markdown content.

### RENDER-E-004: CRLF/CR normalization

Documented deterministic behavior.

### RENDER-E-005: Extremely long repeated punctuation

Bound enforced before rendering.

### RENDER-E-006: Secret-shaped text

Stored in record body when legitimately supplied but never logged/error-echoed.

### RENDER-E-007: Path-like title/request

Cannot influence output directory.

### RENDER-E-008: Body headings count

Fixed headings exactly once in candidate notes/claims/relationships.

## 12. Concurrency/Failure Tests

### CONC-E-001: Identical capture two processes

One record/replay.

### CONC-E-002: Identical note/claim/relationship

One each.

### CONC-E-003: Different request same slug

Distinct collision suffixes.

### FAIL-E-001: Failure after idempotency check before stage

No record; retry creates once.

### FAIL-E-002: Failure after stage before finalize

No final/temp; retry creates once.

### FAIL-E-003: Failure after finalize before response

Retry replays.

### FAIL-E-004: Lock timeout

No write/idempotency metadata.

### FAIL-E-005: Invalid evidence after lock

No file.

## 13. Direct End-to-End Lifecycle

### E2E-E-001

1. Capture synthetic user text.
2. Read source with M7D.
3. Propose pattern note and claim from artifact.
4. Propose supports relationship between pending note/claim with artifact evidence.
5. Confirm report/graph exclude pending.
6. Review/approve note with explicit type and claim.
7. Confirm relationship becomes approval-ready and approve it.
8. Generate graph/report; assert node/claim/edge and report entries.
9. Retry all three proposal requests; assert replay current reviewed/canonical paths.
10. Verify original raw artifact/evidence unchanged.

### E2E-E-002: Rejection path

Propose candidate, reject, retry; no duplicate and retired lifecycle returned.

## 14. Static/Regression Checks

### STATIC-E-001: No MCP dependency/server

No `require "mcp"`, Gemfile, tool classes, stdio server.

### STATIC-E-002: No agent-controlled path/ID/frontmatter

Inspect public signatures.

### STATIC-E-003: No hidden state database

Idempotency derives from record metadata.

### STATIC-E-004: No model/network

No provider/API/sampling calls.

### REG-E-001: M7A-D tests pass

### REG-E-002: M2-M6 tests pass

### REG-E-003: Fixed graph/report bytes for old fixtures unchanged

### PRIV-E-001: Logs/errors contain no content

### PRIV-E-002: Repository vault/worktree clean

## 15. Verification Order

```sh
ruby scripts/test_nous_candidate_writes.rb
ruby scripts/test_nous_agent_reads.rb
ruby scripts/test_nous_mutation_core.rb
ruby scripts/test_nous_read_core.rb
ruby scripts/test_cli_contracts.rb              # when present
ruby scripts/test_ingest_text.rb
ruby scripts/test_ingest_artifact.rb
ruby scripts/test_review_queue.rb
ruby scripts/test_export_graph.rb
ruby scripts/test_generate_nous_report.rb
make test
make lint
git diff --check
git status --short
```

## 16. Pass Conditions

- All four operations pass direct tests.
- Idempotency and concurrency prove one-record behavior.
- Agent controls no filesystem/lifecycle authority.
- Evidence/self-grounding rules hold.
- Injection strings cannot alter record structure.
- Pending excluded; human review lifecycle succeeds.
- All prior tests green.
- No M7F code/dependency present.

## 17. Failure Triage

- Replay after move fails: expand metadata lookup; do not create duplicate.
- Digest unexpectedly differs: inspect canonical serialization; do not normalize user text.
- Pending evidence accepted: fail stage immediately.
- Section injection: fix renderer before enabling any operation.
- Existing CLI changes: revert adapter bleed.
