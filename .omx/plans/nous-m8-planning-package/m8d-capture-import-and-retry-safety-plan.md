# M8D Plan: Capture, Import and Retry Safety

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## 1. Objective

Enable the first app writes only after durable retry and interrupted-import behavior are proven. Preserve confirmed text as raw evidence and expose the existing M6 import loop without source loss or duplicate records.

## 2. Dependencies and entry gate

M8C read-only app is accepted; the optional app metadata/source-descriptor/recovery contract from A is approved. Same-release CLI/MCP processes are required for new recovery guards. Baseline and transport/privacy tests pass before mutation code is enabled.

Formal predecessor: **M8C accepted plus explicit M8D authorization**. Sources establish available interfaces, not passing tests. Read root and every affected local AGENT; recheck the current SHA against the planning baseline. Do not run a second task over an active Coordinator worktree or copy uncommitted recovery work without inspecting its durable state.

## 3. Exact scope

**In scope:** Human capture core with app provenance; bounded file-upload source descriptor reusing M6 behavior; app receipt namespace and outcome lookup; narrowly scoped interrupted-import manifests/guards; progress/cancellation/cleanup; capture/import UI; real cross-interface write contention and response-loss replay.

**Out of scope:** No candidate proposals from an embedded agent, automatic classification, raw-payload editing, batch import, approval/review UI, metadata inference from images, arbitrary source/output paths, background ingestion, general-purpose transaction/database framework.

## 4. Likely files and ownership

Proposed direct-core human capture/import/app-operation/recovery modules under lib/nous/; surgical shared helper extraction from candidate/artifact ingestion and source reader; optional source/app metadata schema documentation; app routes/job coordinator; UI capture/import pages; scripts/test_nous_app_mutations.rb, test_nous_app_recovery.rb and test_nous_app_cross_interface.rb; ignored runtime paths and signposts.

Paths described as proposed are future additions, not existing API evidence. Choose the smallest cohesive modules after inspecting current source; the list does not authorize unrelated edits. Every newly tracked nonempty directory requires an indexed AGENT signpost. No test uses the repository's personal vault.

## 5. Architecture constraints

Follow `m8-shared-contract.md` and `m8-app-adapter-contract.md`. Domain decisions remain in direct core operations; transport/session/native-picker concerns remain in the adapter; view state remains in the UI. No operation shells out to a Ruby business CLI or routes routine actions through MCP. Use one current-release core lock context, not nested calls that reacquire it. Unknown prior state is not automatically repaired.

## 6. Ordered implementation sessions/checkpoints

Each row is a bounded agent session or checkpoint, not permission to one-shot the entire stage. Run the narrow test after each behavior unit. Keep new behavior unavailable until its prerequisite safety checks pass.

| Checkpoint | Outcome | Ordered work |
| --- | --- | --- |
| D.1 | Implement app receipt and recovery foundations | Create the approved app-v1 receipt codec/lookup with direct-core tests. Keep M7 generation untouched. Add bounded recovery-manifest parsing and guards to participating core entrypoints, including safe reads. Test ambiguous/unknown manifests fail closed. Do not expose a UI write yet. |
| D.2 | Implement exact human text capture | Factor only neutral rendering/atomic-write helpers necessary to avoid duplicating capture logic. Store source.capture_channel app and the raw record receipt; extend exact source extraction for validated app captures. Preserve old MCP capture bytes, generation fields, input digest and protocol results. |
| D.3 | Implement bounded human import | Accept trusted adapter IO/source metadata, validate all limits and basename/extension/encoding in core, preserve copied bytes and original filename, share M6 extraction and aligned collision allocation, and attach one import receipt to the artifact owner referencing all results. |
| D.4 | Prove import commit and cancellation | Stage all intended outputs, persist the narrow manifest and finalize with no overwrite. Implement explicit byte-checked recovery and guard same-release readers/writers from partial state. Inject process death after each finalize and after commit before reply. Cancel only before the commit barrier. |
| D.5 | Wire adapter and real UI | Stream the selected file to private bounded spool storage without logging bodies; no lock during upload/user wait. Add operation states/outcome lookup, capture/import forms, explicit authorship, truthful progress and original-preservation/result views. The backend announces write capability only when foundations pass. |
| D.6 | Cross-interface and cleanup gate | Run real app-vs-CLI/MCP races, duplicate-click/timeout replays, unsupported input and disk-full/permission failures. Audit original bytes/mode, fixture leakage, spool ownership and loaded old-process warning. Run all earlier suites after cleanup. |

At each session end, record completed checkpoint, exact revision, changed files, focused/full test outcomes, unresolved risks and the next allowed checkpoint. Resume by inspecting current files and durable executor state, not by trusting stale narration. Never auto-advance to the next M8 stage.

## 7. Migration and compatibility

Existing CLI M6 three-output semantics and suffixes remain unchanged. New app bounds do not reduce CLI allowlists. M7 generation interface/digests remain mcp; app receipts are separate optional metadata. Same-release core introduces an explicit recovery-required error only for unfinished app transactions; older already-running adapters are not claimed compatible with that state.

Update current README/setup/signpost descriptions only to behavior actually verified at this stage; do not wait until H while documentation becomes misleading. Historical M1-M7 plans remain unchanged. An existing test failure requires cause analysis. Do not update snapshots or expected errors solely to conceal behavior drift. Optional metadata must remain portable when the app is not running, and a schema-wide rewrite is not authorized.

## 8. Failure and rollback model

Before commit: remove only owned spool/staging files; originals and preexisting records unchanged. During multi-file finalization: preserve a durable manifest and block ordinary updated-core use until explicit reconciliation. After commit but before response: find the owning receipt and return the same IDs/current paths. External changed bytes are never overwritten during recovery. Source deletion or receipt removal by external tools requires human reconciliation.

A code-stage revert is not a request to delete user records already created. Preserve accepted records and optional metadata. Any rollback that changes stored data needs explicit owner approval and a verified backup/recovery procedure. Never issue reset/clean/delete against an unknown worktree.

## 9. Privacy and security

Enforce byte limits while receiving, cap multipart count and active import count, validate accepted basename without using it as a destination, reject source-path fields, keep native/external originals untouched, and never parse image content into facts. Private transaction backups remain inside ignored core-owned runtime state and never enter logs/Git.

Use synthetic markers and private temporary directories. Sanitized diagnostics may identify a test case/correlation code, never a full request or source body. Review static assets, logs, test videos and failure traces for accidental persistence.

## 10. Acceptance and exit gate

Capture returns one exact raw artifact with correct app origin, and import returns the aligned copied-payload/artifact/draft triple. Replays create no duplicate, cancellation semantics match the barrier, process-kill tests reconcile without overwriting external data, existing MCP captures/CLI imports remain byte-compatible, and UI success follows actual commit.

All cases in `test-spec-m8d-capture-import-and-retry-safety.md` must pass with evidence. The predecessor and all legacy tests remain green. `git diff --check` is clean; relevant AGENT entries are complete; no runtime/fixture/private artifact is tracked. The independent verifier records PASS or BLOCKED, never converts unavailable checks to pass. Exit requires explicit acceptance; it does not authorize default-branch merge.

## 11. Focused verification order

First the changed core/helper contract, then adapter mapping, then real-server integration, then affected browser E2E/manual checks. The following commands/targets are **proposed for this stage** unless already present. Implement their wiring as part of the authorized stage; do not claim they ran during planning.

```sh
ruby scripts/test_nous_app_mutations.rb
ruby scripts/test_nous_app_recovery.rb
bundle exec ruby scripts/test_nous_app_cross_interface.rb
make test-app
make test-e2e
make test-all
```

Expected test programs: scripts/test_nous_app_mutations.rb; scripts/test_nous_app_recovery.rb; scripts/test_nous_app_cross_interface.rb; apps/local-ui/tests/capture-import.e2e.spec.ts (proposed).

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

Stop on any source modification, duplicate on retry, unjournaled partial multi-file finalization, premature success/cancelled claim, unsafe recovery overwrite, old-protocol drift, new raw-to-canonical path, missing capability-based file authorization or unapproved optional metadata.

Also stop on unapproved scope, a private-data leak, required destructive recovery, altered MCP tool inventory, core model/network dependency or uncertainty about overwritten user data. Report the smallest blocking prerequisite and preserved state.

## 14. Codex potholes to prevent

Reusing capture unchanged and falsely labeling it MCP; placing the same generation request_id on all three import files; passing a fake browser path to ingest; losing original filename to upload tempfile naming; equating rescued exceptions with SIGKILL safety; deleting .nous.lock; aborting a thread mid-finalization; rolling back after already reporting success.

Do not implement later-stage controls as fake-success placeholders. Do not leave safety checks only in the UI. Do not replace real-core integration with mocks or add an unrelated cleanup/refactor while troubleshooting.

## 15. Independent verifier checklist

Use an independent process to kill the real backend at controlled commit points and reconcile from a fresh process. Compare full recursive manifests including originals. Replay exact keys through the API; verify changed keys/input conflict. Confirm real CLI/MCP writes share the lock and old M7 output schemas/bytes did not change.

Independently inspect the diff and run the current tests rather than repeating the executor's conclusion. Verify all entry/exit conditions, tests after cleanup, compatibility and artifact privacy. Report skipped manual/platform checks explicitly, with the revision and next safe action. Evidence must be reproducible from synthetic fixtures.

Sources: H01 and the baseline/core gap register. This plan prescribes future behavior only.
