# M8 Planning Artifact Validation

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## Scope of this validation

Only the downloadable planning artifacts were validated in the sandbox. **No Nous M7 or M8 product tests, browser E2E, runtime preflight, native Mac launcher, MCP Inspector/Codex release scenario or repository lint were run here.** The source/evidence register explains why. This report is not milestone acceptance.

## Checks actually performed

| Document check | Result | Detail |
| --- | --- | --- |
| Required umbrella artifacts | PASS | 8 required files present |
| Stage decomposition | PASS | 7 runnable stages; M8G explicitly deferred to M9 |
| Stage plan/test pairs | PASS | 7 implementation plans and 7 matching test specifications |
| Requirements traced | PASS | 30 requirements have owning stages and test mappings |
| Test references exist | PASS | 62 stage-specific test cases declared |
| User flows | PASS | All 12 user flows include preconditions, main flow, failures, trust and acceptance |
| Plan sections | PASS | All 15 required plan sections are present in each stage |
| Test specification sections | PASS | All 11 required test-spec sections are present in each stage |
| Planning status | PASS | Every Markdown artifact identifies draft/non-authorization status |
| No fabricated product results | PASS | Acceptance matrix is NOT RUN; environment/test limitations are explicit |
| Internal links, fences and whitespace | PASS | Local Markdown links resolve; code fences balance; final newlines and clean line endings |

## Manual consistency review of the draft

The proposal preserves the exact MCP surface and separates existing methods from new human operations. It corrects the browser-path assumption, preserves M6 deterministic draft generation, requires a complete edit envelope, identifies source/target version checks, distinguishes exception rollback from process-death recovery, separates app receipts from MCP generation, and does not pretend integrated agent status is observable. It includes separate pending review and graph-filter routes rather than assuming ordinary list endpoints cover them.

The seven-stage sequence includes early recovery foundations before writes, not only a late release check. All 12 flows and 30 PRD requirements have assigned tests. Exact new runtime/package compatibility, unresolved optional metadata approval, full source coverage and actual M7F release evidence remain real gates. Document consistency is not proof that the proposed mechanisms have been implemented correctly.

## Delivery integrity

`SHA256SUMS.txt` lists the final Markdown files and their SHA-256 digests. The ZIP contains those files flat under one package folder. A consolidated Markdown companion is provided only for reading/import convenience; independent stage files remain the execution units. No repository code, dependency, branch or commit was modified to produce these artifacts.
