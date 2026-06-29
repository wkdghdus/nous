# M3 Review Queue Plan

## Requirements Summary

M3 adds the first review and curation workflow on top of the existing text-ingestion path. The current repository already creates inbox draft notes from imported text, but it does not yet provide a way to list pending review items, inspect them against their evidence, or transition them into reviewed and canonical destinations.

Grounding:

- `nous_requirements_and_user_flows.md` defines M3 as "Review queue" with the success condition that the user can approve, edit, merge, reject, and canonicalize outputs.
- `nous_requirements_and_user_flows.md` UF-005 says the system should display unreviewed notes, claims, and relationships; let the user approve, edit, merge, reject, or defer; move approved items into reviewed notes or canonical model; and update review status plus timestamps.
- `docs/architecture/vault-schema.md` defines the inbox lifecycle and current review statuses for notes, claims, and relationships, but only inbox relationships currently have an explicit folder contract.
- `scripts/ingest_text.rb` and `scripts/test_ingest_text.rb` show the current MVP implementation style: dependency-free Ruby scripts, file-first vault mutations, and fixture-based regression tests.
- `vault/02_notes/AGENT.md` and `vault/03_canonical_model/AGENT.md` define separate reviewed-note and canonical-model trust boundaries that the review workflow should preserve.

Assumption for M3 scope: because the repository still has no application UI, the review queue should be delivered as a dependency-free CLI and vault-native report workflow rather than a web interface. That is the smallest path consistent with the current repo shape.

## Acceptance Criteria

- A dependency-free command such as `ruby scripts/review_queue.rb list` enumerates pending inbox items across `vault/01_agent_inbox/notes/`, `vault/01_agent_inbox/claims/`, and `vault/01_agent_inbox/relationships/`.
- The queue output includes at minimum item path, item type, review status, created date, confidence when present, and linked evidence/source reference so the user can compare a generated item against its artifact.
- The queue can be ordered at least by created date and confidence, and it exposes a stable initial "priority" rule for items without a manual priority field.
- A command such as `show` or equivalent prints one item with its frontmatter, review-relevant body sections, and evidence paths without mutating the vault.
- The workflow supports `approve`, `reject`, `deprecated`, and `merge` actions with explicit timestamps and optional reviewer notes recorded on the affected files.
- The workflow supports `edit` as part of the user flow, either by opening the item in `$EDITOR` or by documenting and enforcing an edit-then-approve flow around the same script.
- Approving a reviewed note moves it out of the inbox into the correct reviewed destination under `vault/02_notes/`, updates `review_status` to `reviewed`, sets `status` to `active`, and refreshes `updated`.
- Because inbox notes currently use generic `type: note`, approval of a note requires an explicit reviewed type mapping such as `memory`, `value`, `belief`, `project`, `pattern`, `decision`, `person`, `question`, or `contradiction` before the move occurs.
- Approving a claim moves it from `vault/01_agent_inbox/claims/` to `vault/03_canonical_model/claims/` with reviewed metadata preserved.
- Approving a relationship moves it to a reviewed destination that is added explicitly in M3, preferably `vault/03_canonical_model/relationships/`, instead of leaving reviewed graph edges mixed with inbox records.
- Rejecting or deprecating an item preserves the file for audit, removes it from the pending queue, and records the decision timestamp plus optional reviewer note.
- Merging an inbox item into an existing reviewed or canonical target preserves provenance by copying or appending evidence references, recording the merge destination, and marking the source item as no longer pending.
- A vault-native queue artifact, such as `vault/04_generated/reports/review_queue.md`, can be regenerated to support Obsidian-based review sessions without becoming the source of truth for decisions.
- `make test` and `make lint` pass, and new signposts are added for any new first-level directories introduced by the review workflow.

## Implementation Steps

1. Define the review decision contract in docs and schemas before writing workflow code.
   - Update `docs/architecture/vault-schema.md` to document the reviewed destination for relationships and the expected state transitions for approve, merge, reject, and deprecate.
   - Extend `schemas/note-frontmatter.schema.yaml` with optional review-decision metadata such as a `review` object containing `decision`, `decided_at`, `reviewer_note`, and `merged_into`.
   - Keep the new metadata narrow and reusable across notes, claims, and relationships instead of inventing separate ad hoc shapes per file type.

2. Add the missing reviewed relationship destination to the vault contract.
   - Create `vault/03_canonical_model/relationships/AGENT.md` so approved relationships have an explicit canonical home.
   - Update `vault/03_canonical_model/AGENT.md` and, if needed, `vault/AGENT.md` to list the new direct child and describe its trust level.
   - Avoid introducing a separate archive tree unless testing shows in-place rejected/deprecated records are too awkward to manage.

3. Implement a dependency-free review CLI in `scripts/review_queue.rb`.
   - Support bounded subcommands such as `list`, `show`, `approve`, `reject`, `deprecate`, `merge`, and `edit`.
   - Reuse the current Ruby standard-library approach from `scripts/ingest_text.rb`: `Pathname`, `OptionParser`, `Psych`, and explicit error messages.
   - Centralize inbox discovery, frontmatter parsing, target-path resolution, and status validation so note, claim, and relationship handling stay consistent.
   - Keep review actions explicit and non-destructive: no silent overwrites, and fail clearly if the destination already exists unless the action is an intentional merge.

4. Define the routing rules from inbox items to reviewed/canonical destinations.
   - Notes: require `--as TYPE` on approval because `vault/02_notes/` is typed by directory and M2 draft notes are still generic.
   - Claims: move to `vault/03_canonical_model/claims/`.
   - Relationships: move to `vault/03_canonical_model/relationships/`.
   - Merge: require an explicit `--into PATH` target and record the source item’s merge destination in review metadata.
   - Reject/deprecate: update the item in place with `review_status: rejected|deprecated`, `status: archived`, and a decision note so it falls out of the queue without losing auditability.

5. Add a regenerable review-queue report for Obsidian sessions.
   - Generate `vault/04_generated/reports/review_queue.md` from the live inbox state rather than storing queue state separately.
   - Include enough summary data to triage quickly: kind, created date, confidence, evidence path, and recommended next action.
   - Treat the report as a convenience view only; the file frontmatter on each item remains the source of truth.

6. Add focused regression tests in `scripts/test_review_queue.rb`.
   - Build temporary fixture vaults containing inbox notes, claims, relationships, and supporting artifacts.
   - Cover queue listing, show output, note approval with `--as`, claim approval, relationship approval, reject, deprecate, merge, and duplicate/invalid target failures.
   - Verify that timestamps, `review_status`, `status`, evidence, and destination paths are correct after each action.
   - Verify that rejected/deprecated items disappear from the pending queue while remaining readable on disk.

7. Wire the workflow into repository commands and operator docs.
   - Update `Makefile` so `make test` includes the new review-queue regression test.
   - Update `README.md` with the review workflow commands and the distinction between inbox, reviewed notes, and canonical records.
   - Update `scripts/AGENT.md` to mention `review_queue.rb` and `test_review_queue.rb`.
   - Update any affected signposts if the directory contract changes.

## Risks and Mitigations

- Risk: Reviewed relationships have no current canonical destination, which creates ambiguity about where approved edges belong.
  Mitigation: Make M3 explicitly add `vault/03_canonical_model/relationships/` and document it before implementing move logic.

- Risk: Generic inbox notes cannot be approved deterministically into `vault/02_notes/` because reviewed notes are type-specific.
  Mitigation: Require an explicit `--as TYPE` on approval and validate against the existing reviewed note folders.

- Risk: Merge behavior can accidentally erase source distinctions or duplicate evidence.
  Mitigation: Require an explicit merge target, append provenance conservatively, and mark the source with merge metadata instead of deleting it.

- Risk: Adding an interactive editor flow may be fragile in automated tests.
  Mitigation: Keep `edit` thin, driven by `$EDITOR`, and make the core review transitions testable independently of the editor subprocess.

- Risk: A queue report could drift from actual file state if it becomes stateful.
  Mitigation: Regenerate the report from live inbox files on demand and keep all decision truth in per-item frontmatter/body metadata.

- Risk: Review metadata additions could sprawl into a second schema system.
  Mitigation: Extend the existing frontmatter schema minimally and reuse the same decision fields across all reviewable record types.

## Verification Steps

- Run `ruby scripts/test_review_queue.rb` and confirm fixture-based review actions pass for notes, claims, and relationships.
- Run `make test` to verify the combined ingestion and review workflow regression coverage.
- Run `make lint` to validate repository hygiene, signposts, and schema/docs syntax after M3 changes.
- Manually inspect one approved note, one approved claim, one approved relationship, and one rejected item from a fixture vault to confirm path moves, status transitions, and decision metadata.
- Regenerate the review queue report from fixtures and confirm it lists only pending items and references real evidence paths.
- Confirm `git status --short` only contains the intended review workflow files, docs, schema updates, and any new signposts.

## Suggested Execution Handoff

For `$ralph`:

- Use one executor lane for `scripts/review_queue.rb` and path-routing logic.
- Use one test-engineer or verifier lane for temporary-vault fixtures and state-transition assertions.
- Use one writer lane for README, schema, and vault-contract updates only if documentation starts slowing implementation.
- Keep implementation reasoning at medium and verification reasoning at high because the main failure modes are data-loss and provenance drift, not algorithmic complexity.

For `$team`:

- Executor 1 owns `scripts/review_queue.rb`, destination routing, and report generation.
- Test-engineer owns `scripts/test_review_queue.rb` and `Makefile` test wiring.
- Writer owns `README.md`, `docs/architecture/vault-schema.md`, and signpost updates.
- Verifier owns fixture inspection, queue-report validation, and final `make test` plus `make lint`.

Launch hint:

```sh
omx team --task ".omx/plans/m3-review-queue-plan.md"
```

Team verification path:

- Team proves queue discovery, item inspection, note approval with explicit type mapping, claim and relationship canonicalization, merge semantics, rejected/deprecated audit retention, and report regeneration.
- Ralph or the leader then verifies the workflow stays CLI-only, preserves provenance, and does not let inbox items bypass reviewed/canonical boundaries.
