# Nous Core Signpost

Use this directory for cohesive Nous Core files shared by CLI adapters.

Current M7C-owned modules include:

- path confinement and symlink policy;
- vault-scoped shared/exclusive locking;
- destination-local atomic writes and rollback-safe transactions;
- collision allocation;
- text and artifact ingestion core mutations;
- review approve/reject/deprecate/merge mutations;
- relationship endpoint integrity checks.

Do not add MCP adapters, agent write APIs, request IDs, idempotency metadata, network calls, or editor/shell execution here. `$EDITOR` launch remains an adapter concern in `scripts/review_queue.rb`.
