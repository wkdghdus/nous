# Test Specification: M8H Launcher, Recovery and Developer-Preview Release

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## 1. Strategy and boundaries

Verify the M8H exit gate, not just an attractive UI or a mocked response. Pure validators/renderers get unit tests; domain state transitions and filesystem rules get direct core tests; HTTP authentication/schema/error behavior gets independent transport tests; user interaction gets component tests; at least one relevant complete path uses the real server and real core in a browser or client process.

Existing M2-M7 tests remain contracts. Do not copy their business implementation into a test helper, weaken their expectations or change the MCP schemas to match a new UI DTO. A passing focused suite cannot compensate for an earlier regression.

## 2. Fixture model

Every test starts with a new synthetic vault under an explicit temporary root. Build the known lifecycle folders and schema-compatible records using test factories. Fixtures include empty/populated vaults, generic inbox note/claim/relationship, all nine reviewed note types, active canonical claims/edges, raw text, writing/image/project copied payloads, retired records and legacy optional-field omissions.

Adversarial variants contain duplicate IDs, malformed YAML, symlink roots/components, external absolute source metadata, unsupported/binary/invalid-UTF-8 payloads, large records, misleading MIME, hostile Markdown and secret-shaped marker text. No test scans the owner's home or reuses the repo's default vault. Every spawned CLI/MCP/app process receives the temporary root explicitly; fail the test if it would fall back to `vault/`.

Use an injected fixed UTC clock, exact byte manifests and random private temp directories. For dates, include represented-date versus creation-date differences and Unicode whitespace. Keep expected lifecycle/paths in explicit assertions rather than only large snapshots. Lock/process tests use separate processes and deterministic barriers, not unreliable sleeps.

## 3. Required test programs

scripts/test_nous_app_release.rb; apps/local-ui/tests/app-lifecycle.e2e.spec.ts; all earlier app/core suites (proposed)

All names above are proposed additions/extensions unless the source register marks them existing. Register each introduced program in the current stage's aggregate target. Fixtures and helpers must not require a provider key or network; dependency/browser installation belongs to setup.

## 4. Case inventory and expected results

| ID | Case | Boundary | Required observation |
| --- | --- | --- | --- |
| T-H01 | Launcher and process ownership | Target-platform integration | Prepared launch/reopen/occupied port/missing runtime/stale PID/foreign listener all behave safely; no arbitrary command interpolation or global install occurs. |
| T-H02 | Shutdown and backend death | Process fault injection | Quit blocks new writes and respects commit barrier; crash/restart reauthorizes and reconciles without duplicate submission; old tokens/rendezvous are invalid and owned resources cleaned. |
| T-H03 | Full three-interface lifecycle | Real browser/core/CLI/MCP E2E | Capture/import, actual MCP note/claim/relationship proposals, evidence inspection, edit/approve/merge/retire, endpoint ordering, report/graph and final ID agreement all pass. |
| T-H04 | Offline and no-agent operation | Network-isolated integration | Unset provider keys and block outbound access after setup; deterministic product loop remains useful; no fabricated connection status or hidden model request. |
| T-H05 | Recovery and external-conflict drill | Target-platform integration | Repeat D/E kill cases with the built artifact, old-process compatibility warning, external changed bytes, read-only volume and unfinished manifest; preserve originals and no silent repair. |
| T-H06 | Security/privacy/repository audit | Adversarial + scans | Loopback-only, Host/Origin/token, CSP/Markdown, private storage, no logs/telemetry/secret leak and synthetic-only screenshots/test evidence; no runtime journal/payload committed. |
| T-H07 | Accessibility and measured bounds | Manual + benchmark | Supported browsers pass keyboard/focus/screen-reader/zoom checks; documented 1k/10k record and graph-cap measurements meet budgets or block/obtain explicit scope revision. |
| T-H08 | Built artifact and removal | Independent platform verification | Checksummed preview runs outside the developer server on declared target; setup/version/license docs are reproducible; removal preserves vault and optional metadata readability. |
| T-H09 | Final matrix and post-cleanup regression | Independent audit | Every requirement has passing evidence at the release SHA; all existing and added tests pass again after cleanup; no skipped check is labeled complete and no unauthorized merge occurs. |

## 5. Valid-path coverage

Execute each success path against an empty and populated fixture where applicable. Assert exact IDs, locations, lifecycle/review status, receipt/result shape, bounds and expected file deltas. For read-only paths assert zero product-file changes. For mutations assert only approved destinations and preserved originals. Browser assertions include final visible state and real backing-file state, not a toast alone.

## 6. Invalid/adversarial coverage

Reject malformed/extra properties, wrong types and dangerous paths before side effects. Test source content as untrusted data and never execute instructions embedded in it. Compare structured-error codes while asserting that messages/logs do not echo private markers, paths, body content or tokens. Preserve preexisting files after every rejected action.

## 7. Concurrency, retry and recovery

For read-only stages, verify coherent snapshots, lock contention, epoch/cursor invalidation and backend death; do not invent mutating test operations just to exercise cancellation. For D onward, use a real CLI process, actual MCP server/client and app process against the same fixture. Force response loss before/after commit, retry the identical key, change input under that key, and distinguish not_committed/committed/unknown outcomes.

Use explicit fault barriers to terminate processes around each current-stage finalization point. Raised exceptions alone do not prove process-death recovery. Confirm locks release by OS semantics without deleting the lock pathname. Inspect staged/final/receipt/manifest bytes from a fresh process. Recovery can reconcile only known owned hashes; external divergence must preserve newer data and block unsafe replay. Earlier-stage recovery tests remain mandatory, not only new cases.

## 8. Privacy, path and log scans

Capture stdout/stderr, HTTP headers and error bodies, browser network/storage and build outputs. Look for synthetic secret markers, source-text markers, external-path metadata and auth nonces in prohibited surfaces. Permit explicitly requested verbatim evidence in its authorized response only; do not use a blanket path scan to corrupt source text. Inspect Git tracked/untracked changes for unexpected payloads, journal backups, screenshots, runtime locks, logs and config files.

Scan code/diffs for CLI business subprocesses, direct frontend filesystem writes, unsanitized HTML, unexpected network SDKs, wildcard binds/CORS, browser storage of bodies and silently disabled validators. A textual scan supplements, not replaces, behavior tests.

## 9. Manual checks

Fresh-launch artifact test on macOS Apple Silicon, real Safari/Chrome versions declared by preflight, intended external client integration, keyboard/screen-reader workflow, no-LAN listener check, recovery drill and independent final acceptance.

Record OS/architecture/browser/runtime/client versions, date, target SHA, synthetic fixture recipe, exact steps and result. A recorded screenshot is supporting evidence only. Missing platform/client access is BLOCKED, not a pass inferred from Linux or component tests.

## 10. Verification order and pass conditions

Run the narrow case for each change, then this entire stage suite, affected legacy suites, all previously introduced app/UI suites, the complete baseline, lint and diff/privacy checks. Commands and proposed aggregate wiring are in `m8h-launcher-recovery-and-release-plan.md` and `m8-verification-runbook.md`.

Pass requires every required case to meet its explicit observation; no leaked private data; no unaccounted product-file delta; no dangling process/listener; unchanged legacy contracts; all mandatory manual checks; and independent verification. Do not replace a failing assertion with a larger timeout, relaxed schema or changed snapshot without proving the intended behavior.

## 11. Post-cleanup regression and evidence

After cleanup limited to changed files and proven owned temp artifacts, rerun the focused and entire available regression. Preserve only sanitized evidence: command, revision, environment, case IDs, exit result and safe artifact reference. Report failures/skips separately. No personal vault files, full private request logs or provider credentials belong in the evidence package.

Completion report: stage, target revision, test IDs passed/failed/skipped, relevant byte-manifest differences, manual observations, unresolved risks, verifier verdict and next allowed checkpoint. Do not claim the next stage or merge approval.
