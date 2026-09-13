# Codex M8 Execution and Independent-Verification Handoffs

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## Before using a prompt

These are future execution prompts, not authorization granted by this package. First close the M7F gate described in `m8-verified-state.md`, approve the relevant M8 decisions and authorize one stage. The package intentionally exposes one stage at a time. Do not paste all seven prompts into a single autonomous run.

Each checkpoint is a suggested session/Ralph boundary. A resumed worker first reads current source and durable executor status, then continues the earliest incomplete authorized checkpoint. Tests/evidence, not previous conversational assertions, determine completion. Existing worktrees with uncommitted changes are preserved; do not create a duplicate recovery task.

## Stage-specific execution prompts

### M8A: Preflight and Contract Freeze

```text
You are executing only Nous M8A (Preflight and Contract Freeze).

Authorization prerequisite: explicit owner approval of this stage and its
entry gate. This draft alone does not grant authority. No default-branch merge.

Read root AGENT.md and every applicable directory AGENT. Inspect the current
branch/SHA, dirty files, live roadmap and durable Gajae work before dispatching
or editing. Do not reset/delete preserved or uncommitted work; do not duplicate
an active session. Compare the current revision with planning baseline
14e2a00af439024be853d4aba47acd7184829de5. Reconcile relevant differences first.

Read:
- .omx/plans/m8-verified-state.md
- .omx/plans/prd-m8-local-nous-application.md
- .omx/plans/m8-shared-contract.md
- .omx/plans/m8-architecture-decision.md
- .omx/plans/m8-core-gap-register.md
- .omx/plans/m8-app-adapter-contract.md
- .omx/plans/m8-ux-and-user-flows.md
- .omx/plans/m8a-preflight-and-contract-freeze-plan.md
- .omx/plans/test-spec-m8a-preflight-and-contract-freeze.md
- .omx/plans/m8-verification-runbook.md

Prove this stage's entry gate and baseline before changes. If M7F/current-stage
prerequisites are unverified, stop with BLOCKED and the smallest missing
piece of evidence. Do not treat missing evidence as permission to reimplement
or silently waive a prerequisite.

Implement the ordered checkpoints from m8a-preflight-and-contract-freeze-plan.md only.
Current objective: Close the inherited release evidence gap and prove the smallest read-only browser-to-Ruby-core bridge outside production code. Freeze the application, metadata, security and runtime decisions before adopting a frontend.

Keep every domain rule in direct Nous Core operations. No frontend filesystem
writes, CLI business subprocess wrappers, MCP-as-UI-backend, second database,
agent approval, arbitrary source/output path, remote/LAN exposure or provider.
Preserve the exact eight MCP tools and protocol, existing CLI behavior, source
bytes, provenance and human review authority. Use synthetic temporary vaults.

Run the narrow test after each behavior unit, the entire stage specification,
all earlier introduced tests, the full M2-M7 regression, lint and diff/privacy
checks. Repeat after changed-files-only cleanup. Do not mock core in every E2E
path or weaken schemas/tests to get green. No future-stage implementation.

At each session end report:
- authorized stage/checkpoint and actual revision;
- completed behavior and exact changed files;
- commands/tests passed, failed and skipped;
- preserved data/recovery state and unresolved risks;
- next allowed checkpoint, not the next unapproved stage.

Finish with an evidence-based PASS or BLOCKED for independent verification.
Do not mark the milestone accepted, auto-dispatch the next stage or merge.
```

### M8B: Local Adapter and Vault Session

```text
You are executing only Nous M8B (Local Adapter and Vault Session).

Authorization prerequisite: explicit owner approval of this stage and its
entry gate. This draft alone does not grant authority. No default-branch merge.

Read root AGENT.md and every applicable directory AGENT. Inspect the current
branch/SHA, dirty files, live roadmap and durable Gajae work before dispatching
or editing. Do not reset/delete preserved or uncommitted work; do not duplicate
an active session. Compare the current revision with planning baseline
14e2a00af439024be853d4aba47acd7184829de5. Reconcile relevant differences first.

Read:
- .omx/plans/m8-verified-state.md
- .omx/plans/prd-m8-local-nous-application.md
- .omx/plans/m8-shared-contract.md
- .omx/plans/m8-architecture-decision.md
- .omx/plans/m8-core-gap-register.md
- .omx/plans/m8-app-adapter-contract.md
- .omx/plans/m8-ux-and-user-flows.md
- .omx/plans/m8b-local-adapter-and-vault-session-plan.md
- .omx/plans/test-spec-m8b-local-adapter-and-vault-session.md
- .omx/plans/m8-verification-runbook.md

Prove this stage's entry gate and baseline before changes. If M7F/current-stage
prerequisites are unverified, stop with BLOCKED and the smallest missing
piece of evidence. Do not treat missing evidence as permission to reimplement
or silently waive a prerequisite.

Implement the ordered checkpoints from m8b-local-adapter-and-vault-session-plan.md only.
Current objective: Establish a secure, independently testable read-only app transport and truthful vault session/health model. Add only the human read-core extensions needed by the app, while preserving bounded MCP behavior.

Keep every domain rule in direct Nous Core operations. No frontend filesystem
writes, CLI business subprocess wrappers, MCP-as-UI-backend, second database,
agent approval, arbitrary source/output path, remote/LAN exposure or provider.
Preserve the exact eight MCP tools and protocol, existing CLI behavior, source
bytes, provenance and human review authority. Use synthetic temporary vaults.

Run the narrow test after each behavior unit, the entire stage specification,
all earlier introduced tests, the full M2-M7 regression, lint and diff/privacy
checks. Repeat after changed-files-only cleanup. Do not mock core in every E2E
path or weaken schemas/tests to get green. No future-stage implementation.

At each session end report:
- authorized stage/checkpoint and actual revision;
- completed behavior and exact changed files;
- commands/tests passed, failed and skipped;
- preserved data/recovery state and unresolved risks;
- next allowed checkpoint, not the next unapproved stage.

Finish with an evidence-based PASS or BLOCKED for independent verification.
Do not mark the milestone accepted, auto-dispatch the next stage or merge.
```

### M8C: Read-Only Application Experience

```text
You are executing only Nous M8C (Read-Only Application Experience).

Authorization prerequisite: explicit owner approval of this stage and its
entry gate. This draft alone does not grant authority. No default-branch merge.

Read root AGENT.md and every applicable directory AGENT. Inspect the current
branch/SHA, dirty files, live roadmap and durable Gajae work before dispatching
or editing. Do not reset/delete preserved or uncommitted work; do not duplicate
an active session. Compare the current revision with planning baseline
14e2a00af439024be853d4aba47acd7184829de5. Reconcile relevant differences first.

Read:
- .omx/plans/m8-verified-state.md
- .omx/plans/prd-m8-local-nous-application.md
- .omx/plans/m8-shared-contract.md
- .omx/plans/m8-architecture-decision.md
- .omx/plans/m8-core-gap-register.md
- .omx/plans/m8-app-adapter-contract.md
- .omx/plans/m8-ux-and-user-flows.md
- .omx/plans/m8c-read-only-application-experience-plan.md
- .omx/plans/test-spec-m8c-read-only-application-experience.md
- .omx/plans/m8-verification-runbook.md

Prove this stage's entry gate and baseline before changes. If M7F/current-stage
prerequisites are unverified, stop with BLOCKED and the smallest missing
piece of evidence. Do not treat missing evidence as permission to reimplement
or silently waive a prerequisite.

Implement the ordered checkpoints from m8c-read-only-application-experience-plan.md only.
Current objective: Make the product useful before enabling writes: a real local UI for opening a vault, understanding health, browsing accepted knowledge and inspecting safe evidence.

Keep every domain rule in direct Nous Core operations. No frontend filesystem
writes, CLI business subprocess wrappers, MCP-as-UI-backend, second database,
agent approval, arbitrary source/output path, remote/LAN exposure or provider.
Preserve the exact eight MCP tools and protocol, existing CLI behavior, source
bytes, provenance and human review authority. Use synthetic temporary vaults.

Run the narrow test after each behavior unit, the entire stage specification,
all earlier introduced tests, the full M2-M7 regression, lint and diff/privacy
checks. Repeat after changed-files-only cleanup. Do not mock core in every E2E
path or weaken schemas/tests to get green. No future-stage implementation.

At each session end report:
- authorized stage/checkpoint and actual revision;
- completed behavior and exact changed files;
- commands/tests passed, failed and skipped;
- preserved data/recovery state and unresolved risks;
- next allowed checkpoint, not the next unapproved stage.

Finish with an evidence-based PASS or BLOCKED for independent verification.
Do not mark the milestone accepted, auto-dispatch the next stage or merge.
```

### M8D: Capture, Import and Retry Safety

```text
You are executing only Nous M8D (Capture, Import and Retry Safety).

Authorization prerequisite: explicit owner approval of this stage and its
entry gate. This draft alone does not grant authority. No default-branch merge.

Read root AGENT.md and every applicable directory AGENT. Inspect the current
branch/SHA, dirty files, live roadmap and durable Gajae work before dispatching
or editing. Do not reset/delete preserved or uncommitted work; do not duplicate
an active session. Compare the current revision with planning baseline
14e2a00af439024be853d4aba47acd7184829de5. Reconcile relevant differences first.

Read:
- .omx/plans/m8-verified-state.md
- .omx/plans/prd-m8-local-nous-application.md
- .omx/plans/m8-shared-contract.md
- .omx/plans/m8-architecture-decision.md
- .omx/plans/m8-core-gap-register.md
- .omx/plans/m8-app-adapter-contract.md
- .omx/plans/m8-ux-and-user-flows.md
- .omx/plans/m8d-capture-import-and-retry-safety-plan.md
- .omx/plans/test-spec-m8d-capture-import-and-retry-safety.md
- .omx/plans/m8-verification-runbook.md

Prove this stage's entry gate and baseline before changes. If M7F/current-stage
prerequisites are unverified, stop with BLOCKED and the smallest missing
piece of evidence. Do not treat missing evidence as permission to reimplement
or silently waive a prerequisite.

Implement the ordered checkpoints from m8d-capture-import-and-retry-safety-plan.md only.
Current objective: Enable the first app writes only after durable retry and interrupted-import behavior are proven. Preserve confirmed text as raw evidence and expose the existing M6 import loop without source loss or duplicate records.

Keep every domain rule in direct Nous Core operations. No frontend filesystem
writes, CLI business subprocess wrappers, MCP-as-UI-backend, second database,
agent approval, arbitrary source/output path, remote/LAN exposure or provider.
Preserve the exact eight MCP tools and protocol, existing CLI behavior, source
bytes, provenance and human review authority. Use synthetic temporary vaults.

Run the narrow test after each behavior unit, the entire stage specification,
all earlier introduced tests, the full M2-M7 regression, lint and diff/privacy
checks. Repeat after changed-files-only cleanup. Do not mock core in every E2E
path or weaken schemas/tests to get green. No future-stage implementation.

At each session end report:
- authorized stage/checkpoint and actual revision;
- completed behavior and exact changed files;
- commands/tests passed, failed and skipped;
- preserved data/recovery state and unresolved risks;
- next allowed checkpoint, not the next unapproved stage.

Finish with an evidence-based PASS or BLOCKED for independent verification.
Do not mark the milestone accepted, auto-dispatch the next stage or merge.
```

### M8E: Human Review Workspace

```text
You are executing only Nous M8E (Human Review Workspace).

Authorization prerequisite: explicit owner approval of this stage and its
entry gate. This draft alone does not grant authority. No default-branch merge.

Read root AGENT.md and every applicable directory AGENT. Inspect the current
branch/SHA, dirty files, live roadmap and durable Gajae work before dispatching
or editing. Do not reset/delete preserved or uncommitted work; do not duplicate
an active session. Compare the current revision with planning baseline
14e2a00af439024be853d4aba47acd7184829de5. Reconcile relevant differences first.

Read:
- .omx/plans/m8-verified-state.md
- .omx/plans/prd-m8-local-nous-application.md
- .omx/plans/m8-shared-contract.md
- .omx/plans/m8-architecture-decision.md
- .omx/plans/m8-core-gap-register.md
- .omx/plans/m8-app-adapter-contract.md
- .omx/plans/m8-ux-and-user-flows.md
- .omx/plans/m8e-human-review-workspace-plan.md
- .omx/plans/test-spec-m8e-human-review-workspace.md
- .omx/plans/m8-verification-runbook.md

Prove this stage's entry gate and baseline before changes. If M7F/current-stage
prerequisites are unverified, stop with BLOCKED and the smallest missing
piece of evidence. Do not treat missing evidence as permission to reimplement
or silently waive a prerequisite.

Implement the ordered checkpoints from m8e-human-review-workspace-plan.md only.
Current objective: Complete the highest-value product loop: humans inspect evidence, edit candidates and make explicit review decisions with stable routing, conditional writes, audit information and safe multi-record recovery.

Keep every domain rule in direct Nous Core operations. No frontend filesystem
writes, CLI business subprocess wrappers, MCP-as-UI-backend, second database,
agent approval, arbitrary source/output path, remote/LAN exposure or provider.
Preserve the exact eight MCP tools and protocol, existing CLI behavior, source
bytes, provenance and human review authority. Use synthetic temporary vaults.

Run the narrow test after each behavior unit, the entire stage specification,
all earlier introduced tests, the full M2-M7 regression, lint and diff/privacy
checks. Repeat after changed-files-only cleanup. Do not mock core in every E2E
path or weaken schemas/tests to get green. No future-stage implementation.

At each session end report:
- authorized stage/checkpoint and actual revision;
- completed behavior and exact changed files;
- commands/tests passed, failed and skipped;
- preserved data/recovery state and unresolved risks;
- next allowed checkpoint, not the next unapproved stage.

Finish with an evidence-based PASS or BLOCKED for independent verification.
Do not mark the milestone accepted, auto-dispatch the next stage or merge.
```

### M8F: Report and Read-Only Graph

```text
You are executing only Nous M8F (Report and Read-Only Graph).

Authorization prerequisite: explicit owner approval of this stage and its
entry gate. This draft alone does not grant authority. No default-branch merge.

Read root AGENT.md and every applicable directory AGENT. Inspect the current
branch/SHA, dirty files, live roadmap and durable Gajae work before dispatching
or editing. Do not reset/delete preserved or uncommitted work; do not duplicate
an active session. Compare the current revision with planning baseline
14e2a00af439024be853d4aba47acd7184829de5. Reconcile relevant differences first.

Read:
- .omx/plans/m8-verified-state.md
- .omx/plans/prd-m8-local-nous-application.md
- .omx/plans/m8-shared-contract.md
- .omx/plans/m8-architecture-decision.md
- .omx/plans/m8-core-gap-register.md
- .omx/plans/m8-app-adapter-contract.md
- .omx/plans/m8-ux-and-user-flows.md
- .omx/plans/m8f-report-and-read-only-graph-plan.md
- .omx/plans/test-spec-m8f-report-and-read-only-graph.md
- .omx/plans/m8-verification-runbook.md

Prove this stage's entry gate and baseline before changes. If M7F/current-stage
prerequisites are unverified, stop with BLOCKED and the smallest missing
piece of evidence. Do not treat missing evidence as permission to reimplement
or silently waive a prerequisite.

Implement the ordered checkpoints from m8f-report-and-read-only-graph-plan.md only.
Current objective: Expose the existing reviewed-only projections as usable, explicitly derived views with truthful freshness, bounded visualization and safe manual regeneration.

Keep every domain rule in direct Nous Core operations. No frontend filesystem
writes, CLI business subprocess wrappers, MCP-as-UI-backend, second database,
agent approval, arbitrary source/output path, remote/LAN exposure or provider.
Preserve the exact eight MCP tools and protocol, existing CLI behavior, source
bytes, provenance and human review authority. Use synthetic temporary vaults.

Run the narrow test after each behavior unit, the entire stage specification,
all earlier introduced tests, the full M2-M7 regression, lint and diff/privacy
checks. Repeat after changed-files-only cleanup. Do not mock core in every E2E
path or weaken schemas/tests to get green. No future-stage implementation.

At each session end report:
- authorized stage/checkpoint and actual revision;
- completed behavior and exact changed files;
- commands/tests passed, failed and skipped;
- preserved data/recovery state and unresolved risks;
- next allowed checkpoint, not the next unapproved stage.

Finish with an evidence-based PASS or BLOCKED for independent verification.
Do not mark the milestone accepted, auto-dispatch the next stage or merge.
```

### M8H: Launcher, Recovery and Developer-Preview Release

```text
You are executing only Nous M8H (Launcher, Recovery and Developer-Preview Release).

Authorization prerequisite: explicit owner approval of this stage and its
entry gate. This draft alone does not grant authority. No default-branch merge.

Read root AGENT.md and every applicable directory AGENT. Inspect the current
branch/SHA, dirty files, live roadmap and durable Gajae work before dispatching
or editing. Do not reset/delete preserved or uncommitted work; do not duplicate
an active session. Compare the current revision with planning baseline
14e2a00af439024be853d4aba47acd7184829de5. Reconcile relevant differences first.

Read:
- .omx/plans/m8-verified-state.md
- .omx/plans/prd-m8-local-nous-application.md
- .omx/plans/m8-shared-contract.md
- .omx/plans/m8-architecture-decision.md
- .omx/plans/m8-core-gap-register.md
- .omx/plans/m8-app-adapter-contract.md
- .omx/plans/m8-ux-and-user-flows.md
- .omx/plans/m8h-launcher-recovery-and-release-plan.md
- .omx/plans/test-spec-m8h-launcher-recovery-and-release.md
- .omx/plans/m8-verification-runbook.md

Prove this stage's entry gate and baseline before changes. If M7F/current-stage
prerequisites are unverified, stop with BLOCKED and the smallest missing
piece of evidence. Do not treat missing evidence as permission to reimplement
or silently waive a prerequisite.

Implement the ordered checkpoints from m8h-launcher-recovery-and-release-plan.md only.
Current objective: Ship an honestly scoped developer preview with a repeatable daily launcher, verified local process lifecycle and a complete independently observed end-to-end acceptance record. This stage hardens already-tested recovery; it does not postpone write safety until release.

Keep every domain rule in direct Nous Core operations. No frontend filesystem
writes, CLI business subprocess wrappers, MCP-as-UI-backend, second database,
agent approval, arbitrary source/output path, remote/LAN exposure or provider.
Preserve the exact eight MCP tools and protocol, existing CLI behavior, source
bytes, provenance and human review authority. Use synthetic temporary vaults.

Run the narrow test after each behavior unit, the entire stage specification,
all earlier introduced tests, the full M2-M7 regression, lint and diff/privacy
checks. Repeat after changed-files-only cleanup. Do not mock core in every E2E
path or weaken schemas/tests to get green. No future-stage implementation.

At each session end report:
- authorized stage/checkpoint and actual revision;
- completed behavior and exact changed files;
- commands/tests passed, failed and skipped;
- preserved data/recovery state and unresolved risks;
- next allowed checkpoint, not the next unapproved stage.

Finish with an evidence-based PASS or BLOCKED for independent verification.
Do not mark the milestone accepted, auto-dispatch the next stage or merge.
```

## Independent verifier prompt

```text
Independently verify the single implemented Nous M8 stage identified by its
actual worktree/PR and owner authorization. Do not rely on the executor's PASS
statement. Do not implement additional features, merge, or mark later stages
complete.

Read root/local AGENT instructions, the current roadmap, M8 shared contract,
the selected stage plan/test specification, adapter contract, core gap register,
verification runbook and final acceptance matrix. Confirm the implemented SHA,
predecessor evidence and current durable Gajae state. Preserve dirty work.

Inspect the actual diff for direct frontend/adapter filesystem business logic,
CLI subprocess wrappers, MCP surface drift, provider/network dependencies,
new authoritative data stores, path/lock/idempotency bypasses, stale-write risks,
unsafe Markdown, private browser persistence and lost provenance/history.

Run all applicable stage cases and prior regressions against new synthetic
fixtures. Use the real core/server/CLI/MCP where specified. Independently test
at least one adverse path, relevant cross-interface contention and actual
process-death recovery for each affected write family. Test the built artifact
on the declared platform when the stage requires it. Never infer a manual Mac
or client gate from unrelated Linux/SDK/component success.

Inspect exact before/after bytes and current stable IDs/lifecycle, not only UI
toasts. Audit logs/network/browser storage/temporary and Git artifacts. Rerun
after any executor cleanup or fix; verification must name the final SHA.

Return VERIFIED PASS or BLOCKED with requirement/test IDs, commands, versions,
observations, failure/skip details, evidence locations and the smallest next
safe action. A waiver needs explicit owner approval and cannot silently weaken
inherited safety. Do not merge or dispatch another stage.
```

## Product-owner review prompt for this draft

```text
Review the M8 draft without implementing it. Resolve only the consequential
choices: browser developer preview and local runtime; optional app receipts,
history and interrupted-transaction guards; pending-only review/edit scope;
manual derived refresh and bounded graph; M9 deferral of integrated chat.

Confirm the target branch and actual M7F release evidence. List changes needed
to the PRD/shared/API/stage/tests/matrix together. Do not rewrite historical
M1-M7 artifacts or declare unspecified runtime versions approved. Authorize
M8A only when the gate is satisfied; do not approve all downstream execution
implicitly.
```
