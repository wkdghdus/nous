# M2 Basic Ingestion Context Snapshot

Timestamp: 2026-06-14T23:51:43Z

## Task Statement

Implement `.omx/plans/m2-basic-ingestion-plan.md`.

## Desired Outcome

Add a dependency-free local text ingestion path that converts a UTF-8 `.txt` or `.md` file into one raw artifact note and one generated draft inbox note, with provenance preserved and tests covering success and failure cases.

## Known Facts and Evidence

- `.omx/plans/m2-basic-ingestion-plan.md` scopes M2 to text/Markdown ingestion and requires generated artifact plus draft inbox note outputs.
- `AGENT.md` requires local-first, text-first MVP work and excludes voice, audio, dictation, and transcript features.
- `scripts/AGENT.md` allows dependency-free repository maintenance scripts and rejects package-manager-specific tooling until a runtime is adopted.
- `scripts/lint.sh` already uses Ruby standard library, validates JSON/YAML files, checks text hygiene, and rejects `package.json`.
- `docs/architecture/vault-schema.md` defines the vault lifecycle and required provenance frontmatter.
- `templates/obsidian/artifact.md` defines the raw artifact note shape.
- `templates/obsidian/note.md` defines a general generated note shape, but its `type` field is blank.

## Constraints

- Do not add package manifests, third-party dependencies, audio/transcript handlers, reviewed notes, canonical records, or graph exports.
- Do not write private raw data into the real vault during tests.
- Keep generated interpretations conservative and source-backed.
- Preserve reviewable status: raw artifact notes use `needs_review`; generated inbox notes use `agent_generated`.

## Unknowns and Open Questions

- Whether later milestones will split generated drafts into typed memory, value, belief, project, pattern, or question notes.
- Whether future transcript support will be restored after MVP guidance changes.

## Likely Codebase Touchpoints

- `scripts/ingest_text.rb`
- `scripts/test_ingest_text.rb`
- `Makefile`
- `README.md`
- `scripts/AGENT.md`
- `schemas/note-frontmatter.schema.yaml`
- `templates/obsidian/note.md`
