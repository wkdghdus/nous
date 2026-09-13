# Test Specification: M7F MCP Adapter and Release Gate

Status: Draft verification contract

Date: 2026-08-08

Plan: `m7f-mcp-adapter-and-release-plan.md`

Depends on: M7A-M7E green

## 1. Test Strategy

M7F tests only the adapter/protocol/release boundary exhaustively enough to prove correct mapping. Domain edge cases remain covered by M7D/E direct tests.

Use two client paths:

1. official Ruby MCP client for normal behavior;
2. independent raw stdio JSON-RPC harness for framing, capability, and error hygiene.

No test requires a model provider or network.

## 2. Required Test Program

Add:

```sh
bundle exec ruby scripts/test_nous_mcp.rb
```

It must spawn the real server entrypoint in subprocesses against temporary vaults.

## 3. Dependency and Startup Tests

### DEP-F-001: Official gem identity

Gem metadata/source matches official Ruby SDK.

### DEP-F-002: Exact lock

`Gemfile.lock` pins selected SDK/transitives; no floating branch/git dependency.

### DEP-F-003: Ruby compatibility

Current runtime satisfies gem requirement.

### DEP-F-004: Dependency scope

No Rails/Sinatra/application server/model provider added unintentionally.

### MCP-F-001: Valid startup

Server initializes against temporary vault.

### MCP-F-002: Explicit protocol

Negotiated protocol exactly selected stable revision.

### MCP-F-003: Tools-only capability

No prompts/resources/roots/sampling/elicitation/tasks capability.

### MCP-F-004: Missing vault

Sanitized startup failure; no stdout contamination.

### MCP-F-005: File instead of directory

Fails.

### MCP-F-006: Invalid `NOUS_MCP_TIME`

Fails safely before serving.

### MCP-F-007: Argument/environment precedence

`--vault-root` > env > default as documented.

### MCP-F-008: Startup speed smoke

Within local NFR target after dependencies installed.

### MCP-F-009: No listener

No TCP/Unix network listener beyond stdio pipes.

### MCP-F-010: No API key

Unset common provider keys; server works.

### MCP-F-011: No startup mutation

Vault snapshot unchanged.

## 4. Tool Discovery Tests

### SCHEMA-F-001: Exact tool names

Exactly eight, no aliases:

```text
nous_status
nous_list_records
nous_read_record
nous_read_source_text
nous_capture_user_text
nous_propose_note
nous_propose_claim
nous_propose_relationship
```

### SCHEMA-F-002: No dangerous equivalents

No tool description/name exposes approve, reject, deprecate, merge, delete, canonicalize, edit reviewed, arbitrary path/file, shell, command.

### SCHEMA-F-003: Root object strictness

Every input schema root object with `additionalProperties: false`.

### SCHEMA-F-004: Required fields

Exact mapping to M7D/E.

### SCHEMA-F-005: Bounds/enums/patterns

Compare tool schemas to core constants for all:

- limits;
- string lengths;
- request pattern;
- candidate types;
- basis values;
- relationship types;
- confidence;
- arrays/uniqueness;
- dates.

### SCHEMA-F-006: Output schema present

Every tool.

### SCHEMA-F-007: Successful result validation enabled

Inject/test a deliberately invalid synthetic result through isolated tool fixture or configuration introspection and assert SDK rejects it; do not corrupt product core.

### SCHEMA-F-008: Descriptions state boundaries

Untrusted content, reviewed-only defaults, candidate-only writes, no arbitrary path.

### SCHEMA-F-009: Annotations

Read/write hints exactly appropriate.

### SCHEMA-F-010: Tools list deterministic

Repeated sessions same names/schemas/order where SDK guarantees order; compare normalized lists otherwise.

## 5. Representative Read Tool Calls

### CALL-F-001: `nous_status`

Empty and populated fixture; structured result matches direct core.

### CALL-F-002: `nous_list_records`

Default scopes and one lexical query; result matches direct core.

### CALL-F-003: `nous_read_record`

Reviewed note with bounded body/content labels.

### CALL-F-004: `nous_read_source_text`

M6 writing chunk and M2 embedded source; no arbitrary path.

### CALL-F-005: Read tools mutation-free

Snapshot before/after all calls.

### CALL-F-006: Extra property

Schema/protocol invalid params.

### CALL-F-007: Invalid bounds/enum

Rejected before/core consistently.

### CALL-F-008: Duplicate record/business error

Tool execution error with stable code, sanitized message.

## 6. Representative Write Tool Calls

### CALL-F-009: `nous_capture_user_text`

Raw artifact only, structured result equals direct core contract.

### CALL-F-010: `nous_propose_note`

Inbox only.

### CALL-F-011: `nous_propose_claim`

Inbox only.

### CALL-F-012: `nous_propose_relationship`

Inbox only, endpoint readiness.

### CALL-F-013: Same request replay

Second protocol call returns `replayed: true`, one record.

### CALL-F-014: Idempotency conflict

Stable tool error.

### CALL-F-015: Invalid evidence

Stable tool error; no file.

### CALL-F-016: Injection fixture

Record structure safe and result/logs sanitized.

### CALL-F-017: No canonical/generated write

Recursive manifest proves destinations limited to raw/inbox plus ignored runtime lock.

## 7. Structured Output Tests

### OUTPUT-F-001: Structured content present

Every successful tool.

### OUTPUT-F-002: Compatibility text JSON

Parses and equals structured content semantically.

### OUTPUT-F-003: No divergent prose

No extra success statement contradicting JSON.

### OUTPUT-F-004: No absolute path

Recursive scan.

### OUTPUT-F-005: Content labels

Present on body/source-bearing reads.

### OUTPUT-F-006: Write review fields

`requires_review`, lifecycle, replay, evidence/digest.

### OUTPUT-F-007: Output bounds

Protocol cannot bypass M7D/E limits.

## 8. Error Semantics Tests

### ERROR-F-001: Domain validation error

Tool execution error, stable Nous code.

### ERROR-F-002: Unknown tool

Protocol error, not Nous business error.

### ERROR-F-003: Malformed JSON

Protocol parse error; server remains usable where spec/SDK permits.

### ERROR-F-004: Invalid params type

Protocol/schema error.

### ERROR-F-005: Unexpected exception

Generic client error; sanitized stderr correlation; no body/backtrace on stdout.

### ERROR-F-006: Lock timeout

Stable tool error, server remains alive.

### ERROR-F-007: Path/source error

No absolute path leak.

### ERROR-F-008: Secret-shaped input error

Message/log does not echo secret.

## 9. Raw Stdio Hygiene Tests

The raw harness sends line-delimited/request framing exactly as required by selected SDK/spec.

### STDIO-F-001: Every nonempty stdout frame parses JSON

Across startup, calls, errors, shutdown.

### STDIO-F-002: No banner

First stdout content is protocol response/notification only.

### STDIO-F-003: No CLI prefix

No `artifact:`, `graph:`, `report:`, etc.

### STDIO-F-004: Diagnostics on stderr

Synthetic startup/tool diagnostics do not appear stdout.

### STDIO-F-005: Embedded newline content

JSON framing remains valid.

### STDIO-F-006: Maximum allowed input

Valid frame/result; no extra output.

### STDIO-F-007: Multiple sequential requests

Stable request IDs/responses.

### STDIO-F-008: Multiple server sessions

No leaked global state.

### STDIO-F-009: Graceful EOF/shutdown

Process exits without corrupt output/temp writes.

### STDIO-F-010: Cancellation/liveness minimum

If stable SDK supports cancellation, verify a cancelled long-enough synthetic/read operation does not corrupt server. Do not add artificial product long-running operations solely for this test.

## 10. Capability and Security Tests

### SEC-F-001: Prompt injection source

Returned as data, no tool execution/secondary call initiated by server.

### SEC-F-002: YAML/frontmatter injection proposal

Safe renderer.

### SEC-F-003: No arbitrary command execution

No schema/tool/core path.

### SEC-F-004: No arbitrary local file read

Attempt path-like fields/extra property; rejected.

### SEC-F-005: No network

Observe process/socket behavior during calls.

### SEC-F-006: No telemetry

Dependency/config/source inspection plus offline test.

### SEC-F-007: Log privacy

Capture stderr; assert no user text, statement, excerpts, evidence body, secrets, external absolute path.

### SEC-F-008: No API credential in environment required

Unset and run.

### SEC-F-009: Tool annotations are not sole enforcement

Directly attempt unsafe input; core rejects regardless of hints.

### SEC-F-010: Candidate-only surface

Tool list and resulting file destinations prove no review/canonical authority.

## 11. Client Integration Tests

### CLIENT-F-001: Official Ruby client

Initialize/list/call all eight at least once across suite.

### CLIENT-F-002: MCP Inspector

Manual or automated supported invocation:

- server launches;
- exact tools visible;
- representative read/write call succeeds;
- schemas/results inspect correctly;
- no unexpected capability.

Record tested Inspector version/date.

### CLIENT-F-003: Codex CLI discovery

Using tested configuration syntax and temporary/safe configuration:

- server appears;
- exact tools appear;
- status/read call succeeds;
- capture/propose call succeeds against temporary vault;
- config cleanup verified.

Record Codex version/date.

### CLIENT-F-004: Unsupported client surface

If Codex integration cannot be tested, M7F is not complete unless product owner explicitly accepts the documented gap. SDK/Inspector alone do not prove the intended agent host works.

## 12. Full Release Lifecycle

### E2E-F-001: MCP to human review to outputs

1. Start server on temporary vault.
2. `nous_status` empty.
3. `nous_capture_user_text` synthetic reflection.
4. `nous_read_source_text` verifies content.
5. `nous_propose_note` pattern.
6. `nous_propose_claim` source-backed claim.
7. `nous_propose_relationship` supports edge between pending endpoints.
8. `nous_status` shows pending counts.
9. Generate graph/report via existing CLIs; candidates absent.
10. Stop or keep server; approve note and claim via review CLI.
11. Relationship approval initially/then correctly succeeds once both endpoints active.
12. Generate graph/report; expected nodes/edge/report entries present.
13. Read reviewed/canonical records through MCP.
14. Retry original write tool calls; replay current paths, no duplicate.
15. Inspect raw source unchanged and provenance complete.

### E2E-F-002: Rejection/deprecation path

Create proposal through MCP, reject/deprecate through CLI, verify normal list exclusion and retry no duplicate.

### E2E-F-003: Concurrent MCP/CLI write

Run one MCP candidate write while CLI ingestion/review operation contends; lock prevents corruption and both results are coherent.

## 13. Regression Suite

All must pass:

```sh
bundle exec ruby scripts/test_nous_mcp.rb
ruby scripts/test_nous_candidate_writes.rb
ruby scripts/test_nous_agent_reads.rb
ruby scripts/test_nous_mutation_core.rb
ruby scripts/test_nous_read_core.rb
ruby scripts/test_cli_contracts.rb              # when present
ruby scripts/test_ingest_text.rb
ruby scripts/test_ingest_artifact.rb
ruby scripts/test_review_queue.rb
ruby scripts/test_export_graph.rb
ruby scripts/test_generate_nous_report.rb
make test
make lint
```

## 14. Repository and Dependency Audit

### AUDIT-F-001: Only approved dependency

Inspect direct dependencies; explain all transitive dependencies.

### AUDIT-F-002: Lockfile committed

Reproducible install.

### AUDIT-F-003: No `package.json`

Current repository boundary remains.

### AUDIT-F-004: No frontend/HTTP/model files

Search repository.

### AUDIT-F-005: Signposts

All new directories covered.

### AUDIT-F-006: README accurate

No “placeholders only” contradiction; no claim frontend/model exists.

### AUDIT-F-007: Worktree/privacy

No fixture payload, temp, lock, logs, Codex config, secret, absolute temp path.

### AUDIT-F-008: Diff hygiene

`git diff --check`, changed-files-only cleanup, post-cleanup full regression.

## 15. Pass Conditions

- Exact protocol/tool/schema/result contract passes.
- Raw stdout is clean.
- SDK client, raw harness, Inspector, and Codex work.
- Candidate-only/path-restricted boundary holds.
- Logs/errors are private.
- Full lifecycle works.
- All prior tests pass before and after cleanup.
- Repository docs/dependencies accurately reflect released state.

## 16. Failure Triage

- SDK/raw harness disagree: block release and fix framing/protocol.
- Tool schema accepts extra fields: fix schema before continuing.
- Output validation disabled/fails: fix mapping/core result, not validator.
- Stdout contamination: locate adapter/dependency warning; never ignore.
- Codex cannot launch: inspect tested config/command/runtime; do not claim completion.
- Business rule differs through MCP: remove adapter logic and map directly to core.
- Any canonical write/tool appears: fail release immediately.
