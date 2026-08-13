# PRD: M7D Agent-Safe Read Operations

Status: Final PRD for Ralph planning gate

Plan: `.omx/plans/m7d-agent-safe-read-operations-plan.md`

Test spec: `.omx/plans/test-spec-m7d-agent-safe-read-operations.md`

## Objective

M7D adds direct, mutation-free Nous Core read operations an external archivist agent can eventually use through MCP, without adding MCP in this stage:

- `status`
- `list_records`
- `read_record`
- `read_source_text`

The operations must be deterministic, bounded, stable-ID-based, lifecycle-aware, path-confined, and explicit that returned record/source content is untrusted data.

## In Scope

- Neutral `Nous::RecordIndex` for known-directory discovery, kind/lifecycle classification, duplicate grouping, strict/tolerant scans, symlink exclusion, and bounded diagnostics.
- Public one-shared-lock read methods and lock-free internal context helpers.
- `status` over bounded lifecycle counts and generated-output presence.
- Deterministic lexical listing/search.
- Curated bounded record reads by stable ID.
- Bounded source-text reads by artifact ID.
- Focused tests in `scripts/test_nous_agent_reads.rb`.
- Read contract docs under `docs/agent/`.
- `Makefile` wiring for the focused test.

## Out of Scope

- Candidate writes.
- Request IDs or idempotency.
- MCP server/tool files or dependencies.
- Schema/template migration.
- Semantic search, embeddings, vector/database/persistent index.
- Arbitrary path reads/imports.
- Binary/image bytes, base64, or interpretation.
- Frontend/API/model/network code.
- Review approval/rejection/edit tools.

## Users and Jobs

- Primary user: wants a future agent to inspect accepted knowledge and source evidence without gaining arbitrary file access or canonical write access.
- External archivist agent: will later consume these read semantics through MCP, but in M7D calls are direct core calls only.
- Maintainer: needs one tested core boundary future adapters can reuse without duplicating vault rules.

## Functional Requirements

### FR-D-001: Neutral Record Index

`Nous::RecordIndex` owns:

- known record directory discovery;
- symlinked directory/file exclusion;
- directory-aware record kind;
- lifecycle classification;
- duplicate grouping;
- tolerant and strict scan behavior;
- bounded sanitized diagnostics.

`RelationshipIntegrity` must not own read discovery. It may consume `RecordIndex` later after M7D is green.

### FR-D-002: Lock Boundary

Public read methods acquire exactly one shared vault lock. Internal `_in_context` helpers are lock-free and accept `RecordIndex::Context`, so future M7E can reuse the same index while holding its own operation lock.

### FR-D-003: Status

`status` returns:

- `vault_schema_version`;
- lifecycle/kind counts;
- generated report/graph presence;
- bounded warnings;
- no bodies, excerpts, external absolute paths, or arbitrary file data.

`status` uses tolerant scan semantics.

### FR-D-004: List Records

`list_records` supports:

- optional `query`, 1-500 characters;
- unique `scopes` from `raw_evidence`, `inbox`, `reviewed`, `canonical`;
- default scopes `reviewed`, `canonical`;
- optional unique supported `types`;
- `limit` 1-50, default 20.

It uses deterministic lexical retrieval only. It must not use embeddings, synonyms, model ranking, generated outputs, or copied payload body text.

### FR-D-005: Read Record

`read_record` resolves a unique stable ID and returns a curated envelope:

- ID, kind/type, lifecycle, review/status fields;
- safe relative path;
- normalized evidence/counterevidence refs;
- bounded body and truncation metadata;
- redacted external source paths;
- `content_role: untrusted_data`.

Direct unique retired record reads are allowed and labeled `retired`.

### FR-D-006: Read Source Text

`read_source_text` accepts `artifact_id`, `offset_chars`, and `max_chars`.

Supported text:

- M2 text artifacts: extract only embedded `Observed Content`; never follow external `source.path`.
- M6 writing/project text-like copied payloads: resolve only vault-relative copied payload paths and verify extension, UTF-8, checksum, and bytes when present.

Known unavailable content:

- image artifacts;
- binary project screenshots.

Known unavailable content returns a structured result with:

- `content_available: false`;
- `content_unavailable_reason`;
- lifecycle/content labels;
- no bytes;
- no base64;
- no interpretation;
- no raised exception.

Error cases:

- malformed artifact note;
- unsafe/traversal path;
- symlink;
- missing payload;
- corrupt payload;
- invalid UTF-8;
- checksum mismatch;
- byte-count mismatch;
- duplicate artifact ID;
- unknown artifact ID;
- invalid offset or max.

These cases raise stable sanitized errors.

## Non-Functional Requirements

- Mutation-free except possible documented `.nous.lock` runtime state.
- Deterministic for fixed vault state and fixed inputs.
- Offline and local-only.
- No telemetry or network.
- No private fixture data in the repository.
- Bounded results and diagnostics.
- Stable sanitized errors.
- Existing M2-M7C behavior remains green.

## Acceptance Criteria

1. `Nous::RecordIndex` is present and neutral; read APIs do not depend on `RelationshipIntegrity`.
2. Public reads acquire one shared lock; internal context helpers acquire none.
3. `status` uses tolerant scan and returns bounded counts/diagnostics without content.
4. `list_records`, `read_record`, and `read_source_text` use strict scan semantics.
5. Directory-aware classification covers raw, inbox, reviewed, canonical, contradiction, relationship, and retired records.
6. Symlinked known directories/files are rejected/excluded even when resolving inside the vault.
7. Duplicate IDs never silently choose one record.
8. Record/list envelopes are curated, bounded, lifecycle-labeled, and `untrusted_data` labeled.
9. M2 source reads do not follow `source.path`.
10. M6 text payload reads validate path, extension, UTF-8, checksum, and bytes where present.
11. Known image/binary artifacts return structured unavailable results and no bytes/base64/interpretation.
12. Unsafe/corrupt/malformed source cases raise stable sanitized errors.
13. Existing graph/report reviewed-only behavior remains unchanged.
14. All focused and regression tests pass.
15. No M7E/M7F scope is implemented.

## Verification

The implementation must satisfy `.omx/plans/test-spec-m7d-agent-safe-read-operations.md` and the verification commands in `.omx/plans/m7d-agent-safe-read-operations-plan.md`.

