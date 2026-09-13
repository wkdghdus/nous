# M7C Plan: Mutation Core and Vault Safety

Status: Draft execution plan

Date: 2026-08-08

Depends on: M7B complete and green

Unlocks: M7D Agent-Safe Read Operations

Umbrella PRD: `prd-m7-agent-ready-core-and-mcp.md`

Shared rules: `m7-shared-contract.md`

Verification contract: `test-spec-m7c-mutation-core-and-vault-safety.md`

## 1. Objective

Move all existing M2-M6 vault mutations behind the shared Nous Core and establish the safety primitives required before any new agent-controlled write is introduced.

M7C must preserve every current command while adding:

- vault-root/path validation;
- shared/exclusive OS file locking;
- atomic single-file replacement;
- coordinated multi-file transactions;
- cross-process collision safety;
- global duplicate-ID checks where a lookup or mutation depends on uniqueness;
- relationship approval integrity.

This is the highest-risk M7 stage because it touches existing data mutation. It should be implemented through small checkpoints, never as a single rewrite.

## 2. Requirements Summary

M7C must:

1. add a shared vault lock used by all current mutations;
2. add destination-local staging and atomic rename helpers;
3. preserve M6 three-output checksum/rollback behavior under the lock;
4. move M2 text ingestion into core;
5. move M6 artifact ingestion into core;
6. move review approve/reject/deprecate/merge into core;
7. keep `$EDITOR` process launching in the CLI adapter;
8. centralize safe path confinement for all core file access;
9. prevent cross-process collision races without changing single-process suffix semantics;
10. block relationship approval until both endpoints are active reviewed/canonical graph nodes;
11. preserve graph/report validation as independent defense in depth;
12. keep all current CLI behavior and existing vault records compatible;
13. add direct mutation, failure, locking, concurrency, and lifecycle tests;
14. add no agent write API and no MCP code.

## 3. Scope

### 3.1 In scope

Suggested files, adjusted to the M7B shape:

```text
lib/nous/path_guard.rb
lib/nous/vault_lock.rb
lib/nous/atomic_writer.rb
lib/nous/file_transaction.rb
lib/nous/collision_allocator.rb
lib/nous/text_ingestion.rb
lib/nous/artifact_ingestion.rb
lib/nous/review_mutation.rb
lib/nous/relationship_integrity.rb
scripts/test_nous_mutation_core.rb
```

Existing scripts likely changed:

```text
scripts/ingest_text.rb
scripts/ingest_artifact.rb
scripts/review_queue.rb
scripts/export_graph.rb                 # only if shared read lock/final writer is centralized
scripts/generate_nous_report.rb         # only if shared read lock/final writer is centralized
```

Supporting changes:

- `.gitignore` for runtime lock/temp state if necessary;
- `Makefile`;
- signposts;
- architecture docs.

### 3.2 Out of scope

- `status`, agent listing/search, record envelope, source-text read API.
- Candidate note/claim/relationship creation.
- Request IDs or idempotency metadata.
- Schema/template changes for M7 candidates.
- MCP dependency/server.
- Frontend/API/model/embedding/database/watcher scope.
- Vault-wide migration or rewrite.

## 4. Mandatory Design Decisions

### 4.1 Lock path

Use one predictable runtime lock file per vault, for example:

```text
<vault_root>/.nous.lock
```

Requirements:

- ignored by Git;
- never treated as a vault record;
- created with restrictive normal-user permissions;
- no PID/stale-lock protocol;
- OS `flock`-style semantics release on process termination;
- bounded acquisition timeout;
- safe error when vault is not writable.

Do not place lock state in a new tracked directory unless the repository intentionally adopts and signs it.

### 4.2 Lock modes

Preferred API:

```ruby
lock.with_shared { ... }
lock.with_exclusive { ... }
```

- coherent multi-file reads/builds may use shared lock;
- every mutation uses exclusive lock;
- final graph/report output generation should avoid reading across an active review mutation;
- no nested lock acquisition;
- public operations acquire the lock once and pass an internal context to helpers.

If platform constraints make shared locks unreliable, use one exclusive lock for coherent operations and document the performance tradeoff. Do not silently omit locking.

### 4.3 Atomic writer

Single-file writes:

1. validate destination;
2. create destination directory when contract permits;
3. create unique temp file in the destination directory;
4. write bytes;
5. flush and close;
6. optionally `fsync` file/directory when supported and justified;
7. verify any required parse/checksum condition;
8. fail if final destination unexpectedly exists when overwrite is forbidden;
9. atomically rename;
10. clean temp file in `ensure`.

Existing graph/report replacement semantics permit replacing their derived output only after successful validation. Existing source/candidate records remain no-overwrite/collision-safe.

### 4.4 File transaction

For M6 coordinated outputs:

- choose one suffix under exclusive lock;
- stage payload, artifact note, and draft note in their destination directories;
- verify copied payload size/digest;
- render/parse notes before finalization;
- finalize only after all staging succeeds;
- track invocation-created finals;
- on handled failure, remove staged files and invocation-created finals;
- preserve pre-existing files byte-identically.

Do not replace this with a database transaction or broad framework.

### 4.5 Path guard

Use resolved-path containment, not string-prefix checks.

The guard must address:

- `..` traversal;
- absolute outside paths;
- sibling prefix collisions (`/vault2` vs `/vault`);
- symlink file/directory escapes;
- path components that become symlinks between validation and use where practical;
- missing path cases;
- output destinations controlled by core/adapter contract.

Existing operator import sources may be outside the vault because the user explicitly supplies them. That exception is limited to current ingestion input validation; outputs and all internal references remain confined.

### 4.6 Core mutation results

Core returns structured data such as:

```ruby
{
  artifact_path: "00_raw_artifacts/...",
  draft_path: "01_agent_inbox/..."
}
```

It does not print absolute paths. CLI adapters format current absolute/current path output exactly as before when that is the current command contract.

### 4.7 Review edit command

`edit` remains an adapter concern:

1. core validates/resolves the inbox item;
2. adapter reads `$EDITOR` and launches it;
3. core does not spawn arbitrary commands.

Do not generalize this into command execution.

### 4.8 Relationship approval integrity

Before moving a relationship to canonical:

- resolve both endpoint IDs uniquely;
- require each endpoint to be an active reviewed note or active canonical claim;
- reject raw artifacts, inbox candidates, retired records, relationships, derived outputs, and missing/duplicate IDs;
- report all failing endpoint IDs and their computed lifecycle when safe;
- leave relationship source unchanged on failure;
- retain graph dangling-edge validation.

## 5. Acceptance Criteria

### 5.1 Shared safety primitives

- Lock works across separate processes.
- Timeout is bounded and actionable.
- Process termination releases lock.
- Atomic writer leaves no partial final output.
- Transaction rollback removes only invocation-created files.
- Path guard rejects traversal/symlink escape.
- Temp/lock files are ignored and not treated as records.

### 5.2 Existing text ingestion

- Current CLI invocation/outputs remain.
- Current frontmatter/body/IDs remain.
- Current duplicate suffix behavior remains.
- Concurrent same-slug imports produce distinct non-overwriting files.
- Failure leaves no partial note.

### 5.3 Existing artifact ingestion

- M6 allowlists and preservation remain.
- Original source is unchanged.
- Payload/artifact/draft share a suffix.
- Concurrent imports cannot claim the same set.
- Checksum/size verification remains.
- Forced failure leaves no orphan.
- External absolute source path remains absent.

### 5.4 Review mutations

- Approval/reject/deprecate/merge outputs and metadata remain.
- Existing destination collision failure remains.
- Mutations are atomic and lock-protected.
- Merge target confinement remains.
- Relationship approval gate works.
- `$EDITOR` behavior remains adapter-owned.

### 5.5 Compatibility

- M7A/M7B and all M2-M6 tests pass.
- Fixed graph/report bytes remain.
- Existing vault records require no migration.
- No agent/MCP API is added.

## 6. Implementation Sequence and Checkpoints

### Phase C0: Add failure-injection seams in tests

Before changing writes, identify controlled test seams for:

- failure after staging;
- failure after first finalization in M6;
- lock held by another process;
- collision discovered after an initial check;
- approval endpoint failure.

Use test-only injected callable/filesystem adapter where minimal. Do not add production “debug flags” or environment-controlled destructive behavior.

### Phase C1: Implement path guard

Create narrow functions for:

- validating vault root exists/is directory;
- resolving known internal paths;
- asserting containment;
- rejecting symlinks per operation policy;
- converting safe internal path to vault-relative form.

Do not force external operator source paths through internal containment before copying; validate them as explicit regular non-symlink source files under existing M2/M6 rules.

Focused tests: PATH-C series.

### Phase C2: Implement lock

Implement process-safe lock with timeout.

Define:

- default timeout;
- polling strategy if nonblocking lock is used;
- timeout error code/message;
- shared/exclusive methods;
- no nested acquisition contract.

Do not include user text in lock diagnostics.

Focused tests: LOCK-C-001 through LOCK-C-004.

### Phase C3: Implement atomic writer/transaction

Start with isolated temporary tests.

Writer supports:

- create-no-overwrite;
- replace-derived-output after validation;
- destination-local temp names;
- cleanup.

Transaction supports M6 only; avoid generic distributed transaction abstractions.

Focused tests: WRITE-C and TX-C.

### Phase C4: Extract text ingestion

Move validation/rendering/path allocation/write into core. Preserve:

- source validation;
- date/slug/title/facts behavior;
- raw artifact and draft frontmatter;
- body sections;
- duplicate suffix;
- output path results.

Adapter retains CLI/date parsing and current stdout/stderr.

Checkpoint:

```sh
ruby scripts/test_nous_mutation_core.rb --text
ruby scripts/test_ingest_text.rb
ruby scripts/test_cli_contracts.rb
```

Then add concurrent same-slug subprocess test.

### Phase C5: Extract artifact ingestion

Move M6 logic into core using shared transaction/lock.

Preserve exact allowlists, text bounds, metadata-only binary behavior, source metadata, suffix coordination, digest and rollback.

Do not “improve” media validation or add OCR.

Checkpoint:

```sh
ruby scripts/test_nous_mutation_core.rb --artifact
ruby scripts/test_ingest_artifact.rb
```

Run forced failure and concurrency tests immediately.

### Phase C6: Extract review mutations

Move:

- load/validate pending item;
- approval routing;
- decision metadata;
- approve/reject/deprecate/merge writes;
- evidence merge/dedup;
- destination collision checks.

Retain adapter command parsing/output/editor launch.

Checkpoint each operation rather than moving all at once:

1. reject/deprecate;
2. note approval;
3. claim approval;
4. merge;
5. relationship approval with new integrity gate.

Run `test_review_queue.rb` after each checkpoint.

### Phase C7: Add relationship endpoint gate

Use authoritative record index/lifecycle classification.

Test the full ordering:

- relationship with two pending endpoints cannot approve;
- approve one endpoint: still blocked;
- approve both: succeeds;
- endpoint retired after proposal: blocked;
- manually malformed canonical edge still fails graph export.

Do not auto-approve endpoints or rewrite relationship IDs.

### Phase C8: Apply locks to coherent reads/derived writes

Ensure graph/report/review report generation cannot observe an inconsistent review move. Use shared lock during discovery/build and exclusive or appropriate write coordination for final derived output replacement.

Avoid deadlock by having one top-level lock owner per operation.

### Phase C9: Update docs/signposts/ignore rules

Document:

- runtime lock file;
- lock timeout;
- atomicity;
- relationship approval ordering;
- no user-visible command change.

Update `.gitignore` for runtime lock/temp artifacts without ignoring real vault notes.

### Phase C10: Full regression and adversarial verification

Run all focused, existing, full, lint, diff, privacy, and temp-file scans. Use two-process tests, not only threads, for filesystem locking.

## 7. Detailed Failure Handling

### Lock acquisition failure

- no mutation begins;
- return `NOUS_LOCK_TIMEOUT`;
- include safe timeout/vault label but no body/path leak;
- CLI maps to current command prefix and nonzero status.

### Validation failure before staging

- no directory/file creation except harmless lock file;
- source unchanged;
- pre-existing destinations unchanged.

### Failure during staging

- remove staged files;
- no final created.

### Failure during multi-file finalization

- remove invocation-created finals;
- remove remaining staged files;
- preserve pre-existing files.

### Failure after single-file derived temp write

- preserve old graph/report;
- remove temp.

### Unexpected exception

- ensure lock release/temp cleanup;
- do not convert programmer bugs into success;
- tests may expose exception details, but normal CLI preserves sanitized error policy where applicable.

## 8. Codex Potholes and Prohibitions

Do not:

- use `File.exist?` followed by write without holding the lock;
- use PID files as locks;
- busy-wait without timeout/sleep;
- acquire the same lock recursively;
- lock different operations with different files;
- stage temp files on another filesystem;
- overwrite existing evidence;
- weaken M6 rollback to simplify extraction;
- serialize external source absolute paths;
- use string prefix for containment;
- follow symlinked source payloads;
- put `$EDITOR` execution into core;
- add generic shell execution;
- auto-fix relationship endpoints;
- remove graph endpoint validation;
- add request IDs/candidate writes/MCP early;
- change current filenames, frontmatter, headings, or output text;
- perform unrelated cleanup.

## 9. Risks and Mitigations

### Risk: Lock deadlock from nested public operations

Mitigation: one top-level acquisition; internal helpers receive context; tests detect nested call misuse.

### Risk: Cross-platform `flock` behavior

Mitigation: target supported local OS explicitly; process-based tests; document unsupported platform rather than fake safety.

### Risk: Atomic rename assumptions across filesystems

Mitigation: destination-local staging.

### Risk: Rollback deletes pre-existing file

Mitigation: track only invocation-created final paths and compare pre-existing sentinel bytes.

### Risk: Review mutation writes source before destination validation

Mitigation: validate full transaction and destination first; stage replacement; then move/replace under lock.

### Risk: Relationship gate breaks fixtures with missing endpoints

Mitigation: update only tests that intentionally approved invalid relationships; do not weaken gate. Existing valid fixture endpoints must be present.

### Risk: Read lock blocks normal use excessively

Mitigation: operations are personal-scale and short; keep critical sections bounded; no network/model work while locked.

## 10. Verification Commands

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

Manual checks:

- run two concurrent text imports;
- run two concurrent M6 imports;
- hold lock in one process and confirm timeout in another;
- kill lock holder and confirm recovery;
- force M6 failure and inspect destinations;
- approve relationship in pending/partially reviewed/fully reviewed endpoint states;
- scan for `.tmp`, lock, fixture, and private files.

## 11. Definition of Done

M7C is done when every existing mutation flows through the core, cross-process writes are safe, rollback and source preservation remain, relationship approval cannot create a known invalid canonical edge, all prior tests are green, and no agent/MCP scope has been added.

## 12. Suggested Execution Handoff

Use one executor. A separate verifier should run failure and two-process tests.

Internal checkpoints may be separate commits:

```text
C1 path + lock + writer
C2 text ingestion
C3 artifact ingestion
C4 review mutations + endpoint gate
```

Do not start the next checkpoint if the current one is not fully green.

Handoff message:

```text
Implement M7C only. Move existing mutations into Nous Core and add one shared
OS lock, path confinement, atomic writes, M6 transaction safety, and the
relationship approval endpoint gate. Preserve every CLI and vault contract.
Do not add agent reads/writes, idempotency, schema changes, MCP, or frontend.
```
