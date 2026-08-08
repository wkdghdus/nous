# Test Specification: M6 Raw Artifact Expansion

## Automated fixture coverage

`scripts/test_ingest_artifact.rb` must prove:

1. Writing, image, text-project, and binary-project sources create the exact payload, artifact, and inbox paths with deterministic dates.
2. Payload bytes, byte counts, and SHA-256 digests match the source, while original bytes, path, filename, and permissions remain unchanged.
3. Artifact and inbox frontmatter/body fields preserve portable provenance, context separation, represented date, review status, interpretation level, and an internally resolvable evidence chain.
4. Text-like inputs create no more than three bounded extractive facts, invalid UTF-8 fails, and binary/image inputs contain no invented observed content or embedded payload.
5. Missing/unknown types, invalid dates, missing paths, directories, symlinks, hidden files, extensionless files, and mismatched extensions fail before final output exists.
6. Duplicate imports allocate one shared numeric suffix across all three outputs and never overwrite existing files.
7. A forced destination/finalization failure removes temporary and invocation-created final files while leaving pre-existing files byte-identical.
8. `--vault-root` contains every output below the supplied fixture vault and no test writes raw/generated fixtures into the repository vault.
9. Removing the external source leaves payload and both Markdown provenance hops resolvable inside the fixture vault, with no external absolute path serialized anywhere.
10. Review queue `list` and `show` expose the generated note and artifact evidence; approving a project-derived note as `project` retains evidence without changing payload/artifact hashes.
11. M2 direct-text capture, review, graph export, and report behavior remain unchanged and raw M6 records do not enter reviewed-only outputs.

## Repository verification

Run in order and inspect every result:

1. `ruby scripts/test_ingest_artifact.rb`
2. `ruby scripts/test_ingest_text.rb`
3. `ruby scripts/test_review_queue.rb`
4. `ruby scripts/test_export_graph.rb`
5. `ruby scripts/test_generate_nous_report.rb`
6. `make test`
7. `make lint`
8. Manually import temporary writing, image, and project fixtures into a temporary vault; compare source/copy SHA-256 and source metadata.
9. Remove an external fixture and verify the copied payload and Markdown evidence chain still resolve.
10. Search the temporary vault for the external absolute fixture path and inspect binary/image notes for unsupported interpretation.
11. Inspect `git status --short` for private payloads, temp files, and unintended generated output.
12. Run architect review at STANDARD tier or higher.
13. Run the mandatory cleaner only on Ralph-owned changed files.
14. Repeat focused tests, full tests, lint, and privacy/preservation checks after cleanup.

## Pass conditions

- Every command exits zero and every assertion passes with zero failures/errors.
- Lint reports no violations.
- Original sources and pre-existing destinations remain byte-identical.
- No failed import leaves temporary, payload, artifact, or inbox files.
- No generated vault record contains an external absolute source path or unsupported binary/image claims.
- No tracked private raw artifact or unintended generated fixture is added.
- Architect verdict is approved and no Ralph task remains pending.
