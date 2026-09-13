# M8A Plan: Preflight and Contract Freeze

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## 1. Objective

Close the inherited release evidence gap and prove the smallest read-only browser-to-Ruby-core bridge outside production code. Freeze the application, metadata, security and runtime decisions before adopting a frontend.

## 2. Dependencies and entry gate

The owner authorizes M8A planning/preflight execution only. Before its bridge work, M7F release evidence at the chosen revision is complete, or the agent stops after reporting the exact missing gate. Inspect existing Gajae work and preserve every uncommitted worktree.

Formal predecessor: **M7F verification plus explicit M8A authorization**. Sources establish available interfaces, not passing tests. Read root and every affected local AGENT; recheck the current SHA against the planning baseline. Do not run a second task over an active Coordinator worktree or copy uncommitted recovery work without inspecting its durable state.

## 3. Exact scope

**In scope:** Full source/AGENT review; current M7 regression and actual intended-client release evidence; a disposable static UI/Ruby read-only spike; macOS folder-chooser, token bootstrap/reopen and native dependency feasibility; app schema examples and approved ADR/version matrix.

**Out of scope:** No production frontend/server behavior, product dependencies, package manifests, default runtime changes, MCP schema changes, vault writes, new-vault initialization, agent chat or installer.

## 4. Likely files and ownership

Existing .omx/plans/ documents and docs/decisions/ after authorization; relevant AGENT indexes. Spike assets belong in a disposable directory outside the product checkout. No lib/ or scripts/ product behavior changes in this stage.

Paths described as proposed are future additions, not existing API evidence. Choose the smallest cohesive modules after inspecting current source; the list does not authorize unrelated edits. Every newly tracked nonempty directory requires an indexed AGENT signpost. No test uses the repository's personal vault.

## 5. Architecture constraints

Follow `m8-shared-contract.md` and `m8-app-adapter-contract.md`. Domain decisions remain in direct core operations; transport/session/native-picker concerns remain in the adapter; view state remains in the UI. No operation shells out to a Ruby business CLI or routes routine actions through MCP. Use one current-release core lock context, not nested calls that reacquire it. Unknown prior state is not automatically repaired.

## 6. Ordered implementation sessions/checkpoints

Each row is a bounded agent session or checkpoint, not permission to one-shot the entire stage. Run the narrow test after each behavior unit. Keep new behavior unavailable until its prerequisite safety checks pass.

| Checkpoint | Outcome | Ordered work |
| --- | --- | --- |
| A.1 | Establish authority and baseline | Read every source and local AGENT required by H01, including all current scripts/tests and earlier stage leaves omitted by the remote review. Record target SHA, dirty state and durable executor status. Run M7 tests and real-client gates; stop on any failure or unapproved overlap. |
| A.2 | Prove the read-only bridge | Use a synthetic vault and direct require/core call in a throwaway Ruby backend. A minimal static page displays safe counts through an authenticated loopback route. Prove the normal production direction without importing MCP classes or shelling out to a business CLI. |
| A.3 | Prove local UX/security/runtime seams | On the target Mac, exercise folder choose/cancel, symlink-root rejection, browser bootstrap/scrub/reopen, port collision, and loopback-only listener. Test Ruby 3.4.10/Bundler 2.6.3 and candidate Rack/Puma; record exact Node/npm/UI tool versions, native dependencies and licenses. |
| A.4 | Freeze the contract | Approve optional app receipt/history shapes, current-release process recovery guards, source descriptor, complete edit envelope, query pagination, error union and output freshness. Store versioned request/response examples and the proposed required-vault-folder list. Resolve unsupported runtime or compatibility choices, not TODO them into B. |
| A.5 | Independent checkpoint | Delete only the identified disposable spike, rerun existing regression, verify product/dependency/vault manifests unchanged, and obtain independent review of the chosen ADR and evidence. Authorize no automatic move to B. |

At each session end, record completed checkpoint, exact revision, changed files, focused/full test outcomes, unresolved risks and the next allowed checkpoint. Resume by inspecting current files and durable executor state, not by trusting stale narration. Never auto-advance to the next M8 stage.

## 7. Migration and compatibility

No product or vault migration. A new proposed runtime is not supported until the full baseline passes on it. Pinning a newer Ruby must not silently update MCP or its protocol target. Existing M7 draft files are not rewritten as complete merely because code exists.

Update current README/setup/signpost descriptions only to behavior actually verified at this stage; do not wait until H while documentation becomes misleading. Historical M1-M7 plans remain unchanged. An existing test failure requires cause analysis. Do not update snapshots or expected errors solely to conceal behavior drift. Optional metadata must remain portable when the app is not running, and a schema-wide rewrite is not authorized.

## 8. Failure and rollback model

A failed spike or missing client proof blocks the architecture/entry gate. Preserve source and logs sanitized; remove only owned temporary artifacts. Do not substitute a desktop framework, bypass localhost authorization or skip the manual client test to continue.

A code-stage revert is not a request to delete user records already created. Preserve accepted records and optional metadata. Any rollback that changes stored data needs explicit owner approval and a verified backup/recovery procedure. Never issue reset/clean/delete against an unknown worktree.

## 9. Privacy and security

Use synthetic data only. The throwaway listener is loopback-only, authenticated and short-lived. Do not change global Codex/Inspector configuration, use the personal vault, upload notes to an online playground or log roots/tokens.

Use synthetic markers and private temporary directories. Sanitized diagnostics may identify a test case/correlation code, never a full request or source body. Review static assets, logs, test videos and failure traces for accidental persistence.

## 10. Acceptance and exit gate

M7F release evidence is independently accepted at the target SHA; a real read-only bridge works; exact tested runtime/dependency/browser matrix and approved interface examples exist; product tree and vault bytes remain unchanged; every consequential decision has an owner/status.

All cases in `test-spec-m8a-preflight-and-contract-freeze.md` must pass with evidence. The predecessor and all legacy tests remain green. `git diff --check` is clean; relevant AGENT entries are complete; no runtime/fixture/private artifact is tracked. The independent verifier records PASS or BLOCKED, never converts unavailable checks to pass. Exit requires explicit acceptance; it does not authorize default-branch merge.

## 11. Focused verification order

First the changed core/helper contract, then adapter mapping, then real-server integration, then affected browser E2E/manual checks. The following commands/targets are **proposed for this stage** unless already present. Implement their wiring as part of the authorized stage; do not claim they ran during planning.

```sh
# Run existing M7 gates and the disposable spike; no product app target exists yet.
```

Expected test programs: test_m8_preflight_contracts.rb in the disposable spike directory (proposed; never installed as a product server).

## 12. Full regression order

Run the existing baseline exactly, plus every app/UI program introduced through the current stage. Installation is an explicit setup action, not a hidden test-time download. UI/browser binaries must be installed before offline runtime tests.

```sh
ruby scripts/test_nous_candidate_writes.rb
ruby scripts/test_nous_agent_reads.rb
ruby scripts/test_cli_contracts.rb
ruby scripts/test_nous_read_core.rb
ruby scripts/test_nous_mutation_core.rb
ruby scripts/test_ingest_text.rb
ruby scripts/test_ingest_artifact.rb
ruby scripts/test_review_queue.rb
ruby scripts/test_export_graph.rb
ruby scripts/test_generate_nous_report.rb
bundle exec ruby scripts/test_nous_mcp.rb
make test
make lint
git diff --check
git status --short
```

For B onward, `make test-app` covers all introduced app Ruby suites. For C onward, the proposed `make test-all` combines the unchanged baseline target, app tests, UI type/unit/build checks and real-browser E2E. Do not call nonexistent future targets in earlier stages. After changed-files-only cleanup, repeat the focused set and the entire available regression.

## 13. Mandatory stop conditions

Stop on missing M7F evidence, active overlapping implementation, a dirty worktree without an isolation decision, unresolved metadata/recovery approval, private data in fixtures, incompatible Ruby/Bundler/server or failure of secure native selection/bootstrap.

Also stop on unapproved scope, a private-data leak, required destructive recovery, altered MCP tool inventory, core model/network dependency or uncertainty about overwritten user data. Report the smallest blocking prerequisite and preserved state.

## 14. Codex potholes to prevent

Treating the echo preflight as the eight-tool release; copying a Vite example with host exposure; putting package.json in a subdirectory to evade lint; selecting an HTTP dependency without native-build proof; declaring every Ruby >=2.7 supported; treating a download-only source review as a successful test run.

Do not implement later-stage controls as fake-success placeholders. Do not leave safety checks only in the UI. Do not replace real-core integration with mocks or add an unrelated cleanup/refactor while troubleshooting.

## 15. Independent verifier checklist

Independently replay one actual MCP discovery/read/write and the read-only app spike. Confirm there is no production dependency or behavior diff. Review the complete source coverage record and every unresolved decision rather than trusting the executor summary.

Independently inspect the diff and run the current tests rather than repeating the executor's conclusion. Verify all entry/exit conditions, tests after cleanup, compatibility and artifact privacy. Report skipped manual/platform checks explicitly, with the revision and next safe action. Evidence must be reproducible from synthetic fixtures.

Sources: H01 and the baseline/core gap register. This plan prescribes future behavior only.
