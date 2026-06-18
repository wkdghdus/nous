# Scripts Signpost

Use this directory for dependency-free repository maintenance scripts. Do not add package-manager-specific tooling here unless the project has explicitly adopted that runtime.

Direct children:

- `ingest_text.rb` - dependency-free text/Markdown ingestion into raw artifact and inbox draft notes.
- `lint.sh` - repository lint for schemas, text hygiene, signposts, and scaffold boundaries.
- `test_ingest_text.rb` - dependency-free regression tests for text ingestion behavior.
