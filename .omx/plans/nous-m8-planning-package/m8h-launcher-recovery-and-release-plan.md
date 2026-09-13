# M8H Plan: Launcher, Recovery and Developer-Preview Release

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## 1. Objective

Ship an honestly scoped developer preview with a repeatable daily launcher, verified local process lifecycle and a complete independently observed end-to-end acceptance record. This stage hardens already-tested recovery; it does not postpone write safety until release.

## 2. Dependencies and entry gate

M8A-F are accepted, no safety/compatibility/privacy failure is deferred, and the owner confirms developer-preview rather than self-contained-installer scope. The exact source/build/runtime/browser revision set is frozen for release verification.

Formal predecessor: **M8F accepted plus explicit M8H authorization**. Sources establish available interfaces, not passing tests. Read root and every affected local AGENT; recheck the current SHA against the planning baseline. Do not run a second task over an active Coordinator worktree or copy uncommitted recovery work without inspecting its durable state.

## 3. Exact scope

**In scope:** One-time setup documentation, static build artifact, no-routine-command launcher/reopen/quit, backend lifecycle supervision with bounded restart guidance, supported-platform/browser evidence, recovery drills, accessibility/performance/privacy audit, actual external-MCP interoperability and final release matrix.

**Out of scope:** No embedded agent chat, provider secrets, conversation persistence, automatic updater/login daemon, distribution store, default-branch merge, new feature scope, or claimed signed/notarized/bundled Ruby installer without a separate approved spike.

## 4. Likely files and ownership

Proposed scripts/launch_nous.command or approved equivalent launcher with no business logic; app lifecycle/runtime helper; release/checksum/usage docs and README scope correction; packaging scripts for the developer-preview artifact only; scripts/test_nous_app_release.rb; full browser E2E; final acceptance evidence and signposts.

Paths described as proposed are future additions, not existing API evidence. Choose the smallest cohesive modules after inspecting current source; the list does not authorize unrelated edits. Every newly tracked nonempty directory requires an indexed AGENT signpost. No test uses the repository's personal vault.

## 5. Architecture constraints

Follow `m8-shared-contract.md` and `m8-app-adapter-contract.md`. Domain decisions remain in direct core operations; transport/session/native-picker concerns remain in the adapter; view state remains in the UI. No operation shells out to a Ruby business CLI or routes routine actions through MCP. Use one current-release core lock context, not nested calls that reacquire it. Unknown prior state is not automatically repaired.

## 6. Ordered implementation sessions/checkpoints

Each row is a bounded agent session or checkpoint, not permission to one-shot the entire stage. Run the narrow test after each behavior unit. Keep new behavior unavailable until its prerequisite safety checks pass.

| Checkpoint | Outcome | Ordered work |
| --- | --- | --- |
| H.1 | Build the prepared daily launcher | Validate approved Ruby/Bundler/static assets before launching, bind/verify readiness, open the browser without leaking paths/tokens, and reopen an existing owned instance safely. Missing setup shows exact corrective guidance, not a background installer or global shell mutation. |
| H.2 | Harden shutdown/restart and version boundaries | Stop new writes on Quit, drain/finish commit state, leave recoverable manifests after abnormal death, revoke capability, and release only owned resources. Do not kill an external agent session. Require restart of older CLI/MCP processes before mixed-interface app mutations. |
| H.3 | Run complete product lifecycle | In the actual browser against a temporary synthetic vault, capture/import, receive real MCP proposals, inspect/edit/approve, demonstrate endpoint ordering, merge/retire, browse, generate outputs, verify CLI/MCP agreement and restart. Use a programmatic MCP client for deterministic tests; separately record intended host integration. |
| H.4 | Audit security/privacy/accessibility/performance | Inspect listeners, hostile-origin behavior, request bounds, rendering, logs, storage, temporary files and outbound requests. Measure the proposed performance budgets on documented hardware and data volumes. Run keyboard, screen-reader, zoom and error-recovery checks on supported browsers. |
| H.5 | Package and independently verify | Produce a versioned preview artifact with setup/run/uninstall guidance, dependency/license record and checksums. A second verifier uses the artifact on the target platform rather than the dev server. Mark each matrix row with evidence, not self-reported completion. No automatic merge or scope waiver. |

At each session end, record completed checkpoint, exact revision, changed files, focused/full test outcomes, unresolved risks and the next allowed checkpoint. Resume by inspecting current files and durable executor state, not by trusting stale narration. Never auto-advance to the next M8 stage.

## 7. Migration and compatibility

The release can be removed without deleting the vault or making it unreadable. Local settings/spool/runtime cleanup is scoped and consented. No automatic schema migration or updater. Record exact tested Mac OS/browser versions and Ruby runtime; Windows/Linux and a self-contained installer remain unsupported until separately verified.

Update current README/setup/signpost descriptions only to behavior actually verified at this stage; do not wait until H while documentation becomes misleading. Historical M1-M7 plans remain unchanged. An existing test failure requires cause analysis. Do not update snapshots or expected errors solely to conceal behavior drift. Optional metadata must remain portable when the app is not running, and a schema-wide rewrite is not authorized.

## 8. Failure and rollback model

Missing runtime/dependencies or failed readiness prevents browser authorization to an unknown service. Backend death disables UI writes; no infinite respawn or automatic new-key resubmission. Unresolved receipt/manifest states remain explicit. Failed packaging/platform tests block distribution claims, not justify calling an untested build a desktop app.

A code-stage revert is not a request to delete user records already created. Preserve accepted records and optional metadata. Any rollback that changes stored data needs explicit owner approval and a verified backup/recovery procedure. Never issue reset/clean/delete against an unknown worktree.

## 9. Privacy and security

Use private capability/rendezvous handling and safe fixed launcher arguments. No path/token/body in startup console/log. No analytics or crash upload. All screenshots/evidence use synthetic data. Verify no public listener or global client config/credential mutation. Uninstall never recursively deletes a selected vault.

Use synthetic markers and private temporary directories. Sanitized diagnostics may identify a test case/correlation code, never a full request or source body. Review static assets, logs, test videos and failure traces for accidental persistence.

## 10. Acceptance and exit gate

Every final matrix row passes with revision-specific evidence and independent signoff. The prepared owner can start/use/quit/restart from the launcher; absent-agent and real-MCP-candidate loops both pass. Recovery/conflict handling, CLI/MCP compatibility, local privacy and keyboard operation are demonstrated from the release artifact.

All cases in `test-spec-m8h-launcher-recovery-and-release.md` must pass with evidence. The predecessor and all legacy tests remain green. `git diff --check` is clean; relevant AGENT entries are complete; no runtime/fixture/private artifact is tracked. The independent verifier records PASS or BLOCKED, never converts unavailable checks to pass. Exit requires explicit acceptance; it does not authorize default-branch merge.

## 11. Focused verification order

First the changed core/helper contract, then adapter mapping, then real-server integration, then affected browser E2E/manual checks. The following commands/targets are **proposed for this stage** unless already present. Implement their wiring as part of the authorized stage; do not claim they ran during planning.

```sh
bundle exec ruby scripts/test_nous_app_release.rb
make test-all
# Run the built-artifact manual platform/client/recovery gates separately.
```

Expected test programs: scripts/test_nous_app_release.rb; apps/local-ui/tests/app-lifecycle.e2e.spec.ts; all earlier app/core suites (proposed).

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

Stop release on any failed/unknown mandatory acceptance row, unsupported packaging claim, personal fixture/secret/path leak, security failure, data-loss recovery case, incompatible mixed-interface behavior, inaccessible primary action or unapproved exception.

Also stop on unapproved scope, a private-data leak, required destructive recovery, altered MCP tool inventory, core model/network dependency or uncertainty about overwritten user data. Report the smallest blocking prerequisite and preserved state.

## 14. Codex potholes to prevent

Calling a shell script a signed desktop installer; testing only Vite dev mode; relying on a stale Mac dev environment; killing all Ruby processes to stop one backend; auto-resuming interrupted writes; reporting external agent online from configuration alone; accepting a skipped manual test as pass.

Do not implement later-stage controls as fake-success placeholders. Do not leave safety checks only in the UI. Do not replace real-core integration with mocks or add an unrelated cleanup/refactor while troubleshooting.

## 15. Independent verifier checklist

Use a fresh temporary vault and the built preview artifact, not the executor session. Re-run the entire acceptance scenario, inspect real listener/storage/log behavior and artifact checksums, record exact versions and evidence. Verify removal of app settings does not change vault content. Report unresolved rows honestly.

Independently inspect the diff and run the current tests rather than repeating the executor's conclusion. Verify all entry/exit conditions, tests after cleanup, compatibility and artifact privacy. Report skipped manual/platform checks explicitly, with the revision and next safe action. Evidence must be reproducible from synthetic fixtures.

Sources: H01 and the baseline/core gap register. This plan prescribes future behavior only.
