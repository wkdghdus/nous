# M2 Basic Ingestion Plan

## Requirements Summary

M2 adds the first automated ingestion path for local text captures. A raw text input should become a preserved artifact note under `vault/00_raw_artifacts/text/` plus one or more reviewable draft Obsidian notes under `vault/01_agent_inbox/notes/`.

Grounding:

- `nous_requirements_and_user_flows.md` defines M2 as "Basic ingestion" where raw input becomes an artifact note plus draft Obsidian notes.
- `AGENT.md` requires local-first, text-first MVP work and explicitly excludes voice, audio, dictation, and transcript features from the MVP.
- `README.md` says no application project exists yet, and `scripts/AGENT.md` keeps scripts dependency-free until the project explicitly adopts a runtime.
- `docs/architecture/vault-schema.md` defines the lifecycle from raw artifacts to generated inbox drafts and the required provenance frontmatter.
- `scripts/lint.sh` rejects `package.json`, validates JSON/YAML syntax, and enforces directory signposts.

## Acceptance Criteria

- A local command can ingest a UTF-8 `.txt` or `.md` file without adding a package manager, runtime manifest, or third-party dependency.
- Ingesting a valid text file creates exactly one artifact note in `vault/00_raw_artifacts/text/` with `type: artifact`, `review_status: needs_review`, `interpretation_level: none`, stable `artifact_YYYY-MM-DD_slug` ID, source metadata, and the original content preserved under `## Observed Content`.
- The same ingest run creates at least one draft note in `vault/01_agent_inbox/notes/` with `review_status: agent_generated`, `interpretation_level: low`, an evidence reference to the artifact ID/path, and conservative source-backed sections only.
- Generated filenames are deterministic and collision-safe: repeated imports of the same source path on the same date do not overwrite prior artifact or draft notes unless an explicit force option is added later.
- The ingestion path records provenance with source type, source path, extraction method, created date, updated date, and evidence references matching `docs/architecture/vault-schema.md`.
- Invalid input paths, directories, empty files, and unsupported extensions fail with non-zero exit codes and actionable error messages.
- The implementation does not create reviewed notes, canonical model records, graph exports, transcript-specific metadata, audio processing, or model-generated psychological analysis.
- `make lint` passes after implementation and any new committed directories include `AGENT.md` signposts.

## Implementation Steps

1. Add a dependency-free ingestion script, likely `scripts/ingest_text.rb`, and a small shell entry point only if needed.
   - Parse a single source path argument first; keep flags minimal.
   - Validate file existence, extension, non-empty content, and UTF-8 readability.
   - Generate stable slugs from the source filename and dates using Ruby standard library only.

2. Emit the raw artifact note using the current artifact template contract.
   - Target `vault/00_raw_artifacts/text/`.
   - Populate required frontmatter from `schemas/note-frontmatter.schema.yaml`.
   - Preserve the full source text under `## Observed Content`.
   - Keep `interpretation_level: none`; the artifact is evidence, not analysis.

3. Emit the first draft note into the agent inbox.
   - Target `vault/01_agent_inbox/notes/`.
   - Use the generic note shape from `templates/obsidian/note.md`.
   - Fill `## Source-Backed Facts` with a conservative extractive summary, such as title/first lines and basic observed themes.
   - Leave `## Tentative Hypotheses` empty or explicitly minimal; do not infer identity, values, or mental state.
   - Add evidence pointing back to the generated artifact note.

4. Add focused regression fixtures and tests for ingestion behavior.
   - Prefer a dependency-free script such as `scripts/test_ingest_text.sh` or a Ruby test file using standard library facilities.
   - Use a temporary copy of the vault or configurable output root so tests do not write private data into the real vault.
   - Cover valid text import, markdown import, duplicate collision handling, empty file failure, unsupported extension failure, and missing path failure.

5. Wire verification into existing maintenance commands.
   - Update `Makefile` with a narrow test target if useful, while keeping `make lint` intact.
   - Consider whether `scripts/lint.sh` should remain hygiene-only or call the new ingestion tests via a separate `make test` target.

6. Document the operator workflow.
   - Update `README.md` with the ingestion command, expected output locations, and text-only MVP boundary.
   - Update `scripts/AGENT.md` to list the new script and test helper.
   - Update relevant vault signposts only if new direct children are added; existing text and inbox note directories already exist.

## Risks and Mitigations

- Risk: M2 wording mentions transcripts, while root guidance excludes transcript features.
  Mitigation: Implement plain text and Markdown imports only. Treat any future transcript support as a separate scope change after MVP guidance changes.
- Risk: The draft note generator over-interprets personal content.
  Mitigation: Use low-interpretation, source-backed extraction only; do not classify memories, beliefs, values, or patterns until review workflows exist.
- Risk: Tests accidentally write personal raw data into `vault/`.
  Mitigation: Make tests use temporary directories and fixture content, then assert generated paths and frontmatter.
- Risk: Handwritten YAML generation becomes invalid for edge-case text.
  Mitigation: Generate frontmatter from structured Ruby hashes where practical, escape scalar values safely, and validate with existing YAML lint.
- Risk: Deterministic names collide during repeated imports.
  Mitigation: Add suffixes such as `-2`, `-3` when the target filename already exists; do not overwrite by default.
- Risk: Introducing an app runtime too early conflicts with scaffold constraints.
  Mitigation: Use Ruby already required by `scripts/lint.sh`; do not add `package.json`, lockfiles, or third-party gems.

## Verification Steps

- Run the ingestion tests against temporary fixture input and confirm generated artifact and draft note contents.
- Run `make lint` to validate text hygiene, JSON/YAML syntax, and signpost coverage.
- Manually inspect one generated artifact note and draft note from a fixture to confirm required frontmatter, evidence path, and review statuses.
- Confirm `git status --short` only shows intended implementation, tests, docs, and planning/signpost updates.
- Confirm no package manager files, audio/transcript handlers, graph exports, reviewed notes, or canonical records were added.

## Suggested Execution Handoff

For `$ralph`:

- Use one executor lane for the Ruby ingestion script and CLI behavior.
- Use one test-engineer or verifier lane for fixture-based tests and lint coverage.
- Keep reasoning medium for implementation and high for verification because the main risk is provenance correctness rather than algorithmic complexity.

For `$team`:

- Executor 1 owns `scripts/ingest_text.rb` and any narrow Makefile target.
- Test-engineer owns ingestion fixtures/tests and temporary-output assertions.
- Writer owns README/signpost documentation.
- Verifier owns final `make lint`, generated fixture inspection, and scope-boundary checks.

Launch hint:

```sh
omx team --task ".omx/plans/m2-basic-ingestion-plan.md"
```

Team verification path:

- Team proves fixture ingestion, duplicate handling, validation failures, and lint.
- Ralph or the leader then verifies no private raw data, no package/runtime adoption, and no out-of-scope transcript/audio behavior.
