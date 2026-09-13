# Test Specification: M7B Read-Only Nous Core

Status: Draft verification contract

Date: 2026-08-08

Plan: `m7b-read-only-nous-core-plan.md`

Depends on: M7A green baseline

## 1. Test Strategy

M7B tests the core directly and then proves existing adapters remain behaviorally identical. Direct core tests assert structured behavior and absence of presentation side effects. Existing script tests remain authoritative for CLI compatibility.

## 2. Required Test Program

Add:

```sh
ruby scripts/test_nous_read_core.rb
```

The test uses temporary synthetic vaults and requires `lib/nous` directly.

## 3. Core Load and Isolation

### CORE-B-001: Side-effect-free require

Capture stdout/stderr, snapshot filesystem, set synthetic `ARGV` and environment variables, require `nous`, and assert:

- no output;
- no file change;
- no process exit;
- `ARGV` unchanged;
- environment unchanged;
- no thread/server/socket started.

### CORE-B-002: Repeated require

Requiring the entrypoint again is harmless and silent.

### CORE-B-003: No MCP dependency

Loading core succeeds with no MCP gem installed/loaded. Assert no `MCP` constant dependency from core files.

### CORE-B-004: Explicit vault root

Core operations use the passed temporary vault even when current directory and environment point elsewhere.

### CORE-B-005: Core ignores CLI time environment

Set all `NOUS_*_TIME` values to conflicting values. Pass explicit times and assert explicit values control results.

### CORE-B-006: No adapter prefixes

Representative core errors do not contain command prefixes.

### CORE-B-007: Stable error codes

Missing vault, parse failure, invalid confidence, duplicate ID, and dangling endpoint expose the documented core codes where applicable.

## 4. Frontmatter and Record Tests

### PARSE-B-001: Valid frontmatter/body

Assert metadata and body preserve current semantics.

### PARSE-B-002: Missing frontmatter

Stable parse error with safe relative path/details.

### PARSE-B-003: Invalid YAML

Aliases remain disabled; handled parse error contains no stack trace.

### PARSE-B-004: Non-mapping frontmatter

Rejected.

### PARSE-B-005: Date/time support

Graph/report fixtures with YAML date values parse as current scripts do.

### PARSE-B-006: Body newline preservation

Rendered baseline does not drift from parser extraction.

### RECORD-B-001: Known directory kind

Reviewed note, canonical claim, canonical relationship, and inbox item kinds are computed from directory.

### RECORD-B-002: Directory beats frontmatter trust

Inbox file claiming reviewed remains inbox/non-canonical.

### RECORD-B-003: Signposts excluded

`AGENT.md` never becomes a record.

### RECORD-B-004: Non-Markdown excluded

Copied payloads and unrelated files are ignored by record discovery.

## 5. Normalization Equivalence

### NORM-B-001: Label precedence

First H1, then title, then ID.

### NORM-B-002: Excerpt selection/bound

First nonempty non-heading line and current length bound.

### NORM-B-003: Evidence order/deduplication

First-seen order is preserved.

### NORM-B-004: Confidence validation

Numeric and range behavior matches baseline.

### NORM-B-005: String/date normalization

YAML scalar types produce current deterministic strings.

## 6. Graph Core Tests

### GRAPH-B-001: Structured graph equality

Given baseline fixture/time, core graph hash equals parsed baseline JSON.

### GRAPH-B-002: Rendered byte identity

Core renderer/adapter output equals M7A expected bytes.

### GRAPH-B-003: Stable sort

Nodes and edges sort by ID.

### GRAPH-B-004: Reviewed-only discovery

Inbox/raw/rejected/deprecated/archived absent.

### GRAPH-B-005: Canonical claim/relationship discovery

Expected nodes/edges included.

### GRAPH-B-006: Duplicate node IDs

Fails before output replacement.

### GRAPH-B-007: Duplicate edge IDs

Fails.

### GRAPH-B-008: Unsupported types

Current validation/messages map correctly.

### GRAPH-B-009: Dangling endpoints

Fails with stable core code and adapter-compatible message.

### GRAPH-B-010: Invalid time remains adapter-owned

CLI invalid environment value retains old error. Core accepts only already validated explicit time or raises core input error when directly supplied invalid data per its public contract.

### GRAPH-B-011: No mutation during build

Building graph does not alter any source record.

## 7. Report Core Tests

### REPORT-B-001: Structured report equality

Core report data matches baseline fixture semantics.

### REPORT-B-002: Markdown byte identity

Core renderer/adapter output equals M7A expected bytes.

### REPORT-B-003: Section order/empty state

Exact current order and text.

### REPORT-B-004: Reviewed-only discovery

Excluded lifecycle records absent.

### REPORT-B-005: Unsupported note directories skipped before validation

Preserve current behavior.

### REPORT-B-006: Supported malformed record fails

Preserve output replacement safety.

### REPORT-B-007: Relationship context only with both endpoints

Preserve current filtering.

### REPORT-B-008: Duplicate record/relationship IDs

Stable failure.

### REPORT-B-009: No source mutation

Build/render leaves source bytes unchanged.

## 8. Review Read Core Tests

### REVIEW-B-001: Pending discovery

Notes, claims, and relationships in current pending states are found.

### REVIEW-B-002: Retired excluded

Rejected/deprecated/archived absent from pending list.

### REVIEW-B-003: Priority calculation

Manual priority and confidence/kind fallback match baseline.

### REVIEW-B-004: Sort modes

Priority, created, and confidence ordering match baseline.

### REVIEW-B-005: Evidence path collection

Evidence and source path deduplication match baseline.

### REVIEW-B-006: Show result

Core returns normalized structured item data; adapter text matches baseline.

### REVIEW-B-007: Show is byte-read-only

No file changes.

### REVIEW-B-008: Review report render

Fixed-time report matches baseline bytes.

### REVIEW-B-009: Mutation subcommands unaffected

Existing approval/reject/deprecate/merge/edit tests pass unchanged while their implementation remains outside the extracted read path.

## 9. Adapter Compatibility

### ADAPTER-B-001: Help/usage unchanged

M7A characterization passes.

### ADAPTER-B-002: Stdout/stderr unchanged

Graph/report/review list/show/report current output remains.

### ADAPTER-B-003: Exit statuses unchanged

Handled errors map to current nonzero behavior.

### ADAPTER-B-004: Output path resolution unchanged

Default and custom graph/report paths match baseline.

### ADAPTER-B-005: Fixed-time environment precedence unchanged

Adapters read current env variables and pass explicit values to core.

### ADAPTER-B-006: Core silence

Capture output around direct core calls; all presentation comes from adapter.

## 10. Full Regression

Run:

```sh
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

## 11. Static/Repository Checks

### STATIC-B-001: No MCP files/dependency

No committed `Gemfile`, MCP server, or `require "mcp"` in core.

### STATIC-B-002: No core presentation calls

Search core for `puts`, `warn`, `exit`, `abort`, and `ARGV`. Any occurrence requires explicit justification and should normally fail review.

### STATIC-B-003: No script shelling

Core does not invoke `ruby scripts/...`, `system`, backticks, or `Open3` for business operations.

### STATIC-B-004: Signposts

New directories have `AGENT.md`.

### STATIC-B-005: Privacy

No fixture in repository vault/worktree.

## 12. Pass Conditions

- Direct core test exits zero.
- M7A and M2-M6 tests exit zero.
- Graph/report fixed-time bytes match baseline.
- Review read output matches baseline.
- Core is side-effect free and presentation free.
- No mutation/agent/MCP scope is implemented.
- Lint and diff checks pass.

## 13. Failure Triage

- Byte drift: isolate parser, order, newline, or time change; do not update baseline blindly.
- Adapter prefix drift: restore adapter ownership.
- Core needs environment access: change API to accept explicit input.
- Parser behavior differs between scripts: use explicit mode or preserve separate logic until a later approved convergence.
- Mutation test fails: revert incidental mutation edits; M7B must not refactor them.
