# Ralph Context: M6 Raw Artifact Expansion

## Task statement

Implement `.omx/plans/m6-raw-artifact-expansion-plan.md` to add portable, source-preserving imports for writing, image, and project artifacts.

## Desired outcome

A dependency-free Ruby CLI copies one supported regular file into the matching vault raw-artifact area, records portable audit metadata, creates a conservative reviewable inbox note, preserves the external original, rolls back partial failures, and integrates without changing existing M2 ingestion or reviewed-only graph/report boundaries.

## Known facts and evidence

- The approved M6 plan defines closed type/extension allowlists, a three-output transaction, shared collision suffixing, metadata fields, and exact integration checks.
- Existing `scripts/ingest_text.rb` establishes the CLI, date, slug, YAML, and extractive-fact conventions that M6 should match without modifying M2 behavior.
- Existing review, graph, and report scripts consume Markdown records and enforce reviewed-only trust boundaries; copied binary payloads must not enter those discovery paths.
- The worktree already contains the user-authored M6 plan signpost edit in `.omx/plans/AGENT.md`; it must be preserved.
- No M6 PRD or test specification existed at Ralph startup, so they are derived from the approved plan before implementation to satisfy the workspace planning gate.

## Constraints

- Ruby standard library only; no new dependencies.
- Never mutate, rename, delete, chmod, or persist the absolute path of the external source.
- Reject unsupported or unsafe inputs before final output exists.
- Stage and verify all outputs, then finalize atomically enough to roll back every file created by a failed invocation.
- Keep binary/image interpretation metadata-only and user context visibly separate.
- Preserve `scripts/ingest_text.rb` behavior and reviewed-only graph/report behavior.
- Follow directory guidance and verify focused tests, full tests, lint, manual privacy/preservation behavior, architect review, changed-files-only deslop, and post-deslop regressions.

## Unknowns and open questions

- The exact existing frontmatter/body formatting and test helper patterns require repository inspection.
- The most portable forced-finalization-failure fixture must be chosen from existing filesystem/test conventions.
- Any platform-specific rename or permission behavior discovered during tests must be handled without weakening rollback guarantees.

## Likely codebase touchpoints

- `scripts/ingest_artifact.rb`
- `scripts/test_ingest_artifact.rb`
- `Makefile`
- `schemas/note-frontmatter.schema.yaml`
- `templates/obsidian/artifact.md`
- `README.md`
- `docs/architecture/vault-schema.md`
- `scripts/AGENT.md`
- `.omx/context/AGENT.md` and `.omx/plans/AGENT.md`
- `vault/00_raw_artifacts/**/AGENT.md`
