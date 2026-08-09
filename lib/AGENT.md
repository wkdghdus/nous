# Library Signpost

Use this directory for dependency-free Ruby library code shared by the CLI adapters.

Direct children:

- `nous.rb` - side-effect-free Nous Core entrypoint and require wiring for shared core modules.
- `nous/` - cohesive Nous Core files for read behavior, M7C path/lock/write safety primitives, ingestion mutations, and review mutations.

M7C keeps CLI command parsing and presentation in `scripts/`, while core code owns vault confinement, lock coordination, atomic writes, ingestion behavior, review mutations, and relationship approval integrity.
