# M8 Execution Map and Gates

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## Delivery sequence

```text
Verified M7F + owner approval
        |
        v
M8A: preflight / contract freeze
        |
        v
M8B: secure local adapter / vault session / read core
        |
        v
M8C: read-only application
        |
        v
M8D: capture / import / retry and recovery foundation
        |
        v
M8E: human review workspace
        |
        v
M8F: report / bounded read-only graph
        |
        v
M8H: launcher / recovery hardening / developer-preview release
```

There are **seven runnable stages**. The handoff's hypothetical M8G archivist workspace is deliberately deferred to M9; it is not an unfinished mandatory stage in this plan. M8H retains the handoff's release-stage identifier to make that scope decision visible. No stage depends on an unimplemented chat service.

## Stage files and bounded agent sessions

| Stage | Outcome | Ordered checkpoints | Implementation plan | Test specification |
| --- | --- | --- | --- | --- |
| M8A | Preflight and Contract Freeze | 5 | [m8a-preflight-and-contract-freeze-plan.md](m8a-preflight-and-contract-freeze-plan.md) | [test-spec-m8a-preflight-and-contract-freeze.md](test-spec-m8a-preflight-and-contract-freeze.md) |
| M8B | Local Adapter and Vault Session | 5 | [m8b-local-adapter-and-vault-session-plan.md](m8b-local-adapter-and-vault-session-plan.md) | [test-spec-m8b-local-adapter-and-vault-session.md](test-spec-m8b-local-adapter-and-vault-session.md) |
| M8C | Read-Only Application Experience | 5 | [m8c-read-only-application-experience-plan.md](m8c-read-only-application-experience-plan.md) | [test-spec-m8c-read-only-application-experience.md](test-spec-m8c-read-only-application-experience.md) |
| M8D | Capture, Import and Retry Safety | 6 | [m8d-capture-import-and-retry-safety-plan.md](m8d-capture-import-and-retry-safety-plan.md) | [test-spec-m8d-capture-import-and-retry-safety.md](test-spec-m8d-capture-import-and-retry-safety.md) |
| M8E | Human Review Workspace | 6 | [m8e-human-review-workspace-plan.md](m8e-human-review-workspace-plan.md) | [test-spec-m8e-human-review-workspace.md](test-spec-m8e-human-review-workspace.md) |
| M8F | Report and Read-Only Graph | 5 | [m8f-report-and-read-only-graph-plan.md](m8f-report-and-read-only-graph-plan.md) | [test-spec-m8f-report-and-read-only-graph.md](test-spec-m8f-report-and-read-only-graph.md) |
| M8H | Launcher, Recovery and Developer-Preview Release | 5 | [m8h-launcher-recovery-and-release-plan.md](m8h-launcher-recovery-and-release-plan.md) | [test-spec-m8h-launcher-recovery-and-release.md](test-spec-m8h-launcher-recovery-and-release.md) |

Checkpoints are suggested session boundaries, not time estimates or permission to skip tests. A stage may require more sessions; keep the exit criteria unchanged. One accepted stage at a time is safer than parallel frontend/core branches whose contracts drift.

## Entry and exit gates

**Gate 0:** close actual M7F release evidence at the implementation revision, inspect active durable Gajae work, read current instructions, preserve dirty/recovery work and approve M8A. Planning can be reviewed before this gate; product implementation cannot.

**Gate A -> B:** disposable read-only bridge, native selection/bootstrap and exact runtime/dependency proof pass. The app schema, optional receipt/history/recovery decisions and runtime adoption are explicitly approved. Production code/manifests remain unchanged during A.

**Gate B -> C:** private HTTP/session/health/read contracts pass independent tests; no path leak or unauthenticated access; core remains dependency-free; MCP remains exact; no business write route is available.

**Gate C -> D:** real-browser read-only experience and safe rendering/storage/epoch behavior pass. Existing and new tests are green; UI does not hide backend failures with mock data. The source descriptor and app mutation metadata design are resolved before writes.

**Gate D -> E:** raw capture and three-output import are correct, retry-safe and source-preserving. Actual process death is tested; updated same-release interfaces guard interrupted transactions; cancellation/outcome reconciliation is truthful. No unproved multi-file safety is deferred to H.

**Gate E -> F:** all note/claim/relationship review actions, complete edits, endpoint ordering, merge target checks, source/target preconditions and approve/merge crash recovery pass. This is the main product-value gate. Do not trade its correctness for graph features.

**Gate F -> H:** reviewed-only report/graph views and input/output freshness pass, deterministic legacy output remains compatible, and visualization is bounded/accessibly navigable. Omitting the agreed graph requires explicit scope amendment; an agent cannot silently mark it done.

**Final gate:** built-artifact launch/use/recovery succeeds on declared supported platform/browser versions; all requirement rows have evidence and independent acceptance; no private/runtime artifacts or unapproved changes remain. A completed implementation report does not itself authorize merge.

## Green and usable at each stage

A preserves the existing product. B adds a secure service while CLI/MCP remain usable. C is already useful for inspection. D allows daily source capture/import. E completes the human trust loop. F adds derived understanding. H makes repeatable start/stop and release claims reliable. No stage exposes a placeholder control that pretends to perform a later action.

## Change and branch control

Use the project's actual approved Coordinator/worktree process, discovered at execution time. Do not reuse a stale session ID from past chats. Do not spawn overlapping workers for the same stage, alter a preserved recovery worktree or reset uncommitted implementation. A checkpoint may be committed only under the current execution authority; never merge to the default branch without human authorization.

A requested scope change updates the PRD, shared contract, adapter schema, affected stage plan/test, matrix and handoff together. Optional agent chat, self-contained packaging and accepted-record editing are separate product decisions, not small cleanup tasks.

## Rollback model

Each code stage must be separately revertible, but code rollback does not delete source/accepted records or optional audit metadata. Read-only stage rollback is data-neutral. Write-stage rollback preserves committed vault data and any unresolved transaction manifests; use explicit verified recovery rather than removing metadata to conceal a failure. Restore legacy runtime/tooling only when its compatibility with remaining optional records is established.

## Readiness of this package

**Draft: ready for product-owner review. Implementation: BLOCKED pending Gate 0 and approvals.** No product test or stage implementation was completed as part of planning. See `m8-verified-state.md` for evidence limits and `codex-m8-execution-handoffs.md` for bounded prompts.
