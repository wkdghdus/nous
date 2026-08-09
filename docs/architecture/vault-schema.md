# Vault Schema

Version: 0.1

This document defines the first usable Nous vault contract. It is intentionally file-first and manual-friendly: a user or agent should be able to create consistent Obsidian notes before any application code exists.

## Principles

- Preserve source material before interpretation.
- Keep generated work reviewable until a user accepts it.
- Separate source-backed facts, user-provided context, and model hypotheses.
- Use stable IDs so notes can be renamed without breaking graph references.
- Prefer portable Markdown, YAML frontmatter, and JSON exports.

## Vault Lifecycle

1. Raw evidence starts in `vault/00_raw_artifacts/`.
2. Generated drafts go to `vault/01_agent_inbox/`.
3. Reviewed notes move to `vault/02_notes/`.
4. Accepted claims and curated model records move to `vault/03_canonical_model/`.
5. Reports and graph exports are written to `vault/04_generated/`.

## Folder Contract

| Path | Purpose | Canonical Status |
| --- | --- | --- |
| `vault/00_raw_artifacts/text/` | Direct text reflections and short captures. | Source evidence |
| `vault/00_raw_artifacts/writing/` | Essays, journals, posts, and long-form documents. | Source evidence |
| `vault/00_raw_artifacts/images/` | Photos and screenshots with user-supplied context. | Source evidence |
| `vault/00_raw_artifacts/projects/` | Project records, READMEs, design docs, and summaries. | Source evidence |
| `vault/01_agent_inbox/notes/` | Draft generated notes awaiting review. | Non-canonical |
| `vault/01_agent_inbox/claims/` | Candidate claims awaiting review. | Non-canonical |
| `vault/01_agent_inbox/relationships/` | Candidate graph relationships awaiting review. | Non-canonical |
| `vault/02_notes/` | Reviewed notes grouped by type. | Reviewed |
| `vault/03_canonical_model/claims/` | Accepted source-backed claims. | Canonical |
| `vault/03_canonical_model/relationships/` | Accepted source-backed graph relationships. | Canonical |
| `vault/03_canonical_model/` | Accepted claims, relationships, identity records, values, goals, and timeline entries. | Canonical |
| `vault/04_generated/` | Regenerable reports and graph exports. | Derived |

## Stable ID Format

Use lowercase type prefixes, an ISO date when available, and a short slug:

```text
artifact_2026-06-14_evening-reflection
memory_2026-06-14_first-nous-schema
claim_2026-06-14_systems-building-pattern
edge_2026-06-14_claim-systems-evidenced-by-project
```

IDs are the stable graph handles. File names may change; IDs should not change after review unless the record is deliberately migrated.

## Required Frontmatter

Every note created from a template must include:

```yaml
id:
type:
schema_version: "0.1"
status: draft
review_status: agent_generated
created:
updated:
source:
  type:
  path:
  extraction_method:
```

Generated or interpretive notes must also include:

```yaml
confidence:
interpretation_level: low
evidence:
  - id:
    path:
counterevidence: []
```

## Review Statuses

| Status | Meaning |
| --- | --- |
| `agent_generated` | Created by an agent and not yet reviewed. |
| `needs_review` | Marked for user review after edits or import. |
| `reviewed` | Accepted by the user as accurate enough for reviewed notes. |
| `rejected` | Preserved for audit but excluded from normal generated outputs. |
| `deprecated` | Formerly useful but superseded by newer information. |

## Review Decisions

Review decisions are recorded in item frontmatter under a reusable `review` object:

```yaml
review:
  decision: approved
  decided_at: "2026-06-28T21:00:00Z"
  reviewer_note:
  merged_into:
```

Decision transitions:

- `approve` sets `review_status: reviewed`, `status: active`, refreshes `updated`, and moves the file to its reviewed or canonical destination.
- `reject` sets `review_status: rejected`, `status: archived`, refreshes `updated`, and leaves the source file in place for audit.
- `deprecate` sets `review_status: deprecated`, `status: archived`, refreshes `updated`, and leaves the source file in place for audit.
- `merge` records `review.decision: merged`, `review.merged_into`, sets the source `status: archived`, and appends source evidence to the merge target without deleting the source.

Inbox notes are generic `type: note`; approving a note must include an explicit reviewed note type so it can move to the matching `vault/02_notes/<type>/` directory. Claims move to `vault/03_canonical_model/claims/`. Relationships move to `vault/03_canonical_model/relationships/`.

Relationship approval is intentionally ordered. A candidate relationship cannot move to `vault/03_canonical_model/relationships/` until both endpoint IDs resolve uniquely to active reviewed records that are exportable graph nodes: a supported reviewed note in the matching `vault/02_notes/<type>/` directory, or an active reviewed canonical claim in `vault/03_canonical_model/claims/`. Pending inbox records, raw artifacts, canonical relationships, retired records, malformed reviewed-note directory/type combinations, duplicate IDs, and missing IDs block approval. Graph export keeps its own dangling-endpoint validation as a second defense.

## Interpretation Levels

| Level | Use |
| --- | --- |
| `none` | Raw artifact metadata only. |
| `low` | Classification, summary, and conservative linking. |
| `medium` | Explicit hypothesis grounded in evidence. |
| `high` | Out of MVP unless the user explicitly asks for deeper interpretation. |

## Relationship Records

Relationship notes represent reviewable graph edges. They should name source and target IDs, relationship type, confidence, evidence, and review status. Generated edges start in `vault/01_agent_inbox/relationships/`; approved edges move to `vault/03_canonical_model/relationships/`.

Allowed MVP relationship types:

- `evidenced_by`
- `supports`
- `contradicts`
- `influenced_by`
- `expresses`
- `mentions`
- `changed_by`
- `part_of`
- `similar_to`

## Graph Export

The M4 graph export is a deterministic, reviewed-only JSON projection written to `vault/04_generated/graph/nous_graph.json` by default. It is generated from accepted Markdown records and does not keep separate graph state.

Generation is serialized with the vault mutation lock while it builds the reviewed index and atomically replaces the derived JSON output. Custom `--output` paths retain the CLI contract, but replacement still uses destination-local staging.

Default export sources:

- Reviewed notes in direct child directories of `vault/02_notes/`.
- Reviewed canonical claims in `vault/03_canonical_model/claims/`.
- Reviewed canonical relationships in `vault/03_canonical_model/relationships/`.

Inbox records under `vault/01_agent_inbox/` are excluded from the default export even when their frontmatter resembles reviewed records. Rejected, deprecated, archived, pending, duplicate, unsupported, or dangling records must not appear as active graph records.

Graph node labels are deterministic: first Markdown H1, then frontmatter `title`, then the stable record ID. Node summaries are deterministic excerpts from the first non-empty non-heading body line, bounded to 240 characters. Graph node `source_path` points to the reviewed or canonical Markdown record path inside the vault; evidence refs carry source artifact or note provenance from frontmatter.

## Nous Report

The M5 Nous report is a deterministic, regenerable Markdown summary written to `vault/04_generated/reports/nous.md` by default. It is reviewed-only and source-backed: it reads reviewed notes from `vault/02_notes/`, canonical claims from `vault/03_canonical_model/claims/`, and canonical relationships from `vault/03_canonical_model/relationships/`.

The report command accepts `--vault-root PATH` for fixture or alternate vault roots and `--output PATH` for a different Markdown destination. It may quote or excerpt reviewed records, but it must not introduce new psychological conclusions, hidden inferences, or unsupported certainty beyond the source records.

Report generation, including review queue report generation, is serialized with the vault mutation lock and replaces derived output atomically. Review list and show operations take a shared lock so they do not observe an active review mutation mid-transition.

Inbox, rejected, deprecated, archived, and unsupported records are excluded from the default report. Relationship context is only shown when both endpoints resolve to included report entries.

## M6 Raw Artifact Imports

M6 expands the raw-artifact area into paired payload and provenance directories for supported writing, image, and project imports.

Type directories use the same split:

- `vault/00_raw_artifacts/writing/files/` holds copied writing payloads.
- `vault/00_raw_artifacts/writing/notes/` holds artifact records for those copied payloads.
- `vault/00_raw_artifacts/images/files/` holds copied image payloads.
- `vault/00_raw_artifacts/images/notes/` holds artifact records for those copied payloads.
- `vault/00_raw_artifacts/projects/files/` holds copied project payloads.
- `vault/00_raw_artifacts/projects/notes/` holds artifact records for those copied payloads.

The copied payload is the immutable source of record. The importer never renames, rewrites, deletes, or changes the permissions of the external original, and the artifact record uses the vault-relative copied payload path rather than the external absolute source path.

Artifact provenance can record the original filename, SHA-256 digest, and byte count as optional audit metadata on the `source` object. The copied payload path, original filename, digest, and byte count together make the import portable and auditable without exposing workstation-specific absolute paths.

Collision handling is additive: one shared suffix is chosen for the payload copy, artifact note, and inbox note so the emitted paths stay aligned. Existing files are never overwritten.

Binary and image imports stay metadata-only. They may record user-authored context, represented date, and import date, but they do not infer visible content, identity, emotion, or theme from the payload itself. Observed content remains empty unless the source is a supported text-like file and the importer can extract bounded source-backed facts.

The generated inbox note points to the artifact record, not directly to the copied payload. Review, graph export, and report generation continue to operate on reviewed or canonical Markdown records rather than raw payload files.

## M7C Vault Safety

M7C adds shared filesystem safety primitives without changing CLI contracts. Mutating CLI commands acquire one vault-scoped `.nous.lock` with OS `flock` semantics. Coherent reads use shared locks, and build-plus-derived-write commands use exclusive locks. The lock file is runtime state and is ignored by Git.

All new core-controlled writes stage in the destination directory before finalization. Evidence and candidate creation use no-overwrite finalization; derived outputs use atomic replacement after successful rendering or validation. Multi-file ingestion and merge operations track invocation-created files so handled failures remove only files from the current operation while preserving pre-existing records and external sources.

## Manual M1 Done Check

- A raw text artifact can be recorded with `templates/obsidian/artifact.md`.
- A draft memory, belief, value, project, pattern, or question can be created from a specific template.
- A claim can cite evidence and counterevidence.
- A relationship can connect two note IDs with confidence and review status.
- A graph export can represent the same IDs and relationships using `schemas/graph.schema.json`.
- A Nous report can represent reviewed records and canonical support without adding unsupported interpretation.
