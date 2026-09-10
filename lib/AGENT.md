# Library Signpost

Use this directory for Ruby library code shared by local adapters. Nous Core
remains dependency-free; only the M7F MCP adapter loads the official SDK.

Direct children:

- `nous.rb` - side-effect-free Nous Core entrypoint and require wiring for shared core modules.
- `nous/` - cohesive Nous Core files plus the isolated `nous/mcp/` protocol adapter boundary.

M7C keeps CLI command parsing and presentation in `scripts/`, while core code owns vault confinement, lock coordination, atomic writes, ingestion behavior, review mutations, and relationship approval integrity.
