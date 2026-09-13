# M8 Verification Runbook

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## 1. Safety before commands

This runbook is for a future authorized executor with a real checkout. No commands in it were executed against Nous during planning. Inspect the current revision and all instructions; check durable Coordinator status; isolate work without resetting or deleting uncommitted work. Do not point a test, screenshot run or MCP smoke at the personal vault. Ensure every subprocess receives an explicit synthetic vault root.

Use installed/pinned dependencies and browser binaries. Registry downloads are setup activity, not evidence that runtime is offline. Record failures before changing code. Tests that need the Mac/native picker/intended client must run there; Linux success is not proof of those gates.

## 2. Existing mandatory baseline

The following current commands are taken from the Makefile and M7 release contract:

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

Also run the actual M7F Inspector and intended Codex host discovery/read/write/full-lifecycle gates with exact client version/date, not merely the old echo-tool preflight. Confirm successful require is side-effect free and the stdio protocol still exposes exactly eight tools. Record any checks not available; do not mark them green.

## 3. Proposed M8 aggregate wiring

Keep current `make test`, `test-core`, `test-mcp` and `lint` available. Add `test-app` in B for every introduced Ruby application suite. Add `test-ui`, `test-e2e` and `test-all` in C, where `test-all` combines the existing baseline with all current app, UI type/unit/build and real-browser E2E checks. Later stages register their cases rather than bypass the aggregate. Earlier stages must not depend on nonexistent future suites.

Typical direct commands once their stage creates them:

```sh
bundle exec ruby scripts/test_nous_app_transport.rb
ruby scripts/test_nous_human_reads.rb
ruby scripts/test_nous_app_mutations.rb
ruby scripts/test_nous_app_review.rb
ruby scripts/test_nous_app_outputs.rb
ruby scripts/test_nous_app_recovery.rb
bundle exec ruby scripts/test_nous_app_cross_interface.rb
bundle exec ruby scripts/test_nous_app_release.rb
npm --prefix apps/local-ui run typecheck
npm --prefix apps/local-ui run test -- --run
npm --prefix apps/local-ui run build
make test-e2e
make test-all
make lint
git diff --check
git status --short
```

The `ruby` versus `bundle exec` split preserves dependency-free direct core tests; transport/MCP/release tests may require their locked adapter dependencies. Do not solve a missing dependency by loading HTTP/MCP globally from core.

## 4. Fault-injection method

Add deterministic test-only barriers around current operation staging/finalization, disabled outside tests. Launch the actual operation in a subprocess against a fresh fixture; wait for the barrier through a pipe; inspect the expected on-disk phase; terminate the process; start a fresh process and inspect/explicitly reconcile. A timeout is a test failure, not a retry that hides a deadlock.

Cover capture single-finalize, each import output, approval metadata/move boundaries and both merge records. Verify before-finalization, partial-finalization, after-finalization-before-response and competing external modification. Compare hashes, receipt ownership, source preservation, no-overwrite behavior, lock release and updated-interface recovery guards. Never delete the lock file to make a test pass.

## 5. Browser and transport checks

Use real-browser E2E with the built static UI served by the Ruby adapter, not only dev server/proxy mode. Instrument network to reject nonloopback requests. Inspect localStorage, sessionStorage, IndexedDB, service-worker registrations and API caching. Confirm no personal body/query/draft/token persistence. Check no-store/CSP/Host/Origin/custom-header behavior with an independent HTTP client as well as the browser.

Use synthetic malicious Markdown (script/events/iframes/remote images/executable URL schemes) and payload filename/path attacks. Do not sanitize source evidence by deleting its text; verify safe rendering and structural metadata redaction separately. Capture UI media only from synthetic fixtures.

## 6. Performance and accessibility evidence

Measure the documented 1k/10k record fixtures and graph thresholds on recorded hardware/storage/runtime/browser versions. Record warm/cold runs and p95 samples; do not publish unmeasured performance as fact. Long operations need progress/error feedback even when a target is missed. A target change requires review, not a hidden test timeout bump.

Manually exercise keyboard-only launch/session selection, browse, evidence, capture/import, all review decisions, conflict handling, report and graph table. Check focus, accessible names, readable errors, zoom and reduced motion. Automated accessibility checks supplement a real walkthrough; do not claim formal certification from a tool score.

## 7. Evidence and final cleanup

Evidence entries contain stage/case, SHA, exact command/environment, exit status and safe synthetic observations. No real record contents or personal paths. Inspect the changed-files list and Git tracked/untracked state; remove only identified owned fixtures/build/runtime artifacts. Do not run broad `git clean` or destructive resets. Re-run focused and full available suites after cleanup.

Final report separates verified facts, failed/skipped checks, assumptions and approvals. Independent verification happens at the same final SHA or explicitly reruns after any change. Do not merge, dispatch another stage or declare the entire roadmap complete as a side effect of this runbook.
