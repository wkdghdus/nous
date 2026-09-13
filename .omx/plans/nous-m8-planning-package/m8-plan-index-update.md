# M8 Proposed Planning Signpost Update

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## No repository update has been performed

After owner review and authorization, copy the chosen flat planning files into `.omx/plans/` and append the following direct-child entries to its existing `AGENT.md`. Preserve all current M1-M7 entries and any unrelated new work. Read current local guidance first. This is a proposed addition block, not a replacement file or an executed patch.

The existing inspected index has older M1-M6 entries and may itself lag other files. Do not use M8 as authority to rewrite historical plans or clean unrelated files. Any broader index correction needs separate review of the actual tree.

## Proposed direct-child addition block

```markdown
- `README-M8.md` - Nous M8 Planning Package: Start Here.
- `codex-m8-execution-handoffs.md` - Codex M8 Execution and Independent-Verification Handoffs.
- `m8-app-adapter-contract.md` - M8 Local Application Adapter Contract.
- `m8-architecture-decision.md` - M8 Architecture Decision and Alternatives.
- `m8-core-gap-register.md` - M8 Core Integration Gap Register.
- `m8-dependency-and-license-matrix.md` - M8 Dependency and License Decision Matrix.
- `m8-execution-map.md` - M8 Execution Map and Gates.
- `m8-final-acceptance-matrix.md` - M8 Final Acceptance Matrix.
- `m8-package-validation.md` - M8 planning-artifact validation, not product-test evidence.
- `m8-plan-index-update.md` - M8 proposed planning-index additions.
- `m8-release-and-packaging-decision.md` - M8 Release and Packaging Decision.
- `m8-risk-register.md` - M8 Risk Register.
- `m8-shared-contract.md` - M8 Shared Contract.
- `m8-source-evidence-register.md` - M8 Source and Evidence Register.
- `m8-ux-and-user-flows.md` - M8 UX Map and Detailed User Flows.
- `m8-verification-runbook.md` - M8 Verification Runbook.
- `m8-verified-state.md` - M8 Verified Baseline and Entry-Gate Report.
- `m8a-preflight-and-contract-freeze-plan.md` - M8A Plan: Preflight and Contract Freeze.
- `m8b-local-adapter-and-vault-session-plan.md` - M8B Plan: Local Adapter and Vault Session.
- `m8c-read-only-application-experience-plan.md` - M8C Plan: Read-Only Application Experience.
- `m8d-capture-import-and-retry-safety-plan.md` - M8D Plan: Capture, Import and Retry Safety.
- `m8e-human-review-workspace-plan.md` - M8E Plan: Human Review Workspace.
- `m8f-report-and-read-only-graph-plan.md` - M8F Plan: Report and Read-Only Graph.
- `m8h-launcher-recovery-and-release-plan.md` - M8H Plan: Launcher, Recovery and Developer-Preview Release.
- `prd-m8-local-nous-application.md` - PRD: M8 Local Nous Application.
- `test-spec-m8a-preflight-and-contract-freeze.md` - Test Specification: M8A Preflight and Contract Freeze.
- `test-spec-m8b-local-adapter-and-vault-session.md` - Test Specification: M8B Local Adapter and Vault Session.
- `test-spec-m8c-read-only-application-experience.md` - Test Specification: M8C Read-Only Application Experience.
- `test-spec-m8d-capture-import-and-retry-safety.md` - Test Specification: M8D Capture, Import and Retry Safety.
- `test-spec-m8e-human-review-workspace.md` - Test Specification: M8E Human Review Workspace.
- `test-spec-m8f-report-and-read-only-graph.md` - Test Specification: M8F Report and Read-Only Graph.
- `test-spec-m8h-launcher-recovery-and-release.md` - Test Specification: M8H Launcher, Recovery and Developer-Preview Release.
```

## Repository application checks

Verify each named file exists after copying; ensure there are no unexpected duplicate/newer M8 documents, conflicting instructions or overwritten owner changes. All files need final newlines and valid internal links. Run `make lint` and `git diff --check`; reconcile only the approved planning diff. Do not add the archive, consolidation, generator script, private audit directory or temporary source download attempts to the project unless separately requested.

`SHA256SUMS.txt` and the ZIP are delivery metadata, not required source files for `.omx/plans/`. The combined Markdown companion is a reading convenience; use the individual stage files for execution. Future actual verification reports must also be indexed when they are genuinely created, not prefilled as passing evidence.
