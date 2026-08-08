# Test Spec: M4 Graph Export

## Test Strategy

Use dependency-free Ruby fixture tests that create temporary vaults and run `scripts/export_graph.rb` through `Open3.capture3`. Keep fixtures small, explicit, and isolated so both success and failure paths can prove output behavior.

## Required Coverage

- Success export includes expected top-level keys: `schema_version`, `generated_at`, `nodes`, `edges`.
- Reviewed active note nodes export with `id`, `type`, `label`, `review_status`, `evidence`, `confidence`, `summary`, and `source_path`.
- Canonical claim nodes export from `vault/03_canonical_model/claims/`.
- Canonical relationship edges export from `vault/03_canonical_model/relationships/`.
- Pending inbox records are excluded by default.
- Rejected, deprecated, and archived records are excluded.
- Node and edge arrays sort by `id`.
- Evidence arrays preserve first-seen order after duplicate evidence refs are removed.
- Labels prefer body H1, then frontmatter `title`, then ID.
- Summaries use the first non-empty non-heading body line and are bounded.
- `NOUS_GRAPH_TIME` produces deterministic `generated_at`.
- Invalid `NOUS_GRAPH_TIME` fails clearly.
- Duplicate node IDs fail without writing or changing an existing output.
- Duplicate edge IDs fail.
- Unsupported node types fail for otherwise exportable records.
- Unsupported relationship types fail for otherwise exportable records.
- Dangling edge endpoints fail.
- Repeated runs with fixed time are byte-identical.

## Command Coverage

- Direct test: `ruby scripts/test_export_graph.rb`
- Full regression: `make test`
- Repository hygiene: `make lint`
- Manual/smoke export: `ruby scripts/export_graph.rb`

## Completion Standard

The feature is complete when direct export tests, full tests, lint, default repository export smoke, architect verification, deslop pass, and post-deslop regression all pass.
