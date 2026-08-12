# Agent Docs Signpost

Use this directory for contracts that describe mutation-free agent read semantics over a Nous vault.

Direct children:

- `read-contract.md` - M7D core read operation contract for `status`, `list_records`, `read_record`, and `read_source_text`.

Do not document MCP availability, write tools, request IDs, idempotency, model calls, network behavior, or candidate mutation workflows here unless a later milestone explicitly adds them.

When updating this directory, keep examples and contracts path-safe:

- describe records by stable IDs and vault-relative paths only;
- label user/source payloads as untrusted data;
- keep binary/image behavior as structured unavailability, not interpretation;
- document future adapters as consumers of core semantics, not as available M7D features.
