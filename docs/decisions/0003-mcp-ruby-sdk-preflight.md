# 0003. Select the Official Ruby MCP SDK for Local Stdio

## Decision

Use the official `mcp` Ruby gem for the released M7F protocol adapter:

- gem: `mcp` 1.5.1, pinned exactly;
- explicit runtime companion: `base64` 0.3.0, pinned exactly for Ruby 3.4;
- source: `modelcontextprotocol/ruby-sdk`, published through RubyGems with signed provenance;
- license: Apache-2.0;
- required Ruby: `>= 2.7.0`;
- tested Ruby: 3.4.2;
- tested Bundler: 2.6.3;
- M7 handshake target: `2025-11-25`, pinned explicitly in server configuration;
- current upstream protocol release at revalidation: `2026-07-28`;
- transport: local stdio;
- capabilities: tools only, with server-side result validation.

The upstream current protocol and the product compatibility target are distinct:
M7 does not silently advance its handshake when the SDK or protocol site does.

## Context

Nous originally used Ruby standard library code only. M7F adds the official SDK
as a narrow protocol adapter around existing core behavior. The adapter does
not own vault business rules.

The M7A proof used `mcp` 1.1.0. M7F revalidated and pinned the then-current
official release, 1.5.1, which still requires Ruby `>= 2.7`. The official
repository provides stdio server/client support, explicit protocol
configuration, output schemas, structured content, and server-side result
validation.

## Preflight Method

The initial throwaway proof ran on 2026-08-08. M7F dependency and protocol facts
were revalidated on 2026-09-10 before the product dependencies were pinned.

The proof server:

- registered one synthetic read-only, idempotent, closed-world echo tool;
- declared an input schema and output schema;
- returned both compatibility text content and `structuredContent`;
- enabled SDK result validation;
- pinned protocol `2025-11-25`;
- used `MCP::Server::Transports::StdioTransport`;
- wrote diagnostics only to stderr.

The initial proof ran through:

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

## Dependency, License, and Provenance Record

The committed lock resolves this runtime tree:

```text
mcp 1.5.1 (Apache-2.0)
└── json_schemer 2.5.0 (MIT)
    ├── bigdecimal 4.1.2 (Ruby OR BSD-2-Clause)
    ├── hana 1.3.7 (MIT)
    ├── regexp_parser 2.12.0 (MIT)
    └── simpleidn 0.3.0 (MIT)

base64 0.3.0 (Ruby OR BSD-2-Clause; explicit dependency)
```

The lock also records the `arm64-darwin-24` and `ruby` platforms and Bundler
2.6.3. `mcp` provenance is RubyGems plus the official
`modelcontextprotocol/ruby-sdk` source repository. The other gemspec source
links are:

- `ruby/base64`
- `ruby/bigdecimal`
- `tenderlove/hana`
- `davishmcclurg/json_schemer`
- `ammar/regexp_parser`
- `mmriis/simpleidn`

Dependency installation may require registry/network access. The installed
server runtime remains local stdio and opens no network listener.

## Results

- Dependency resolution succeeded on Ruby 3.4.2 and Bundler 2.6.3.
- The M7F lock contains `mcp` 1.5.1 and the exact runtime tree recorded above.
  `base64` 0.3.0 is explicit rather than an `mcp` transitive dependency.
- The official client initialized, listed `echo_tool`, called it, and received text plus `{ "echo": "hello" }` structured content.
- The raw client negotiated exactly `2025-11-25`, listed the tool, called it successfully, and received the same structured result.
- Every captured server stdout line was valid JSON-RPC JSON. Server boot and call diagnostics appeared on stderr.
- An `lsof` check found no TCP listener in the stdio server process.
- No model API key was configured or required by the server or either direct client proof. Dependency installation was the only network-dependent step; runtime protocol checks were local process I/O.
- Codex discovered `m7a_preflight`, called `echo_tool` with `codex-preflight`, received matching text and structured content, and returned `codex-preflight`.
- The Codex run was ephemeral, ignored user configuration, and received the server definition through command-line overrides, so it did not add or remove global or project MCP configuration.

## Consequences

- The M7F Ruby/stdout direction is implemented against an exact dependency lock.
- The product server pins `2025-11-25` instead of inheriting the current SDK or
  upstream protocol default.
- Tools should declare accurate read-only/destructive/idempotent/open-world annotations; Codex approval behavior uses this metadata and configured policy.
- Tools with output schemas should enable server-side result validation and return structured content plus compatibility text.
- Stdout is reserved for protocol frames. Diagnostics, warnings, and Bundler output must never be written there by the server process.
- No HTTP/SSE transport, listener, API key, model provider, frontend, prompt,
  resource, root, sampling, elicitation, or task capability belongs in the
  tools-only local adapter.

## Alternatives Considered

- Keep the earlier `mcp` 1.1.0 preflight version.
  - Rejected because 1.5.1 was the current official release at M7F
    revalidation and passed the dependency/protocol checks.
- Use an unofficial Ruby MCP package.
  - Rejected because the official `modelcontextprotocol/ruby-sdk` gem passed both identity and transport checks.
- Hand-roll JSON-RPC for the product server.
  - Rejected because the official SDK already supplies negotiation, schemas, validation, and stdio transport while the raw harness independently guards framing compatibility.
- Adopt the upstream `2026-07-28` protocol immediately.
  - Rejected because M7's tested compatibility contract is `2025-11-25`.
    Upstream publication does not replace a product handshake target without a
    deliberate compatibility change.

## Verification and Revalidation Gate

Evidence sources:

- <https://rubygems.org/gems/mcp>
- <https://github.com/modelcontextprotocol/ruby-sdk>
- <https://github.com/modelcontextprotocol/modelcontextprotocol/releases/tag/2025-11-25>
- <https://modelcontextprotocol.io/specification/2026-07-28>
- <https://developers.openai.com/codex/mcp>

M7F revalidated the SDK identity, exact version, Ruby requirement, dependency
tree, licenses, provenance, and `2025-11-25` official-client/raw-stdio
handshake. Client configuration syntax is separately version-dependent: every
Codex or Inspector verification record must include the client name, exact
version output, date, configured command, and negotiated protocol. The M7F
release documentation does not claim that a manual release scenario or every
client-version gate has passed.
