# M7F Release Evidence

Status: VERIFYING — automated and local protocol evidence captured; host/manual release gates remain open.

Date: 2026-09-13T17:46:05Z UTC
Revision: `d09f6ee00f716b2cae706662f5227c3bf2c77ce6`
Worktree: clean before and after evidence collection.

## Evidence captured

### Dependency/runtime

- Ruby: `3.4.2`
- Bundler: `2.6.3`
- Locked project dependencies are exercised through Bundler.
- MCP Inspector CLI: `2.6.0` (queried from npm; executed with `npx @modelcontextprotocol/inspector@latest`).
- Codex CLI: `0.153.4`.

### Automated M7F and regression verification

Command:

```sh
make test
```

Result: PASS for all wired suites.

- M7E candidate writes: `557 assertions`
- M7F MCP suite: `10 runs, 391 assertions, 0 failures, 0 errors, 0 skips`
- M2–M7E regression suites: PASS

Command:

```sh
bundle exec ruby scripts/test_nous_mcp.rb
```

Result: `10 runs, 391 assertions, 0 failures, 0 errors, 0 skips`.

Command:

```sh
git diff --check
```

Result: PASS / clean.

### Inspector CLI protocol evidence

Against a disposable empty synthetic vault, Inspector CLI connected to the real stdio server and returned:

- tool count: `8`
- exact names:
  - `nous_status`
  - `nous_list_records`
  - `nous_read_record`
  - `nous_read_source_text`
  - `nous_capture_user_text`
  - `nous_propose_note`
  - `nous_propose_claim`
  - `nous_propose_relationship`
- schema errors: `0`
- schema portability: `0 errors, 7 warnings across 3 tools`

A real Inspector `nous_status` call returned structured content and matching compatibility JSON for an empty vault:

- `vault_schema_version: 0.1`
- `record_count: 0`
- no warnings
- `isError: false`

The Inspector CLI invocation used only a disposable temporary vault. No real vault content was read or changed.

### Codex configuration evidence

No global Codex configuration was changed. Using ephemeral `--config` overrides, `codex mcp list` recognized the Nous server entry as enabled with the configured command, arguments, and repository working directory.

This proves configuration parsing/discovery of the entry, but not a real Codex model-session tool call.

## Remaining release-gate gaps

These cannot be honestly closed by repository-local automated tests alone:

1. Real Codex CLI session discovers the server and successfully calls representative read and write tools.
2. Full MCP-to-human-review-to-graph/report lifecycle against a synthetic vault, including review CLI transitions.
3. Concurrent MCP/CLI write scenario and final independent acceptance pass.
4. MCP Inspector interactive/manual evidence, if the release record requires the web UI rather than the supported CLI mode.

The existing M7F test suite covers protocol and raw-stdio behavior, but the M7F test specification explicitly treats Codex host verification and the full lifecycle as release gates.

## Current lint blocker

```sh
make lint
```

Result: FAIL, with:

```text
.omx/plans/nous-m8-planning-package: missing AGENT.md signpost
```

This is an M8 planning-package signpost issue, not an M7F source/test failure. It remains unresolved because changing M8 planning artifacts is outside the M7F scope.

## Verdict

M7F implementation and automated protocol boundary: **PASS**.

M7F final release gate: **VERIFYING / not yet complete**, pending Codex host proof, full lifecycle evidence, independent acceptance, and resolution or explicit disposition of the repository lint blocker.
