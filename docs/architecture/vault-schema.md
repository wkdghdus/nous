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
| `vault/03_canonical_model/` | Accepted claims, identity records, values, goals, and timeline entries. | Canonical |
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

## Interpretation Levels

| Level | Use |
| --- | --- |
| `none` | Raw artifact metadata only. |
| `low` | Classification, summary, and conservative linking. |
| `medium` | Explicit hypothesis grounded in evidence. |
| `high` | Out of MVP unless the user explicitly asks for deeper interpretation. |

## Relationship Records

Relationship notes represent reviewable graph edges. They should name source and target IDs, relationship type, confidence, evidence, and review status. Generated edges start in `vault/01_agent_inbox/relationships/`.

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

## Manual M1 Done Check

- A raw text artifact can be recorded with `templates/obsidian/artifact.md`.
- A draft memory, belief, value, project, pattern, or question can be created from a specific template.
- A claim can cite evidence and counterevidence.
- A relationship can connect two note IDs with confidence and review status.
- A graph export can represent the same IDs and relationships using `schemas/graph.schema.json`.
