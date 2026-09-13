# Test Specification: M8C Read-Only Application Experience

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## 1. Strategy and boundaries

Verify the M8C exit gate, not just an attractive UI or a mocked response. Pure validators/renderers get unit tests; domain state transitions and filesystem rules get direct core tests; HTTP authentication/schema/error behavior gets independent transport tests; user interaction gets component tests; at least one relevant complete path uses the real server and real core in a browser or client process.

Existing M2-M7 tests remain contracts. Do not copy their business implementation into a test helper, weaken their expectations or change the MCP schemas to match a new UI DTO. A passing focused suite cannot compensate for an earlier regression.

## 2. Fixture model

Every test starts with a new synthetic vault under an explicit temporary root. Build the known lifecycle folders and schema-compatible records using test factories. Fixtures include empty/populated vaults, generic inbox note/claim/relationship, all nine reviewed note types, active canonical claims/edges, raw text, writing/image/project copied payloads, retired records and legacy optional-field omissions.

Adversarial variants contain duplicate IDs, malformed YAML, symlink roots/components, external absolute source metadata, unsupported/binary/invalid-UTF-8 payloads, large records, misleading MIME, hostile Markdown and secret-shaped marker text. No test scans the owner's home or reuses the repo's default vault. Every spawned CLI/MCP/app process receives the temporary root explicitly; fail the test if it would fall back to `vault/`.

Use an injected fixed UTC clock, exact byte manifests and random private temp directories. For dates, include represented-date versus creation-date differences and Unicode whitespace. Keep expected lifecycle/paths in explicit assertions rather than only large snapshots. Lock/process tests use separate processes and deterministic barriers, not unreliable sleeps.

## 3. Required test programs

apps/local-ui/src/**/*.test.tsx; apps/local-ui/tests/read-only.e2e.spec.ts (proposed)

All names above are proposed additions/extensions unless the source register marks them existing. Register each introduced program in the current stage's aggregate target. Fixtures and helpers must not require a provider key or network; dependency/browser installation belongs to setup.

## 4. Case inventory and expected results

| ID | Case | Boundary | Required observation |
| --- | --- | --- | --- |
| T-C01 | First-run shell and truthful status | Browser E2E | Open/cancel/switch/invalid/read-only/recovery states work against the real B adapter, with no test seed data injected into the real vault. |
| T-C02 | Knowledge query and all pages | Component + E2E | Filters, stable ordering, reset-on-query, 51+ results and explicit pending/retired scopes behave exactly like core queries. |
| T-C03 | Trust and evidence presentation | Component + integration | Lifecycle, review status, confidence, context/hypotheses and missing/duplicate/redacted evidence are visually distinct; absent legacy metadata is not fabricated. |
| T-C04 | Markdown and payload security | Adversarial browser | Script tags, event handlers, javascript/data/file URLs, iframes, remote images and mislabeled payloads cannot execute or make unexpected network requests. |
| T-C05 | External refresh and stale UI | Real-file E2E | CLI/direct fixture edits, rename, deletion, duplicate IDs, polling/focus refresh and stale cursors invalidate the appropriate view without changing files. |
| T-C06 | Session/reload isolation | Browser integration | Late old-epoch responses never populate new-vault UI; reload does not recover secrets from web storage; expired authorization returns to safe reopen state. |
| T-C07 | Accessibility and empty/error states | Component + manual | Keyboard navigation, focus restoration, labels, text error cues, zoom and loading/no-results/error distinctions pass core-flow checks. |
| T-C08 | Browser privacy and real-core coverage | Browser instrumentation + scan | No sensitive local/session storage, IndexedDB, service worker, cached API body, remote telemetry or secret-bearing bundle; at least one full path is not mocked. |

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

Keyboard-only first-run/browse/evidence flow, screen-reader spot check, zoom and reduced-motion check on the supported browser versions; inspect developer tools storage/network with synthetic content.

Record OS/architecture/browser/runtime/client versions, date, target SHA, synthetic fixture recipe, exact steps and result. A recorded screenshot is supporting evidence only. Missing platform/client access is BLOCKED, not a pass inferred from Linux or component tests.

## 10. Verification order and pass conditions

Run the narrow case for each change, then this entire stage suite, affected legacy suites, all previously introduced app/UI suites, the complete baseline, lint and diff/privacy checks. Commands and proposed aggregate wiring are in `m8c-read-only-application-experience-plan.md` and `m8-verification-runbook.md`.

Pass requires every required case to meet its explicit observation; no leaked private data; no unaccounted product-file delta; no dangling process/listener; unchanged legacy contracts; all mandatory manual checks; and independent verification. Do not replace a failing assertion with a larger timeout, relaxed schema or changed snapshot without proving the intended behavior.

## 11. Post-cleanup regression and evidence

After cleanup limited to changed files and proven owned temp artifacts, rerun the focused and entire available regression. Preserve only sanitized evidence: command, revision, environment, case IDs, exit result and safe artifact reference. Report failures/skips separately. No personal vault files, full private request logs or provider credentials belong in the evidence package.

Completion report: stage, target revision, test IDs passed/failed/skipped, relevant byte-manifest differences, manual observations, unresolved risks, verifier verdict and next allowed checkpoint. Do not claim the next stage or merge approval.
