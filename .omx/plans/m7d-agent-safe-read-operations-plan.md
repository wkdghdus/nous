# M7D Plan: Agent-Safe Read Operations

Status: Consensus approved final plan

Consensus result: Critic iteration 2 `APPROVE`

Cross-links:

- PRD: `.omx/plans/prd-m7d-agent-safe-read-operations.md`
- Test spec: `.omx/plans/test-spec-m7d-agent-safe-read-operations.md`
- Source context: `.omx/context/nous-m7d-20260812T002925Z.md`
- Staged M7 package: `.omx/plans/nous-m7-six-stage-draft/`

## RALPLAN-DR Summary

### Principles

1. **Vault authority remains file-first.** M7D adds no database, persistent index, vector store, hidden canonical state, migration, or generated duplicate truth (`.omx/plans/nous-m7-six-stage-draft/m7-shared-contract.md:79-81`, `.omx/plans/nous-m7-six-stage-draft/m7-shared-contract.md:252-260`).
2. **Agent reads are ID-based and bounded.** Records are addressed by stable IDs, source text by artifact ID, and all user/content payloads are bounded and labeled `content_role: untrusted_data` (`.omx/plans/nous-m7-six-stage-draft/m7-shared-contract.md:201-221`, `.omx/plans/nous-m7-six-stage-draft/m7-shared-contract.md:262-275`).
3. **Discovery belongs to a neutral core primitive.** `Nous::RecordIndex` owns discovery, directory-aware kind/lifecycle classification, duplicate grouping, strict/tolerant scan behavior, symlink exclusion, and diagnostics. `RelationshipIntegrity` remains endpoint-validation logic and may consume `RecordIndex` later (`lib/nous/relationship_integrity.rb:5-24`, `lib/nous/relationship_integrity.rb:39-67`).
4. **M2-M7C behavior cannot drift.** Existing CLI contracts, reviewed-only graph/report behavior, mutation safety, lock behavior, and regression suites remain authoritative (`.omx/plans/nous-m7-six-stage-draft/m7-shared-contract.md:135-155`, `.omx/plans/nous-m7-six-stage-draft/m7-execution-map.md:66-72`, `Makefile:6-14`).
5. **Conservative exposure beats convenience.** No arbitrary paths, no raw frontmatter leaks, no binary bytes/base64, no model calls, no network, no MCP files, and no candidate-write/idempotency scope (`.omx/plans/nous-m7-six-stage-draft/m7d-agent-safe-read-operations-plan.md:68-79`, `.omx/plans/nous-m7-six-stage-draft/m7-shared-contract.md:157-191`).

### Decision Drivers

1. **Safety/privacy:** M7D's highest risk is arbitrary file access and trust confusion (`.omx/plans/nous-m7-six-stage-draft/m7-execution-map.md:38-45`).
2. **Leverage without coupling:** current code already has stable errors, Markdown parsing, reviewed-only graph/report loaders, known record dirs, path confinement, and locks (`lib/nous.rb:75-83`, `lib/nous.rb:163-178`, `lib/nous.rb:187-214`, `lib/nous/path_guard.rb:21-46`, `lib/nous/vault_lock.rb:18-30`).
3. **Stage isolation:** M7D unlocks M7E but must not implement M7E/M7F features (`.omx/plans/nous-m7-six-stage-draft/m7-execution-map.md:74-80`).

### Viable Options

#### Option A: Neutral `Nous::RecordIndex` plus thin read services

Pros:

- One source for discovery/classification/duplicates/diagnostics.
- Keeps relationship approval logic from owning read APIs.
- Preserves `Nous.load_records` as reviewed/export-only for graph/report (`lib/nous.rb:187-214`).
- Gives M7E a future evidence-resolution primitive without implementing writes.

Cons:

- Adds a small module and requires regression coverage around graph/report and relationship integrity.

#### Option B: Four independent scanners

Pros:

- Small-looking per-operation implementation.

Cons:

- Duplicate/lifecycle/malformed/symlink behavior can diverge across operations.
- Harder for M7E to reuse safely.

#### Option C: Make `RelationshipIntegrity` the read owner

Pros:

- Reuses `records_by_id` and `lifecycle_for` directly (`lib/nous/relationship_integrity.rb:69-90`, `lib/nous/relationship_integrity.rb:119-128`).

Cons:

- Rejected. Relationship approval is consumer-specific validation, not neutral discovery. Coupling reads to it would invite review/write logic into read operations.

#### Option D: Expand `Nous.load_records`

Pros:

- Reuses current `Record` and parser helpers (`lib/nous.rb:85`, `lib/nous.rb:163-178`).

Cons:

- Rejected. `Nous.load_records` currently feeds reviewed/canonical graph/report discovery; broadening it risks reviewed-only output drift (`lib/nous.rb:187-214`, `.omx/plans/nous-m7-six-stage-draft/m7-shared-contract.md:106-115`).

**Decision:** Option A.

## Requirements Summary

M7D adds direct core operations only:

- `status`
- `list_records`
- `read_record`
- `read_source_text`

M7D must not add candidate writes, request IDs, idempotency, schema/template changes, MCP files, semantic search, persistent indexing, arbitrary path reads, frontend/API/model/network code, or binary source reads (`.omx/context/nous-m7d-20260812T002925Z.md:12-17`).

## Resolved Contracts

- `status` uses tolerant scanning and returns bounded diagnostics for malformed known records when safe counting can continue.
- `list_records`, `read_record`, and `read_source_text` use strict scans so selected corruption is not hidden.
- Duplicate IDs never resolve by sort order. `list_records` and `read_record` fail with `NOUS_DUPLICATE_ID`; `status` reports bounded duplicate diagnostics.
- Direct unique retired record reads are allowed and labeled `retired`; normal listing excludes retired records.
- Known image artifacts and binary project screenshots return structured `content_available: false` with `content_unavailable_reason`; they do not raise and never return bytes, base64, or interpretation.
- Malformed, unsafe, missing, corrupt, traversal, symlink, invalid UTF-8, checksum mismatch, and byte-count mismatch source cases raise stable sanitized errors.
- `offset_chars == total_chars` returns an empty chunk with `truncated: false`; `offset_chars > total_chars` raises `NOUS_INVALID_INPUT`.
- Safe legacy M6 text payloads missing checksum/byte metadata may be read with a bounded warning; if either field is present it must match.

## Directory-Aware Classifier

`Nous::RecordIndex` classifies from vault-relative path first, then validates frontmatter. Frontmatter cannot promote trust across directories (`.omx/plans/nous-m7-six-stage-draft/m7-shared-contract.md:93-105`).

| Relative path pattern | Record kind | Lifecycle |
| --- | --- | --- |
| `00_raw_artifacts/text/*.md` | `artifact` | `source_evidence` unless retired |
| `00_raw_artifacts/writing/notes/*.md` | `artifact` | `source_evidence` unless retired |
| `00_raw_artifacts/images/notes/*.md` | `artifact` | `source_evidence` unless retired |
| `00_raw_artifacts/projects/notes/*.md` | `artifact` | `source_evidence` unless retired |
| `01_agent_inbox/notes/*.md` | `note` | `agent_candidate` unless retired |
| `01_agent_inbox/claims/*.md` | `claim` | `agent_candidate` unless retired |
| `01_agent_inbox/relationships/*.md` | `relationship` | `agent_candidate` unless retired |
| `02_notes/{memories,values,beliefs,projects,patterns,decisions,people,questions,contradictions}/*.md` | directory-mapped note type | `human_reviewed` when active/reviewed, otherwise `retired` |
| `03_canonical_model/claims/*.md` | `claim` | `canonical` when active/reviewed, otherwise `retired` |
| `03_canonical_model/relationships/*.md` | `relationship` | `canonical` when active/reviewed, otherwise `retired` |

Retirement rule: `status: archived`, `review_status: rejected`, `review_status: deprecated`, or review decision `merged` makes the record `retired`.

## Operation Matrix

| Operation | Scan mode | Locking | Duplicate behavior | Malformed behavior | Symlink behavior | Content/redaction |
| --- | --- | --- | --- | --- | --- | --- |
| `status` | tolerant | one public shared lock; internal context lock-free | bounded diagnostics | bounded diagnostics unless traversal unsafe | exclude/diagnose symlinked known dirs/files | no bodies/excerpts/absolute paths |
| `list_records` | strict selected scopes | one public shared lock; `_in_context` lock-free | `NOUS_DUPLICATE_ID` | stable error for selected malformed record | `NOUS_SYMLINK_REJECTED` | curated summaries, excerpt max 240, `untrusted_data` |
| `read_record` | strict unique ID | one public shared lock; `_in_context` lock-free | `NOUS_DUPLICATE_ID` | stable error for requested malformed record | `NOUS_SYMLINK_REJECTED` | curated envelope, bounded body, redaction |
| `read_source_text` | strict artifact ID | one public shared lock; `_in_context` lock-free | `NOUS_DUPLICATE_ID` | stable source/parse error | `NOUS_SYMLINK_REJECTED` | artifact-ID only; binary unavailable object; text bounded |

## Implementation Steps

1. **Baseline before edits.**
   - Run `ruby scripts/test_nous_read_core.rb`, `ruby scripts/test_nous_mutation_core.rb`, `make test`, `make lint`, and `git status --short`.
   - Existing broad test target is in `Makefile:6-14`.

2. **Add neutral `Nous::RecordIndex`.**
   - New file: `lib/nous/record_index.rb`.
   - Mirror or extract known directory and note-type rules from current relationship code without making `RelationshipIntegrity` the read owner (`lib/nous/relationship_integrity.rb:5-35`, `lib/nous/relationship_integrity.rb:39-67`).
   - Implement `scan` tolerant semantics, `scan!` strict semantics, duplicate grouping, bounded diagnostics, directory-aware classifier, deterministic ordering, and `RecordIndex::Context`.
   - Reject/exclude symlinked known directories and record files, including symlinks resolving inside the vault.
   - Keep `Nous.load_records` reviewed/export-only (`lib/nous.rb:187-214`).

3. **Add read operation namespace.**
   - New file: `lib/nous/agent_reads.rb`, or split small files if clearer.
   - Add public one-shared-lock methods: `status`, `list_records`, `read_record`, `read_source_text`.
   - Add lock-free internal helpers: `status_in_context`, `list_records_in_context`, `read_record_in_context`, `read_source_text_in_context`.
   - Update `lib/nous.rb` requires after current common primitives (`lib/nous.rb:10-18`).

4. **Add curated envelopes.**
   - Curate summary and full-record fields. Do not return raw frontmatter, `Pathname`, unknown secret-shaped keys, or absolute paths.
   - Reuse local label/evidence/confidence helpers where appropriate (`lib/nous.rb:240-259`, `lib/nous.rb:261-325`).

5. **Implement `status`.**
   - Use tolerant scan.
   - Return `vault_schema_version`, counts, generated report/graph presence, and bounded warnings.
   - Do not include bodies, excerpts, or absolute paths.

6. **Implement `list_records`.**
   - Use strict selected-scope scan.
   - Validate query/scopes/types/limit strictly.
   - Default scopes: reviewed + canonical.
   - Implement lexical ranking only; no semantic/model/payload search.

7. **Implement `read_record`.**
   - Use strict unique-ID scan.
   - Permit unique retired direct reads with explicit labels.
   - Bound body by Unicode characters and redact external source paths.

8. **Implement `read_source_text`.**
   - Use strict artifact-ID scan.
   - M2 text artifacts: extract `## Observed Content` from the note only; never follow `source.path` (`lib/nous/text_ingestion.rb:122-138`, `lib/nous/text_ingestion.rb:173-195`).
   - M6 writing/project text payloads: resolve only safe vault-relative copied payloads and verify extension, UTF-8, checksum, and bytes when present (`lib/nous/artifact_ingestion.rb:8-14`, `lib/nous/artifact_ingestion.rb:185-207`).
   - Known image artifacts and binary project screenshots: return `content_available: false`, `content_unavailable_reason`, metadata, lifecycle/content labels, no bytes/base64/interpretation, no exception.
   - Malformed/unsafe/missing/corrupt/traversal/symlink/invalid UTF-8/checksum/byte mismatch cases raise stable sanitized errors.

9. **Add focused tests.**
   - New file: `scripts/test_nous_agent_reads.rb`.
   - Use synthetic temporary vaults only.
   - Cover mutation snapshots, deterministic repeats, directory-aware classifiers, strict/tolerant scans, duplicates, malformed records, symlinked dirs/files, symlink-to-inside-vault, source unavailable vs source error distinction, path redaction, UTF-8/offset behavior, and banned scope checks.

10. **Wire docs and test target.**
    - Add `docs/agent/AGENT.md` and `docs/agent/read-contract.md`.
    - Update `Makefile` to run `ruby scripts/test_nous_agent_reads.rb`.
    - Keep docs clear that M7D is core semantics, not MCP availability.

11. **Verify and audit.**
    - Run all commands in the Verification Plan below.
    - Search for banned scope, write primitives in read modules, private data, absolute paths, MCP/idempotency/candidate write creep.

## Acceptance Criteria

1. `Nous::RecordIndex` is the neutral discovery/classification/duplicate/diagnostic owner; read APIs do not depend on `RelationshipIntegrity`.
2. Public read operations acquire exactly one shared lock; `_in_context` helpers are lock-free and accept `RecordIndex::Context`.
3. Read modules do not call write primitives or create temp files; repeated reads leave vault bytes/names unchanged except possible `.nous.lock` runtime state (`lib/nous/vault_lock.rb:32-45`).
4. Index scans only known M7D record directories and excludes `AGENT.md`, non-Markdown files, copied payloads, generated outputs, unknown directories, and symlinked dirs/files.
5. Symlinked known dirs/files are excluded with tolerant diagnostics or rejected with `NOUS_SYMLINK_REJECTED`, including symlinks resolving inside the vault.
6. Duplicate IDs never pick a winner; strict selected operations raise `NOUS_DUPLICATE_ID`, status reports bounded diagnostics.
7. Lifecycle classifier covers raw, inbox notes, inbox claims, inbox relationships, reviewed note families including contradictions, canonical claims, canonical relationships, and retired variants.
8. `status` output is deterministic, bounded, body-free, excerpt-free, and absolute-path-free.
9. `list_records` validates query/scopes/types/limit; default scope is reviewed + canonical; raw/inbox require explicit opt-in; retired records are excluded.
10. Lexical search is deterministic and transparent; no embeddings, synonyms, model calls, generated-output search, or copied-payload search.
11. List summaries and record reads use curated envelopes, bounded excerpts/body, normalized evidence refs, lifecycle labels, and `content_role: untrusted_data`.
12. `read_record` resolves by stable ID, permits unique retired direct read with `retired` label, and redacts external absolute source paths.
13. `read_source_text` accepts artifact IDs only, not paths.
14. M2 source reads use only observed content embedded in the artifact note.
15. M6 text-like payload reads use only safe vault-relative copied payload paths and verify checksum/bytes when present.
16. Known image artifacts and binary project screenshots return `content_available: false` and `content_unavailable_reason`, with no bytes/base64/interpretation and no raised error.
17. Malformed/unsafe/missing/corrupt/traversal/symlink/invalid UTF-8/checksum/byte mismatch source cases raise stable sanitized errors.
18. All errors/results expose no external absolute paths, backtraces, environment variables, temp filenames, body excerpts in errors, or secrets.
19. Existing graph/report behavior remains reviewed/canonical-only.
20. Existing M2-M7C tests, focused M7D tests, `make test`, `make lint`, and `git diff --check` pass.
21. No M7E/M7F scope appears: no MCP files, candidate writes, request IDs, idempotency, schema migration, frontend, database, embeddings, network, or model-provider code.

## Risks and Mitigations

- **Graph/report drift:** keep `Nous.load_records` export-only and run existing graph/report tests.
- **Relationship coupling:** keep `RelationshipIntegrity` as a consumer candidate, not owner.
- **Read mutation:** snapshot vault before/after reads and statically search read modules for write primitives.
- **Trust confusion:** directory-first lifecycle, explicit labels, and `untrusted_data`.
- **Arbitrary file read:** artifact-ID-only source reads, `PathGuard` containment, no M2 external path following.
- **Unavailable vs error ambiguity:** image/binary known types return structured unavailable; unsafe/corrupt cases raise stable errors.
- **Unicode corruption:** decode valid UTF-8 before character slicing; reject invalid UTF-8.

## Verification Plan

```sh
ruby scripts/test_nous_agent_reads.rb
ruby scripts/test_nous_read_core.rb
ruby scripts/test_nous_mutation_core.rb
ruby scripts/test_cli_contracts.rb
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

Static audits:

```sh
rg -n "request_id|idempot|MCP|mcp|embedding|vector|OpenAI|Net::HTTP|TCPSocket|Sinatra|Rails|Rack|read_file|run_command" lib scripts docs Makefile
rg -n "AtomicWriter|FileTransaction|CollisionAllocator|ReviewMutation|TextIngestion\\.ingest|ArtifactIngestion\\.ingest|File\\.write|binwrite|File\\.rename|FileUtils" lib/nous
rg -n "/tmp/|/Users/|private|secret|api[_-]?key|BEGIN RSA" .
```

Interpret static audit hits manually. Existing write modules and docs may match; new read modules must not call write primitives or implement banned scope.

## ADR

### Decision

Implement M7D with neutral `Nous::RecordIndex` as the authoritative in-memory owner for record discovery, directory-aware kind/lifecycle classification, duplicate grouping, strict/tolerant scan semantics, symlink exclusion, and sanitized diagnostics. Public read services use that index for status, list/search, record reads, and source text reads.

### Drivers

- M7D's top risk is arbitrary file access and trust confusion.
- Current M7C code provides useful directory, path, and lock primitives but relationship endpoint validation should not own reads.
- M7D must preserve stage isolation and stop before candidate writes or MCP.

### Alternatives Considered

- Four independent scanners: rejected because semantics can diverge.
- `RelationshipIntegrity` as read owner: rejected because it couples reads to relationship approval.
- Expanding `Nous.load_records`: rejected because it risks graph/report reviewed-only behavior.
- Persistent index/cache: rejected because M7 keeps the vault reconstructable.

### Why Chosen

Neutral `RecordIndex` gives all read operations the same discovery, lifecycle, duplicate, symlink, and diagnostic semantics while keeping write/review/protocol code out of M7D.

### Consequences

- Adds a small core module.
- Requires explicit classifier and scan-mode tests.
- Provides a future-safe context for M7E evidence validation without implementing M7E.

### Follow-ups

- M7E may reuse `RecordIndex::Context` inside its own lock boundary.
- A later cleanup may refactor `RelationshipIntegrity.records_by_id` to consume `RecordIndex`.
- M7F maps MCP read tools to these core operations without owning vault logic.

## Available Agent Types

- `planner`: scope and handoff.
- `architect`: boundaries, classifier/index design, locking.
- `critic`: acceptance criteria and risk review.
- `executor`: implementation.
- `test-engineer`: fixtures, adversarial tests, regression coverage.
- `security-reviewer`: path/symlink/privacy/scope audit.
- `verifier`: final evidence pass.
- `writer`: read-contract docs.

## Execution Handoff

### `$ralph`

Launch hint:

```text
$ralph "Implement M7D from .omx/plans/m7d-agent-safe-read-operations-plan.md, .omx/plans/prd-m7d-agent-safe-read-operations.md, and .omx/plans/test-spec-m7d-agent-safe-read-operations.md. Add direct core status/list/read_record/read_source_text, neutral Nous::RecordIndex, focused tests, and read-contract docs. No MCP, no candidate writes, no idempotency, no schema migration, no arbitrary path reads, no model/network/frontend/database scope. Preserve M2-M7C behavior and run the full verification plan."
```

Suggested reasoning:

- Executor: high.
- Test-engineer lane inside Ralph loop: high.
- Verifier/security pass: high.

Ralph verification path:

1. `ruby scripts/test_nous_agent_reads.rb`
2. Existing read/mutation/core regressions.
3. `make test`, `make lint`, `git diff --check`, `git status --short`.
4. Static banned-scope/path/privacy audits.

### `$team`

Launch hint:

```text
$team "Implement M7D only from the finalized M7D plan/PRD/test-spec under .omx/plans. Split lanes into RecordIndex/envelopes, source reader, tests, docs, and security verification. No M7E/M7F scope."
```

Suggested staffing:

- `executor` lane 1, high: `Nous::RecordIndex`, strict/tolerant scans, lifecycle/kind classifier, status/list/read_record.
- `executor` lane 2, high: `read_source_text`, M2 observed content, M6 copied text payloads, structured unavailable results.
- `test-engineer`, high: `scripts/test_nous_agent_reads.rb`, fixtures, mutation snapshots, operation matrix tests.
- `writer`, medium: `docs/agent/AGENT.md`, `docs/agent/read-contract.md`.
- `security-reviewer`, high: symlink/path/privacy/banned-scope audit.
- `verifier`, high: final command suite.

Team verification path:

1. Test lane runs focused M7D tests after each merged behavior slice.
2. Security lane audits before broad tests.
3. Verifier runs the full verification plan.
4. Leader confirms final `git status --short` contains only intentional M7D implementation/test/doc files and no private fixture data.

## Consensus Changelog

- Iteration 1 draft chose a shared agent-read index and resolved open policy choices.
- Architect/Critic iteration 1 required neutral `Nous::RecordIndex`, strict/tolerant scans, symlink-to-inside-vault rejection, classifier table, operation matrix, and lock-free context API.
- Iteration 2 revised the draft to reject `RelationshipIntegrity` read ownership and add those contracts.
- Critic iteration 2 approved.
- Finalization applies the source availability rule: known image/binary artifacts return structured unavailable objects; unsafe/corrupt cases raise stable sanitized errors.
