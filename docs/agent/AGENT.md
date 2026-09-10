# Agent Docs Signpost

Use this directory for agent behavior, read semantics, and local MCP client
setup over a Nous vault.

Direct children:

- `read-contract.md` - M7D core read operation contract for `status`, `list_records`, `read_record`, and `read_source_text`.
- `archivist-contract.md` - behavior and trust contract for direct core and MCP capture/candidate proposal operations.
- `mcp-setup.md` - M7F local stdio server startup, inspection, client configuration, and removal guidance.

Document only the released local stdio MCP adapter. Do not imply network
transport, built-in model calls, or frontend availability.

When updating this directory, keep examples and contracts path-safe:

- describe records by stable IDs and vault-relative paths only;
- label user/source payloads as untrusted data;
- keep binary/image behavior as structured unavailability, not interpretation;
- keep the MCP adapter a consumer of core semantics, never a second source of business rules.
