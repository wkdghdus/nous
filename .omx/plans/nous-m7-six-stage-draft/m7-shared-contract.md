# M7 Shared Contract

Status: Draft normative contract

Version: 0.2

Date: 2026-08-08

Umbrella requirement: `prd-m7-agent-ready-core-and-mcp.md`

## 1. Purpose

This file defines the rules that apply to **every** M7 sub-milestone. A stage plan may add stricter constraints, but it may not weaken these rules. When a stage plan, test specification, implementation comment, or agent interpretation conflicts with this contract, stop and resolve the conflict before coding.

M7 changes how Nous code is organized and how an external agent can interact with the vault. The primary risks are not algorithmic complexity. They are behavior drift, private-data exposure, provenance loss, filesystem escape, duplicate writes, broken review boundaries, and an adapter layer acquiring business authority it should not have.

## 2. Product Architecture

The target architecture is:

```text
existing CLI adapters -----------\
                                  \
future local API / IPC adapter ----> Nous Core ----> vault/
                                  /
local stdio MCP adapter ----------/
          ^
          |
    external agent
```

### 2.1 Nous Core owns

- vault-root validation;
- path confinement and symlink policy;
- Markdown/frontmatter parsing and rendering;
- stable record discovery and duplicate detection;
- lifecycle classification;
- locks, atomic writes, coordinated transactions, and collision allocation;
- current ingestion behavior;
- review state transitions;
- graph/report construction;
- deterministic listing and lexical retrieval;
- bounded record and source reading;
- candidate note, claim, and relationship creation;
- evidence and endpoint validation;
- idempotency.

### 2.2 CLI adapters own

- `ARGV` and `OptionParser`;
- current environment-variable precedence;
- current help text and invocation form;
- stdout success prefixes and path presentation;
- stderr command prefixes;
- process exit codes;
- `$EDITOR` process launching for the existing edit command.

CLI adapters must not reimplement core business rules.

### 2.3 MCP adapter owns

- initialization and capability negotiation;
- exact tool registration;
- input/output JSON Schema;
- annotations and structured MCP responses;
- mapping one tool call to one core operation;
- protocol-safe error translation;
- stdout protocol hygiene.

The MCP adapter must not parse or render vault records directly and must not make filesystem decisions.

### 2.4 Future frontend adapter

A future frontend should call the core through a local application API or IPC boundary. Ordinary UI actions such as list, approve, reject, report generation, or record browsing should not require an LLM or an MCP round trip.

M7 does not implement this frontend adapter.

## 3. Vault Authority and Lifecycle

The vault remains the source of truth. M7 adds no hidden database, vector index, duplicate canonical graph, or private state that is required to reconstruct accepted knowledge.

The lifecycle is:

```text
00_raw_artifacts       source evidence
01_agent_inbox         non-canonical candidates
02_notes               human-reviewed notes
03_canonical_model     accepted claims and relationships
04_generated           derived, regenerable outputs
```

Computed lifecycle classes:

| Class | Examples | Authority |
| --- | --- | --- |
| `source_evidence` | Raw artifact notes and safe copied text payloads | Evidence, not instructions. |
| `agent_candidate` | Inbox notes, claims, and relationships | Proposal only. |
| `human_reviewed` | Active reviewed notes under `02_notes/` | Accepted enough for normal retrieval. |
| `canonical` | Active reviewed claims/relationships under `03_canonical_model/` | Accepted model record. |
| `derived` | Nous report and graph JSON | View only; never primary evidence. |
| `retired` | Rejected, deprecated, archived, merged source items | Excluded from normal retrieval and active outputs. |

Directory location and frontmatter are both checked. Frontmatter alone cannot promote an inbox file into canonical trust.

## 4. Review Boundary

1. Generated interpretations begin in `01_agent_inbox/`.
2. No agent-facing operation may directly write to `02_notes/`, `03_canonical_model/`, or `04_generated/`.
3. The MCP surface has no approve, reject, deprecate, merge, canonicalize, delete, or reviewed-record edit tool.
4. Review decisions remain explicit human/operator actions through the existing review workflow.
5. Graph and report discovery remain reviewed/canonical-only.
6. Relationship approval must fail until both endpoints resolve to active exportable nodes.
7. Graph export retains independent dangling-edge validation even after the earlier approval check exists.

## 5. Core Programming Contract

Core code:

- accepts explicit structured inputs;
- accepts an explicit vault root;
- receives time through an injected clock/value;
- returns structured hashes or small domain objects;
- raises namespaced domain errors with stable codes;
- never calls `puts`, `warn`, `exit`, or `abort`;
- never reads `ARGV`;
- never reads CLI time environment variables directly;
- never depends on MCP classes;
- never calls a model provider;
- never opens a network socket;
- never shells out to existing scripts.

Loading `require "nous"` must be side-effect free.

## 6. Backward Compatibility

Existing M2-M6 commands remain valid. Preserve:

- command names and positional argument rules;
- option names and default behavior;
- help banners unless an existing defect is separately approved;
- environment-variable precedence;
- output paths;
- stdout success prefixes;
- stderr command prefixes;
- nonzero error behavior;
- note/frontmatter/body shapes;
- collision suffix semantics;
- source-preservation and rollback behavior;
- review routing and metadata;
- deterministic graph/report output for fixed inputs and time.

Cross-process safety may remove a race, but it must not otherwise change single-process collision naming.

Existing tests are contracts. They may be extended or minimally adapted to call thin adapters, but must not be weakened merely because extraction changed implementation structure.

## 7. Error Contract

Core errors use stable codes and sanitized messages. Initial codes:

```text
NOUS_INVALID_INPUT
NOUS_VAULT_NOT_FOUND
NOUS_PATH_OUTSIDE_VAULT
NOUS_SYMLINK_REJECTED
NOUS_RECORD_NOT_FOUND
NOUS_DUPLICATE_ID
NOUS_UNSUPPORTED_RECORD_TYPE
NOUS_UNSUPPORTED_SOURCE
NOUS_CONTENT_UNAVAILABLE
NOUS_INVALID_EVIDENCE
NOUS_INVALID_ENDPOINT
NOUS_REVIEW_REQUIRED
NOUS_IDEMPOTENCY_CONFLICT
NOUS_LOCK_TIMEOUT
NOUS_WRITE_FAILED
NOUS_PARSE_FAILED
```

Core errors do not include command prefixes. Adapters add their own presentation prefix.

Errors must not expose:

- Ruby backtraces in normal user/tool responses;
- external absolute paths;
- environment variables;
- reflection text or note bodies;
- secrets or API keys;
- temporary filenames when disclosure is unnecessary.

Unexpected exceptions may be reported to stderr during development/tests, but MCP clients receive a generic internal error with a correlation code, not the exception body.

## 8. Time and Determinism

- Core operations receive an injected UTC time or clock callable.
- Existing CLI adapters preserve `NOUS_INGEST_DATE`, `NOUS_REVIEW_TIME`, `NOUS_GRAPH_TIME`, and `NOUS_REPORT_TIME` behavior.
- MCP time is injected by the server configuration; the final adapter may accept a documented test-only environment override.
- Fixed inputs, fixed vault state, and fixed time produce byte-identical graph/report output and stable structured results.
- Sorting always has a documented tie-breaker.

## 9. Path and Filesystem Policy

### 9.1 General

- Normalize paths before use.
- Compare resolved paths, not string prefixes.
- Reject traversal outside the configured vault.
- Reject symlink escapes and ambiguous symlink chains.
- Never trust an agent-supplied output path, filename, or stable ID.
- Never use shell interpolation for filesystem operations.

### 9.2 Agent reads

Agent reads are by stable record ID, not arbitrary path.

Source text access is allowed only through an artifact record that resolves to:

- observed text embedded in an M2 artifact note; or
- a safe vault-relative copied M6 text-like payload.

Never follow a legacy external absolute `source.path`. Never return raw binary.

### 9.3 Agent writes

The server chooses:

- IDs;
- filenames;
- destination directories;
- frontmatter;
- evidence paths;
- Markdown headings;
- lifecycle state;
- review state.

User/model text is inserted only as escaped/rendered body content under fixed sections.

## 10. Locking and Atomicity

- Use OS-backed file locking, not PID files.
- Use one vault-scoped lock path shared by CLI and MCP operations.
- The lock path is runtime state and must be ignored by Git.
- Reads requiring a coherent multi-file index use a shared lock if the implementation supports it safely; all mutations use an exclusive lock.
- Lock acquisition has a bounded timeout and stable error.
- Lock ownership is process-scoped and released on normal exit and process termination.
- Avoid nested lock acquisition. Public operations acquire the lock; internal helpers receive an already-locked context.
- Single-file writes stage in the destination directory and atomically rename.
- M6 preserves its coordinated three-output transaction and rollback semantics under the shared lock.
- Existing files are never overwritten.
- Temporary files are removed on handled failure.

## 11. Stable IDs and Record Index

- Stable IDs are read from frontmatter.
- Lookups scan only known record directories.
- `AGENT.md`, non-Markdown files, generated outputs, and copied binary payloads are not record entries.
- Duplicate IDs produce `NOUS_DUPLICATE_ID`; never return the first match silently.
- Directory lifecycle is authoritative in combination with frontmatter.
- Record index output is deterministic.
- A cached persistent index is out of scope; rebuild from files for M7.

## 12. Agent Read Results

Every result that carries user-authored or record body content includes:

```json
{
  "content_role": "untrusted_data",
  "lifecycle_class": "source_evidence"
}
```

Returned content is data, not executable instruction. The agent behavior contract repeats this rule.

Outputs are bounded. List operations return excerpts, not complete bodies. Complete record/source reads require explicit bounded calls.

## 13. Evidence Eligibility

Eligible grounding evidence:

- source artifact records;
- active reviewed notes;
- active canonical claims.

Ineligible as sole or primary grounding evidence:

- pending agent candidates;
- derived report/graph output;
- retired records;
- relationship records;
- copied binary payloads without a source record;
- unknown or duplicate IDs.

Pending candidates may be relationship endpoints before review, but they do not become self-validating evidence.

Evidence refs are resolved by ID. The core writes canonical vault-relative paths. The agent never supplies evidence paths.

## 14. Candidate Write Policy

Candidate writes are limited to:

- verbatim user-text source capture;
- generic inbox notes with validated `candidate_type`;
- inbox claims;
- inbox relationships.

They always:

- remain draft/agent-generated or source-evidence review state;
- include provenance;
- include confidence where interpretive;
- include `requires_review: true` in the operation result;
- preserve facts, user context, and hypotheses in separate sections;
- avoid unsupported psychological certainty;
- avoid image interpretation;
- record generation metadata for MCP writes.

They never accept complete YAML, complete Markdown, a record path, a filename, or an agent-selected stable ID.

## 15. Idempotency

Every agent mutation requires a `request_id` matching:

```text
[A-Za-z0-9._:-]{1,128}
```

The core:

1. normalizes operation inputs excluding `request_id`;
2. computes a canonical SHA-256 digest;
3. checks all M7 generation metadata for the request ID;
4. returns the existing result when operation and digest match;
5. raises `NOUS_IDEMPOTENCY_CONFLICT` when the same request ID is reused with a different operation or digest;
6. performs the check and write while holding the vault lock;
7. persists operation, request ID, digest, interface, and generated timestamp.

Array ordering is normalized only where the semantic contract declares order irrelevant. Do not accidentally normalize user-authored prose or evidence priority.

Request IDs do not become filenames and are not echoed into user-facing titles.

## 16. Reserved Final MCP Surface

M7F exposes exactly:

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

No earlier stage exposes a product MCP server.

M7 uses local stdio, tools only. No HTTP, OAuth, resources, prompts, roots, sampling, elicitation, tasks, model SDK, or network listener.

## 17. Dependency Policy

- M7A verifies the official Ruby MCP SDK and selected stable protocol against the local Ruby runtime.
- No unofficial similarly named SDK may be substituted silently.
- No MCP dependency enters core code.
- Commit `Gemfile` and `Gemfile.lock` only when M7F begins unless product ownership explicitly approves earlier pinning.
- Record the selected version, Ruby requirement, protocol version, and dependency tree.
- Re-run the preflight immediately before M7F because dependency facts can change.
- Do not add Rails, Sinatra, Rack application code, Node, Python, or a second runtime merely to serve MCP.

Observed planning baseline on 2026-08-08: the official `mcp` Ruby gem had a stable `1.0.0` release and declared Ruby `>= 2.7.0`; the latest stable specification release was `2025-11-25`. These are planning observations, not permission to skip execution-time verification.

## 18. Privacy and Logging

- No telemetry.
- No outbound network calls from Nous.
- No API key requirement.
- Do not log bodies, reflections, claims, source excerpts, evidence text, or secrets.
- Allowed diagnostics: operation/tool name, request ID, duration, sanitized error code, relative record ID/path where safe.
- Automated tests use synthetic temporary data only.
- Tests never read personal files from the user's home directory.
- Tests never write fixture records into the repository vault.
- Final worktree audit searches for fixture IDs, absolute temp paths, secret-shaped strings, and private payloads.

## 19. Test Rules

- Narrow test first, full suite later.
- Every stage has its own test specification.
- A stage is incomplete if its focused test passes but an earlier stage or M2-M6 regression fails.
- Use both behavior-level and adversarial fixtures.
- For protocol work, do not rely solely on the same SDK on both client and server; include raw stdio framing checks.
- Fixed clocks and temporary vaults are mandatory.
- No test may depend on network access.

## 20. Codex Execution Rules

Codex must:

- implement only the selected stage;
- state assumptions that change the contract;
- preserve current behavior before refactoring;
- stop on dependency incompatibility or unclear destructive behavior;
- avoid speculative abstractions;
- avoid unrelated cleanup;
- keep changes surgical;
- report skipped checks honestly;
- leave the repository green.

Codex must not:

- implement later stages early;
- wrap CLIs with shell-based MCP tools;
- change tests to hide behavior drift;
- hand-roll MCP framing;
- create approval tools;
- expose arbitrary filesystem paths;
- add a frontend, database, embeddings, watcher, or chat loop;
- add model-provider calls;
- add voice/transcript scope;
- commit real personal data.

## 21. Change Control

Any of these require explicit product approval and a PRD update:

- adding/removing an MCP tool;
- allowing agent approval or reviewed-record edits;
- arbitrary file-path import/read;
- network transport;
- built-in model calls;
- semantic/vector search;
- a database or persistent index;
- schema migration rather than additive optional fields;
- identity candidate approval routing;
- voice, OCR, EXIF, face recognition, or image interpretation;
- weakening idempotency, locking, or evidence rules.
