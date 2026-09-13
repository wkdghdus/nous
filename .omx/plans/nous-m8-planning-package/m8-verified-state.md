# M8 Verified Baseline and Entry-Gate Report

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## Verdict

**M7 supervision state: VERIFYING. M8 implementation readiness: BLOCKED.** The public branch contains the M7 core, candidate-write implementation, MCP adapter and test wiring. This assessment does not establish that M7F is incomplete in the owner's environment; it establishes that its complete release gate is not verified by the evidence available here.

The planning draft is reviewable now. Production M8 changes must wait for revision-specific M7F release evidence and product approval of the M8 decisions. Do not reimplement M7F or dispatch duplicate work merely because its release evidence is unavailable.

## Observed baseline

| Area | Observation | Evidence / confidence |
| --- | --- | --- |
| Target | Public `main` at `14e2a00af439024be853d4aba47acd7184829de5`. | GitHub branch API, observed. |
| Core | `lib/nous.rb` loads cohesive path, mutation, indexing, reads and candidate modules. | R10; source observed, runtime side-effect check not run. |
| M7A-M7E tests | Characterization, read-core, mutation-core, agent-read and candidate-write programs are wired into Makefile. | R07; presence/wiring is not a passing result. |
| M7F | A real stdio adapter and protocol-test program exist; source config enables argument/result validation. | R18-R19. |
| MCP surface | Exactly the eight named tools are documented and asserted in inspected test declarations. | R03/R19; live discovery not run here. |
| Protocol | Product target explicitly remains `2025-11-25`. | R18/R21; do not upgrade incidentally. |
| Dependencies | MCP 1.5.1, base64 0.3.0 and minitest 5.25.4 are locked; Bundler 2.6.3 recorded. | R09. |
| Runtime | Historical preflight records Ruby 3.4.2; no claim that all Ruby >=2.7 releases are supported. | R20. |
| Frontend | Root `package.json` is deliberately rejected by lint. | R08. |
| Import | Three outputs include an existing deterministic review draft. | R03/R14. |
| Review edit | Core resolves an edit path, but inspected review module has no structured save-edit operation. | R13. |
| Retry safety | M7 candidate replay is persisted in `generation`; app import/review request receipts are not established. | R12/R13/R14/R16. |
| Crash safety | The inspected multi-file transaction tracks rollback state in memory and handles exceptions. | R15; no durable crash journal in that class. |
| Derived freshness | Status reports output presence, not a source-fingerprint freshness proof. | R11. |
| User workspace | Dirty files, private vault state, current recovery branch and Coordinator sessions are inaccessible. | Unknown; no claim of a clean laptop workspace. |

## Exact inherited MCP surface

```text
nous_status
nous_list_records
nous_read_record
nous_read_source_text
nous_capture_user_text
nous_propose_note
nous_propose_claim
nous_propose_relationship
```

The app will not add a ninth tool, mutate MCP schemas to support human review, or call this surface for routine UI operations.

## Smallest prerequisite closure

At the intended implementation revision, run the full existing regression and the M7F manual/independent gates in R24-R27. Record the exact Ruby/Bundler/client versions, revision, commands, outcomes and sanitized evidence locations. Specifically close Inspector, intended Codex host discovery/read/write against the real eight-tool server, full capture/propose/human-review/output lifecycle, and independent acceptance verification. The historical echo-tool preflight is not a substitute.

Before dispatch, inspect the owner's existing Gajae durable session/turn state. Reuse active work rather than starting a second M7F task. Obtain a clean or deliberately isolated worktree without resetting or deleting uncommitted work. Do not copy private vault files into fixtures.

## Source-authority discrepancies

The old v0.1 ideation document mentions voice/transcripts and broader future outputs. The current root guardrails and this M8 handoff explicitly exclude voice and retain reviewed-only derived output. Preserve the old document as historical context; do not silently rewrite it or use it to reopen excluded scope.

The M7 artifacts include draft labels. Their presence alone does not establish human execution approval. This package does not retroactively change their status. Obtain actual authority from the owner or the live roadmap before implementation.

## Action performed in this cycle

Read-only repository and roadmap inspection; public evidence reconciliation; offline M8 planning-file generation. No repository code, dependencies, branches, commits, pull requests, client settings or Gajae sessions were changed.

Gajae session: unknown. Turn: unknown. Durable status: unavailable. Next safe action: close the M7F evidence gap, review the M8 architecture/metadata decisions, then authorize M8A only.

References: H01; R03-R27 in `m8-source-evidence-register.md`.
