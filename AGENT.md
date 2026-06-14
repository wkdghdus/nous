# Nous

Nous is a personal self-knowledge system. It turns user-authored text, raw artifacts, and project records into source-backed Obsidian notes, reviewed claims, and graph relationships. The MVP does **not** support voice input.

## Product guardrails

- Preserve provenance: every generated note, claim, or edge should point back to its source artifact or user input.
- Separate facts, user-authored context, and model hypotheses.
- The archivist agent should capture, classify, and connect; it should not psychoanalyze.
- Write generated notes to a reviewable state before treating them as canonical.
- Keep the interpersonal / friends web app as future scope unless explicitly requested.
- Do not add voice, audio, dictation, or transcript features to the MVP.

## Engineering behavior

### Think before coding

- State assumptions when they affect implementation.
- If the request is ambiguous, present the likely interpretations or ask.
- Push back when a simpler approach fits better.
- Stop and name confusion instead of silently guessing.

### Simplicity first

- Build the smallest solution that satisfies the request.
- Do not add speculative features, abstractions, options, or configurability.
- Avoid single-use abstractions.
- If the solution feels overbuilt, rewrite it smaller.

### Surgical changes

- Touch only files required for the task.
- Match existing style, naming, formatting, and structure.
- Do not refactor unrelated code or clean up unrelated dead code.
- Remove only unused imports, variables, or functions made obsolete by your change.
- Mention unrelated issues separately instead of fixing them unasked.

### Goal-driven execution

- Convert tasks into verifiable success criteria.
- For bugs: reproduce with a failing test or fixture, then fix.
- For validation: test invalid and valid inputs.
- For refactors: verify behavior before and after.
- After changes, run the narrowest useful check first, then broader checks when warranted.

## Done means

- The requested behavior is implemented and verified.
- No private raw data was added accidentally.
- MVP scope stayed intact.
- The relevant local guidance file was followed.
- Any uncertainty, tradeoff, or skipped check is stated clearly.

## Directory signposts

- `docs/` contains planning, architecture, and decision records.
- `schemas/` contains versioned data-shape drafts for notes, graph records, and exports.
- `templates/` contains reusable Obsidian note templates and future prompt/template assets.
- `vault/` contains the empty Obsidian-compatible vault skeleton.
- `.omx/` contains local workflow state and planning artifacts; runtime logs and state are not product files.
- `nous_requirements_and_user_flows.md` contains the ground-truth ideation plus functional and technical requirements for this project.
