# M7B Plan: Read-Only Nous Core

Status: Draft execution plan

Date: 2026-08-08

Depends on: M7A complete and green

Unlocks: M7C Mutation Core and Vault Safety

Umbrella PRD: `prd-m7-agent-ready-core-and-mcp.md`

Shared rules: `m7-shared-contract.md`

Verification contract: `test-spec-m7b-read-only-nous-core.md`

## 1. Objective

Establish a reusable, presentation-free Ruby core beneath existing CLI adapters, beginning with read-heavy deterministic behavior. Move parsing, normalization, lifecycle discovery, graph construction, report construction, and review inspection into the core without changing any current command or vault output.

M7B proves the architecture with the smallest safe blast radius. It does not move existing state mutations and does not add agent/MCP operations.

## 2. Requirements Summary

M7B must:

1. add a side-effect-free `Nous` library entrypoint;
2. add namespaced domain errors and explicit result structures;
3. add an injected clock/time boundary;
4. centralize safe Markdown/frontmatter parsing used by extracted read operations;
5. centralize deterministic string/evidence/label/excerpt normalization used by graph/report;
6. provide known-directory record discovery and lifecycle classification sufficient for current read operations;
7. move graph construction/rendering into core code;
8. move Nous report construction/rendering into core code;
9. move review queue list/show/report discovery/rendering into core code while leaving review mutations untouched;
10. keep scripts as thin presentation adapters with identical behavior;
11. preserve exact fixed-time graph/report bytes;
12. leave all M2-M6 tests green.

## 3. Scope Boundary

### 3.1 In scope

Suggested core files:

```text
lib/AGENT.md
lib/nous.rb
lib/nous/AGENT.md
lib/nous/errors.rb
lib/nous/clock.rb
lib/nous/frontmatter.rb
lib/nous/record.rb
lib/nous/lifecycle.rb
lib/nous/record_index.rb
lib/nous/normalization.rb
lib/nous/graph_builder.rb
lib/nous/graph_renderer.rb
lib/nous/report_builder.rb
lib/nous/report_renderer.rb
lib/nous/review_reader.rb
lib/nous/review_report_renderer.rb
scripts/test_nous_read_core.rb
```

This is a suggested shape, not a mandate to create one file per noun. Prefer fewer cohesive files over speculative architecture.

Existing scripts likely changed:

```text
scripts/export_graph.rb
scripts/generate_nous_report.rb
scripts/review_queue.rb
```

The graph/report scripts may retain adapter-owned atomic file writing until M7C. Core builders/renderers return validated structures/bytes.

### 3.2 Explicitly out of scope

- Moving `ingest_text` or `ingest_artifact` writes.
- Moving approve/reject/deprecate/merge mutations.
- Shared write lock.
- New atomic writer/transaction framework.
- Relationship approval gate.
- Agent-safe status/list/read/source operations.
- Candidate creation or idempotency.
- Schema changes.
- MCP dependency/server.
- Frontend/API/model/search infrastructure.

## 4. Design Decisions

### 4.1 Library loading

Scripts add the repository `lib/` directory to `$LOAD_PATH` explicitly and `require "nous"`. Do not package/publish a gem in M7B.

`require "nous"`:

- defines constants/classes/modules only;
- prints nothing;
- creates no files;
- reads no vault;
- reads no environment variable;
- starts no thread/process/server;
- does not inspect `ARGV`.

### 4.2 Core API style

Use explicit keyword arguments and small results. Example shape:

```ruby
Nous::Graph.build(vault_root:, generated_at:)
Nous::Report.build(vault_root:, generated_at:)
Nous::Review.list(vault_root:, sort:)
Nous::Review.show(vault_root:, path:)
Nous::Review.render_report(vault_root:, generated_at:)
```

Names are illustrative. Avoid a service container or dependency-injection framework.

### 4.3 Time

Adapters parse current environment variables and pass validated values into core operations. Core code does not read:

```text
NOUS_GRAPH_TIME
NOUS_REPORT_TIME
NOUS_REVIEW_TIME
```

A tiny clock/value abstraction is enough. Do not introduce a framework.

### 4.4 Errors

Core raises `Nous::Error` subclasses or errors carrying a stable code. It does not prepend command names.

Adapters preserve current prefixes and exit behavior.

### 4.5 Record model

A record minimally carries:

- absolute internal `Pathname` for controlled core use;
- vault-relative path for presentation/provenance;
- parsed frontmatter;
- body;
- computed directory kind/lifecycle where needed.

Do not expose arbitrary absolute paths in returned public hashes.

### 4.6 Known-directory discovery

Discovery is explicit, not recursive over the whole vault.

Current read operations scan only the directories they already own:

- reviewed note direct children;
- canonical claims;
- canonical relationships;
- inbox note/claim/relationship directories for review inspection.

M7D later broadens the index for agent-safe reads. Do not prematurely implement search/source reading.

### 4.7 Derived output writing

M7B core returns rendered JSON/Markdown. Existing adapters may keep their current output path resolution and atomic replacement implementation temporarily. M7C will centralize writers/locks.

This temporary duplication is intentional and bounded. Do not build a half-general writer in M7B.

## 5. Acceptance Criteria

### 5.1 Core load and isolation

- `require "nous"` is side-effect free.
- Core ignores `ARGV` and command environment variables.
- Core emits no stdout/stderr.
- Core files have no MCP dependency.
- Core files do not shell out to scripts.

### 5.2 Graph

- Core builds the same graph object for the same fixture/time.
- Adapter writes byte-identical JSON to the previous implementation.
- All current validation and errors remain.
- Inbox/raw/retired remain excluded.
- Duplicate and dangling-edge behavior remains.

### 5.3 Report

- Core builds/renders the same Markdown for the same fixture/time.
- Adapter writes byte-identical output.
- Fixed sections/order/empty state remain.
- Reviewed-only trust boundary remains.
- Relationship context behavior remains.

### 5.4 Review inspection

- `list` output remains byte-identical for fixed fixtures.
- `show` remains read-only and presentation-compatible.
- `report` content remains compatible.
- Sort behavior remains.
- approve/reject/deprecate/merge/edit behavior remains in existing code and continues to pass tests.

### 5.5 Repository

- New directories have signposts.
- No package/dependency file is added.
- M7A characterization and all M2-M6 tests pass.
- No vault migration or data rewrite occurs.

## 6. Detailed Implementation Steps

### Step 1: Add entrypoint and minimal errors

Create a minimal `Nous` namespace and domain error contract.

Suggested error representation:

```ruby
class Nous::Error < StandardError
  attr_reader :code, :details
end
```

Use stable codes from the shared contract. Do not create a deep exception hierarchy unless different rescue behavior actually requires it.

Write the side-effect-free load test before further extraction.

### Step 2: Add explicit time value boundary

Provide a helper that validates/normalizes an explicit time value. Existing adapters remain responsible for reading environment variables and preserving current error wording.

Do not change timestamp formatting.

### Step 3: Extract frontmatter parsing

Unify the relevant parser behavior only where current scripts are compatible.

Requirements:

- frontmatter must begin at file start;
- aliases disabled;
- permitted `Date`/`Time` classes match current script needs;
- body extraction preserves current leading-newline behavior;
- invalid/missing/mapping errors remain mappable to current adapter messages;
- file encoding behavior does not silently change.

If graph/report/review currently differ materially, preserve explicit modes rather than forcing one parser and changing behavior.

### Step 4: Extract normalization helpers

Candidate helpers:

- string normalization;
- first H1;
- title fallback;
- first non-heading excerpt;
- evidence normalization/deduplication;
- confidence validation;
- supported type validation;
- status/review filtering.

Before sharing a helper, compare current behavior and tests. Do not “clean up” differences that are product-visible.

### Step 5: Add minimal record and lifecycle representation

Represent a loaded Markdown record and compute its kind from its known directory.

Directory location must participate in trust classification. A file with `review_status: reviewed` under the inbox remains an inbox record.

At this stage, lifecycle only needs to support current graph/report/review inspection. M7D adds the full agent envelope.

### Step 6: Extract graph builder

Move discovery, parsing, filtering, node/edge construction, uniqueness validation, endpoint validation, sorting, and timestamped graph-object construction into core.

Leave CLI option parsing, output path resolution, stdout, stderr, and exit in `export_graph.rb`.

Whether JSON pretty rendering sits in core or renderer is less important than byte compatibility and no adapter business logic.

Checkpoint:

```sh
ruby scripts/test_nous_read_core.rb --graph    # if test supports focus
ruby scripts/test_export_graph.rb
```

Compare fixed-time bytes to M7A baseline.

### Step 7: Extract report builder/renderer

Move candidate discovery, supported-note filtering, validation, entry creation, relationship filtering, sorting, and Markdown rendering into core.

Leave CLI presentation/output path/error prefix in adapter.

Checkpoint:

```sh
ruby scripts/test_nous_read_core.rb --report
ruby scripts/test_generate_nous_report.rb
```

Compare fixed-time bytes.

### Step 8: Extract review read path

Move:

- inbox discovery;
- item loading;
- pending filtering;
- evidence path collection;
- priority and sort logic;
- list row construction;
- show data construction;
- review queue report data/rendering.

Do **not** move or refactor:

- approval destination routing;
- write metadata;
- reject/deprecate/merge;
- editor launching.

The `review_queue.rb` command dispatcher can call core for list/show/report and current local functions for mutations until M7C.

Checkpoint:

```sh
ruby scripts/test_nous_read_core.rb --review
ruby scripts/test_review_queue.rb
```

### Step 9: Thin adapters without over-compressing

Adapters should remain readable. “Thin” does not mean a one-line metaprogrammed dispatcher.

Each adapter:

1. parses CLI input;
2. resolves/validates CLI-specific time/path options;
3. calls core;
4. writes output if currently responsible;
5. prints current success line;
6. rescues domain errors and emits current prefix/status.

### Step 10: Add core tests

Create `scripts/test_nous_read_core.rb` using temporary fixtures and direct calls.

It must prove:

- no output;
- no environment/ARGV coupling;
- structured results;
- domain errors;
- graph/report deterministic equivalence;
- review list/show/report equivalence;
- lifecycle/location trust behavior.

Do not test private helper method names.

### Step 11: Documentation and signposts

Update:

- `lib/AGENT.md` and `lib/nous/AGENT.md`;
- `scripts/AGENT.md`;
- architecture docs to describe the core/adapters boundary only to the extent implemented;
- README only if needed to avoid false statements about the current code shape.

Do not document MCP operations as available.

### Step 12: Full regression and cleanup

Run focused tests after each extraction. Then run all M2-M6 and M7A tests, full test/lint, deterministic comparisons, diff/worktree/privacy checks.

## 7. Files Codex Should Not Touch in M7B

Unless required for a narrow compatibility fix:

- ingestion implementation scripts/tests;
- note schema/templates;
- `.gitignore`;
- dependency files;
- MCP files;
- vault content;
- product requirements beyond marking M7B progress.

## 8. Codex Potholes and Prohibitions

Do not:

- extract every script at once;
- create a generic repository/service framework;
- add dependency injection libraries;
- build persistent caches/indexes;
- change output path semantics;
- switch from `Psych`/stdlib rendering in a way that changes bytes;
- make record discovery recursively scan unknown directories;
- move review mutations early;
- centralize helpers that have subtly different existing behavior without tests;
- expose core absolute paths in results;
- read environment variables in core;
- add status/search/source read operations early;
- add MCP/Gemfile/frontend/model code;
- rewrite tests to new outputs.

## 9. Risks and Mitigations

### Risk: Shared parser changes YAML/date behavior

Mitigation: Characterization first; explicit parser modes when required; direct equivalence tests.

### Risk: Graph/report bytes drift due to hash insertion order or newline changes

Mitigation: fixed-time byte comparisons after every extraction; preserve current renderer and ordering.

### Risk: Adapter still contains hidden business rules

Mitigation: identify validation/discovery rules in tests, but do not force mutation extraction into M7B. Record remaining mutation logic for M7C.

### Risk: Core becomes a speculative framework

Mitigation: extract only code used by graph, report, and review inspection. No plugin system, registry, container, or interface hierarchy.

### Risk: Review command dispatcher becomes inconsistent

Mitigation: keep one public CLI behavior test covering all subcommands while list/show/report move first.

## 10. Verification Commands

```sh
ruby scripts/test_nous_read_core.rb
ruby scripts/test_cli_contracts.rb              # if added in M7A
ruby scripts/test_export_graph.rb
ruby scripts/test_generate_nous_report.rb
ruby scripts/test_review_queue.rb
ruby scripts/test_ingest_text.rb
ruby scripts/test_ingest_artifact.rb
make test
make lint
git diff --check
git status --short
```

Repeat fixed-time graph and report generation and compare bytes to the M7A baseline.

## 11. Definition of Done

M7B is done when the reusable read/domain core exists, graph/report/review inspection use it, current adapters behave identically, every test is green, and no mutation-safety/agent/MCP work has leaked into the stage.

## 12. Suggested Execution Handoff

One executor is recommended. A second verifier can compare baseline outputs independently after extraction.

Recommended reasoning: high for extraction/equivalence.

Handoff message:

```text
Implement M7B only. Establish a side-effect-free read/domain Nous Core and
move graph, report, and review inspection into it. Preserve exact CLI and
fixed-time output behavior. Do not move ingestion/review mutations, add locks,
add agent operations, add dependencies, or add MCP/frontend/model code.
```
