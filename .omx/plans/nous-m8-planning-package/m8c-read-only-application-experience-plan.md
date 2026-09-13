# M8C Plan: Read-Only Application Experience

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## 1. Objective

Make the product useful before enabling writes: a real local UI for opening a vault, understanding health, browsing accepted knowledge and inspecting safe evidence.

## 2. Dependencies and entry gate

M8B private API/read contracts and security tests pass. M8A runtime adoption is approved. Product owner authorizes the exact frontend-manifest path and build/test tooling; no unresolved read-core gap is hidden with mocks.

Formal predecessor: **M8B accepted plus explicit M8C authorization**. Sources establish available interfaces, not passing tests. Read root and every affected local AGENT; recheck the current SHA against the planning baseline. Do not run a second task over an active Coordinator worktree or copy uncommitted recovery work without inspecting its durable state.

## 3. Exact scope

**In scope:** React/TypeScript static app shell, first-run/vault selection, health dashboard, complete lexical/metadata browsing, stable-ID detail/evidence, explicit source/inbox/retired views, external-change refresh, empty/error/loading/disconnected states and keyboard navigation.

**Out of scope:** No capture/import/review writes, no graph visualization, no report regeneration, no chat/provider, no localStorage/IndexedDB/service-worker content cache, no design-system project, no Next.js or Node production server.

## 4. Likely files and ownership

Proposed apps/AGENT.md; apps/local-ui/ with package.json, exact package-lock.json, TypeScript/Vite config, src/ and tests/ signposts; controlled scripts/lint.sh manifest policy; Makefile test-ui/test-e2e/test-all wiring; UI test fixtures in temporary builders, not vault/.

Paths described as proposed are future additions, not existing API evidence. Choose the smallest cohesive modules after inspecting current source; the list does not authorize unrelated edits. Every newly tracked nonempty directory requires an indexed AGENT signpost. No test uses the repository's personal vault.

## 5. Architecture constraints

Follow `m8-shared-contract.md` and `m8-app-adapter-contract.md`. Domain decisions remain in direct core operations; transport/session/native-picker concerns remain in the adapter; view state remains in the UI. No operation shells out to a Ruby business CLI or routes routine actions through MCP. Use one current-release core lock context, not nested calls that reacquire it. Unknown prior state is not automatically repaired.

## 6. Ordered implementation sessions/checkpoints

Each row is a bounded agent session or checkpoint, not permission to one-shot the entire stage. Run the narrow test after each behavior unit. Keep new behavior unavailable until its prerequisite safety checks pass.

| Checkpoint | Outcome | Ordered work |
| --- | --- | --- |
| C.1 | Adopt the approved static UI toolchain | Update lint intentionally to allow only the agreed nested UI manifest/lock while preserving root/other-path rejection and schema/signpost checks. Pin build/test packages. Serve built assets through the authenticated-backend origin; no production Vite dev server. |
| C.2 | Implement session and health shell | Build first-run, chooser, vault alias/epoch handling, capability-based navigation, health and disconnected/recovery banners. Purge personal in-memory state when vault epoch changes; distinguish zero data from read failure. |
| C.3 | Build accepted knowledge browsing | Wire server-side pagination, types/date/confidence/tags filters and stable-ID navigation. Expose explicit nonaccepted scopes with durable labels. Do not implement domain search against an incomplete client page. |
| C.4 | Build safe detail/evidence and refresh | Render sanitized Markdown, metadata, confidence and separate facts/context/hypotheses when available. Resolve evidence through core. Add focus/manual/visible polling invalidation and stale/deleted/duplicate states. Never load remote embedded content. |
| C.5 | Verify real-browser accessibility/privacy | Run component tests plus a real browser/server/core E2E using synthetic vaults. Check keyboard/focus, browser storage/cache/network, late responses and reload authorization. Keep unavailable mutation controls absent or explicitly read-only, not fake-success buttons. |

At each session end, record completed checkpoint, exact revision, changed files, focused/full test outcomes, unresolved risks and the next allowed checkpoint. Resume by inspecting current files and durable executor state, not by trusting stale narration. Never auto-advance to the next M8 stage.

## 7. Migration and compatibility

Frontend installation/build does not change vault shape, CLI commands or MCP surface. Production is static assets plus Ruby. No service worker or IndexedDB schema becomes a migration dependency. Existing JSON/YAML/text lint and every AGENT signpost rule remain intact.

Update current README/setup/signpost descriptions only to behavior actually verified at this stage; do not wait until H while documentation becomes misleading. Historical M1-M7 plans remain unchanged. An existing test failure requires cause analysis. Do not update snapshots or expected errors solely to conceal behavior drift. Optional metadata must remain portable when the app is not running, and a schema-wide rewrite is not authorized.

## 8. Failure and rollback model

Backend death replaces actionable controls with reconnect/reopen guidance; old responses are discarded by epoch. Failed record read never leaves the previous body under a new title. Reload intentionally loses memory-only state and requires safe reauthorization; do not work around that by persisting a bearer token.

A code-stage revert is not a request to delete user records already created. Preserve accepted records and optional metadata. Any rollback that changes stored data needs explicit owner approval and a verified backup/recovery procedure. Never issue reset/clean/delete against an unknown worktree.

## 9. Privacy and security

No dangerously rendered raw HTML, remote images, file:// links or static vault directory. Bundle contains no tokens/roots/provider keys. Personal bodies/search/drafts never enter web storage. Explicit source text stays verbatim; metadata path redaction is applied in the backend.

Use synthetic markers and private temporary directories. Sanitized diagnostics may identify a test case/correlation code, never a full request or source body. Review static assets, logs, test videos and failure traces for accidental persistence.

## 10. Acceptance and exit gate

The owner can launch/open/inspect/browse a synthetic vault in the real browser with no terminal commands after prepared setup. Every accepted record remains reachable, source/inbox/retired states are distinct, external changes refresh safely, and accessibility/privacy tests pass with real core integration.

All cases in `test-spec-m8c-read-only-application-experience.md` must pass with evidence. The predecessor and all legacy tests remain green. `git diff --check` is clean; relevant AGENT entries are complete; no runtime/fixture/private artifact is tracked. The independent verifier records PASS or BLOCKED, never converts unavailable checks to pass. Exit requires explicit acceptance; it does not authorize default-branch merge.

## 11. Focused verification order

First the changed core/helper contract, then adapter mapping, then real-server integration, then affected browser E2E/manual checks. The following commands/targets are **proposed for this stage** unless already present. Implement their wiring as part of the authorized stage; do not claim they ran during planning.

```sh
npm --prefix apps/local-ui ci
npm --prefix apps/local-ui run typecheck
npm --prefix apps/local-ui run test -- --run
npm --prefix apps/local-ui run build
make test-e2e
make test-all
```

Expected test programs: apps/local-ui/src/**/*.test.tsx; apps/local-ui/tests/read-only.e2e.spec.ts (proposed).

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

Stop on unsafe Markdown, any sensitive browser persistence or outbound fetch, client-side domain rules, lost lifecycle labels, stale cross-vault content, an unexplained mutation during a read-only stage, or weakened legacy lint checks.

Also stop on unapproved scope, a private-data leak, required destructive recovery, altered MCP tool inventory, core model/network dependency or uncertainty about overwritten user data. Report the smallest blocking prerequisite and preserved state.

## 14. Codex potholes to prevent

Beginning with graph polish; persisting query libraries to disk; making all E2E calls mocks; concealing backend diagnostics behind empty cards; using MCP for browsing; interpreting a confidence value as trust; accidentally storing record text in screenshot/test artifacts from the personal vault.

Do not implement later-stage controls as fake-success placeholders. Do not leave safety checks only in the UI. Do not replace real-core integration with mocks or add an unrelated cleanup/refactor while troubleshooting.

## 15. Independent verifier checklist

Browse an empty and populated fixture without a provider; paginate past 50; use only keyboard to open and inspect evidence; modify a fixture externally and switch vaults while a request is in flight. Inspect storage/network and assert no business writes happened.

Independently inspect the diff and run the current tests rather than repeating the executor's conclusion. Verify all entry/exit conditions, tests after cleanup, compatibility and artifact privacy. Report skipped manual/platform checks explicitly, with the revision and next safe action. Evidence must be reproducible from synthetic fixtures.

Sources: H01 and the baseline/core gap register. This plan prescribes future behavior only.
