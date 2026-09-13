# Test Specification: M7C Mutation Core and Vault Safety

Status: Draft verification contract

Date: 2026-08-08

Plan: `m7c-mutation-core-and-vault-safety-plan.md`

Depends on: M7A and M7B green

## 1. Test Strategy

M7C tests direct mutation APIs, subprocess CLI compatibility, process-level concurrency, forced failure cleanup, path adversaries, and lifecycle integrity.

Use separate processes for locking tests. Ruby threads alone do not prove inter-process safety.

## 2. Required Test Program

Add:

```sh
ruby scripts/test_nous_mutation_core.rb
```

It may support focus flags for development, but running without flags must execute all M7C coverage.

## 3. Fixture and Failure-Injection Rules

- Every test uses a temporary vault/source.
- All sources are synthetic.
- Capture pre-existing file bytes before mutation.
- Failure injection uses test-only collaborators/callables, not production environment backdoors.
- Every failure test scans for staged/temp/final files.
- Every concurrency test has a bounded timeout and kills child processes on test teardown.
- No child process writes to repository vault.

## 4. Path Guard Tests

### PATH-C-001: Valid internal path

Known vault child resolves and returns safe vault-relative path.

### PATH-C-002: Parent traversal

`../../outside` rejected.

### PATH-C-003: Absolute outside path

Rejected for internal read/write destination.

### PATH-C-004: Prefix collision

A sibling such as `<tmp>/vault-evil` is not considered inside `<tmp>/vault`.

### PATH-C-005: Symlink file escape

Internal symlink to outside file rejected.

### PATH-C-006: Symlink directory escape

Internal symlink directory to outside rejected.

### PATH-C-007: Symlink chain

Rejected.

### PATH-C-008: Missing internal parent

Creation allowed only for known server-controlled destination trees.

### PATH-C-009: Operator external import source

Current explicit source outside vault remains accepted when a regular non-symlink file with supported extension.

### PATH-C-010: External source symlink

Rejected under existing M6 policy.

### PATH-C-011: Relative path normalization

Equivalent internal spellings normalize to one result.

### PATH-C-012: Safe errors

No external absolute path appears in public structured error/details beyond what current CLI explicitly owns; core result/error remains sanitized.

## 5. Lock Tests

### LOCK-C-001: Exclusive acquire/release

One process acquires; second cannot acquire until release.

### LOCK-C-002: Shared readers

When shared lock mode is implemented, two readers coexist and a writer waits/fails by timeout.

### LOCK-C-003: Writer excludes readers/writers

Exclusive holder blocks another coherent operation.

### LOCK-C-004: Timeout

Bounded elapsed time and `NOUS_LOCK_TIMEOUT`.

### LOCK-C-005: Process termination

Kill holder process; new process acquires without deleting a PID file.

### LOCK-C-006: Exception releases lock

Raise inside lock block; subsequent acquisition succeeds.

### LOCK-C-007: Lock file ignored

Record discovery and lint do not treat `.nous.lock` as data.

### LOCK-C-008: Restrictive critical section

No model/network/sleeping work occurs under normal mutation lock beyond file operations and deterministic validation.

### LOCK-C-009: No nested lock deadlock

Public operation calling internal helper does not acquire second lock. If nested acquisition is prohibited, direct nested test fails fast with a programmer-facing error rather than hanging.

## 6. Atomic Writer Tests

### WRITE-C-001: Create new file

Bytes exact; temp removed.

### WRITE-C-002: No overwrite

Existing evidence/candidate destination remains byte-identical; stable conflict error.

### WRITE-C-003: Replace derived output

Validated graph/report atomically replaces old output.

### WRITE-C-004: Failure before rename

Old output preserved; temp removed.

### WRITE-C-005: Invalid directory/unwritable destination

Handled error; no partial output.

### WRITE-C-006: Destination-local staging

Temp path has same parent as final.

### WRITE-C-007: Unique temp names

Concurrent staging cannot collide.

### WRITE-C-008: Final newline/encoding

Preserve current output bytes.

## 7. Transaction Tests

### TX-C-001: Three-output M6 success

Payload/artifact/draft all finalized with one suffix.

### TX-C-002: Failure during payload staging

No final/temp files.

### TX-C-003: Checksum mismatch

No final; source unchanged.

### TX-C-004: Failure rendering artifact

Staged payload removed.

### TX-C-005: Failure rendering draft

All staged removed.

### TX-C-006: Failure after first finalization

Invocation-created final removed; pre-existing sentinels preserved.

### TX-C-007: Failure after second finalization

Both invocation-created finals removed.

### TX-C-008: Existing destination race

Under lock, second process allocates next suffix rather than overwriting/failing incorrectly.

### TX-C-009: External source removed after success

Copied payload and evidence chain remain.

### TX-C-010: Temp scan

No `.tmp-*` remains after success/failure.

## 8. Text Ingestion Core Tests

### TEXT-C-001: Direct core success

Structured result paths/IDs; core silent.

### TEXT-C-002: CLI compatibility

Current stdout, paths, frontmatter, body, and error prefix match baseline.

### TEXT-C-003: Explicit date/time injection

Core uses passed date; adapter precedence unchanged.

### TEXT-C-004: Source validation matrix

Missing, directory, extension, empty, invalid UTF-8 preserve behavior.

### TEXT-C-005: Duplicate suffix single process

Current `-2`, `-3` behavior.

### TEXT-C-006: Concurrent same slug

Two processes succeed with distinct complete artifact/draft sets; no overwrite or orphan.

### TEXT-C-007: Forced artifact write failure

No draft/orphan.

### TEXT-C-008: Source unchanged

Bytes/path/name/mode unchanged.

## 9. Artifact Ingestion Core Tests

Retain every M6 test and add:

### ART-C-001: Direct core structured result

Core returns safe relative/structured values and is silent.

### ART-C-002: Concurrent same source

Two processes create suffix-aligned sets.

### ART-C-003: Concurrent different sources same slug

Both preserved distinctly.

### ART-C-004: Lock timeout before source copy

No output/source mutation.

### ART-C-005: Rollback under lock

Failure releases lock and cleans files.

### ART-C-006: No external path leak after extraction

Scan generated Markdown.

### ART-C-007: Binary boundary preserved

No interpretation introduced by refactor.

## 10. Review Mutation Core Tests

### REVIEW-C-001: Direct reject

Structured result, current metadata, atomic write.

### REVIEW-C-002: Direct deprecate

Current metadata.

### REVIEW-C-003: Note approval

Requires type; valid move and metadata.

### REVIEW-C-004: Claim approval

Canonical claim destination.

### REVIEW-C-005: Merge

Target evidence updates atomically; source archived/annotated; failure before both updates leaves both unchanged.

### REVIEW-C-006: Destination collision

Source unchanged; destination unchanged.

### REVIEW-C-007: Invalid merge target traversal/symlink

Rejected.

### REVIEW-C-008: Concurrent decisions on same item

At most one valid transition succeeds; no duplicate destination or corrupted source.

### REVIEW-C-009: Concurrent report generation and approval

Report sees a coherent before-or-after state, not malformed/partial file.

### REVIEW-C-010: Edit remains adapter-owned

Core exposes validation/resolution only; no `system`/shell in core. Existing edit tests pass.

## 11. Relationship Approval Integrity

### REL-C-001: Two reviewed endpoints

Approval succeeds.

### REL-C-002: Both endpoints pending

Approval fails `NOUS_REVIEW_REQUIRED`; relationship bytes unchanged.

### REL-C-003: One pending, one reviewed

Fails and identifies pending endpoint.

### REL-C-004: Missing endpoint

Fails.

### REL-C-005: Duplicate endpoint ID

Fails `NOUS_DUPLICATE_ID`.

### REL-C-006: Raw artifact endpoint

Fails.

### REL-C-007: Relationship endpoint

Fails.

### REL-C-008: Retired endpoint

Fails.

### REL-C-009: Frontmatter-reviewed inbox endpoint

Fails because directory lifecycle is non-canonical.

### REL-C-010: Endpoint changes after proposal

Retiring endpoint before approval blocks approval.

### REL-C-011: Progressive review ordering

Pending/pending blocked; approve first blocked; approve second succeeds.

### REL-C-012: Graph defense in depth

A manually placed malformed canonical relationship still causes graph export failure.

## 12. Regression and Byte Compatibility

### REG-C-001: M7A CLI characterization

Passes.

### REG-C-002: M7B direct read core

Passes.

### REG-C-003: M2-M6 direct tests

All pass.

### REG-C-004: Fixed graph/report bytes

Match baseline.

### REG-C-005: No migration

Copy a synthetic pre-M7 vault; run read/generate commands; existing records remain byte-identical except intentional generated output.

## 13. Static/Privacy Checks

### STATIC-C-001: All mutations use lock

Review public mutation entrypoints; tests can instrument lock acquisition count.

### STATIC-C-002: No string-prefix containment

No unsafe `start_with?` path security check in path guard.

### STATIC-C-003: No PID lock

No PID/stale lock protocol.

### STATIC-C-004: No shell/editor in core

Search `system`, backticks, `Open3`, `$EDITOR` in core.

### STATIC-C-005: No agent/MCP code

No candidate APIs, request IDs, `require "mcp"`, or server files.

### STATIC-C-006: Runtime files ignored

Lock/temp runtime artifacts untracked.

### STATIC-C-007: Privacy

No fixture/private payload or absolute temp path leaks.

## 14. Verification Order

```sh
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
git diff --check
git status --short
```

Then run manual two-process/failure/relationship sequence and scan temp/lock/private files.

## 15. Pass Conditions

- All focused and prior tests pass.
- Concurrency tests terminate within bounded time.
- No overwrite/orphan/temp leak occurs.
- Existing source and pre-existing destination bytes remain intact on failure.
- Relationship approval integrity is enforced.
- Current CLI/output contracts remain.
- No M7D-M7F scope is present.

## 16. Failure Triage

- Hanging test: capture child PIDs/stderr, terminate, inspect nested lock usage.
- Collision overwrite: verify allocation occurs inside exclusive lock.
- Rollback deletes sentinel: fix invocation-created tracking before continuing.
- Byte drift: restore adapter/render behavior; do not update baseline.
- Relationship existing test fails because fixture endpoints absent: make fixture valid; do not weaken gate.
