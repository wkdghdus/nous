# M8B Plan: Local Adapter and Vault Session

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## 1. Objective

Establish a secure, independently testable read-only app transport and truthful vault session/health model. Add only the human read-core extensions needed by the app, while preserving bounded MCP behavior.

## 2. Dependencies and entry gate

M8A is accepted, M7F evidence is complete, exact runtime/backend dependencies and optional schemas are approved, and the intended worktree has no active overlapping task. Re-run the pre-stage baseline.

Formal predecessor: **M8A accepted plus explicit M8B authorization**. Sources establish available interfaces, not passing tests. Read root and every affected local AGENT; recheck the current SHA against the planning baseline. Do not run a second task over an active Coordinator worktree or copy uncommitted recovery work without inspecting its durable state.

## 3. Exact scope

**In scope:** Pinned app-only HTTP dependency adoption; same-origin static-shell/private-API separation; authorization/Host/Origin/size/error controls; startup/shutdown primitives; native vault selection and one-vault epoch; read-only health, paginated human query, safe detail/source access and recovery-state inspection.

**Out of scope:** No production React app/package yet, no source or candidate mutation, no import worker, no approval, no output regeneration, no provider/client orchestration, no migration/repair, no public listener.

## 4. Likely files and ownership

Proposed lib/nous/app/ adapter files; scripts/nous_app_server.rb; schemas/app-api.schema.json; direct-core human read/health/source modules under lib/nous/; Gemfile app group and lockfile; Makefile test-app target; affected .gitignore and AGENT signposts. Keep HTTP dependencies out of lib/nous.rb require wiring.

Paths described as proposed are future additions, not existing API evidence. Choose the smallest cohesive modules after inspecting current source; the list does not authorize unrelated edits. Every newly tracked nonempty directory requires an indexed AGENT signpost. No test uses the repository's personal vault.

## 5. Architecture constraints

Follow `m8-shared-contract.md` and `m8-app-adapter-contract.md`. Domain decisions remain in direct core operations; transport/session/native-picker concerns remain in the adapter; view state remains in the UI. No operation shells out to a Ruby business CLI or routes routine actions through MCP. Use one current-release core lock context, not nested calls that reacquire it. Unknown prior state is not automatically repaired.

## 6. Ordered implementation sessions/checkpoints

Each row is a bounded agent session or checkpoint, not permission to one-shot the entire stage. Run the narrow test after each behavior unit. Keep new behavior unavailable until its prerequisite safety checks pass.

| Checkpoint | Outcome | Ordered work |
| --- | --- | --- |
| B.1 | Adopt the approved server boundary | Pin the approved app dependencies without changing existing MCP pins. Add strict adapter schemas and sanitized error mapping; private routes are denied by default. Wire independent Ruby app tests, not a browser-only test harness. |
| B.2 | Secure startup and authorization | Bind the actual loopback socket, validate Host/Origin/framing/limits, implement one-use bootstrap and private runtime rendezvous, set security/no-store headers, and test occupied-port and unauthorized requests before returning any vault data. |
| B.3 | Add native vault session | Implement the fixed picker adapter, server-side handle mapping, existing-root validation and private alias/recents policy. Establish one active epoch and clear state on switch. Health diagnoses invalid/read-only/locked/unsupported states without auto-creation or repair. |
| B.4 | Add direct human read operations | Introduce paginated/filterable core queries, explicit retired scope, bounded record/source DTOs and safe copied-payload access. Core computes lifecycle, hashes and reference resolution. Preserve MCP query limits, fields and default scopes exactly. |
| B.5 | Verify transport and cross-interface reads | Run adversarial HTTP and synthetic-vault integration with the real server and core. Verify CLI/MCP/app stable IDs agree, reads leave product bytes unchanged and load-time isolation still holds. No write route is advertised as available. |

At each session end, record completed checkpoint, exact revision, changed files, focused/full test outcomes, unresolved risks and the next allowed checkpoint. Resume by inspecting current files and durable executor state, not by trusting stale narration. Never auto-advance to the next M8 stage.

## 7. Migration and compatibility

The app group may load HTTP/schema dependencies only at the adapter entrypoint. Core remains reusable without the app bundle. Preserve existing read/MCP output keys; app lifecycle normalization is a separate DTO. Document intentional new read-only diagnostics without replacing old CLI help/error prefixes.

Update current README/setup/signpost descriptions only to behavior actually verified at this stage; do not wait until H while documentation becomes misleading. Historical M1-M7 plans remain unchanged. An existing test failure requires cause analysis. Do not update snapshots or expected errors solely to conceal behavior drift. Optional metadata must remain portable when the app is not running, and a schema-wide rewrite is not authorized.

## 8. Failure and rollback model

Startup failure leaves no listener, active nonce or owned socket/rendezvous artifact. Failed selection leaves the previous vault/epoch unchanged. Invalid/locked/read-only views fail closed; do not initialize folders or delete a lock. An unknown future recovery manifest is reported safely, never executed.

A code-stage revert is not a request to delete user records already created. Preserve accepted records and optional metadata. Any rollback that changes stored data needs explicit owner approval and a verified backup/recovery procedure. Never issue reset/clean/delete against an unknown worktree.

## 9. Privacy and security

Authorization and exact Host/Origin validation precede private data access. File serving is not a static mount of vault/. Source reads resolve from stable artifact IDs with inherited path/symlink rules. Native dialogs accept no client script/path. Query bodies, record slugs, roots and tokens stay out of access logs.

Use synthetic markers and private temporary directories. Sanitized diagnostics may identify a test case/correlation code, never a full request or source body. Review static assets, logs, test videos and failure traces for accidental persistence.

## 10. Acceptance and exit gate

A real HTTP test client can securely select/validate/read a temporary vault. All unauthorized/path/schema attacks fail, more than 50 results are pageable, explicit retired scope is separate, invalid health is truthful, and all M7 behavior remains green without a frontend runtime.

All cases in `test-spec-m8b-local-adapter-and-vault-session.md` must pass with evidence. The predecessor and all legacy tests remain green. `git diff --check` is clean; relevant AGENT entries are complete; no runtime/fixture/private artifact is tracked. The independent verifier records PASS or BLOCKED, never converts unavailable checks to pass. Exit requires explicit acceptance; it does not authorize default-branch merge.

## 11. Focused verification order

First the changed core/helper contract, then adapter mapping, then real-server integration, then affected browser E2E/manual checks. The following commands/targets are **proposed for this stage** unless already present. Implement their wiring as part of the authorized stage; do not claim they ran during planning.

```sh
bundle exec ruby scripts/test_nous_app_transport.rb
ruby scripts/test_nous_human_reads.rb
make test-app
```

Expected test programs: scripts/test_nous_app_transport.rb; scripts/test_nous_human_reads.rb (both proposed).

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

Stop on any unauthenticated content, nonloopback bind, path escape, private logging, read-induced product mutation, hidden runtime upgrade, inability to isolate dependencies, or unresolved read-only locking semantics.

Also stop on unapproved scope, a private-data leak, required destructive recovery, altered MCP tool inventory, core model/network dependency or uncertainty about overwritten user data. Report the smallest blocking prerequisite and preserved state.

## 14. Codex potholes to prevent

Serializing raw Ruby records with absolute Pathname values; accepting vault_root in JSON; requiring Origin on static navigation while leaving API reads open; using wildcards for dev convenience; resolving IDs in an adapter then doing filesystem work; changing MCP schemas to expose pagination.

Do not implement later-stage controls as fake-success placeholders. Do not leave safety checks only in the UI. Do not replace real-core integration with mocks or add an unrelated cleanup/refactor while troubleshooting.

## 15. Independent verifier checklist

Exercise routes using an independent HTTP client with malicious headers and payloads. Inspect actual bound interfaces. Compare before/after file manifests, query all pages, verify current ID/lifecycle results against CLI/MCP and run core-load isolation with app dependencies absent.

Independently inspect the diff and run the current tests rather than repeating the executor's conclusion. Verify all entry/exit conditions, tests after cleanup, compatibility and artifact privacy. Report skipped manual/platform checks explicitly, with the revision and next safe action. Evidence must be reproducible from synthetic fixtures.

Sources: H01 and the baseline/core gap register. This plan prescribes future behavior only.
