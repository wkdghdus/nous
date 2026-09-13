# Codex Execution Handoffs for M7A-M7F

Status: Draft operator aid

Date: 2026-08-08

## 1. Common Instructions for Every Stage

Prepend this block to every stage-specific prompt:

```text
You are implementing one bounded stage of Nous M7.

Read and follow, in this order:
1. repository root AGENT.md;
2. prd-m7-agent-ready-core-and-mcp.md;
3. m7-shared-contract.md;
4. m7-execution-map.md;
5. the selected stage plan;
6. the selected stage test specification;
7. local AGENT.md files for every directory you touch.

Implement only the selected stage. Do not implement work assigned to later
stages, even when it looks convenient. Do not weaken existing tests, change
current CLI behavior, commit private data, add speculative abstractions, or
perform unrelated cleanup.

Before coding:
- inspect git status and the relevant implementation/tests;
- run the stage's required baseline checks;
- state any assumption that materially affects implementation;
- stop and report if the baseline is not green, a dependency is incompatible,
  a destructive behavior is unclear, or the written contracts conflict.

During coding:
- use temporary synthetic fixtures only;
- run the narrowest focused test after each checkpoint;
- preserve provenance and the human review boundary;
- keep core code presentation-free and adapter code authority-free;
- keep changes surgical.

Before completion:
- run the full stage verification order;
- run make test, make lint, git diff --check, and git status --short;
- inspect changed files for private payloads, temp files, runtime state,
  absolute test paths, and scope creep;
- perform a changed-files-only cleanup and rerun tests;
- report exactly what was changed, verified, skipped, or remains blocked.
```

## 2. M7A Handoff

```text
Selected stage: M7A Baseline Characterization and Dependency Preflight.

Use:
- m7a-baseline-characterization-and-preflight-plan.md
- test-spec-m7a-baseline-characterization-and-preflight.md

Goal:
Freeze M2-M6 operator-visible behavior and prove the official Ruby MCP SDK,
stable protocol, raw stdio framing, and intended Codex client path using a
throwaway preflight.

Allowed work:
- characterization tests;
- synthetic fixed-output baselines;
- preflight/architecture ADRs;
- Makefile/signpost changes required by those tests/docs.

Forbidden work:
- lib/nous core implementation;
- committed Gemfile/Gemfile.lock;
- product MCP server;
- locks, candidate operations, schema changes;
- frontend, model calls, semantic search, database, voice.

Stop when:
- current CLI contracts are executable and explicit;
- all M2-M6 tests remain green;
- SDK/stdio feasibility is proven or a precise incompatibility blocks work;
- no M7B-M7F product implementation exists.
```

## 3. M7B Handoff

```text
Selected stage: M7B Read-Only Nous Core.

Use:
- m7b-read-only-nous-core-plan.md
- test-spec-m7b-read-only-nous-core.md

Goal:
Create a side-effect-free presentation-free Nous Core and move graph building,
report building, and review list/show/report inspection into it while
preserving exact CLI and fixed-time output behavior.

Allowed work:
- lib/nous entrypoint, errors, clock, parser, record/lifecycle/normalization;
- graph/report/review-read core extraction;
- thin adapter changes for export_graph, generate_nous_report, and read-only
  review subcommands;
- direct read-core tests and signposts/docs.

Forbidden work:
- ingestion or review mutation extraction;
- locks/writer/transactions;
- agent status/search/record/source operations;
- candidate writes/idempotency/schema changes;
- MCP dependency/server; frontend/model/database work.

Mandatory checkpoint order:
1. side-effect-free load/errors/time;
2. parser/normalization;
3. graph equivalence;
4. report equivalence;
5. review list/show/report equivalence.

Stop when all existing commands/bytes remain compatible and no later-stage
scope exists.
```

## 4. M7C Handoff

```text
Selected stage: M7C Mutation Core and Vault Safety.

Use:
- m7c-mutation-core-and-vault-safety-plan.md
- test-spec-m7c-mutation-core-and-vault-safety.md

Goal:
Move every existing M2-M6 mutation into Nous Core and make writes path-safe,
process-safe, atomic, rollback-safe, and lifecycle-safe before any agent write
surface exists.

Allowed work:
- path guard;
- one vault-scoped OS lock;
- atomic writer and M6 coordinated transaction;
- collision allocator;
- text/artifact ingestion core extraction;
- approve/reject/deprecate/merge core extraction;
- relationship approval endpoint gate;
- runtime ignore/docs/signposts/tests.

Forbidden work:
- request IDs/idempotency/candidate metadata;
- agent read or write operations;
- MCP/Gemfile/frontend/model/search/database work;
- changing current filenames/frontmatter/output;
- moving $EDITOR execution into core.

Mandatory checkpoint order:
1. path guard + lock + writer tests;
2. text ingestion;
3. artifact ingestion and forced rollback/concurrency;
4. review mutations;
5. relationship endpoint gate;
6. coherent read/derived-output locking.

Do not continue past a checkpoint until its focused and regression tests pass.
```

## 5. M7D Handoff

```text
Selected stage: M7D Agent-Safe Read Operations.

Use:
- m7d-agent-safe-read-operations-plan.md
- test-spec-m7d-agent-safe-read-operations.md

Goal:
Add direct mutation-free core operations for status, deterministic lexical
record listing, bounded record reading, and artifact-ID-based source-text
reading.

Allowed work:
- authoritative known-directory index;
- lifecycle classifier and curated envelopes;
- status/list_records/read_record/read_source_text;
- lexical deterministic ranking;
- M2 embedded and M6 copied-text source resolution;
- path/digest/UTF-8/binary/bounds tests;
- read-contract docs.

Forbidden work:
- arbitrary path input;
- binary/image bytes;
- persistent index/database;
- embeddings/model ranking;
- candidate writes/idempotency;
- MCP/Gemfile/frontend/model calls.

Default retrieval must remain reviewed + canonical. Raw/inbox require explicit
scope. Returned content must be labeled untrusted data. Duplicate IDs must
fail, never select the first record.
```

## 6. M7E Handoff

```text
Selected stage: M7E Agent Candidate Writes and Idempotency.

Use:
- m7e-agent-candidate-writes-and-idempotency-plan.md
- test-spec-m7e-agent-candidate-writes-and-idempotency.md

Goal:
Add direct core operations for confirmed user-text capture and candidate note,
claim, and relationship proposals. Every write is server-rendered,
evidence-grounded, review-bound, locked, atomic, and retry-safe.

Allowed work:
- request ID validation and canonical digest;
- generation metadata lookup/replay/conflict;
- optional additive schema fields;
- safe candidate renderers;
- capture_user_text, propose_note, propose_claim, propose_relationship;
- evidence and endpoint validators;
- review metadata display and archivist contract;
- direct candidate/idempotency/end-to-end tests.

Forbidden work:
- MCP gem/tool/server;
- agent approval/review/delete/canonicalize authority;
- arbitrary path/ID/filename/frontmatter/Markdown input;
- pending candidates as evidence;
- identity candidate routing;
- frontend/model/semantic search/database/voice/image interpretation.

Implement idempotency and safe rendering before exposing any proposal method.
Stop only after retry-after-approval/rejection and process concurrency tests
prove no duplicate records.
```

## 7. M7F Handoff

```text
Selected stage: M7F MCP Adapter and Release Gate.

Use:
- m7f-mcp-adapter-and-release-plan.md
- test-spec-m7f-mcp-adapter-and-release.md

Goal:
Reverify and pin the official Ruby MCP SDK, then expose exactly the eight
approved tools over local tools-only stdio as a thin adapter over the
already-tested core. Complete Inspector, Codex, privacy, protocol, and full
lifecycle release verification.

Allowed work:
- Gemfile/Gemfile.lock for exact verified official SDK;
- MCP server/tool adapter/error/result files;
- server entrypoint and protocol tests;
- archivist/client setup docs;
- README/architecture/Makefile/lint/signposts required for release.

Forbidden work:
- additional or alias tools;
- approve/reject/deprecate/merge/delete/canonicalize tools;
- arbitrary path/file/shell tools;
- business validation in tool classes;
- shelling out to CLI scripts;
- hand-rolled MCP framing;
- HTTP/OAuth/resources/prompts/roots/sampling/elicitation/tasks;
- model SDK/calls; frontend/local API; semantic search/database/voice.

Required proof:
- exact schemas and output validation;
- official client plus independent raw stdio harness;
- protocol-only stdout and private stderr;
- MCP Inspector;
- Codex CLI discovery/calls against a temporary vault;
- full capture -> proposal -> human review -> graph/report lifecycle;
- all M2-M7E tests before and after cleanup.
```

## 8. Independent Verifier Handoff

Use after each stage, especially M7C, M7E, and M7F:

```text
Act as an independent verifier, not the implementer.

Read the umbrella PRD, shared contract, execution map, selected stage plan,
and selected test specification. Inspect the changed files and run the full
verification order yourself.

Prioritize:
- behavior drift from M2-M6;
- unauthorized later-stage scope;
- private/test data leakage;
- filesystem traversal/symlink/race/rollback defects;
- review-boundary violations;
- idempotency/concurrency errors;
- MCP schema/stdout/error/privacy defects;
- documentation claiming untested behavior.

Do not fix broad issues silently. Report findings by severity with exact file,
behavior, reproduction, violated requirement/test ID, and the smallest safe
remediation. Approve only when all mandatory checks pass and skipped checks
are explicitly accepted by the product owner.
```

## 9. Agent Output Format

Ask every executor to finish with:

```text
Stage implemented:
Files changed:
Behavior added:
Behavior intentionally unchanged:
Focused tests run:
Full tests/lint run:
Manual/security/privacy checks run:
Skipped/not testable:
Known residual risks:
Gate status: PASS | BLOCKED
Next permitted stage:
```

A stage with `BLOCKED` gate status must not roll into the next stage in the same execution.
