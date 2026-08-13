# M4 Graph Export Plan

## Requirements Summary

M4 adds a dependency-free JSON graph export for reviewed/canonical vault records. The roadmap defines M4 as "Graph export" with the deliverable "JSON export for nodes and relationships" and the success condition that "Reviewed notes generate stable graph records" (`nous_requirements_and_user_flows.md:521-527`).

Grounding:

- The product thesis says the MVP is an Obsidian-based archive with a reviewable graph of nodes and relationships (`nous_requirements_and_user_flows.md:9-15`).
- MVP scope includes candidate nodes and relationships, a canonical reviewed self-model, and generated graph JSON (`nous_requirements_and_user_flows.md:43-50`).
- The conceptual data model already separates Obsidian notes, structured graph nodes/edges, and generated outputs (`nous_requirements_and_user_flows.md:92-97`).
- Graph requirements call for candidate graph nodes, candidate relationships, confidence tracking, JSON export, and regeneration from source notes without losing reviewed decisions (`nous_requirements_and_user_flows.md:169-179`).
- The vault contract sends graph exports to `vault/04_generated/` and already reserves `vault/04_generated/graph/` for repeatable generated graph outputs (`docs/architecture/vault-schema.md:15-21`, `vault/04_generated/graph/AGENT.md:1-7`).
- `schemas/graph.schema.json` already defines the target export shape with `schema_version`, `generated_at`, `nodes`, and `edges` (`schemas/graph.schema.json:1-29`).
- M3 established canonical reviewed claims and relationships under `vault/03_canonical_model/claims/` and `vault/03_canonical_model/relationships/` (`docs/architecture/vault-schema.md:31-38`, `docs/architecture/vault-schema.md:104-111`).
- The current implementation style is dependency-free Ruby scripts with fixture-based regression tests wired through `make test` (`scripts/ingest_text.rb:1-9`, `scripts/test_review_queue.rb:1-23`, `Makefile:1-8`).

Scope assumption:

- The first M4 export should include reviewed notes from `vault/02_notes/`, canonical claims from `vault/03_canonical_model/claims/`, and canonical relationships from `vault/03_canonical_model/relationships/`.
- Pending inbox items are out of scope for the default export. A future `--include-inbox` or hypothesis graph mode can add non-canonical records after the reviewed-only export is stable.
- M4 exports existing reviewed graph facts; it does not create new semantic nodes, infer new relationships, or summarize the user's identity.

## Acceptance Criteria

- `ruby scripts/export_graph.rb` writes a JSON graph export to `vault/04_generated/graph/nous_graph.json` by default.
- The command supports `--vault-root PATH` so tests and future callers can run against temporary vaults.
- The command supports `--output PATH` so callers can choose a different export destination.
- The command writes `schema_version: "0.1"`, an ISO-8601 UTC `generated_at`, a `nodes` array, and an `edges` array matching the existing graph schema keys (`schemas/graph.schema.json:7-29`).
- `NOUS_GRAPH_TIME` can override `generated_at` during tests; invalid timestamps fail clearly.
- Reviewed notes under `vault/02_notes/*/*.md` become graph nodes when their frontmatter has `review_status: reviewed`, non-archived `status`, a non-empty `id`, and a schema-supported node `type`.
- Canonical claims under `vault/03_canonical_model/claims/*.md` become graph nodes when their frontmatter has `review_status: reviewed`, non-archived `status`, and `type: claim`.
- Pending inbox notes, claims, and relationships under `vault/01_agent_inbox/` are excluded from the default export even when they have valid-looking frontmatter.
- Rejected, deprecated, archived, or malformed records are excluded or fail according to the validation rules below, but are never silently exported as active graph records.
- Each exported node includes `id`, `type`, `label`, `review_status`, `evidence`, and optional `confidence`, `summary`, and `source_path` when present and valid.
- Node `label` is deterministic: prefer the first Markdown H1 in the body, then a non-empty frontmatter `title` if present, then the record ID.
- Node `summary` is deterministic and bounded: use the first non-empty non-heading body line, trimmed to a documented length, or omit it.
- Canonical relationship files under `vault/03_canonical_model/relationships/*.md` become graph edges when their frontmatter has `review_status: reviewed`, non-archived `status`, `type: relationship`, a non-empty edge `id`, and a `relationship` object with `from`, `to`, and supported `type`.
- Exported edge endpoints must reference exported node IDs. Missing endpoints fail the command with a clear error instead of writing a dangling graph by default.
- Duplicate node IDs or duplicate edge IDs fail the command with a clear error and do not write a partial export.
- Output ordering is stable: nodes sort by `id`, edges sort by `id`, and evidence arrays preserve source order after duplicate evidence entries are removed.
- Running the export twice against the same vault and fixed `NOUS_GRAPH_TIME` produces byte-identical JSON.
- `ruby scripts/test_export_graph.rb`, `make test`, and `make lint` pass after implementation.
- README usage docs explain the reviewed-only default and the output path.

## Implementation Steps

1. Clarify the graph export contract before writing export code.
   - Update `docs/architecture/vault-schema.md` with an M4 graph export section that states default exports are reviewed-only and generated from `vault/02_notes/`, `vault/03_canonical_model/claims/`, and `vault/03_canonical_model/relationships/`.
   - Confirm `schemas/graph.schema.json` still matches the planned output shape: node `type` enum, edge `relationship` enum, evidence refs, optional `confidence`, optional `summary`, and optional `source_path` (`schemas/graph.schema.json:44-115`).
   - Only change `schemas/graph.schema.json` if tests prove a real mismatch; avoid schema churn before the exporter exists.

2. Implement `scripts/export_graph.rb` as a dependency-free Ruby CLI.
   - Follow the existing script style: standard library only, `Pathname`, `OptionParser`, `Psych`, `JSON`, explicit errors, and a top-level `GraphExportError` (`scripts/ingest_text.rb:1-14`, `scripts/review_queue.rb:1-44`).
   - Add options for `--vault-root PATH`, `--output PATH`, and `--pretty` only if pretty output is not the default; prefer deterministic pretty JSON by default for reviewability.
   - Parse Markdown frontmatter with a local helper equivalent to the M3 parser (`scripts/review_queue.rb:161-180`).
   - Discover reviewed note files from direct child directories of `vault/02_notes/`, excluding `AGENT.md`.
   - Discover canonical claim files from `vault/03_canonical_model/claims/`, excluding `AGENT.md`.
   - Discover canonical relationship files from `vault/03_canonical_model/relationships/`, excluding `AGENT.md`.
   - Filter records to reviewed, non-archived items; do not export inbox files by default.
   - Normalize evidence refs to `{ "id": "...", "path": "..." }`, drop invalid empty refs, and deduplicate by `[id, path]`.
   - Validate confidence as numeric `0..1` when present; fail clearly when an exported record has an invalid confidence value.
   - Build the final hash as `{ "schema_version" => "0.1", "generated_at" => timestamp, "nodes" => nodes, "edges" => edges }`.
   - Write to a temporary file in the output directory and move into place only after validation passes, so failures do not leave a partial graph export.

3. Define strict-but-useful validation rules.
   - Fail on duplicate node IDs and edge IDs.
   - Fail on an exported relationship whose `from` or `to` endpoint is not present in the exported node ID set.
   - Fail on unsupported node types or relationship types rather than inventing new schema values.
   - Fail on missing required frontmatter for records that otherwise live in reviewed/canonical export directories.
   - Skip non-Markdown files and `AGENT.md` signposts.
   - Keep rejected, deprecated, archived, and pending records out of the export without treating their mere presence as an error.

4. Add focused regression coverage in `scripts/test_export_graph.rb`.
   - Build temporary fixture vaults with one reviewed memory, one canonical claim, one canonical relationship, one pending inbox note, one rejected note, and one referenced evidence path.
   - Verify the exported JSON has the expected top-level keys, deterministic `generated_at`, sorted nodes, sorted edges, labels, evidence refs, confidence values, and source paths.
   - Verify pending inbox records are excluded by default.
   - Verify rejected/deprecated/archived records are excluded.
   - Verify duplicate node IDs fail without writing or changing the previous output.
   - Verify duplicate edge IDs fail.
   - Verify unsupported node type and unsupported relationship type fail.
   - Verify dangling edge endpoints fail.
   - Verify invalid `NOUS_GRAPH_TIME` fails.
   - Verify repeated runs with fixed `NOUS_GRAPH_TIME` are byte-identical.

5. Wire the exporter into repository commands and docs.
   - Update `Makefile` so `make test` runs `ruby scripts/test_export_graph.rb` after existing ingestion and review-queue tests (`Makefile:1-8`).
   - Update `README.md` with `ruby scripts/export_graph.rb`, default output path, and reviewed-only semantics.
   - Update `scripts/AGENT.md` to list `export_graph.rb` and `test_export_graph.rb`.
   - Update `vault/04_generated/graph/AGENT.md` to list the expected generated `nous_graph.json` output once it exists.
   - If implementation creates additional directories, add or update signposts so `make lint` continues to pass (`scripts/lint.sh:48-54`).

6. Regenerate and inspect the default graph output.
   - Run `ruby scripts/export_graph.rb` against the repository vault.
   - Commit `vault/04_generated/graph/nous_graph.json` only if the current vault produces a meaningful deterministic artifact; otherwise keep `.gitkeep` and document that the output appears once reviewed records exist.
   - Confirm the generated graph does not include `vault/01_agent_inbox/` records by default.

## Risks and Mitigations

- Risk: Export code accidentally treats unreviewed inbox items as canonical graph data.
  Mitigation: Restrict default discovery to `vault/02_notes/`, `vault/03_canonical_model/claims/`, and `vault/03_canonical_model/relationships/`; add an explicit regression test with an inbox record.

- Risk: The exporter creates a graph with dangling edges because a relationship references a missing node.
  Mitigation: Validate every exported edge endpoint against the exported node ID set and fail before writing output.

- Risk: Duplicate IDs make graph consumers unstable.
  Mitigation: Fail on duplicate node and edge IDs with exact file paths in the error message.

- Risk: JSON Schema validation would require a new dependency.
  Mitigation: Do not add a JSON Schema gem for M4. Use Ruby stdlib `JSON.parse` plus targeted tests for required fields, enums, ID uniqueness, and endpoint integrity.

- Risk: Label and summary extraction becomes an accidental summarization feature.
  Mitigation: Use deterministic text extraction only: H1 for label and the first non-empty non-heading line for summary. Do not call an LLM or infer meaning.

- Risk: The generated graph output drifts from source vault records.
  Mitigation: Make `export_graph.rb` fully regenerable from Markdown frontmatter/body and keep no separate graph state.

## Verification Steps

- Run `ruby scripts/test_export_graph.rb`.
- Run `make test`.
- Run `make lint`.
- Run `ruby scripts/export_graph.rb --vault-root PATH_TO_FIXTURE --output PATH_TO_TMP_JSON` in a fixture and inspect the generated `nodes` and `edges`.
- Run `ruby scripts/export_graph.rb` against the repository vault and confirm the output path is `vault/04_generated/graph/nous_graph.json` when reviewed data exists.
- Parse the generated JSON with Ruby stdlib `JSON.parse`.
- Confirm no default export node or edge path comes from `vault/01_agent_inbox/`.
- Confirm `git status --short` contains only intended M4 files and generated artifacts.

## Suggested Execution Handoff

For `$ralph`:

- Use one executor lane for `scripts/export_graph.rb` and graph validation.
- Use one test-engineer lane for `scripts/test_export_graph.rb`, deterministic fixtures, and failure-path coverage.
- Use one writer lane only if documentation/schema updates become non-trivial; otherwise keep docs with the executor.
- Keep implementation reasoning at medium and verification reasoning at high because the main failure modes are trust-boundary leakage, duplicate IDs, and dangling graph edges.

For `$team`:

- Executor 1 owns `scripts/export_graph.rb`, output writing, discovery, validation, and deterministic ordering.
- Test-engineer owns `scripts/test_export_graph.rb` and `Makefile` test wiring.
- Writer owns `README.md`, `docs/architecture/vault-schema.md`, `scripts/AGENT.md`, and `vault/04_generated/graph/AGENT.md`.
- Verifier owns final `make test`, `make lint`, fixture inspection, and generated JSON sanity checks.

Launch hint:

```sh
omx team --task ".omx/plans/m4-graph-export-plan.md"
```

Team verification path:

- Team proves reviewed-only graph discovery, stable node export, stable edge export, duplicate detection, dangling-edge rejection, deterministic output, docs alignment, and full test/lint pass.
- Ralph or the leader then verifies the graph export remains local-first, dependency-free, and strictly generated from reviewed/canonical vault records.
