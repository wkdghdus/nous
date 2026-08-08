# PRD: M4 Graph Export

## Objective

Ship a dependency-free graph export path that turns reviewed/canonical vault records into stable JSON graph data for downstream local-first consumers.

## Scope

In scope:

- Export reviewed notes from `vault/02_notes/*/*.md`.
- Export canonical claims from `vault/03_canonical_model/claims/*.md`.
- Export canonical relationships from `vault/03_canonical_model/relationships/*.md`.
- Support `--vault-root PATH`, `--output PATH`, and deterministic test time via `NOUS_GRAPH_TIME`.
- Produce schema version `0.1` graph JSON with sorted nodes and edges.
- Fail before writing on malformed exported records, duplicate IDs, invalid confidence, unsupported types, and dangling relationship endpoints.
- Add focused regression coverage, docs, and signpost updates.

Out of scope:

- Inbox or hypothesis graph export.
- Semantic inference, summarization, or LLM-generated graph records.
- JSON Schema runtime validation dependency.
- Application runtime or UI changes.

## User Stories

### US-001: Reviewed Node Export

As a local-first Nous user, I want reviewed notes and canonical claims exported as graph nodes so graph consumers only receive accepted records.

Acceptance criteria:

- Reviewed active notes under `vault/02_notes/*/*.md` export as nodes when required frontmatter is valid.
- Reviewed active canonical claims under `vault/03_canonical_model/claims/*.md` export as nodes.
- Inbox, rejected, deprecated, archived, and pending records are excluded by default.
- Labels and summaries are deterministic and never inferred by an LLM.

### US-002: Canonical Relationship Export

As a local-first Nous user, I want canonical relationships exported as graph edges so reviewed connections can be consumed safely.

Acceptance criteria:

- Reviewed active relationships under `vault/03_canonical_model/relationships/*.md` export as edges.
- Edge endpoints must reference exported node IDs.
- Duplicate edge IDs and dangling endpoints fail clearly without partial writes.

### US-003: Deterministic CLI Output

As an agent or developer, I want repeatable graph JSON output so tests and generated files remain stable.

Acceptance criteria:

- `ruby scripts/export_graph.rb` writes `vault/04_generated/graph/nous_graph.json` by default.
- `--vault-root PATH` and `--output PATH` override defaults.
- `NOUS_GRAPH_TIME` controls `generated_at` in tests and invalid timestamps fail clearly.
- Two runs with fixed inputs and fixed time produce byte-identical JSON.

### US-004: Repository Integration

As a maintainer, I want M4 covered by existing repository checks so regressions are caught by the same workflow.

Acceptance criteria:

- `ruby scripts/test_export_graph.rb` passes.
- `make test` includes export graph tests.
- `make lint` passes.
- README and architecture docs describe reviewed-only graph export semantics.

## Verification

- `ruby scripts/test_export_graph.rb`
- `make test`
- `make lint`
- `ruby scripts/export_graph.rb`
- Parse generated JSON with Ruby stdlib `JSON.parse`.
