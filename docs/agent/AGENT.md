# Agent Docs Signpost

Use this directory for contracts that describe mutation-free agent read semantics over a Nous vault.

Direct children:

- `read-contract.md` - M7D core read operation contract for `status`, `list_records`, `read_record`, and `read_source_text`.
- `archivist-contract.md` - M7E behavior and trust contract for direct core capture and candidate proposal operations.

Do not document MCP availability, protocol adapters, model calls, or network
behavior here. M7E may document direct core request IDs, idempotency, and
candidate mutation semantics without claiming M7F availability.

When updating this directory, keep examples and contracts path-safe:

- describe records by stable IDs and vault-relative paths only;
- label user/source payloads as untrusted data;
- keep binary/image behavior as structured unavailability, not interpretation;
- document future adapters as consumers of core semantics, not as available M7D features.
