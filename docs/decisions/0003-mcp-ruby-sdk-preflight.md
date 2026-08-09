# 0003. Select the Official Ruby MCP SDK for Local Stdio

## Decision

Use the official `mcp` Ruby gem as the planned M7F protocol adapter dependency, with the following M7A preflight baseline:

- gem: `mcp` 1.1.0;
- source: `modelcontextprotocol/ruby-sdk`, published through RubyGems with signed provenance;
- license: Apache-2.0;
- required Ruby: `>= 2.7.0`;
- tested Ruby: 3.4.2;
- tested RubyGems: 3.6.3;
- tested Bundler: 2.6.3;
- stable protocol: `2025-11-25`, pinned explicitly in server configuration;
- transport: local stdio;
- capabilities: tools only.

M7A does not add this dependency to the product. M7F must repeat the preflight and pin the then-approved exact version in the repository dependency files.

## Context

Nous currently uses Ruby standard library code only. M7 will eventually expose a narrow agent integration surface, so the official SDK, stable protocol, raw stdio framing, structured tool results, and Codex client path must be proven before product code is designed around them.

The planning assumption was `mcp` 1.0.0. At execution time, RubyGems identified 1.1.0 as the current official release, still requiring Ruby `>= 2.7.0`. The official repository documents stdio server/client support, explicit protocol configuration, output schemas, structured content, and server-side result validation.

## Preflight Method

On 2026-08-08 in the local timezone, a throwaway directory outside the repository contained a temporary Gemfile pinned to `mcp` 1.1.0, a lockfile, a tools-only echo server, and two clients. No Gemfile, lockfile, spike server, or Codex configuration was added to Nous.

The proof server:

- registered one synthetic read-only, idempotent, closed-world echo tool;
- declared an input schema and output schema;
- returned both compatibility text content and `structuredContent`;
- enabled SDK result validation;
- pinned protocol `2025-11-25`;
- used `MCP::Server::Transports::StdioTransport`;
- wrote diagnostics only to stderr.

The proof ran through:

1. the official `MCP::Client::Stdio` client;
2. an independent raw JSON-RPC harness sending `initialize`, `notifications/initialized`, `tools/list`, and a successful `tools/call`;
3. Codex CLI 0.147.0 using ephemeral inline MCP configuration with user configuration ignored.

The commands were equivalent to:

```sh
bundle install
bundle exec ruby proof.rb
codex exec --ephemeral --ignore-user-config --sandbox read-only \
  -c 'mcp_servers.m7a_preflight.command="<bundle>"' \
  -c 'mcp_servers.m7a_preflight.args=["exec","<ruby>","<tmpdir>/server.rb"]' \
  -c 'mcp_servers.m7a_preflight.cwd="<tmpdir>"' \
  -c 'mcp_servers.m7a_preflight.required=true' \
  -c 'mcp_servers.m7a_preflight.default_tools_approval_mode="auto"' \
  '<call the synthetic echo tool>'
```

## Results

- Dependency resolution succeeded on Ruby 3.4.2 and Bundler 2.6.3.
- The resolved runtime bundle contained `mcp` 1.1.0, `json_schemer` 2.5.0, `bigdecimal` 4.1.2, `hana` 1.3.7, `regexp_parser` 2.12.0, and `simpleidn` 0.2.3. `base64` 0.3.0 was added explicitly for the throwaway Ruby 3.4 proof rather than by `mcp`.
- The official client initialized, listed `echo_tool`, called it, and received text plus `{ "echo": "hello" }` structured content.
- The raw client negotiated exactly `2025-11-25`, listed the tool, called it successfully, and received the same structured result.
- Every captured server stdout line was valid JSON-RPC JSON. Server boot and call diagnostics appeared on stderr.
- An `lsof` check found no TCP listener in the stdio server process.
- No model API key was configured or required by the server or either direct client proof. Dependency installation was the only network-dependent step; runtime protocol checks were local process I/O.
- Codex discovered `m7a_preflight`, called `echo_tool` with `codex-preflight`, received matching text and structured content, and returned `codex-preflight`.
- The Codex run was ephemeral, ignored user configuration, and received the server definition through command-line overrides, so it did not add or remove global or project MCP configuration.

## Consequences

- The planned M7F Ruby/stdout direction is feasible on the current runtime.
- The product server should pin the stable protocol explicitly instead of inheriting an SDK default that may advance.
- Tools should declare accurate read-only/destructive/idempotent/open-world annotations; Codex approval behavior uses this metadata and configured policy.
- Tools with output schemas should enable server-side result validation and return structured content plus compatibility text.
- Stdout is reserved for protocol frames. Diagnostics, warnings, and Bundler output must never be written there by the server process.
- No HTTP transport, listener, API key, model provider, prompt, resource, root, or sampling capability is needed for the planned tools-only local adapter.

## Alternatives Considered

- Keep the planning baseline on `mcp` 1.0.0 without rechecking the registry.
  - Rejected because 1.1.0 was the current official release at execution time and passed the required proof.
- Use an unofficial Ruby MCP package.
  - Rejected because the official `modelcontextprotocol/ruby-sdk` gem passed both identity and transport checks.
- Hand-roll JSON-RPC for the product server.
  - Rejected because the official SDK already supplies negotiation, schemas, validation, and stdio transport while the raw harness independently guards framing compatibility.
- Adopt the `2026-07-28` release candidate protocol.
  - Rejected because M7 targets the current stable `2025-11-25` protocol, and the later revision was still a release candidate during preflight.

## Verification and Revalidation Gate

Evidence sources:

- <https://rubygems.org/gems/mcp>
- <https://github.com/modelcontextprotocol/ruby-sdk>
- <https://github.com/modelcontextprotocol/modelcontextprotocol/releases/tag/2025-11-25>
- <https://developers.openai.com/codex/mcp>

This record is a feasibility proof, not a permanent version promise. Before M7F adds product dependency files, reverify the official gem identity, exact version, Ruby requirement, stable protocol support, dependency tree, stdout behavior, raw handshake, and Codex discovery/call.
