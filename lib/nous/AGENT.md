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

M7E adds direct core-only candidate validation, rendering, persisted idempotency,
verbatim user-text capture, and candidate note/claim/relationship mutations here.
The `mcp/` subdirectory is the M7F protocol adapter boundary over those public
core operations; its own signpost governs that directory.

Do not add MCP dependencies to core modules, network calls, model-provider
calls, or editor/shell execution here. `$EDITOR` launch remains an adapter
concern in `scripts/review_queue.rb`.
