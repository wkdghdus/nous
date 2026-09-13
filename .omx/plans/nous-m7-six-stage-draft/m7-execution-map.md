# M7 Execution Map

Status: Draft staged-delivery contract

Date: 2026-08-08

Umbrella PRD: `prd-m7-agent-ready-core-and-mcp.md`

Shared rules: `m7-shared-contract.md`

## 1. Delivery Principle

M7 is one coherent product capability delivered through six independently green stages. A stage may depend on earlier stage interfaces, but it must not assume code from later stages.

```text
M7A baseline/preflight
        |
        v
M7B read-only core
        |
        v
M7C mutation core + safety
        |
        v
M7D agent-safe reads
        |
        v
M7E candidate writes + idempotency
        |
        v
M7F MCP adapter + release gate
```

Do not merge two adjacent stages into one Codex prompt merely because they share files. The gates exist to make failures attributable.

## 2. Stage Summary

| Stage | Primary outcome | Highest risk | Product MCP server? |
| --- | --- | --- | --- |
| M7A | Current behavior frozen; SDK/transport feasibility proven. | Missing implicit CLI contract. | No. |
| M7B | Reusable side-effect-free read/domain core. | Silent M2-M6 behavior drift. | No. |
| M7C | Existing mutations use shared safety primitives. | Data loss, races, lifecycle corruption. | No. |
| M7D | Direct agent-safe retrieval API exists. | Arbitrary file access and trust confusion. | No. |
| M7E | Direct candidate creation API exists and is retry-safe. | Auto-promotion, duplicate writes, evidence laundering. | No. |
| M7F | Exact eight-tool stdio server over tested core. | Protocol errors and adapter authority creep. | Yes. |

## 3. Cross-Stage Gates

### Gate A: Start M7B only when

- M2-M6 direct tests pass;
- `make test` and `make lint` pass;
- current CLI behavior has explicit characterization coverage;
- Ruby/Bundler/SDK/protocol feasibility is documented;
- no product MCP dependency or server code was committed as part of the spike;
- worktree contains no private artifact.

### Gate B: Start M7C only when

- `require "nous"` is side-effect free;
- graph/report builders and review inspection use core operations;
- adapters retain their old output/error behavior;
- fixed-time graph/report bytes match baseline;
- all M2-M6 tests remain green.

### Gate C: Start M7D only when

- all existing mutations flow through the core;
- shared lock, atomic writer, and M6 transaction tests pass;
- relationship approval blocks non-exportable endpoints;
- CLI behavior remains compatible;
- no orphan/temp files remain after forced failures.

### Gate D: Start M7E only when

- stable-ID index and lifecycle classifier are authoritative;
- path and symlink adversarial tests pass;
- read operations are deterministic and mutation-free;
- legacy external source paths are redacted and never followed;
- binary source reads are refused.

### Gate E: Start M7F only when

- all four candidate operations pass direct core tests;
- idempotent replay/conflict/crash recovery is proven;
- agent writes remain raw/inbox-only;
- evidence and relationship rules are proven;
- graph/report continue excluding pending candidates;
- SDK/protocol preflight has been re-run.

### Final M7 gate

M7 is complete only when:

- all six focused test programs pass;
- all M2-M6 tests pass;
- full test and lint targets pass;
- MCP raw stdio and official client tests pass;
- MCP Inspector passes;
- Codex CLI discovers and calls the server;
- capture → propose → human review → graph/report passes;
- privacy/worktree audit passes;
- an independent verification pass approves the result.

## 4. Stage Artifacts

| Stage | Plan | Test specification |
| --- | --- | --- |
| M7A | `m7a-baseline-characterization-and-preflight-plan.md` | `test-spec-m7a-baseline-characterization-and-preflight.md` |
| M7B | `m7b-read-only-nous-core-plan.md` | `test-spec-m7b-read-only-nous-core.md` |
| M7C | `m7c-mutation-core-and-vault-safety-plan.md` | `test-spec-m7c-mutation-core-and-vault-safety.md` |
| M7D | `m7d-agent-safe-read-operations-plan.md` | `test-spec-m7d-agent-safe-read-operations.md` |
| M7E | `m7e-agent-candidate-writes-and-idempotency-plan.md` | `test-spec-m7e-agent-candidate-writes-and-idempotency.md` |
| M7F | `m7f-mcp-adapter-and-release-plan.md` | `test-spec-m7f-mcp-adapter-and-release.md` |

## 5. Suggested Branch and Commit Model

Preferred:

```text
m7a/baseline-preflight
m7b/read-only-core
m7c/mutation-safety
m7d/agent-reads
m7e/candidate-writes
m7f/mcp-release
```

One PR per stage is safest.

For a solo linear branch, create a checkpoint commit after every stage and do not squash until final verification. Every checkpoint must pass all tests available at that point.

Do not maintain six long-lived branches in parallel. Later stages depend on the exact interfaces established earlier.

## 6. File Ownership by Stage

This is guidance, not permission to touch every listed file.

### M7A likely owns

- current test files where characterization is missing;
- `scripts/test_cli_contracts.rb` if a separate characterization suite is justified;
- an ADR or preflight record under `docs/decisions/`;
- `Makefile` only to wire the characterization test;
- relevant signposts.

### M7B likely owns

- `lib/nous.rb`;
- `lib/nous/errors.rb`;
- `lib/nous/clock.rb`;
- `lib/nous/frontmatter.rb`;
- `lib/nous/record.rb`;
- `lib/nous/lifecycle.rb`;
- `lib/nous/record_index.rb`;
- pure graph/report/review-inspection core files;
- thin changes to `export_graph.rb`, `generate_nous_report.rb`, and read-only portions of `review_queue.rb`;
- `scripts/test_nous_read_core.rb`;
- signposts.

### M7C likely owns

- lock/path/writer/transaction core files;
- ingestion and review mutation core files;
- thin changes to all mutating CLI scripts;
- relationship approval validation;
- `scripts/test_nous_mutation_core.rb`;
- `.gitignore` for runtime lock state;
- relevant docs/signposts.

### M7D likely owns

- query/status/read/source-reader core files;
- `scripts/test_nous_agent_reads.rb`;
- documentation of the read envelope and trust labels.

### M7E likely owns

- candidate validation/rendering;
- idempotency;
- optional additive schema fields;
- note/claim/relationship template updates if needed;
- review display of candidate metadata;
- `scripts/test_nous_candidate_writes.rb`;
- archivist behavior contract draft.

### M7F likely owns

- `Gemfile` and `Gemfile.lock`;
- MCP adapter files;
- server entrypoint;
- MCP protocol test;
- client setup docs;
- README/current-state correction;
- Makefile/lint/signpost updates;
- final end-to-end release documentation.

## 7. Shared Stop Conditions

Stop the current stage and report rather than guessing when:

- current behavior and written plan conflict materially;
- an existing test fails before stage changes;
- Ruby/SDK/protocol compatibility cannot be proven;
- a path operation would touch data outside a temporary fixture or intended vault;
- a migration of existing user records seems required;
- a write cannot be made atomic under the current design;
- an agent capability would cross the review boundary;
- a tool or operation needs arbitrary file access;
- a proposed abstraction is only justified by a later unapproved stage;
- private data appears in the working tree.

## 8. Rollback Expectations

Each stage must be individually revertible.

- M7A reverts characterization/docs only.
- M7B reverts adapters to existing in-script behavior without changing vault data.
- M7C reverts implementation structure but must not require vault migration.
- M7D adds read-only APIs and is data-neutral.
- M7E adds optional fields and new candidate records only; existing records stay valid.
- M7F removes the adapter/dependency without changing core or vault data.

No stage may introduce an irreversible vault migration.

## 9. Verification Cadence

Within every stage:

1. run the narrowest focused test after each behavior unit;
2. run affected M2-M6 tests after adapter changes;
3. run the stage test suite;
4. run `make test`;
5. run `make lint`;
6. inspect `git diff --check` and `git status --short`;
7. inspect generated/temp/private files;
8. perform a changed-files-only cleanup;
9. repeat focused and broad checks.

## 10. Final Handoff to M8

M8 may begin only after M7F proves:

- core operations are reusable without CLI/MCP presentation concerns;
- the MCP interface is agent-safe;
- ordinary product actions do not require MCP;
- reviewed data remains the authority;
- the vault is still portable and reconstructable.

Recommended M8 boundary:

```text
M8: Local Nous Application Surface
- local API or IPC adapter over Nous Core
- Capture, Inbox, Knowledge, and Chat UI
- no duplication of core rules in frontend code
```
