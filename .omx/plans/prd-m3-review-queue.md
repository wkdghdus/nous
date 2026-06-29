# PRD: M3 Review Queue

## Problem

Generated inbox records can be created from text ingestion, but users cannot yet review, approve, reject, merge, or canonicalize them through a repeatable local workflow.

## Goal

Provide a dependency-free CLI and regenerable vault report for reviewing pending inbox notes, claims, and relationships while preserving provenance and auditability.

## Scope

- Pending queue discovery across `vault/01_agent_inbox/notes/`, `vault/01_agent_inbox/claims/`, and `vault/01_agent_inbox/relationships/`.
- Read-only item inspection with frontmatter, review-relevant body, and evidence/source references.
- State transitions for `approve`, `reject`, `deprecate`, and `merge`.
- Thin `edit` command using `$EDITOR`.
- Approved notes move to `vault/02_notes/<type>/`.
- Approved claims move to `vault/03_canonical_model/claims/`.
- Approved relationships move to `vault/03_canonical_model/relationships/`.
- Rejected, deprecated, and merged source files remain in place with decision metadata.
- Report generation to `vault/04_generated/reports/review_queue.md`.

## Non-Goals

- Web UI or application server.
- New dependencies or package-manager adoption.
- Automatic semantic merging.
- Deleting rejected, deprecated, or merged source files.
- Changing raw artifact ingestion behavior except through tests that prove compatibility.

## Acceptance Criteria

- `ruby scripts/review_queue.rb list` enumerates pending inbox items with path, kind, status, created date, confidence, evidence/source reference, and stable priority.
- `list` supports ordering by created date and confidence.
- `show PATH` prints item frontmatter, body, and evidence/source paths without mutation.
- `approve PATH --as TYPE` for notes validates reviewed note type and moves to the matching reviewed notes directory.
- `approve PATH` for claims and relationships moves them to canonical claims and canonical relationships destinations.
- `reject PATH` and `deprecate PATH` update files in place with archived status, decision timestamp, and optional reviewer note.
- `merge PATH --into TARGET` records merge provenance and removes the source from the pending queue without deleting it.
- `edit PATH` opens `$EDITOR` and fails clearly when no editor is configured.
- `report` regenerates `vault/04_generated/reports/review_queue.md` from live pending items.
- `make test` and `make lint` pass.

## Risks

- Data loss from overwrites; mitigate by failing if approval destination already exists.
- Ambiguous note routing; mitigate by requiring `--as TYPE`.
- Provenance drift in merge; mitigate by recording `review.merged_into` and leaving the source item intact.
