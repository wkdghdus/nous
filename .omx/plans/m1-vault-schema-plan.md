# M1 Vault Schema Plan

## Requirements Summary

M1 turns the initial scaffold into a usable vault schema baseline. The deliverable is still documentation and templates only: no application runtime, no dependencies, and no ingestion automation.

Grounding:

- `nous_requirements_and_user_flows.md` defines M1 as "Vault schema" with folder structure, note templates, and YAML schema.
- `AGENT.md` keeps the MVP text-first and excludes voice, audio, dictation, and transcript features.

## Acceptance Criteria

- Manual notes can be created from templates for artifacts, memories, values, beliefs, projects, patterns, questions, claims, and relationships.
- Frontmatter fields define required metadata, review status, provenance, and interpretation safety.
- Graph export schema captures nodes, edges, evidence, confidence, and review status.
- Vault lifecycle is documented from raw artifact to inbox to reviewed notes to canonical model to generated outputs.
- No source app, package manifest, dependency lockfile, or runtime code is added.

## Implementation Steps

1. Add `docs/architecture/vault-schema.md` as the human-readable vault contract.
2. Add `docs/decisions/0001-vault-schema-first.md` to record the first project decision.
3. Expand `schemas/note-frontmatter.schema.yaml` and `schemas/graph.schema.json`.
4. Add Obsidian templates for the initial note types.
5. Update local signposts to list new direct children.

## Risks and Mitigations

- Risk: Templates become too interpretive.
  Mitigation: Separate source-backed facts, user context, and hypotheses.
- Risk: Schema becomes too rigid before implementation.
  Mitigation: Keep schema versioned and explicit but still draft-level.
- Risk: Requirements mention transcript support.
  Mitigation: Follow root guidance and leave audio/transcript out of MVP artifacts.

## Verification Steps

- Parse JSON schema syntax.
- Confirm no `package.json` exists.
- Confirm committed directories have `AGENT.md` signposts.
- Review `git diff --stat` for scaffold-only changes.
