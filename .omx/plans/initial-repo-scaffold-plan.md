# Initial Repository Scaffold Plan

## Requirements Summary

- Create a boilerplate-only repository structure for Nous.
- Do not create an application project, runtime, package manager setup, or dependencies.
- Add agent-friendly `AGENT.md` signposts at each directory level.
- Keep the MVP text-first despite older requirements mentioning voice or transcripts, because root guidance excludes voice/audio/transcript MVP work.
- Initialize a nested Git repository in this directory and create an initial commit.

## Acceptance Criteria

- `git rev-parse --show-toplevel` from this directory resolves to `/Users/wkdghdus/Desktop/coding/nous`.
- Every committed directory, excluding `.git`, has an `AGENT.md` signpost.
- Empty intentional directories contain `.gitkeep` placeholders.
- The scaffold contains docs, schemas, templates, and vault areas but no source app project or dependency manifest.
- The initial commit follows the Lore Commit Protocol.

## Implementation Steps

1. Add `.gitignore`, `README.md`, and update root `AGENT.md` with a direct-child map.
2. Add `docs/`, `schemas/`, `templates/`, and `vault/` signpost trees.
3. Add lightweight schema/template placeholders only where useful for future work.
4. Initialize a nested Git repo in `/Users/wkdghdus/Desktop/coding/nous`.
5. Stage only this repository's scaffold files and create the initial commit.

## Risks and Mitigations

- Risk: Accidentally committing parent-home repository noise.
  Mitigation: Initialize a nested repository in `nous` before staging.
- Risk: Scaffolding implies implementation decisions too early.
  Mitigation: Avoid app source folders, package manifests, dependencies, and runtime code.
- Risk: Requirements mention voice while local guardrails exclude it.
  Mitigation: Use text, writing, image, and project artifact placeholders only.

## Verification Steps

- Run `find` to confirm signpost coverage.
- Run `git status --short`.
- Run `git rev-parse --show-toplevel`.
- Inspect the initial commit summary.
