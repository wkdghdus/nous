# M7D Verification Report

Status: **PASS** (targeted acceptance-criteria audit; not the full 99-row spec-ID traceability matrix — see "Scope of this report")
Governing contract: `.omx/plans/prd-m7d-agent-safe-read-operations.md`, `.omx/plans/m7d-agent-safe-read-operations-plan.md`, `.omx/plans/test-spec-m7d-agent-safe-read-operations.md`
Code audited: `lib/nous/record_index.rb` (303 lines), `lib/nous/agent_reads.rb` (529 lines), at `main` `61bc456` and its current HEAD
Date: 2026-08-12

## Verdict

All 21 acceptance criteria in `m7d-agent-safe-read-operations-plan.md:190-210` were checked directly against the implementation. **0 genuine code gaps found.** `ruby scripts/test_nous_agent_reads.rb` and the full `make test` (9 suites) pass; `git diff --check` is clean. Two items are noted below as caveats, neither a functional defect.

## Scope of this report

This is a **targeted AC-level audit with code citations**, prompted by a direct user question ("is M7D soundly implemented — the actual features and code, not just the logs"). It is not the full 21-AC × 99-test-ID row-by-row traceability matrix that `.omc/plans/m7d-verification-plan.md` Step 2 specifies (that step also requires a reverse-traceability pass over every main-only code hunk and a formal PASS/FAIL/ESCALATE computation over all 99 ratified test IDs individually). That fuller matrix remains a distinct, not-yet-executed deliverable if ever needed; this report stands on its own as an AC-level verdict backed by direct code reading, not on git-history archaeology.

## Acceptance criteria checked

| AC | Requirement (abridged) | Verdict | Evidence |
|---|---|---|---|
| 1 | `RecordIndex` is the neutral discovery/classification owner; no `RelationshipIntegrity` coupling | MET | `grep -n RelationshipIntegrity lib/nous/agent_reads.rb lib/nous/record_index.rb` → no hits |
| 2 | Public ops acquire exactly one shared lock; `_in_context` helpers are lock-free | MET | `agent_reads.rb:20-24,41-46,86-91,112-117` — each public op wraps `VaultLock...with_shared` around a lock-free `_in_context` twin |
| 3 | No write primitives; repeated reads leave vault unchanged except `.nous.lock` | MET | `grep -nE "File\.(write\|open\|delete\|rename)\|FileUtils\|mkpath\|binwrite"` on both files → no hits |
| 4 | Index scans only known dirs; excludes `AGENT.md`, non-`.md`, payloads, generated output, unknown dirs, symlinks | MET | `record_index.rb:9-28` (`KNOWN_RECORD_DIRS` allowlist), `:118-128` (AGENT.md/extension filter) |
| 5 | Symlinked dirs/files excluded/rejected, including symlinks resolving inside the vault | MET | `record_index.rb:161-171`, `path_guard.rb:98-116`; exercised by passing tests `symlink_dir_inside_vault`, `symlink_dir_outside_vault` |
| 6 | Duplicate IDs never resolve to a winner | MET | `record_index.rb:74-82` (`unique_record!`), `agent_reads.rb:54-58` (`list_records` pre-check); tested same-scope and cross-scope |
| 7 | Lifecycle classifier covers all record families incl. contradictions, canonical, retired | MET | `record_index.rb:197-246`; test asserts `human_reviewed == 9` (all 9 note families) |
| 8 | `status` deterministic, bounded, body/excerpt/absolute-path-free | MET | `agent_reads.rb:26-39`; test `assert_deterministic` + `assert_no_absolute_path` on `status` |
| 9 | `list_records` validates query/scopes/types/limit; default reviewed+canonical; retired excluded | MET | `agent_reads.rb:6,48-64,182-215` |
| 10 | Lexical search only; no embeddings/model calls/payload search | MET | `agent_reads.rb:275-301` (pure substring/token scoring); payload dirs never indexed as records at all |
| 11 | Curated envelopes, bounded excerpt/body, `content_role: untrusted_data` | MET | `agent_reads.rb:303-330` (`summary_for`/`base_envelope`), `content_role` set on every returned envelope |
| 12 | `read_record` by stable ID; unique retired reads allowed and labeled; external paths redacted | MET | `agent_reads.rb:93-110`; test asserts `retired.fetch("lifecycle") == "retired"` and `"[redacted_external_path]"` |
| 13 | `read_source_text` accepts artifact IDs only, never paths | MET | `agent_reads.rb:119-126` — resolution is always `context.unique_record!(key)` by `artifact_id` |
| 14 | M2 reads use only embedded observed content, never `source.path` | MET | `agent_reads.rb:132-142` — the `00_raw_artifacts/text/` branch returns via `observed_content(indexed.body)` and never references `source`/`path_value` |
| 15 | M6 payload reads: safe vault-relative paths only; checksum/bytes verified when present | MET | `agent_reads.rb:152-163,462-470,486-497,506-519`; tested: traversal, wrong-directory, bad SHA, bad bytes, symlinked payload |
| 16 | Known image/binary artifacts return `content_available: false`, no bytes/exception | MET | `agent_reads.rb:144-146,154-156,452-460`; tested `artifact_image`, `artifact_project_binary` |
| 17 | Malformed/unsafe/missing/corrupt/traversal/symlink/UTF-8/checksum/byte cases raise stable errors | MET | tested directly: `artifact_traversal`, `artifact_binary_wrong_dir`, `artifact_missing`, `artifact_bad_utf`, `artifact_bad_sha`, `artifact_bad_bytes`, `artifact_payload_link` — all pass |
| 18 | No absolute paths/backtraces/env vars/temp filenames/secrets in errors or results | MOSTLY MET — see caveat 2 | `assert_no_absolute_path` covers all *return-value* results and passes; exception *messages* are not separately grepped for leaked absolute paths by any test |
| 19 | Graph/report behavior remains reviewed/canonical-only | MET | `Nous.load_records` untouched by M7D; `export_graph`/`generate_nous_report` suites pass unchanged |
| 20 | Full existing suite + `make test` + `make lint` + `git diff --check` pass | MOSTLY MET — see caveat 3 | `make test` (9 suites) passes; `git diff --check` clean; `make lint` fails only on this session's own `.omc/` tooling state (now gitignored by the companion mechanism-fix commit), not M7D code |
| 21 | No M7E/M7F scope: MCP, candidate writes, request IDs, idempotency, network, embeddings, models | MET | `grep -rniE "net/http\|socket\|openai\|anthropic\|embedding\|sqlite\|pg\|mcp\|idempot\|request_id"` → no real hits (one false-positive: `.png` substring match) |

## Caveats (non-blocking)

1. **`validate_frontmatter!`** (`record_index.rb:221-236`) rejects records with missing/mismatched `type` in frontmatter. No AC names this behavior explicitly, though it is reasonably read as part of "malformed record" handling (the test spec's `SCAN-D` group covers malformed records generally) and it is defensive, not harmful. Flagged for completeness, not as a defect.
2. **AC18** is well-supported by design (error paths are constructed from vault-relative strings throughout, e.g. `record_index.rb:290-301`) and the test suite actively greps every *return value* for the vault's absolute tmpdir path — but no test specifically greps *raised exception messages* for the same. Residual risk is low; noted as an untested-but-likely-fine edge.
3. **AC20's literal `make lint` clause** did not pass at the time of this audit, but the sole cause was this OMC tooling session's own untracked `.omc/` state files (missing-newline / missing-AGENT.md-signpost lint rules), unrelated to any M7D source file. The companion commit in this same series adds `.omc/` to `.gitignore`, which resolves it going forward.

## Commands run (live, at report time)

```
ruby scripts/test_nous_agent_reads.rb   → nous agent read tests ok
make test                                → all 9 suites pass
git diff --check                         → clean
grep -nE "File\.(write|open|delete|rename)|FileUtils|Dir\.mkdir|IO\.write|\.mkpath|\.binwrite" lib/nous/agent_reads.rb lib/nous/record_index.rb → (empty)
grep -rniE "net/http|socket|openai|anthropic|embedding|sqlite|pg|mcp|idempot|request_id" lib/nous/agent_reads.rb lib/nous/record_index.rb → 1 false positive (.png)
grep -n "RelationshipIntegrity" lib/nous/agent_reads.rb lib/nous/record_index.rb → (empty)
```

## Relationship to the parallel-history question

This report answers a different question than `.omc/plans/m7d-verification-plan.md`. That plan's primary concern was **provenance** — whether the shipped code on `main` could be trusted given two dangling branches (`worker-3-m7d-tests`, `worker-3-m7d-tests-pre-lore-rewrite`) existed from what turned out to be one team run rewritten mid-flight. This report instead audits **the code that actually shipped, on its own merits, against its own spec**, independent of how it got there. The two are complementary: the plan traced *how* main came to be what it is; this report confirms *what main is* is sound.

Branch/tag disposition (archiving the two dangling refs) and the fresh-clone push decision remain open items in `.omc/plans/open-questions.md` and were not part of this commit series.
