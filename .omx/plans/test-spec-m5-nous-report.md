# Test Specification: M5 Nous Report

## Automated fixture coverage

`scripts/test_generate_nous_report.rb` must prove:

1. A complete fixture with one reviewed value, belief, pattern, memory, contradiction, and question renders the fixed sections in order.
2. Each rendered note exposes its stable ID, chosen label, vault-relative source path, optional confidence, bounded excerpt, and ordered deduplicated evidence references.
3. A canonical claim renders in Source-Backed Claims.
4. A canonical relationship is rendered only when both endpoints are included; dangling relationships do not create report context.
5. Pending inbox, rejected, deprecated, archived, and unsupported records are absent.
6. Empty supported sections render `No reviewed records found.`
7. Duplicate included IDs fail clearly and preserve an existing output file.
8. Missing `id`, `type`, `status`, or `review_status` on an otherwise exportable reviewed record fails clearly and preserves an existing output file.
9. Invalid `NOUS_REPORT_TIME` fails clearly.
10. Repeated generation with a fixed timestamp is byte-identical.
11. Default output and explicit `--vault-root`/`--output` behavior are exercised.

## Repository verification

Run in this order and inspect every result:

1. `ruby scripts/test_generate_nous_report.rb`
2. `make test`
3. `make lint`
4. `ruby scripts/generate_nous_report.rb`
5. Inspect `vault/04_generated/reports/nous.md` for fixed sections, source-backed language, and absence of `01_agent_inbox/` sources.
6. Run the generator twice with a fixed `NOUS_REPORT_TIME` and compare bytes.
7. Run architect review at STANDARD tier or higher.
8. Run the mandatory cleaner only on Ralph-owned changed files.
9. Repeat focused tests, full tests, lint, generation, and deterministic comparison after cleanup.

## Pass conditions

- Every command exits zero.
- All assertions pass with zero failures and errors.
- Lint reports no violations.
- The default report contains no inbox, rejected, deprecated, or archived content.
- No tracked source file contains an unintended private raw artifact.
- Architect verdict is approved and there are no pending Ralph tasks.
