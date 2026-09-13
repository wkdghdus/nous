# M8F Plan: Report and Read-Only Graph

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## 1. Objective

Expose the existing reviewed-only projections as usable, explicitly derived views with truthful freshness, bounded visualization and safe manual regeneration.

## 2. Dependencies and entry gate

M8E accepted and capture-review flow is usable. Existing graph/report byte and semantic tests remain green. Output fingerprint/manifest format is approved without changing graph schema or report semantics.

Formal predecessor: **M8E accepted plus explicit M8F authorization**. Sources establish available interfaces, not passing tests. Read root and every affected local AGENT; recheck the current SHA against the planning baseline. Do not run a second task over an active Coordinator worktree or copy uncommitted recovery work without inspecting its durable state.

## 3. Exact scope

**In scope:** Current/previous report viewing, safe source navigation, direct-core manual regeneration, output-specific freshness manifests, bounded graph query/visualization/table, error/empty/large/stale states and fixed-time compatibility verification.

**Out of scope:** No auto-generation after every save, new psychological report content, force-directed polish project, graph editing, second graph database, embeddings, provider summaries, remote assets, background rendering worker infrastructure or desktop packaging.

## 4. Likely files and ownership

Proposed direct-core derived-view/freshness module plus existing builders via safe public operations; adapter output and graph-query routes; optional manifest documentation; Report/Graph UI and table; scripts/test_nous_app_outputs.rb; UI outputs E2E; relevant schema/signposts without incompatible graph-schema change.

Paths described as proposed are future additions, not existing API evidence. Choose the smallest cohesive modules after inspecting current source; the list does not authorize unrelated edits. Every newly tracked nonempty directory requires an indexed AGENT signpost. No test uses the repository's personal vault.

## 5. Architecture constraints

Follow `m8-shared-contract.md` and `m8-app-adapter-contract.md`. Domain decisions remain in direct core operations; transport/session/native-picker concerns remain in the adapter; view state remains in the UI. No operation shells out to a Ruby business CLI or routes routine actions through MCP. Use one current-release core lock context, not nested calls that reacquire it. Unknown prior state is not automatically repaired.

## 6. Ordered implementation sessions/checkpoints

Each row is a bounded agent session or checkpoint, not permission to one-shot the entire stage. Run the narrow test after each behavior unit. Keep new behavior unavailable until its prerequisite safety checks pass.

| Checkpoint | Outcome | Ordered work |
| --- | --- | --- |
| F.1 | Define authoritative freshness and output reads | Compute fingerprints from exact eligible input records, generator/version/options and output bytes. Define legacy/no-manifest as unknown. Validate output schema plus current core lifecycle eligibility; a syntactically valid pending node is not acceptable. |
| F.2 | Implement safe manual generation | Call core build+atomic-write operations at fixed default destinations with exclusive lock and expected input revision. Stage/validate fully before final replacement. Publish freshness metadata in an order that makes a torn pair unknown, never falsely fresh. Graph/report are separate outcomes. |
| F.3 | Build report experience | Render current sanitized report with source navigation, generated timestamp/freshness and actionable errors. Previous legacy/stale text requires an explicit snapshot warning. Keep established sections and do not add unsupported conclusions or assume every browsable type appears in every report section. |
| F.4 | Build bounded graph and table | Add a core-owned filterable graph projection endpoint, read-only node-link view and accessible table. Use deterministic layout or a small approved library only if justified. Preserve edge direction, evidence and current eligibility; show too-large state before render limits are exceeded. |
| F.5 | Verify trust, compatibility and failure | Compare fixed-time core/CLI/app graph/report bytes, pending exclusions, invalid/dangling/error cases, manifest mismatch, external edits and failed regeneration. Inspect no additional authoritative files or layout persistence. Keep review UX/regressions green. |

At each session end, record completed checkpoint, exact revision, changed files, focused/full test outcomes, unresolved risks and the next allowed checkpoint. Resume by inspecting current files and durable executor state, not by trusting stale narration. Never auto-advance to the next M8 stage.

## 7. Migration and compatibility

Graph schema and existing report bytes remain unchanged for fixed state/time; freshness lives in separate disposable manifests. Existing CLI regeneration without updated metadata may yield unknown freshness, never falsely current. Generated data remains reconstructable from vault records. No new report claims are synthesized.

Update current README/setup/signpost descriptions only to behavior actually verified at this stage; do not wait until H while documentation becomes misleading. Historical M1-M7 plans remain unchanged. An existing test failure requires cause analysis. Do not update snapshots or expected errors solely to conceal behavior drift. Optional metadata must remain portable when the app is not running, and a schema-wide rewrite is not authorized.

## 8. Failure and rollback model

Before final replacement, any build/render/validation failure preserves the previous valid output. A torn or stale manifest/output pair is unknown and regenerable. After successful output replacement but lost response, reconcile the output digest/operation state instead of falsely reporting failure. Large graphs use filtered/table views; never rewrite the exported graph to fit UI limits.

A code-stage revert is not a request to delete user records already created. Preserve accepted records and optional metadata. Any rollback that changes stored data needs explicit owner approval and a verified backup/recovery procedure. Never issue reset/clean/delete against an unknown worktree.

## 9. Privacy and security

Reports/labels/evidence are untrusted Markdown/text. No remote linked assets, raw HTML, arbitrary file output destinations or direct access to generated paths. Graph acceptance comes from core trust rules as well as schema validation. Keep existing source and reviewed files unchanged during generation.

Use synthetic markers and private temporary directories. Sanitized diagnostics may identify a test case/correlation code, never a full request or source body. Review static assets, logs, test videos and failure traces for accidental persistence.

## 10. Acceptance and exit gate

The user can manually generate/view the existing report and a bounded current graph, navigate to actual source records, detect stale/unknown outputs and recover from generation errors. Pending/retired data does not appear as current accepted output, deterministic projections match existing contracts, and the table is usable without visualization.

All cases in `test-spec-m8f-report-and-read-only-graph.md` must pass with evidence. The predecessor and all legacy tests remain green. `git diff --check` is clean; relevant AGENT entries are complete; no runtime/fixture/private artifact is tracked. The independent verifier records PASS or BLOCKED, never converts unavailable checks to pass. Exit requires explicit acceptance; it does not authorize default-branch merge.

## 11. Focused verification order

First the changed core/helper contract, then adapter mapping, then real-server integration, then affected browser E2E/manual checks. The following commands/targets are **proposed for this stage** unless already present. Implement their wiring as part of the authorized stage; do not claim they ran during planning.

```sh
ruby scripts/test_nous_app_outputs.rb
make test-app
make test-e2e
make test-all
```

Expected test programs: scripts/test_nous_app_outputs.rb; apps/local-ui/tests/outputs.e2e.spec.ts (proposed).

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

Stop on any pending/retired-as-current output, dangling edge accepted, incompatible graph/report format, new psychological inference, path-controlled output, unsafe rendering, lost prior valid output before commit, or unmeasured graph scope expansion.

Also stop on unapproved scope, a private-data leak, required destructive recovery, altered MCP tool inventory, core model/network dependency or uncertainty about overwritten user data. Report the smallest blocking prerequisite and preserved state.

## 14. Codex potholes to prevent

Equating file presence/mtime with freshness; trusting graph schema review_status enum as eligibility; writing layout coordinates into canonical records; silently dropping nodes over the cap; auto-regenerating on health/poll; changing report prose to look more intelligent; claiming both outputs succeeded when one failed.

Do not implement later-stage controls as fake-success placeholders. Do not leave safety checks only in the UI. Do not replace real-core integration with mocks or add an unrelated cleanup/refactor while troubleshooting.

## 15. Independent verifier checklist

Create pending and accepted fixtures, generate via CLI/core/app at fixed time, compare outputs and inspect evidence links. Modify input/output files outside the app to invalidate freshness, corrupt a manifest, force generation failure, and verify table/keyboard access for an oversized graph.

Independently inspect the diff and run the current tests rather than repeating the executor's conclusion. Verify all entry/exit conditions, tests after cleanup, compatibility and artifact privacy. Report skipped manual/platform checks explicitly, with the revision and next safe action. Evidence must be reproducible from synthetic fixtures.

Sources: H01 and the baseline/core gap register. This plan prescribes future behavior only.
