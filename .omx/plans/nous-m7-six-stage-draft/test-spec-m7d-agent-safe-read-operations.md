# Test Specification: M7D Agent-Safe Read Operations

Status: Draft verification contract

Date: 2026-08-08

Plan: `m7d-agent-safe-read-operations-plan.md`

Depends on: M7A-M7C green

## 1. Test Strategy

Call read operations directly through Nous Core. Snapshot all fixture files before and after each operation. Exercise lifecycle ambiguity, duplicates, path attacks, large/binary/invalid content, deterministic ranking, and content-label behavior.

## 2. Required Test Program

Add:

```sh
ruby scripts/test_nous_agent_reads.rb
```

## 3. Fixture Matrix

Create one temporary vault containing synthetic:

- M2 text artifact with embedded observed content and external-looking `source.path`;
- M6 writing artifact plus copied `.md` payload;
- M6 text project artifact plus copied `.json` payload;
- M6 image artifact plus binary payload;
- M6 binary project screenshot;
- pending generic note with candidate-like metadata;
- pending claim;
- pending relationship;
- reviewed value, belief, pattern, memory, question, contradiction, project;
- canonical claim;
- canonical relationship;
- rejected/deprecated/archived records;
- generated report and graph presence;
- adversarial prompt/YAML/path strings as inert content.

Use separate focused vaults for duplicates/malformed/symlink cases.

## 4. Mutation-Free Tests

### READONLY-D-001: Status snapshot

All file names, bytes, and mtimes where stable remain unchanged.

### READONLY-D-002: List snapshot

No mutation/temp output.

### READONLY-D-003: Record read snapshot

No mutation.

### READONLY-D-004: Source read snapshot

No mutation, including source payload.

### READONLY-D-005: Error snapshot

Failed reads do not “repair” metadata or create output.

### READONLY-D-006: Repeated reads

Identical structured result and no accumulated runtime files except the documented ignored lock file if shared locking creates it.

## 5. Index and Lifecycle Tests

### INDEX-D-001: Known locations indexed

All and only documented record locations.

### INDEX-D-002: Signposts excluded

Every `AGENT.md` ignored.

### INDEX-D-003: Payloads excluded

Copied `.md` payload in `files/` is not a record even though Markdown.

### INDEX-D-004: Generated outputs excluded

Report/graph are presence indicators, not records.

### INDEX-D-005: Unknown directory excluded

A valid-looking note under an unrecognized path is ignored/warned according to contract.

### INDEX-D-006: Symlinked record excluded/rejected

Never followed.

### INDEX-D-007: Duplicate reviewed IDs

Unique lookup/list fails stable duplicate error.

### INDEX-D-008: Duplicate across raw and inbox

Fails; directory priority must not select one.

### INDEX-D-009: Frontmatter-reviewed inbox

Lifecycle remains `agent_candidate`.

### INDEX-D-010: Archived reviewed path

Lifecycle `retired`.

### INDEX-D-011: Reviewed canonical claim

Lifecycle `canonical`.

### INDEX-D-012: Pending relationship

Lifecycle `agent_candidate` and record type relationship.

## 6. Status Tests

### STATUS-D-001: Empty vault

Zero counts, false generated presence, schema version.

### STATUS-D-002: Complete fixture counts

Exact lifecycle/kind counts.

### STATUS-D-003: Generated presence

Known paths only.

### STATUS-D-004: No absolute path

Recursive scan of result strings.

### STATUS-D-005: Malformed record warning

Bounded warning or documented stable failure.

### STATUS-D-006: Duplicate warning/count

Diagnostic behavior matches plan and does not expose absolute path.

### STATUS-D-007: Warning bound

More malformed files than limit does not create unbounded output.

### STATUS-D-008: Determinism

Repeated calls equal.

## 7. Listing and Lexical Query Tests

### QUERY-D-001: Default scopes

Only reviewed + canonical.

### QUERY-D-002: Explicit raw scope

Raw source artifact summaries included.

### QUERY-D-003: Explicit inbox scope

Pending records included and labeled candidate.

### QUERY-D-004: Multiple scopes unique

Duplicate scope input rejected or normalized according to strict contract; preferred strict unique-array validation.

### QUERY-D-005: Type filter

Exact supported types only.

### QUERY-D-006: Unsupported type

Stable invalid input.

### QUERY-D-007: Empty query order

Created then ID/path tie-break.

### QUERY-D-008: Exact ID ranking

First.

### QUERY-D-009: Exact label ranking

Ahead of body-only match.

### QUERY-D-010: Tag match

Deterministic.

### QUERY-D-011: Multi-token all-token behavior

Documented behavior; no fuzzy inference.

### QUERY-D-012: Case-insensitive

ASCII and representative Unicode case where Ruby behavior is stable.

### QUERY-D-013: Stable tie-break

Identical score records deterministic.

### QUERY-D-014: Limit default/min/max

1 and 50 valid; 0/51 invalid.

### QUERY-D-015: Query length

500 valid; 501 invalid.

### QUERY-D-016: Token bound

Excess tokens rejected or deterministically truncated per contract; preferred reject.

### QUERY-D-017: Excerpt bound

At most 240 chars.

### QUERY-D-018: Evidence ID bound

Bounded list/truncation indicator.

### QUERY-D-019: Prompt injection text

Returned as excerpt with `content_role: untrusted_data`; no side effect.

### QUERY-D-020: No semantic synonym match

Querying an absent synonym does not produce a model-inferred match.

### QUERY-D-021: No payload-body search

Text only in copied payload but absent from record body is not list-searched.

### QUERY-D-022: Absolute path scan

None in results.

## 8. Record Read Tests

### RECORD-D-001: Reviewed note envelope

All required curated fields, lifecycle, content role.

### RECORD-D-002: Candidate note envelope

Candidate type where present; non-canonical label.

### RECORD-D-003: Raw artifact envelope

Source evidence lifecycle.

### RECORD-D-004: Canonical claim envelope

Canonical lifecycle.

### RECORD-D-005: Relationship envelope

Endpoint IDs/type represented safely.

### RECORD-D-006: Retired record

Direct ID read allowed or rejected according to explicit contract; recommended allowed with `retired` label, while normal list excludes by default. Lock this behavior.

### RECORD-D-007: Unknown ID

`NOUS_RECORD_NOT_FOUND`.

### RECORD-D-008: Duplicate ID

`NOUS_DUPLICATE_ID`.

### RECORD-D-009: Body default bound

12,000 chars.

### RECORD-D-010: Body maximum

50,000 valid; larger requested invalid.

### RECORD-D-011: Zero body

Metadata only and deterministic.

### RECORD-D-012: Multibyte truncation

No broken UTF-8; character count semantics.

### RECORD-D-013: External source path redaction

Legacy absolute `source.path` not returned.

### RECORD-D-014: Safe relative source path

Preserved.

### RECORD-D-015: Unknown frontmatter secret-shaped field

Not returned by curated envelope.

### RECORD-D-016: Evidence normalization

IDs/paths bounded and safe.

### RECORD-D-017: Content labels

Every body-bearing result has `untrusted_data`.

## 9. Source Text Tests

### SOURCE-D-001: M2 embedded observed content

Returns section text; does not open external `source.path`.

### SOURCE-D-002: M2 malicious absolute path

Even when existing/readable, not followed.

### SOURCE-D-003: M6 writing Markdown

Safe chunk and metadata.

### SOURCE-D-004: M6 writing text

Safe.

### SOURCE-D-005: M6 project JSON

Returned as text.

### SOURCE-D-006: M6 project YAML

Returned as text without parsing/executing aliases.

### SOURCE-D-007: Image artifact

`content_available: false` or `NOUS_CONTENT_UNAVAILABLE` per contract; no bytes.

### SOURCE-D-008: Binary project screenshot

Unavailable.

### SOURCE-D-009: Non-artifact ID

Invalid input/unsupported source.

### SOURCE-D-010: Missing payload

Stable error/warning.

### SOURCE-D-011: External relative traversal path

Rejected.

### SOURCE-D-012: Symlink payload

Rejected.

### SOURCE-D-013: Invalid UTF-8

Rejected; no replacement decoding that hides corruption.

### SOURCE-D-014: SHA mismatch

Rejected.

### SOURCE-D-015: Byte-count mismatch

Rejected.

### SOURCE-D-016: Missing audit metadata

Legacy safe internal text payload may be read with warning; exact policy documented/tested.

### SOURCE-D-017: Offset zero

First chunk.

### SOURCE-D-018: Middle offset

Correct character slice and next offset.

### SOURCE-D-019: Offset at end

Empty chunk, not truncated.

### SOURCE-D-020: Offset past end

Stable invalid input or empty result; choose/document one. Preferred stable invalid input.

### SOURCE-D-021: Max bound

50,000 valid; 50,001 invalid.

### SOURCE-D-022: Multibyte offset

Character-aligned.

### SOURCE-D-023: Large text memory smoke

Bounded result and acceptable runtime; test need not assert process RSS precisely.

### SOURCE-D-024: Prompt injection content

Returned inertly with content label.

### SOURCE-D-025: No absolute payload path

Only safe vault-relative path.

## 10. Performance Smoke

On a synthetic temporary vault with up to 10,000 small Markdown records:

- index/status completes within the NFR smoke target on normal local SSD;
- list limit 20 completes within target;
- read_record completes within target.

Treat timing as a diagnostic smoke with reasonable tolerance, not a flaky nanosecond unit test. Record environment if it fails.

## 11. Regression/Static Checks

### REG-D-001: M7A-C tests

All pass.

### REG-D-002: M2-M6 tests

All pass.

### STATIC-D-001: No writes in read operation modules

No atomic writer/transaction call from public reads.

### STATIC-D-002: No arbitrary path public argument

Inspect method signatures and docs.

### STATIC-D-003: No network/model/embedding/database dependency

Search and dependency check.

### STATIC-D-004: No MCP files

No tool/server/dependency yet.

### STATIC-D-005: Privacy

No fixture/source content in repo vault/worktree/logs.

## 12. Verification Order

```sh
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

## 13. Pass Conditions

- All direct read tests pass.
- Vault snapshot remains unchanged.
- Path/symlink/external/binary/digest adversaries are blocked.
- Results are bounded and deterministic.
- Default list exposes only reviewed/canonical data.
- Content is labeled untrusted.
- All previous tests remain green.
- No M7E/M7F scope exists.

## 14. Failure Triage

- Duplicate ambiguity: fail rather than choose.
- Source mismatch: do not bypass verification; inspect artifact metadata.
- Search ordering drift: reduce heuristic complexity and restore documented tie-break.
- Unicode failure: define/test character semantics explicitly.
- Status malformed-record policy unclear: stop and resolve before coding.
