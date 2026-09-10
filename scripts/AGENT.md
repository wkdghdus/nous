# Scripts Signpost

Use this directory for repository maintenance CLIs and the one SDK-backed local
MCP stdio adapter. Keep every other script dependency-free.

Direct children:

- `export_graph.rb` - dependency-free graph export CLI for reviewed/canonical vault records.
- `ingest_artifact.rb` - dependency-free raw artifact ingestion CLI for writing, image, and project imports.
- `ingest_text.rb` - dependency-free text/Markdown ingestion into raw artifact and inbox draft notes.
- `generate_nous_report.rb` - dependency-free Markdown report CLI for reviewed Nous records and canonical support.
- `lint.sh` - repository lint for schemas, text hygiene, signposts, and scaffold boundaries.
- `review_queue.rb` - dependency-free review queue CLI for inbox notes, claims, and relationships.
- `nous_mcp_server.rb` - Bundler-launched, tools-only local stdio MCP server over Nous Core.
- `test_cli_contracts.rb` - dependency-free cross-script CLI contract characterization tests.
- `test_export_graph.rb` - dependency-free regression tests for graph export behavior.
- `test_ingest_artifact.rb` - dependency-free regression tests for raw artifact ingestion behavior.
- `test_ingest_text.rb` - dependency-free regression tests for text ingestion behavior.
- `test_generate_nous_report.rb` - dependency-free regression tests for Nous report generation behavior.
- `test_nous_mutation_core.rb` - dependency-free direct tests for M7C path, lock, write, transaction, ingestion, review, relationship, and coherent read/write safety.
- `test_nous_read_core.rb` - dependency-free direct tests for the side-effect-free read-only Nous Core.
- `test_nous_candidate_writes.rb` - dependency-free direct tests for M7E capture, candidate writes, idempotency, rendering, lifecycle, and concurrency.
- `test_nous_mcp.rb` - official-client and independent raw-stdio tests for the M7F MCP boundary.
- `test_review_queue.rb` - dependency-free regression tests for review queue state transitions.

M7C CLI scripts should remain thin adapters: they own option parsing, environment-variable precedence, stdout/stderr prefixes, path presentation, and `$EDITOR` launch. Core modules under `lib/nous/` own vault mutation rules, locking, atomic writes, and relationship endpoint integrity.

The MCP entrypoint must keep stdout protocol-only, expose exactly the approved
eight tools, and delegate every business operation directly to Nous Core.
