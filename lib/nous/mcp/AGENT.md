# Nous MCP Adapter Signpost

This directory contains the thin, local-stdio MCP adapter for Nous Core.

- `server.rb` builds and runs the tools-only MCP server.
- `tools.rb` declares the eight public tools and their protocol schemas.
- `tool_result.rb` serializes equivalent structured and compact JSON results.
- `error_mapper.rb` converts sanitized `Nous::Error` values into MCP tool errors.

Keep protocol and presentation concerns here. Business rules stay in Nous Core.
Never add arbitrary path access, review/approval authority, model calls, or
network transports to this adapter.
