# Nous M8 Planning Package: Start Here

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## What this package is

A source-grounded draft for **M8: Local Nous Application**, based on the attached planning handoff and public `main@14e2a00`. It contains seven gated implementation stages, seven matching test specifications, the product/API/shared contracts, explicit core gaps, risk/dependency/release decisions, a final acceptance matrix and copy-paste execution/verifier prompts.

**No application was implemented and no repository state was changed.** No M7/M8 product tests were run in this environment. Source presence and historical preflight evidence do not close the full M7F gate. Planning is ready to review; implementation remains BLOCKED pending fresh M7F evidence, current execution-state inspection and owner approval.

## Read in this order

1. [Verified baseline and blockers](m8-verified-state.md).
2. [Product requirements](prd-m8-local-nous-application.md) and [architecture decisions](m8-architecture-decision.md).
3. [Shared contract](m8-shared-contract.md), [core gaps](m8-core-gap-register.md) and [application adapter contract](m8-app-adapter-contract.md).
4. [Detailed user flows](m8-ux-and-user-flows.md) and [execution map](m8-execution-map.md).
5. Only the currently authorized stage plan and matching test specification.
6. [Final acceptance matrix](m8-final-acceptance-matrix.md), [verification runbook](m8-verification-runbook.md) and [execution handoffs](codex-m8-execution-handoffs.md).

Supporting decisions: [risks](m8-risk-register.md), [dependencies/licenses](m8-dependency-and-license-matrix.md), [release/packaging](m8-release-and-packaging-decision.md) and [source evidence/coverage](m8-source-evidence-register.md).

## Architecture in one paragraph

Use a static React/TypeScript interface built with Vite and served by a small authenticated loopback Ruby app adapter. The adapter calls dependency-free Nous Core directly. The vault remains authoritative. CLI and the exact eight-tool stdio MCP adapter continue using the same core. Integrated chat is M9; the deterministic M8 app is useful with no agent. The first distribution is an honestly scoped macOS Apple Silicon developer preview with a launcher, not a promised self-contained desktop installer.

## Important implementation discoveries

Current capture provenance/exact-source reading is MCP-specific. Current review edit resolves an operator file path rather than exposing a structured conditional save. Agent listing is capped at 50 with no cursor; it cannot be treated as a complete human browser API. M6 imports already create a deterministic inbox draft. Inspected multi-file rollback is exception-based/in-memory, not proof of arbitrary-process-death recovery. Current output status reports presence, not freshness. These are explicit stage-owned core gaps, not frontend workarounds.

## Stage index

| Stage | Primary deliverable | Plan | Tests |
| --- | --- | --- | --- |
| M8A | Preflight and Contract Freeze | [m8a-preflight-and-contract-freeze-plan.md](m8a-preflight-and-contract-freeze-plan.md) | [test-spec-m8a-preflight-and-contract-freeze.md](test-spec-m8a-preflight-and-contract-freeze.md) |
| M8B | Local Adapter and Vault Session | [m8b-local-adapter-and-vault-session-plan.md](m8b-local-adapter-and-vault-session-plan.md) | [test-spec-m8b-local-adapter-and-vault-session.md](test-spec-m8b-local-adapter-and-vault-session.md) |
| M8C | Read-Only Application Experience | [m8c-read-only-application-experience-plan.md](m8c-read-only-application-experience-plan.md) | [test-spec-m8c-read-only-application-experience.md](test-spec-m8c-read-only-application-experience.md) |
| M8D | Capture, Import and Retry Safety | [m8d-capture-import-and-retry-safety-plan.md](m8d-capture-import-and-retry-safety-plan.md) | [test-spec-m8d-capture-import-and-retry-safety.md](test-spec-m8d-capture-import-and-retry-safety.md) |
| M8E | Human Review Workspace | [m8e-human-review-workspace-plan.md](m8e-human-review-workspace-plan.md) | [test-spec-m8e-human-review-workspace.md](test-spec-m8e-human-review-workspace.md) |
| M8F | Report and Read-Only Graph | [m8f-report-and-read-only-graph-plan.md](m8f-report-and-read-only-graph-plan.md) | [test-spec-m8f-report-and-read-only-graph.md](test-spec-m8f-report-and-read-only-graph.md) |
| M8H | Launcher, Recovery and Developer-Preview Release | [m8h-launcher-recovery-and-release-plan.md](m8h-launcher-recovery-and-release-plan.md) | [test-spec-m8h-launcher-recovery-and-release.md](test-spec-m8h-launcher-recovery-and-release.md) |


M8G from the original stage hypothesis is the deferred integrated agent workspace. It is not runnable or required for this seven-stage release. The final release stage retains M8H to make that decision explicit.

## Applying these documents

The files are delivered flat. After review/authorization, their intended repository destination is `.omx/plans/`. This package did not copy them into GitHub or create a branch/commit. Use `m8-plan-index-update.md` to append the corresponding direct-child entries to the existing planning AGENT signpost, preserving all unrelated entries. Read current root/local instructions and reconcile the target SHA before applying anything.

Do not paste every stage into a one-shot agent run. Start with the authorized M8A handoff only; require an independent exit gate before moving forward. The consolidated Markdown companion, when supplied, is a reading/import convenience, not a monolithic execution instruction.

## Approval decisions

The owner should approve or amend the browser/runtime/developer-preview direction, new optional app receipt/history and interrupted-transaction guards, candidate-only editing/review scope, manual derived refresh/bounded graph, and M9 chat deferral. Exact new tool/dependency/browser versions must be frozen and tested in A before adoption. None of these defaults is represented as prior owner approval.

## Artifact quality checks versus product tests

`m8-package-validation.md` records only local document checks such as file presence, internal links, required sections and traceability. `SHA256SUMS.txt` verifies this archive's document contents. Neither is evidence that Nous or an M8 application passes tests.
