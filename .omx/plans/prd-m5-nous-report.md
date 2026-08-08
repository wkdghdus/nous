# PRD: M5 Nous Report

## Objective

Provide a dependency-free, deterministic Markdown summary of reviewed Nous records so a user can audit their values, beliefs, patterns, memories, contradictions, questions, and source-backed canonical claims without exposing pending or rejected material or introducing unsupported interpretation.

## Scope

- Add a Ruby CLI with default and overridden vault/output paths.
- Discover reviewed supported notes plus eligible canonical claims and relationships.
- Validate required metadata and duplicate IDs before output replacement.
- Render a stable, source-backed Markdown report with fixed sections and empty states.
- Add fixture-driven regression coverage, repository checks, usage/architecture docs, and the default generated report.

## Out of scope

- LLM summarization or new psychological conclusions.
- Inbox records, rejected/deprecated review states, archived records, and unsupported note types.
- Raw artifact dereferencing or long source quotations.
- Shared parser refactors or new dependencies.

## User stories

### US-001: Generate a reviewed Nous report

As a Nous user, I want one Markdown report organized by supported knowledge type so that I can review an auditable summary of accepted records.

Acceptance criteria:

- `ruby scripts/generate_nous_report.rb` writes `vault/04_generated/reports/nous.md` by default.
- `--vault-root` and `--output` override their respective paths.
- The report begins with `# Nous Report`, includes a generated timestamp and reviewed/canonical-only notice, and always renders Core Values, Beliefs, Patterns, Memories, Contradictions, Questions, and Source-Backed Claims.
- Populated records include ID, label, source path, optional confidence, bounded excerpt, and evidence references when present.
- Empty sections say `No reviewed records found.`

### US-002: Preserve the review trust boundary

As a Nous user, I want generated summaries to exclude untrusted lifecycle states so that pending or retired interpretations cannot appear as accepted self-knowledge.

Acceptance criteria:

- Inbox, rejected, deprecated, archived, and unsupported note records are excluded.
- Canonical relationships appear only when both endpoints resolve to report entries.
- Malformed otherwise-exportable records and duplicate IDs fail clearly before replacing prior output.

### US-003: Make output deterministic and maintainable

As a maintainer, I want stable output and automated checks so that changes are reviewable and regressions are caught.

Acceptance criteria:

- `NOUS_REPORT_TIME` fixes test time and invalid values fail clearly.
- Records have stable ordering and evidence references retain first-seen order after deduplication.
- Two runs with the same inputs and fixed time are byte-identical.
- Focused tests, full tests, and lint pass.
- README, architecture docs, and directory signposts describe the feature.

## Verification contract

The canonical verification artifact is `.omx/plans/test-spec-m5-nous-report.md`. Completion also requires architect approval, changed-files-only deslop, and a green post-deslop regression run.
