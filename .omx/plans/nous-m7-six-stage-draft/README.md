# Nous M7 Six-Stage Draft Package

Status: Draft for product and execution approval

Date: 2026-08-08

## 1. Purpose

This package replaces the earlier monolithic M7 implementation plan and test specification with six gated sub-milestones while preserving one umbrella product requirement:

> **M7 — Agent-Ready Nous Core and Local MCP Interface**

M7 should not be executed as one large Codex prompt. The staged package is designed so every implementation step leaves the repository usable, tested, and revertible.

## 2. Delivery Order

```text
M7A  Baseline Characterization and Dependency Preflight
  |
  v
M7B  Read-Only Nous Core
  |
  v
M7C  Mutation Core and Vault Safety
  |
  v
M7D  Agent-Safe Read Operations
  |
  v
M7E  Agent Candidate Writes and Idempotency
  |
  v
M7F  MCP Adapter and Release Gate
```

Do not skip gates or run stages in parallel. Later stages rely on interfaces and invariants established earlier.

## 3. Package Contents

### Umbrella and shared contracts

- `prd-m7-agent-ready-core-and-mcp.md` — product scope, functional/non-functional requirements, exact future MCP surface, lifecycle and trust decisions.
- `m7-shared-contract.md` — rules that apply to all stages: authority, compatibility, paths, locks, evidence, idempotency, privacy, and Codex prohibitions.
- `m7-execution-map.md` — stage dependency graph, entry/exit gates, likely file ownership, rollback model, and M8 handoff.
- `m7-final-acceptance-matrix.md` — maps every M7 requirement to its owning stage and verification contract.

### Six implementation plans

- `m7a-baseline-characterization-and-preflight-plan.md`
- `m7b-read-only-nous-core-plan.md`
- `m7c-mutation-core-and-vault-safety-plan.md`
- `m7d-agent-safe-read-operations-plan.md`
- `m7e-agent-candidate-writes-and-idempotency-plan.md`
- `m7f-mcp-adapter-and-release-plan.md`

### Six test specifications

- `test-spec-m7a-baseline-characterization-and-preflight.md`
- `test-spec-m7b-read-only-nous-core.md`
- `test-spec-m7c-mutation-core-and-vault-safety.md`
- `test-spec-m7d-agent-safe-read-operations.md`
- `test-spec-m7e-agent-candidate-writes-and-idempotency.md`
- `test-spec-m7f-mcp-adapter-and-release.md`

### Agent execution aid

- `codex-execution-handoffs.md` — common execution protocol plus copy-paste prompts for M7A-M7F and an independent verifier.

## 4. Intended Repository Placement

The files follow the existing planning convention and can be placed flat under:

```text
.omx/plans/
```

Update `.omx/plans/AGENT.md` to list each direct child.

The package itself is flat so copying it into `.omx/plans/` does not create new signpost directories.

## 5. Main Architecture Decision

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

- The vault remains the source of truth.
- Nous Core owns business and filesystem rules.
- Existing CLIs become adapters.
- MCP is an agent adapter, not the frontend backend.
- A future frontend uses a separate local API/IPC adapter over the same core.
- M7 embeds no model provider and builds no frontend.

## 6. Why Six Stages

The original M7 combined:

- compatibility-sensitive refactoring;
- lock/transaction/path security work;
- new read operations;
- new idempotent write operations;
- schema changes;
- an external protocol/dependency;
- client integration and release verification.

Separating them makes failures attributable:

- M7A establishes what cannot drift.
- M7B proves the core boundary with read-heavy code.
- M7C secures all existing writes before adding agent writes.
- M7D defines exactly what an agent can read.
- M7E defines exactly what an agent can write.
- M7F maps tested operations into MCP without duplicating business logic.

## 7. Binding Product Boundaries

The first agent interface is candidate-only and path-restricted.

The agent may:

- inspect bounded reviewed/canonical knowledge;
- explicitly inspect raw/inbox records;
- read bounded text through a validated artifact ID;
- preserve confirmed verbatim user text;
- propose candidate notes, claims, and relationships.

The agent may not:

- approve, reject, deprecate, merge, delete, canonicalize, or edit reviewed records;
- import/read an arbitrary local path;
- choose an output path, filename, frontmatter, Markdown document, or stable ID;
- write directly to reviewed/canonical/generated directories;
- execute shell commands;
- make model-provider calls from Nous;
- infer image content, identity, emotion, or meaning.

## 8. Reserved Final MCP Tools

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

No MCP product server should exist before M7F.

## 9. Dependency Baseline

Planning observation on 2026-08-08:

- official Ruby SDK gem: `mcp`;
- observed stable gem version: `1.0.0`;
- observed Ruby requirement: `>= 2.7.0`;
- observed stable MCP protocol release: `2025-11-25`.

M7A must verify these against the local runtime, and M7F must verify them again before pinning. The observations are not permission to skip preflight.

## 10. How to Use the Package with Codex

For each stage:

1. Give Codex:
   - root `AGENT.md`;
   - umbrella PRD;
   - shared contract;
   - execution map;
   - only the current stage plan;
   - only the current stage test specification.
2. Use the stage prompt from `codex-execution-handoffs.md`.
3. Require a clean baseline before changes.
4. Require focused tests after each checkpoint.
5. Require all earlier tests before completion.
6. Stop the execution when the stage exit gate is satisfied.
7. Review and commit before starting the next stage.

Do not give an implementation agent all six stages with “continue until done.” The package is thorough for reference, but the execution context should be deliberately narrow.

## 11. Recommended PR Sequence

```text
PR 1  M7A baseline and preflight
PR 2  M7B read-only core
PR 3  M7C mutation core and safety
PR 4  M7D agent-safe reads
PR 5  M7E candidate writes and idempotency
PR 6  M7F MCP adapter and release
```

A solo linear branch is acceptable when every stage ends in a separate green checkpoint commit and no stage is squashed away before independent verification.

## 12. Required Global Checks

Every stage ends with:

```sh
make test
make lint
git diff --check
git status --short
```

Plus all focused and earlier-stage tests listed in that stage's specification.

M7F additionally requires:

- official MCP client tests;
- independent raw stdio tests;
- MCP Inspector;
- Codex CLI discovery/calls;
- full capture → proposal → human review → graph/report lifecycle;
- privacy/log/stdout/worktree audit.

## 13. What This Package Does Not Decide

These remain future product decisions:

- frontend framework and desktop/web packaging;
- local API versus IPC shape for the frontend;
- memory-chat orchestration;
- semantic/vector retrieval;
- graph visualization;
- voice/transcript support;
- automatic background ingestion;
- interpersonal graph;
- agent approval authority;
- remote MCP transport.

M7 is intentionally the safe local core and agent interface that those later layers can build on.

## 14. Approval Checklist Before Starting M7A

Confirm:

- candidate-only MCP policy is accepted;
- arbitrary path import/read remains excluded;
- stdio/tools-only is accepted;
- no built-in model runtime is accepted;
- identity candidate routing remains excluded;
- lexical-only retrieval is accepted;
- `request_id` is required for every agent mutation;
- human review remains the only canonicalization path;
- M7 will be delivered stage by stage rather than one-shot.
