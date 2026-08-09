# Scripts Signpost

Use this directory for dependency-free repository maintenance scripts. Do not add package-manager-specific tooling here unless the project has explicitly adopted that runtime.

Direct children:

- `export_graph.rb` - dependency-free graph export CLI for reviewed/canonical vault records.
- `ingest_artifact.rb` - dependency-free raw artifact ingestion CLI for writing, image, and project imports.
- `ingest_text.rb` - dependency-free text/Markdown ingestion into raw artifact and inbox draft notes.
- `generate_nous_report.rb` - dependency-free Markdown report CLI for reviewed Nous records and canonical support.
- `lint.sh` - repository lint for schemas, text hygiene, signposts, and scaffold boundaries.
- `review_queue.rb` - dependency-free review queue CLI for inbox notes, claims, and relationships.
- `test_cli_contracts.rb` - dependency-free cross-script CLI contract characterization tests.
- `test_export_graph.rb` - dependency-free regression tests for graph export behavior.
- `test_ingest_artifact.rb` - dependency-free regression tests for raw artifact ingestion behavior.
- `test_ingest_text.rb` - dependency-free regression tests for text ingestion behavior.
- `test_generate_nous_report.rb` - dependency-free regression tests for Nous report generation behavior.
- `test_nous_read_core.rb` - dependency-free direct tests for the side-effect-free read-only Nous Core.
- `test_review_queue.rb` - dependency-free regression tests for review queue state transitions.
