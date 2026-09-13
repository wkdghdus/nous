# M8E Plan: Human Review Workspace

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## 1. Objective

Complete the highest-value product loop: humans inspect evidence, edit candidates and make explicit review decisions with stable routing, conditional writes, audit information and safe multi-record recovery.

## 2. Dependencies and entry gate

M8D capture/import, receipt namespace, recovery guards and cross-interface tests are accepted. The owner approved candidate-only edits and the stricter human merge-target policy. Baseline is green and complete edit DTOs are specified before building an editor.

Formal predecessor: **M8D accepted plus explicit M8E authorization**. Sources establish available interfaces, not passing tests. Read root and every affected local AGENT; recheck the current SHA against the planning baseline. Do not run a second task over an active Coordinator worktree or copy uncommitted recovery work without inspecting its durable state.

## 3. Exact scope

**In scope:** Pending queue sorting/filtering; evidence and counterevidence inspection; complete candidate-body/type editing; explicit note/claim/relationship approval; pending reject/deprecate; evidence-only merge; core endpoint/target readiness; conditional source/target versions; app audit history; approval/merge recovery and UI conflict handling.

**Out of scope:** No raw/frontmatter editor, arbitrary reviewed-record editing or deprecation, confidence rewriting, agent review authority, full body-history reconstruction, prose-synthesis merge, bulk approval, changes to the MCP tool inventory, or graph/report auto-generation.

## 4. Likely files and ownership

Proposed human-review core module and surgical already-locked helpers in review_mutation.rb/relationship integrity; approved optional app audit schema; recovery state machines for approve/merge; adapter candidate/review endpoints; Inbox/Editor/Merge/Conflict UI; scripts/test_nous_app_review.rb and additional recovery/cross-interface cases; UI review E2E and signposts.

Paths described as proposed are future additions, not existing API evidence. Choose the smallest cohesive modules after inspecting current source; the list does not authorize unrelated edits. Every newly tracked nonempty directory requires an indexed AGENT signpost. No test uses the repository's personal vault.

## 5. Architecture constraints

Follow `m8-shared-contract.md` and `m8-app-adapter-contract.md`. Domain decisions remain in direct core operations; transport/session/native-picker concerns remain in the adapter; view state remains in the UI. No operation shells out to a Ruby business CLI or routes routine actions through MCP. Use one current-release core lock context, not nested calls that reacquire it. Unknown prior state is not automatically repaired.

## 6. Ordered implementation sessions/checkpoints

Each row is a bounded agent session or checkpoint, not permission to one-shot the entire stage. Run the narrow test after each behavior unit. Keep new behavior unavailable until its prerequisite safety checks pass.

| Checkpoint | Outcome | Ordered work |
| --- | --- | --- |
| E.1 | Implement review inspection and complete edits | Core returns pending queue in documented sort order and a complete edit envelope. Save only allowed body/type fields with expected raw-byte version. Preserve unknown frontmatter, original generation/source/evidence/relationship metadata and stable ID. Append a real app edit event; maintain needs_review. |
| E.2 | Implement conditional simple decisions | Build ID-based human approve/reject/deprecate operations sharing core rules, with source-version checks and app receipt ownership. Notes require an explicit supported route. Approvals validate current endpoint exportability, not cached UI readiness. |
| E.3 | Implement evidence-only merge and multi-file recovery | Validate matching accepted target kind (and identical tuple for relationships), both source/target versions and lifecycle in core. Preserve target body and append evidence, archive source, and persist an auditable receipt. Extend D recovery for source-to-destination approval and two-file merge without nested locks. |
| E.4 | Build the review workspace | Create cards/detail/evidence side-by-side, editable body/type, explicit confirmation, destination/target preview and known history display. Save edits before approval as separate acknowledged operations. Retain unsaved text on conflict and require re-review rather than silent automatic merge. |
| E.5 | Prove all transitions and cross-interface races | Test notes across all nine routes, claims, relationships before/after endpoint approval, retired/default exclusion, CLI/MCP concurrent actions, stale source/target and generation metadata replay after moves. Kill before/after every approval/merge boundary. |
| E.6 | Independent human-loop audit | An independent verifier performs import/MCP proposal -> inspect -> edit -> approve/reject/deprecate/merge in the actual UI and validates bytes/provenance/current IDs via CLI/MCP. Resolve every data-integrity or accessibility issue before release to F. |

At each session end, record completed checkpoint, exact revision, changed files, focused/full test outcomes, unresolved risks and the next allowed checkpoint. Resume by inspecting current files and durable executor state, not by trusting stale narration. Never auto-advance to the next M8 stage.

## 7. Migration and compatibility

M8 edit affects pending body/type only and retains existing review object semantics. Optional app history starts now, without fabricated earlier events. Stricter app merge eligibility is a new human-core wrapper contract, not a silent rewrite of legacy CLI target validation. Preserve CLI output prefixes/options and M7 replay of moved candidates.

Update current README/setup/signpost descriptions only to behavior actually verified at this stage; do not wait until H while documentation becomes misleading. Historical M1-M7 plans remain unchanged. An existing test failure requires cause analysis. Do not update snapshots or expected errors solely to conceal behavior drift. Optional metadata must remain portable when the app is not running, and a schema-wide rewrite is not authorized.

## 8. Failure and rollback model

A stale/invalid source or target returns a no-write conflict. Keep the unsaved draft in memory and offer comparison/reload, never last-writer-wins. Simple single-file decisions commit receipt atomically. Approve/merge interruptions use the D journal/guard model and explicit recovery; external divergence preserves all files. A response loss is reconciled by the same operation key.

A code-stage revert is not a request to delete user records already created. Preserve accepted records and optional metadata. Any rollback that changes stored data needs explicit owner approval and a verified backup/recovery procedure. Never issue reset/clean/delete against an unknown worktree.

## 9. Privacy and security

No mutation request includes complete frontmatter, filesystem destination, user-selected ID or agent approval flag. Candidate body can contain untrusted Markdown but must not alter metadata structure or execute in the UI. Protect provenance and historical generation; sanitizer/privacy rules apply equally to reviewer notes and merge previews.

Use synthetic markers and private temporary directories. Sanitized diagnostics may identify a test case/correlation code, never a full request or source body. Review static assets, logs, test videos and failure traces for accidental persistence.

## 10. Acceptance and exit gate

All five human review flows work from the UI with complete evidence and correct route/lifecycle. Editing never approves, relationship ordering is enforced at commit, stale source/target never silently overwrites, evidence-only merge preserves target body, and receipt/audit/recovery tests pass with every prior suite green.

All cases in `test-spec-m8e-human-review-workspace.md` must pass with evidence. The predecessor and all legacy tests remain green. `git diff --check` is clean; relevant AGENT entries are complete; no runtime/fixture/private artifact is tracked. The independent verifier records PASS or BLOCKED, never converts unavailable checks to pass. Exit requires explicit acceptance; it does not authorize default-branch merge.

## 11. Focused verification order

First the changed core/helper contract, then adapter mapping, then real-server integration, then affected browser E2E/manual checks. The following commands/targets are **proposed for this stage** unless already present. Implement their wiring as part of the authorized stage; do not claim they ran during planning.

```sh
ruby scripts/test_nous_app_review.rb
ruby scripts/test_nous_app_recovery.rb
bundle exec ruby scripts/test_nous_app_cross_interface.rb
make test-app
make test-e2e
make test-all
```

Expected test programs: scripts/test_nous_app_review.rb; extended test_nous_app_recovery.rb and test_nous_app_cross_interface.rb; apps/local-ui/tests/review.e2e.spec.ts (proposed).

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

Stop on canonical writes through an agent path, lost evidence/generation/stable IDs, edited source payloads, unsupported note route, any stale overwrite, dangling relationship approval, fake history, unsafe crash recovery or unapproved broad accepted-record editing.

Also stop on unapproved scope, a private-data leak, required destructive recovery, altered MCP tool inventory, core model/network dependency or uncertainty about overwritten user data. Report the smallest blocking prerequisite and preserved state.

## 14. Codex potholes to prevent

Editing a truncated agent read; saving reconstructed metadata that drops unknown fields; approving from candidate_type without human confirmation; deprecating accepted records through pending-only APIs; merge rewriting target prose; trusting frontend endpoint flags; overwriting a new external edit during rollback; treating old last-decision metadata as a full history.

Do not implement later-stage controls as fake-success placeholders. Do not leave safety checks only in the UI. Do not replace real-core integration with mocks or add an unrelated cleanup/refactor while troubleshooting.

## 15. Independent verifier checklist

Manually inspect before/after frontmatter and body bytes for each action. Use another process to mutate source and merge target between load and submit. Verify every supported note route and edge ordering, kill/restart approve/merge, and confirm MCP original-request replay points to the current moved record without duplication.

Independently inspect the diff and run the current tests rather than repeating the executor's conclusion. Verify all entry/exit conditions, tests after cleanup, compatibility and artifact privacy. Report skipped manual/platform checks explicitly, with the revision and next safe action. Evidence must be reproducible from synthetic fixtures.

Sources: H01 and the baseline/core gap register. This plan prescribes future behavior only.
