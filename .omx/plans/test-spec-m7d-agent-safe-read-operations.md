# Test Specification: M7D Agent-Safe Read Operations

Status: Final test specification for Ralph planning gate

Plan: `.omx/plans/m7d-agent-safe-read-operations-plan.md`

PRD: `.omx/plans/prd-m7d-agent-safe-read-operations.md`

## Required Focused Test

Add:

```sh
ruby scripts/test_nous_agent_reads.rb
```

Use synthetic temporary vaults only. Do not mutate repository vault content.

## Fixture Matrix

Create synthetic fixtures for:

- empty vault;
- M2 text artifact with embedded `Observed Content` and external-looking `source.path`;
- M6 writing artifact with copied `.md` payload;
- M6 writing artifact with copied `.txt` payload;
- M6 project artifact with copied `.json` payload;
- M6 project artifact with copied `.yaml`/`.yml` payload;
- M6 image artifact with copied image/binary payload;
- M6 binary project screenshot;
- inbox note;
- inbox claim;
- inbox relationship;
- reviewed memories, values, beliefs, projects, patterns, decisions, people, questions, and contradictions;
- canonical claim;
- canonical relationship;
- archived, rejected, deprecated, and merged retired records;
- generated report/graph presence;
- duplicate IDs across same and different scopes;
- malformed frontmatter/body records;
- unknown directory record-like files;
- copied payload Markdown under `files/`;
- symlinked known directory;
- symlinked record file;
- symlink resolving inside the vault;
- symlink resolving outside the vault;
- adversarial prompt/path/secret-shaped strings.

## Test Groups

### READONLY-D

- `READONLY-D-001`: `status` leaves file names, bytes, and stable mtimes unchanged, except documented `.nous.lock`.
- `READONLY-D-002`: `list_records` is mutation-free.
- `READONLY-D-003`: `read_record` is mutation-free.
- `READONLY-D-004`: `read_source_text` is mutation-free.
- `READONLY-D-005`: failed reads do not repair metadata or create output.
- `READONLY-D-006`: repeated reads return identical structured results and no accumulated runtime files beyond `.nous.lock`.

### INDEX-D

- `INDEX-D-001`: all and only known record locations are indexed.
- `INDEX-D-002`: `AGENT.md` files are ignored.
- `INDEX-D-003`: copied payloads under `files/` are not records.
- `INDEX-D-004`: generated outputs are presence indicators, not records.
- `INDEX-D-005`: unknown directories are excluded or diagnosed according to tolerant/strict mode.
- `INDEX-D-006`: symlinked known directories are excluded in tolerant scan and rejected in strict scan, even when resolving inside the vault.
- `INDEX-D-007`: symlinked record files are excluded/rejected, including inside-vault and outside-vault targets.
- `INDEX-D-008`: duplicate reviewed IDs fail strict resolution.
- `INDEX-D-009`: duplicate IDs across raw/inbox/reviewed/canonical fail strict selected operations.
- `INDEX-D-010`: frontmatter-reviewed inbox records remain `agent_candidate`.
- `INDEX-D-011`: archived/rejected/deprecated/merged records classify as `retired`.
- `INDEX-D-012`: inbox claim and inbox relationship classify as `agent_candidate` with correct kind.
- `INDEX-D-013`: canonical relationship classifies as `canonical` with kind `relationship`.
- `INDEX-D-014`: reviewed contradiction classifies as `human_reviewed` with type `contradiction`.

### SCAN-D

- `SCAN-D-001`: tolerant scan returns records plus bounded diagnostics for malformed records.
- `SCAN-D-002`: strict scan raises stable sanitized errors for malformed selected records.
- `SCAN-D-003`: tolerant scan reports duplicate groups without absolute paths.
- `SCAN-D-004`: strict selected scan raises `NOUS_DUPLICATE_ID`.
- `SCAN-D-005`: tolerant scan diagnostics are capped.

### STATUS-D

- `STATUS-D-001`: empty vault returns zero counts and generated presence false.
- `STATUS-D-002`: complete fixture returns exact counts.
- `STATUS-D-003`: generated presence checks known paths only.
- `STATUS-D-004`: recursive result string scan finds no absolute paths.
- `STATUS-D-005`: malformed record produces bounded warning when safe.
- `STATUS-D-006`: duplicate IDs produce bounded diagnostic.
- `STATUS-D-007`: repeated calls are deterministic.

### QUERY-D

- `QUERY-D-001`: default scopes include reviewed + canonical only.
- `QUERY-D-002`: explicit raw scope includes raw artifact summaries.
- `QUERY-D-003`: explicit inbox scope includes pending candidates.
- `QUERY-D-004`: duplicate scope input is rejected.
- `QUERY-D-005`: unsupported type is rejected.
- `QUERY-D-006`: empty query ordering is deterministic.
- `QUERY-D-007`: exact ID ranks first.
- `QUERY-D-008`: exact label ranks ahead of body-only match.
- `QUERY-D-009`: tag and evidence-ID matches are deterministic.
- `QUERY-D-010`: multi-token behavior is documented and tested.
- `QUERY-D-011`: query length 500 valid, 501 invalid.
- `QUERY-D-012`: token bound is enforced.
- `QUERY-D-013`: limit 1 and 50 valid, 0/51 invalid.
- `QUERY-D-014`: excerpts are capped at 240 chars.
- `QUERY-D-015`: evidence IDs are bounded with truncation signal.
- `QUERY-D-016`: prompt injection text is returned as `untrusted_data`.
- `QUERY-D-017`: absent synonym does not match by semantic inference.
- `QUERY-D-018`: copied payload-only text is not list-searched.
- `QUERY-D-019`: result strings expose no absolute paths.

### RECORD-D

- `RECORD-D-001`: reviewed note envelope has required curated fields.
- `RECORD-D-002`: candidate note envelope has candidate lifecycle.
- `RECORD-D-003`: raw artifact envelope has source-evidence lifecycle.
- `RECORD-D-004`: canonical claim envelope has canonical lifecycle.
- `RECORD-D-005`: canonical relationship envelope is safe and kinded.
- `RECORD-D-006`: retired unique record is readable and labeled `retired`.
- `RECORD-D-007`: unknown ID raises `NOUS_RECORD_NOT_FOUND`.
- `RECORD-D-008`: duplicate ID raises `NOUS_DUPLICATE_ID`.
- `RECORD-D-009`: default body cap is 12,000 chars.
- `RECORD-D-010`: max body cap 50,000 valid, larger invalid.
- `RECORD-D-011`: zero body limit returns metadata only.
- `RECORD-D-012`: multibyte truncation is character-safe.
- `RECORD-D-013`: external source path is redacted.
- `RECORD-D-014`: safe relative source path is preserved.
- `RECORD-D-015`: unknown secret-shaped frontmatter is omitted.
- `RECORD-D-016`: every body result has `content_role: untrusted_data`.

### SOURCE-D

- `SOURCE-D-001`: M2 embedded observed content returns text.
- `SOURCE-D-002`: M2 external `source.path` is never followed, even if readable.
- `SOURCE-D-003`: M6 writing Markdown returns safe chunk and metadata.
- `SOURCE-D-004`: M6 writing text returns safe chunk and metadata.
- `SOURCE-D-005`: M6 project JSON returns text.
- `SOURCE-D-006`: M6 project YAML returns text without parsing/executing aliases.
- `SOURCE-D-007`: image artifact returns `content_available: false`, `content_unavailable_reason`, no `text`, no bytes/base64/interpretation, and no raised exception.
- `SOURCE-D-008`: binary project screenshot returns `content_available: false`, `content_unavailable_reason`, no `text`, no bytes/base64/interpretation, and no raised exception.
- `SOURCE-D-009`: optional focused assertion distinguishes known unavailable artifacts from corrupt/unsafe errors by asserting image/binary returns a result while checksum mismatch raises.
- `SOURCE-D-010`: non-artifact ID raises stable invalid/unsupported source error.
- `SOURCE-D-011`: missing payload raises stable sanitized error.
- `SOURCE-D-012`: traversal payload path raises stable sanitized error.
- `SOURCE-D-013`: symlink payload raises `NOUS_SYMLINK_REJECTED`.
- `SOURCE-D-014`: invalid UTF-8 raises stable error.
- `SOURCE-D-015`: SHA mismatch raises stable error.
- `SOURCE-D-016`: byte-count mismatch raises stable error.
- `SOURCE-D-017`: missing audit metadata on safe legacy text payload returns text with bounded warning.
- `SOURCE-D-018`: offset zero returns first chunk.
- `SOURCE-D-019`: middle offset returns correct character slice and next offset.
- `SOURCE-D-020`: offset at end returns empty chunk with `truncated: false`.
- `SOURCE-D-021`: offset past end raises `NOUS_INVALID_INPUT`.
- `SOURCE-D-022`: `max_chars` 50,000 valid, 50,001 invalid.
- `SOURCE-D-023`: multibyte offsets are character-aligned.
- `SOURCE-D-024`: large text smoke returns bounded result.
- `SOURCE-D-025`: prompt injection source content is returned inertly with `untrusted_data`.
- `SOURCE-D-026`: output exposes only safe vault-relative payload path.

### STATIC-D

- `STATIC-D-001`: new read modules do not call write primitives.
- `STATIC-D-002`: no public read operation accepts arbitrary path input.
- `STATIC-D-003`: no network/model/embedding/database dependency.
- `STATIC-D-004`: no MCP server/tool/dependency files.
- `STATIC-D-005`: no request ID/idempotency/candidate write scope.
- `STATIC-D-006`: no fixture/private content committed to repository vault.

## Verification Order

```sh
ruby scripts/test_nous_agent_reads.rb
ruby scripts/test_nous_read_core.rb
ruby scripts/test_nous_mutation_core.rb
ruby scripts/test_cli_contracts.rb
ruby scripts/test_ingest_text.rb
ruby scripts/test_ingest_artifact.rb
ruby scripts/test_review_queue.rb
ruby scripts/test_export_graph.rb
ruby scripts/test_generate_nous_report.rb
make test
make lint
git diff --check
git status --short
```

## Pass Conditions

- All focused M7D tests pass.
- All prior M2-M7C tests pass.
- Full suite and lint pass.
- Snapshot tests prove mutation-free behavior.
- Source-unavailable and source-error cases are distinguished.
- Path/symlink/traversal/privacy adversaries are blocked.
- Results are bounded, deterministic, sanitized, and `untrusted_data` labeled.
- No M7E/M7F scope is present.
