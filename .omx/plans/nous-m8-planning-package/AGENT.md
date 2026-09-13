# M8 Local Nous Application Planning Package Signpost

Status: Draft planning package; not implementation authorization

This directory contains the staged planning artifacts for **M8: Local Nous Application**. It defines how Nous should gain a local human-facing application while preserving the vault as the source of truth, keeping Nous Core authoritative for business/filesystem rules, retaining the existing CLI and MCP boundaries, and keeping human review authoritative.

## How agents should use this directory

- Start with `README-M8.md`; it explains the package status, reading order, architecture summary, and approval gates.
- Treat `m8-verified-state.md` as the baseline report, not as proof that M7 is complete. Re-verify the target repository revision before implementation.
- Read the umbrella requirements and shared contracts before any stage plan. A stage plan may narrow work, but it must not weaken the PRD, shared contract, adapter contract, or inherited M1-M7 guarantees.
- Follow the stage order defined in `m8-execution-map.md`: M8A -> M8B -> M8C -> M8D -> M8E -> M8F -> M8H. M8G is intentionally deferred to M9 and is not a runnable stage in this package.
- Execute only the currently authorized stage and its matching test specification. Do not combine adjacent stages into one implementation prompt merely because they touch related files.
- Before changing repository files, read the repository root `AGENT.md` and every local `AGENT.md` governing directories that will be touched. Reconcile this package's `main@14e2a00` planning baseline with the actual target revision.
- Treat `m8-package-validation.md` and `SHA256SUMS.txt` as planning-artifact integrity evidence only. They do not prove product tests, runtime compatibility, M7F completion, or M8 acceptance.
- Keep this signpost updated whenever a direct child is added, removed, renamed, superseded, or materially repurposed.

## Entry point and verified baseline

- `README-M8.md` - package overview, recommended reading order, architecture summary, stage index, approval decisions, and application instructions.
- `m8-verified-state.md` - source-inspection report for the repository baseline, including what was observed, what was not verified, and the M7/M8 entry blockers.
- `m8-source-evidence-register.md` - traceability register connecting important planning claims and inherited constraints to repository evidence.
- `m8-core-gap-register.md` - concrete gaps between the current reusable core and the human-facing operations M8 requires, with stage ownership rather than frontend workarounds.

## Product, architecture, and shared contracts

- `prd-m8-local-nous-application.md` - umbrella M8 product requirements, goals, non-goals, requirements, acceptance intent, and release boundary.
- `m8-shared-contract.md` - invariants every M8 stage must obey, including vault/core authority, review boundaries, privacy, path safety, concurrency, compatibility, and scope controls.
- `m8-architecture-decision.md` - product-shell and app-to-core architecture decision, considered alternatives, security boundary, and rationale for the proposed browser-first local application.
- `m8-ux-and-user-flows.md` - detailed M8 user flows, trust/lifecycle treatment, failure states, and UX requirements for launch, capture/import, review, browsing, outputs, external changes, and recovery.
- `m8-app-adapter-contract.md` - transport-facing contract between the frontend and Nous Core, including operation ownership, request/response boundaries, errors, security, versioning, retry behavior, and prohibited adapter authority.
- `m8-execution-map.md` - stage ordering, dependencies, cross-stage gates, ownership guidance, rollback expectations, and rules for advancing between stages.
- `m8-final-acceptance-matrix.md` - requirement-to-stage/test traceability and final evidence required before M8 can be declared complete.

## Risk, dependency, release, and verification support

- `m8-risk-register.md` - architecture, privacy, data-integrity, concurrency, recovery, scope, and delivery risks with mitigations and stage ownership.
- `m8-dependency-and-license-matrix.md` - proposed dependency categories, adoption gates, license/provenance expectations, and items that M8A must verify before versions are frozen.
- `m8-release-and-packaging-decision.md` - developer-preview versus packaged-desktop boundary, runtime assumptions, platform scope, packaging spike expectations, and release claims that are not yet justified.
- `m8-verification-runbook.md` - ordered cross-stage and final verification procedure, including regressions, security/privacy audits, cross-interface checks, recovery checks, and release evidence.
- `m8-package-validation.md` - validation of this planning package itself: required documents, links, sections, traceability, formatting, and non-fabrication checks; it is not product acceptance evidence.
- `m8-plan-index-update.md` - proposed update instructions for the repository-level `.omx/plans/AGENT.md` when these M8 artifacts are eventually applied to the repository.
- `SHA256SUMS.txt` - SHA-256 checksums for the package documents so archive contents can be verified after transfer.

## Stage plans and matching verification contracts

- `m8a-preflight-and-contract-freeze-plan.md` - M8A plan for fresh M7 entry verification, stack/transport preflight, security/runtime decisions, and freezing the initial application contract.
- `test-spec-m8a-preflight-and-contract-freeze.md` - M8A verification for baseline compatibility, architecture spikes, dependency/runtime facts, and contract freeze evidence.
- `m8b-local-adapter-and-vault-session-plan.md` - M8B plan for the secure local application adapter, vault selection/session lifecycle, health/status, structured errors, and shutdown.
- `test-spec-m8b-local-adapter-and-vault-session.md` - M8B contract, transport-security, vault-session, error, lifecycle, and adapter isolation verification.
- `m8c-read-only-application-experience-plan.md` - M8C plan for the frontend shell, vault/status experience, knowledge browser, record/evidence detail, deterministic retrieval, and external-change refresh.
- `test-spec-m8c-read-only-application-experience.md` - M8C frontend/component/integration verification for lifecycle presentation, safe rendering, browsing, refresh, accessibility, and read-only behavior.
- `m8d-capture-import-and-retry-safety-plan.md` - M8D plan for verbatim text capture, human-controlled writing/image/project import, progress/cancellation, retry receipts, and recovery foundations.
- `test-spec-m8d-capture-import-and-retry-safety.md` - M8D mutation, import, preservation, idempotency/retry, failure, cancellation, privacy, and interrupted-write verification.
- `m8e-human-review-workspace-plan.md` - M8E plan for the review inbox, complete candidate editing, approve/reject/deprecate/merge flows, evidence inspection, relationship readiness, stale-write protection, and audit presentation.
- `test-spec-m8e-human-review-workspace.md` - M8E review-state, edit/version, concurrency, relationship, merge, audit, failure, and cross-interface verification.
- `m8f-report-and-read-only-graph-plan.md` - M8F plan for explicit report/graph regeneration, freshness/error visibility, source navigation, and a bounded read-only graph experience.
- `test-spec-m8f-report-and-read-only-graph.md` - M8F verification for reviewed-only derived outputs, deterministic regeneration, freshness, failure preservation, navigation, graph bounds, and read-only semantics.
- `m8h-launcher-recovery-and-release-plan.md` - M8H plan for repeatable local startup/shutdown, backend supervision, recovery, built-artifact checks, platform claims, privacy/security audits, and the developer-preview release gate.
- `test-spec-m8h-launcher-recovery-and-release.md` - M8H verification for launcher lifecycle, restart/recovery, release artifacts, supported-platform claims, full cross-interface lifecycle, and final regression/audit gates.

## Execution handoff

- `codex-m8-execution-handoffs.md` - bounded copy-paste prompts for each M8 stage and independent verification. Use only the prompt for the currently authorized stage; do not treat the full file as one execution request.

## Package boundary

These files are delivered as a flat draft package. Their intended repository destination after review and authorization is `.omx/plans/`, subject to current repository instructions and a fresh baseline check. This directory contains planning authority and execution guidance only; it does not mean the M8 application exists, that dependencies are approved, or that any stage has passed its release gate.
