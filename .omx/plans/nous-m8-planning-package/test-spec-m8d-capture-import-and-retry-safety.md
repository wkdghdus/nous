# Test Specification: M8D Capture, Import and Retry Safety

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## 1. Strategy and boundaries

Verify the M8D exit gate, not just an attractive UI or a mocked response. Pure validators/renderers get unit tests; domain state transitions and filesystem rules get direct core tests; HTTP authentication/schema/error behavior gets independent transport tests; user interaction gets component tests; at least one relevant complete path uses the real server and real core in a browser or client process.

Existing M2-M7 tests remain contracts. Do not copy their business implementation into a test helper, weaken their expectations or change the MCP schemas to match a new UI DTO. A passing focused suite cannot compensate for an earlier regression.

## 2. Fixture model

Every test starts with a new synthetic vault under an explicit temporary root. Build the known lifecycle folders and schema-compatible records using test factories. Fixtures include empty/populated vaults, generic inbox note/claim/relationship, all nine reviewed note types, active canonical claims/edges, raw text, writing/image/project copied payloads, retired records and legacy optional-field omissions.

Adversarial variants contain duplicate IDs, malformed YAML, symlink roots/components, external absolute source metadata, unsupported/binary/invalid-UTF-8 payloads, large records, misleading MIME, hostile Markdown and secret-shaped marker text. No test scans the owner's home or reuses the repo's default vault. Every spawned CLI/MCP/app process receives the temporary root explicitly; fail the test if it would fall back to `vault/`.

Use an injected fixed UTC clock, exact byte manifests and random private temp directories. For dates, include represented-date versus creation-date differences and Unicode whitespace. Keep expected lifecycle/paths in explicit assertions rather than only large snapshots. Lock/process tests use separate processes and deterministic barriers, not unreliable sleeps.

## 3. Required test programs

scripts/test_nous_app_mutations.rb; scripts/test_nous_app_recovery.rb; scripts/test_nous_app_cross_interface.rb; apps/local-ui/tests/capture-import.e2e.spec.ts (proposed)

All names above are proposed additions/extensions unless the source register marks them existing. Register each introduced program in the current stage's aggregate target. Fixtures and helpers must not require a provider key or network; dependency/browser installation belongs to setup.

## 4. Case inventory and expected results

| ID | Case | Boundary | Required observation |
| --- | --- | --- | --- |
| T-D01 | Verbatim capture and app provenance | Core contract | Unicode, blank lines, leading/trailing whitespace, title/context/date and confirmation are correct; raw only; app channel plus optional app receipt; no M7 generation forgery. |
| T-D02 | Capture replay and legacy parity | Core + HTTP | Double-click, same-key retry, changed input, same key in distinct app/MCP namespaces and moved/retired receipt owners behave deliberately; original MCP capture fixtures and source extraction remain unchanged. |
| T-D03 | Allowlisted IO import and preservation | Core integration | Every allowed extension/type, accepted mixed-case extension and text/image/project case preserves source bytes/mode, basename, checksum, size, evidence and aligned three-output suffixes. |
| T-D04 | Adversarial upload and bounds | HTTP + core | Path-like/hidden/null filenames, unsupported PDF/SVG/audio, invalid UTF-8, excess byte/chunk/multipart count, forged MIME/hash and missing source metadata fail with no product writes. |
| T-D05 | Truthful UI results and uncertainty | Browser E2E | Authorship confirmation, pending state, displayed artifact/draft IDs, lock timeout, network drop and duplicate clicks never show success before finalization or blindly allocate a new retry key. |
| T-D06 | Cancel and handled rollback | Core + real-server | Cancel while receiving/validating/staged leaves no output; cancel at commit is too late and reconciles. Disk-full, permissions, checksum and deliberate handled exceptions preserve originals/preexisting records. |
| T-D07 | Process-death import recovery | Multi-process fault injection | Kill before staging, after each output finalize and after receipt-bearing commit before response. Updated CLI/MCP/app reads/writes guard partial state; restart resolves only proven owned bytes. |
| T-D08 | Recovery conflict and ownership | Adversarial filesystem | Externally changed target/staging paths, forged or stale manifests, symlinked runtime entries and unknown manifest versions cannot cause arbitrary read/delete/overwrite; recovery requires explicit action. |
| T-D09 | Real cross-interface serialization | Multi-process integration | App capture/import versus actual CLI ingestion and MCP proposal respects one lock and never overwrites collision targets; key replay yields stable IDs without deadlock. |
| T-D10 | Privacy and post-cleanup parity | Instrumentation + regressions | No bodies, paths, tokens, payloads or private journal data in logs/repository; no outbound request; old M2-M7 suites and all B/C checks still pass. |

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

One real local file-picker import of each type using synthetic files; deliberate offline/no-provider use; interruption/restart and read-only/disk-full reporting on the target Mac; inspect original file permissions and digest.

Record OS/architecture/browser/runtime/client versions, date, target SHA, synthetic fixture recipe, exact steps and result. A recorded screenshot is supporting evidence only. Missing platform/client access is BLOCKED, not a pass inferred from Linux or component tests.

## 10. Verification order and pass conditions

Run the narrow case for each change, then this entire stage suite, affected legacy suites, all previously introduced app/UI suites, the complete baseline, lint and diff/privacy checks. Commands and proposed aggregate wiring are in `m8d-capture-import-and-retry-safety-plan.md` and `m8-verification-runbook.md`.

Pass requires every required case to meet its explicit observation; no leaked private data; no unaccounted product-file delta; no dangling process/listener; unchanged legacy contracts; all mandatory manual checks; and independent verification. Do not replace a failing assertion with a larger timeout, relaxed schema or changed snapshot without proving the intended behavior.

## 11. Post-cleanup regression and evidence

After cleanup limited to changed files and proven owned temp artifacts, rerun the focused and entire available regression. Preserve only sanitized evidence: command, revision, environment, case IDs, exit result and safe artifact reference. Report failures/skips separately. No personal vault files, full private request logs or provider credentials belong in the evidence package.

Completion report: stage, target revision, test IDs passed/failed/skipped, relevant byte-manifest differences, manual observations, unresolved risks, verifier verdict and next allowed checkpoint. Do not claim the next stage or merge approval.
