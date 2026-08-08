# M5 Nous Report Plan

## Requirements Summary

M5 adds a dependency-free Markdown report generator for the reviewed Nous vault. The roadmap defines M5 as "Nous report" with the deliverable "Generated Markdown summary" and the success condition that the user gets a source-backed summary of values, beliefs, patterns, memories, contradictions, and questions (`nous_requirements_and_user_flows.md:521-528`). The feature also satisfies FR-037, which calls for a Markdown report covering core values, beliefs, patterns, memories, contradictions, and questions (`nous_requirements_and_user_flows.md:191-198`).

Grounding:

- The MVP remains text-first and local-first; the README states no app project exists and current implementation is repository scripts plus vault files (`README.md:1-21`).
- The vault lifecycle says generated reports and graph exports belong in `vault/04_generated/` after raw, inbox, reviewed, and canonical stages (`docs/architecture/vault-schema.md:15-21`).
- Generated reports specifically belong under `vault/04_generated/reports/` (`vault/04_generated/reports/AGENT.md:1-7`).
- Review status is the trust boundary: reviewed items are accepted, while rejected/deprecated/archived records must not appear as active generated output (`docs/architecture/vault-schema.md:82-111`, `docs/architecture/vault-schema.md:148-150`).
- M4 already established reviewed-only record discovery from `vault/02_notes/`, canonical claims, and canonical relationships, with inbox records excluded (`docs/architecture/vault-schema.md:138-150`, `scripts/export_graph.rb:128-172`).
- Existing CLIs are dependency-free Ruby scripts using `OptionParser`, `Pathname`, `Psych`, explicit errors, fixture tests, and `make test` wiring (`scripts/export_graph.rb:1-17`, `scripts/review_queue.rb:95-136`, `scripts/test_export_graph.rb:1-23`, `Makefile:1-8`).

Scope assumption:

- The first M5 report should be deterministic extraction and organization, not LLM summarization. It should assemble reviewed source-backed notes into readable Markdown using titles, body excerpts, confidence, source paths, and evidence references.
- Default output should be `vault/04_generated/reports/nous.md`.
- Default input should be reviewed notes under `vault/02_notes/` plus canonical claims and relationships only when they add source-backed support or contradiction context.
- Inbox items, rejected items, deprecated items, archived items, and unsupported note types are out of scope for the default report.

## Acceptance Criteria

- `ruby scripts/generate_nous_report.rb` writes Markdown to `vault/04_generated/reports/nous.md` by default.
- The command supports `--vault-root PATH` for fixture and alternate vault roots.
- The command supports `--output PATH` for custom report destinations.
- The command supports deterministic test time via `NOUS_REPORT_TIME`; invalid timestamps fail clearly.
- The report starts with `# Nous Report`, includes generated timestamp metadata, and states that it is generated from reviewed/canonical records only.
- The report includes sections for Core Values, Beliefs, Patterns, Memories, Contradictions, and Questions, even when a section is empty.
- Each populated section lists reviewed records of the matching note type from `vault/02_notes/<type>/`.
- Each listed record includes a stable ID, label/title, source path, optional confidence, a bounded deterministic excerpt, and evidence links when present.
- Canonical claims from `vault/03_canonical_model/claims/` are included in a Source-Backed Claims section or nested support subsection when doing so remains deterministic and readable.
- Canonical relationships from `vault/03_canonical_model/relationships/` are used only for deterministic "related records" or contradiction/support context when both endpoints are present in exported report records.
- Pending inbox records under `vault/01_agent_inbox/` are excluded by default.
- Rejected, deprecated, and archived records are excluded by default.
- Malformed reviewed records fail with clear error messages before writing output when required fields such as `id`, `type`, `status`, or `review_status` are missing.
- Duplicate record IDs fail clearly and do not overwrite the previous output.
- Output ordering is stable: sections appear in fixed order, records sort by `created` then `id` or by `id` when dates are absent, and evidence refs preserve source order after deduplication.
- Running the command twice with fixed `NOUS_REPORT_TIME` against the same vault produces byte-identical Markdown.
- `ruby scripts/test_generate_nous_report.rb`, `make test`, and `make lint` pass after implementation.
- README usage docs explain the command, default output path, reviewed-only semantics, and how to override vault/output paths.

## Implementation Steps

1. Extend the generated-report contract in documentation.
   - Add an M5 Nous report section to `docs/architecture/vault-schema.md` near the M4 graph export section (`docs/architecture/vault-schema.md:138-150`).
   - Specify that the report is derived, regenerable, reviewed-only by default, and written to `vault/04_generated/reports/nous.md`.
   - State that the report may quote/excerpt reviewed records but must not create new psychological certainty beyond the source records, aligning with interpretation safety (`nous_requirements_and_user_flows.md:215-220`).

2. Implement `scripts/generate_nous_report.rb` as a dependency-free Ruby CLI.
   - Follow the existing script shape: shebang, `# frozen_string_literal: true`, stdlib-only requires, top-level constants, custom error class, `Options` struct, `parse_options`, `run`, and final rescue block (`scripts/export_graph.rb:1-17`, `scripts/export_graph.rb:374-387`).
   - Add `--vault-root PATH`, `--output PATH`, and `-h/--help`.
   - Use a local `parse_frontmatter` helper equivalent to current script parsers (`scripts/export_graph.rb:79-90`, `scripts/review_queue.rb:161-172`).
   - Reuse the M4 discovery boundary: reviewed note files from direct child directories of `vault/02_notes/`, canonical claims from `vault/03_canonical_model/claims/`, and canonical relationships from `vault/03_canonical_model/relationships/` (`scripts/export_graph.rb:120-139`).
   - Keep implementation local to this script for M5 unless duplication becomes painful; extracting shared vault helpers can be a later cleanup after tests lock behavior.

3. Define report data normalization.
   - Normalize string values, labels, excerpts, confidence, evidence refs, and source paths consistently with M4 graph export helpers (`scripts/export_graph.rb:153-213`, `scripts/export_graph.rb:183-193`).
   - Use first Markdown H1, then frontmatter `title`, then stable `id` as the label.
   - Use the first non-empty non-heading body line as the excerpt, bounded to a documented maximum such as 240 characters.
   - Deduplicate evidence refs by `[id, path]` while preserving source order.
   - Require `review_status: reviewed` and non-archived `status` for records included in the report.
   - Treat `review_status: rejected`, `review_status: deprecated`, and `status: archived` as excluded records, matching the M4 trust boundary (`scripts/export_graph.rb:157-172`).

4. Render deterministic Markdown.
   - Build a report object first, then render Markdown from that object so validation happens before writing.
   - Render fixed sections: `## Core Values`, `## Beliefs`, `## Patterns`, `## Memories`, `## Contradictions`, `## Questions`, and `## Source-Backed Claims`.
   - Use compact bullets or tables, but prefer bullets if evidence lists make tables hard to read.
   - Include `Source: <vault-relative-path>` for every listed item.
   - Include evidence refs as vault-relative links or plain paths; do not dereference raw artifacts or include long source text in M5.
   - Include "No reviewed records found." in empty sections so an empty vault still produces a useful report.
   - Write atomically through a temporary file and move into place after validation, matching M4's no-partial-output pattern (`scripts/export_graph.rb:365-372`).

5. Add focused regression coverage in `scripts/test_generate_nous_report.rb`.
   - Build temporary fixture vaults with one reviewed value, belief, pattern, memory, contradiction, question, canonical claim, and canonical relationship.
   - Verify the report has the expected title, timestamp, reviewed-only note, fixed section order, item labels, IDs, source paths, confidence values, excerpts, and evidence refs.
   - Verify pending inbox records are excluded.
   - Verify rejected, deprecated, and archived records are excluded.
   - Verify empty sections render a clear empty-state line.
   - Verify duplicate IDs fail without overwriting an existing output file.
   - Verify missing required metadata in an otherwise exportable reviewed record fails clearly.
   - Verify invalid `NOUS_REPORT_TIME` fails clearly.
   - Verify repeated runs with fixed `NOUS_REPORT_TIME` are byte-identical.

6. Wire the report generator into repository checks and signposts.
   - Update `Makefile` so `make test` runs `ruby scripts/test_generate_nous_report.rb` after existing tests (`Makefile:1-8`).
   - Update `README.md` with a "Nous Report" section after Graph Export, including default path and reviewed-only behavior (`README.md:73-83`).
   - Update `scripts/AGENT.md` to list `generate_nous_report.rb` and `test_generate_nous_report.rb` (`scripts/AGENT.md:1-13`).
   - Update `vault/04_generated/reports/AGENT.md` to list `nous.md` as the default generated Nous summary (`vault/04_generated/reports/AGENT.md:1-7`).

7. Generate and inspect the default report.
   - Run `ruby scripts/generate_nous_report.rb` against the repository vault.
   - Commit `vault/04_generated/reports/nous.md` only if the current vault has meaningful reviewed records; otherwise allow the command to produce an empty-section report but consider leaving generated output uncommitted if it adds noise.
   - Confirm no listed source path starts with `01_agent_inbox/`.
   - Confirm report language labels derived statements as source-backed records, not new conclusions.

## Risks and Mitigations

- Risk: The report becomes interpretive summarization and overstates the user's psychology.
  Mitigation: Keep M5 deterministic. Extract labels, excerpts, evidence, confidence, and source paths from reviewed records only; do not infer new claims.

- Risk: Pending or rejected records leak into a user-facing self-summary.
  Mitigation: Reuse the reviewed-only discovery boundary and add explicit fixture tests for inbox, rejected, deprecated, and archived exclusions.

- Risk: The report is technically source-backed but hard to audit.
  Mitigation: Every item must show stable ID, vault-relative source path, and evidence refs when present.

- Risk: M5 duplicates M4 parsing and filtering helpers.
  Mitigation: Accept limited duplication for the first report generator to keep the diff small; extract shared vault helpers later only if M5 and M4 behavior must evolve together.

- Risk: Canonical relationships make report prose confusing or create dangling references.
  Mitigation: Only include relationship context when both endpoints resolve to included report records or canonical claims; otherwise skip or fail according to the tested rule chosen during implementation.

- Risk: Empty repository vault output looks like a failure.
  Mitigation: Render all required sections with explicit empty states and still print the output path.

## Verification Steps

- Run `ruby scripts/test_generate_nous_report.rb`.
- Run `make test`.
- Run `make lint`.
- Run `ruby scripts/generate_nous_report.rb --vault-root PATH_TO_FIXTURE --output PATH_TO_TMP_MD` and inspect the generated Markdown.
- Run `ruby scripts/generate_nous_report.rb` against the repository vault and confirm the output path is `vault/04_generated/reports/nous.md`.
- Confirm no default report source path comes from `vault/01_agent_inbox/`.
- Confirm rejected, deprecated, and archived records are absent from the report.
- Confirm repeated generation with fixed `NOUS_REPORT_TIME` is byte-identical.
- Confirm `git status --short` contains only intended M5 files and generated artifacts.

## Suggested Execution Handoff

For `$ralph`:

- Use one executor lane for `scripts/generate_nous_report.rb`, record discovery, report rendering, validation, and atomic output.
- Use one test-engineer lane for `scripts/test_generate_nous_report.rb`, deterministic fixtures, and failure-path coverage.
- Use one writer lane only if documentation updates become larger than the script change; otherwise keep docs with the executor.
- Use verifier reasoning at high because trust-boundary leakage and unsupported interpretation are the main correctness risks.

For `$team`:

- Executor owns `scripts/generate_nous_report.rb`, deterministic rendering, reviewed-only filtering, and output writing.
- Test-engineer owns `scripts/test_generate_nous_report.rb` and `Makefile` test wiring.
- Writer owns `README.md`, `docs/architecture/vault-schema.md`, `scripts/AGENT.md`, and `vault/04_generated/reports/AGENT.md`.
- Verifier owns final `make test`, `make lint`, fixture inspection, default report generation, and inbox-leak checks.

Launch hint:

```sh
omx team --task ".omx/plans/m5-nous-report-plan.md"
```

Team verification path:

- Team proves reviewed-only report discovery, stable Markdown rendering, source/evidence visibility, exclusion of unreviewed and archived records, deterministic output, docs alignment, and full test/lint pass.
- Ralph or the leader then verifies the report remains local-first, dependency-free, and source-backed without adding unsupported interpretation.
