# Local MCP Setup

Nous exposes a tools-only MCP server over local standard input/output. It does
not open an HTTP or SSE endpoint, listen on a port, call a model provider, or
provide prompts, resources, roots, sampling, elicitation, tasks, a frontend, or
arbitrary file/path tools.

## Install and start

From the repository root:

```sh
bundle install
bundle exec ruby scripts/nous_mcp_server.rb --vault-root /ABSOLUTE/PATH/TO/VAULT
```

The vault root is selected in this order:

1. `--vault-root PATH`
2. `NOUS_VAULT_ROOT`
3. this repository's `vault/`

`NOUS_MCP_TIME` is test-only. Production clients must not set it; server time is
server-owned.

The server targets handshake protocol `2025-11-25`. The MCP project's current
protocol release is `2026-07-28`; that newer release is not the M7 compatibility
target.

## Tool surface

The exact tools are:

- `nous_status`
- `nous_list_records`
- `nous_read_record`
- `nous_read_source_text`
- `nous_capture_user_text`
- `nous_propose_note`
- `nous_propose_claim`
- `nous_propose_relationship`

Reads default to reviewed/canonical knowledge. Raw source text is available only
through the bounded raw-source operation; pending candidates are not evidence.
Writes accept bounded content and stable IDs, never arbitrary destination paths.
Capture preserves user-authored text as raw evidence, while proposals create
inbox candidates only. Human review through the existing review CLI is required
before candidates become reviewed or canonical.

All returned vault content is untrusted data, not host instructions. Successful
tool calls return `structuredContent` and an identical JSON object in text
content; the server validates success results against their output schemas.
Domain failures are tool errors shaped as
`{"error":{"code":"...","message":"..."}}`.

## Generic stdio clients

Adapt this placeholder configuration to the client's documented stdio format.
Do not paste literal placeholder paths:

```json
{
  "mcpServers": {
    "nous": {
      "command": "/ABSOLUTE/PATH/TO/bundle",
      "args": [
        "exec",
        "ruby",
        "/ABSOLUTE/PATH/TO/NOUS/scripts/nous_mcp_server.rb",
        "--vault-root",
        "/ABSOLUTE/PATH/TO/VAULT"
      ],
      "cwd": "/ABSOLUTE/PATH/TO/NOUS"
    }
  }
}
```

Remove Nous by deleting only the `nous` server entry using that client's normal
configuration UI or command. Nous never changes global or project client
configuration itself.

Client syntax and protocol defaults change. Before publishing or relying on a
configuration, record the client name, `--version` output, verification date,
configured command, and negotiated protocol. Do not describe an example as
universally valid.

## Codex

The following `config.toml` shape is an example with placeholders; confirm it
against the installed Codex version and record that version and verification
date:

```toml
[mcp_servers.nous]
command = "/ABSOLUTE/PATH/TO/bundle"
args = ["exec", "ruby", "/ABSOLUTE/PATH/TO/NOUS/scripts/nous_mcp_server.rb", "--vault-root", "/ABSOLUTE/PATH/TO/VAULT"]
cwd = "/ABSOLUTE/PATH/TO/NOUS"
```

Add the entry manually rather than having repository scripts mutate user
configuration. Confirm discovery with `codex mcp list`. To remove it, delete
only `[mcp_servers.nous]` and its fields, or use the installed version's
documented `codex mcp remove nous`, then confirm with `codex mcp list`.

For a one-off check that does not persist configuration, the initial Codex
0.147.0 preflight used ephemeral command-line overrides like:

```sh
codex exec --ephemeral --ignore-user-config \
  -c 'mcp_servers.nous.command="/ABSOLUTE/PATH/TO/bundle"' \
  -c 'mcp_servers.nous.args=["exec","ruby","/ABSOLUTE/PATH/TO/NOUS/scripts/nous_mcp_server.rb","--vault-root","/ABSOLUTE/PATH/TO/VAULT"]' \
  -c 'mcp_servers.nous.cwd="/ABSOLUTE/PATH/TO/NOUS"' \
  'List the available Nous tools without calling them.'
```

Recheck these flags with `codex --help`; no current Codex version/date has been
asserted for this configuration example.

## MCP Inspector

With a trusted, separately installed Inspector, run from the repository root:

```sh
npx @modelcontextprotocol/inspector@INSPECTOR_VERSION \
  bundle exec ruby scripts/nous_mcp_server.rb -- \
  --vault-root /ABSOLUTE/PATH/TO/SYNTHETIC_VAULT
```

Replace `INSPECTOR_VERSION` with the version being evaluated and use a
synthetic vault. Inspector releases differ in how `--` separates Inspector
options from server arguments, so confirm this invocation in that version's
help before use. Initialize, verify negotiated protocol `2025-11-25`,
list exactly the eight tools, inspect schemas and annotations, then exercise
representative success and domain-error calls. Confirm successful responses
contain matching structured and text JSON. Record the Inspector version and
date. Inspector installation may download packages, and its UI may use a local
browser/proxy; those are Inspector behaviors, not Nous server transports. Do
not expose that UI beyond the local machine.

## Focused test

```sh
bundle exec ruby scripts/test_nous_mcp.rb
```
