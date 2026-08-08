# Scripts Signpost

Use this directory for dependency-free repository maintenance scripts. Do not add package-manager-specific tooling here unless the project has explicitly adopted that runtime.

Direct children:

- `export_graph.rb` - dependency-free graph export CLI for reviewed/canonical vault records.
- `ingest_text.rb` - dependency-free text/Markdown ingestion into raw artifact and inbox draft notes.
- `generate_nous_report.rb` - dependency-free Markdown report CLI for reviewed Nous records and canonical support.
- `lint.sh` - repository lint for schemas, text hygiene, signposts, and scaffold boundaries.
- `review_queue.rb` - dependency-free review queue CLI for inbox notes, claims, and relationships.
- `test_export_graph.rb` - dependency-free regression tests for graph export behavior.
- `test_ingest_text.rb` - dependency-free regression tests for text ingestion behavior.
- `test_generate_nous_report.rb` - dependency-free regression tests for Nous report generation behavior.
- `test_review_queue.rb` - dependency-free regression tests for review queue state transitions.
