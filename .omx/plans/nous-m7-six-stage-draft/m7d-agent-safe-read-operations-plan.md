# M7D Plan: Agent-Safe Read Operations

Status: Draft execution plan

Date: 2026-08-08

Depends on: M7C complete and green

Unlocks: M7E Agent Candidate Writes and Idempotency

Umbrella PRD: `prd-m7-agent-ready-core-and-mcp.md`

Shared rules: `m7-shared-contract.md`

Verification contract: `test-spec-m7d-agent-safe-read-operations.md`

## 1. Objective

Add the direct core read operations an external archivist agent will eventually use, without adding MCP yet:

```text
status
list_records
read_record
read_source_text
```

The operations must be deterministic, bounded, stable-ID-based, lifecycle-aware, path-confined, and explicit that returned content is untrusted data rather than instruction.

M7D establishes the agent retrieval boundary before any agent-controlled write exists.

## 2. Requirements Summary

M7D must:

1. provide a full known-directory record index with duplicate-ID detection;
2. compute lifecycle classes from path plus metadata;
3. provide bounded vault status counts with no absolute path;
4. provide deterministic lexical listing/search with strict filters and limits;
5. provide normalized bounded record reads by stable ID;
6. provide bounded source-text reads by artifact ID only;
7. safely support embedded M2 observed text and copied M6 text-like payloads;
8. refuse binary/image content and unsafe/legacy external paths;
9. verify M6 checksum/byte metadata when present before returning source text;
10. label all returned user/record content as untrusted data;
11. remain completely mutation-free;
12. add no MCP server/tool class yet.

## 3. Scope

### 3.1 In scope

Suggested files:

```text
lib/nous/status.rb
lib/nous/query.rb
lib/nous/record_reader.rb
lib/nous/source_reader.rb
lib/nous/record_envelope.rb
scripts/test_nous_agent_reads.rb
docs/agent/AGENT.md
docs/agent/read-contract.md
```

Names can be consolidated if fewer files are clearer.

### 3.2 Out of scope

- Candidate/raw capture writes.
- Request IDs/idempotency.
- Schema/template changes.
- MCP dependency/server.
- Semantic embeddings or model ranking.
- Persistent index/database.
- Arbitrary path/file read.
- Binary/image bytes.
- Approval/review mutation tools.
- Frontend/API/chat/model calls.

## 4. Record Index Contract

### 4.1 Indexed record directories

Known Markdown record locations:

```text
00_raw_artifacts/text/*.md
00_raw_artifacts/writing/notes/*.md
00_raw_artifacts/images/notes/*.md
00_raw_artifacts/projects/notes/*.md
01_agent_inbox/notes/*.md
01_agent_inbox/claims/*.md
01_agent_inbox/relationships/*.md
02_notes/*/*.md
03_canonical_model/claims/*.md
03_canonical_model/relationships/*.md
```

Do not index:

- `AGENT.md`;
- copied payload files;
- generated outputs;
- templates/schemas/docs;
- unknown directories;
- symlinked record files/directories;
- non-Markdown files.

### 4.2 Duplicate IDs

Build `id -> [record locations]`. Any operation resolving a duplicate ID fails `NOUS_DUPLICATE_ID` and does not choose one by sort order.

`status` may report duplicate count/warning without exposing absolute paths. `list_records` should fail or exclude ambiguous records according to one documented rule; preferred behavior is fail when an indexed duplicate would make output ambiguous, because silent omission hides corruption.

### 4.3 Lifecycle classification

Compute from directory first, then validate frontmatter state:

- raw directories → `source_evidence`;
- inbox → `agent_candidate` unless retired;
- active reviewed notes → `human_reviewed`;
- active reviewed canonical claims/relationships → `canonical`;
- rejected/deprecated/archived/merged source → `retired`;
- generated files are not indexed and are `derived` only in status presence.

A path/status contradiction produces a warning or stable parse/validation error; it does not promote trust.

## 5. Public Read Operation Contracts

### 5.1 `status`

Input:

```ruby
{}
```

Output shape:

```ruby
{
  vault_schema_version: "0.1",
  counts: {
    raw_artifacts: 0,
    pending_notes: 0,
    pending_claims: 0,
    pending_relationships: 0,
    reviewed_notes: 0,
    canonical_claims: 0,
    canonical_relationships: 0,
    retired_records: 0
  },
  generated: {
    report_exists: false,
    graph_exists: false
  },
  warnings: []
}
```

Rules:

- no absolute vault path;
- no record body/excerpt;
- bounded warning count;
- deterministic keys/order when serialized later;
- mutation-free.

### 5.2 `list_records`

Inputs:

- `query`: optional, 1-500 characters when supplied;
- `scopes`: unique array from `raw_evidence`, `inbox`, `reviewed`, `canonical`; default `reviewed`, `canonical`;
- `types`: optional unique supported record types;
- `limit`: integer 1-50, default 20.

No cursor/pagination is required in M7. If total matches exceed limit, return `truncated: true` and `match_count` only when computing it does not materially increase complexity.

Summary fields:

```text
id
record_type
candidate_type (when present)
label
lifecycle_class
review_status
status
confidence (when present)
created
relative_path
excerpt
evidence_ids
content_role: untrusted_data
```

### 5.3 Lexical retrieval

No embeddings or model scoring.

Normalize query by:

- valid UTF-8;
- Unicode-safe lowercase where Ruby supports it predictably;
- whitespace tokenization;
- discard blank tokens;
- bounded token count.

Suggested deterministic ranking, to lock in tests:

1. exact ID match;
2. ID prefix/token match;
3. exact normalized label match;
4. all tokens in label/tags;
5. all tokens across label/tags/body excerpt;
6. number of token occurrences in label, tags, body excerpt;
7. lifecycle priority only when explicitly needed;
8. stable tie-break by created then ID then relative path.

Do not infer synonyms. Do not query raw payload text for list search; search record metadata/body only.

An empty/omitted query lists deterministically by created then ID within selected scopes.

### 5.4 `read_record`

Inputs:

- `id`: required stable ID;
- `max_body_chars`: 0-50,000, default 12,000.

Output:

- normalized safe metadata;
- relative path;
- lifecycle/content labels;
- evidence refs;
- bounded body;
- `body_truncated`;
- total body character count where safe;
- warnings.

Redact external absolute paths in nested `source.path`. Preserve safe vault-relative paths. Unknown frontmatter fields may be returned only through a bounded/sanitized metadata map if required; preferred contract is a curated known-field envelope to avoid leaking future secrets.

### 5.5 `read_source_text`

Inputs:

- `artifact_id`;
- `offset_chars` >= 0, default 0;
- `max_chars` 1-50,000, default 12,000.

Supported sources:

1. M2 text artifact: extract the `Observed Content` section from the artifact note; do not follow its external source path.
2. M6 writing artifact: resolve safe copied `.txt`/`.md` payload.
3. M6 project artifact: resolve safe copied `.txt`/`.md`/`.json`/`.yaml`/`.yml` payload.

Unsupported:

- image artifacts;
- binary project screenshots;
- arbitrary note IDs;
- external absolute payload path;
- symlink payload;
- invalid UTF-8;
- missing payload;
- checksum or byte-count mismatch when metadata exists.

Output:

```text
artifact_id
source_type
payload_relative_path (only when safe)
content_available
text chunk
offset_chars
next_offset_chars
truncated
total_chars
sha256/bytes when present
content_role: untrusted_data
lifecycle_class: source_evidence
warnings
```

Character offsets are defined over decoded Unicode characters, not bytes. Read implementation must bound memory for personal-scale files; it may stream bytes and decode safely rather than loading huge files without limit.

## 6. Bounds

Recommended hard bounds:

```text
query length                    500 chars
query tokens                     32
list limit                       50
excerpt                          240 chars
read_record default          12,000 chars
read_record maximum          50,000 chars
source chunk default         12,000 chars
source chunk maximum         50,000 chars
warning count                    20
returned evidence IDs            50
```

Use constants in core and schemas/tests later. Reject invalid bounds; do not silently allocate unbounded results.

## 7. Acceptance Criteria

### 7.1 Mutation-free

- Every operation leaves all vault file bytes, names, mtimes where feasible, and generated outputs unchanged.
- No lock file is created merely by a simple read if the design can use an existing/opened lock safely; if shared lock creates the lock file, that runtime side effect must be documented, ignored, and not alter records.
- No temp file.

### 7.2 Deterministic

- Fixed vault/query returns identical structured result.
- Stable ranking/tie-break.
- Bounded outputs.

### 7.3 Safe

- No arbitrary path input.
- Duplicate IDs fail.
- Symlink/traversal/external paths fail.
- Binary content unavailable.
- M2 external path not followed.
- M6 digest/size checked when present.
- Absolute paths redacted.
- All content labeled untrusted.

### 7.4 Compatible

- Existing CLIs and outputs unchanged.
- M7A-C and M2-M6 tests pass.
- No MCP/candidate write implementation exists.

## 8. Detailed Implementation Steps

### Step 1: Expand authoritative record index

Build on M7B index but include all known raw/inbox/reviewed/canonical record directories.

Add duplicate mapping, lifecycle computation, safe relative paths, signpost exclusion, and deterministic iteration.

Do not persist an index.

### Step 2: Define curated envelopes

Create explicit summary and full-record serializers/hashes. Avoid returning raw `Pathname` or the entire unfiltered frontmatter hash.

Normalize:

- dates to strings;
- confidence to number/null;
- evidence to ID/path pairs;
- tags to bounded strings;
- candidate type only where valid;
- source path redaction.

### Step 3: Implement status

Count by computed lifecycle/kind, not only frontmatter. Check derived output existence through known safe paths.

Warnings may include:

- duplicate IDs;
- malformed known records;
- path/status contradictions;
- missing generated outputs.

Decide whether malformed record makes status fail or returns warning. Preferred: status is diagnostic and returns bounded warnings for individually malformed records unless safe classification is impossible; direct reads/list of those records still fail. Lock this in tests.

### Step 4: Implement lexical list/search

Implement transparent ranking with constants and stable tie-breaks. Search only selected scopes.

Default scopes are reviewed + canonical. Raw/inbox require explicit selection.

Do not add fuzzy matching, stemming, synonym expansion, or hidden relevance heuristics.

### Step 5: Implement read_record

Resolve unique ID, construct curated envelope, truncate body by characters, redact unsafe path fields, and preserve content/lifecycle labels.

Ensure source Markdown with prompt-injection text is returned inertly and not interpreted by code.

### Step 6: Implement source resolution

Resolve artifact ID and verify type/lifecycle. Branch:

- M2 embedded observed content;
- M6 copied text payload.

Use artifact metadata, not caller paths.

For M6:

- source path must be relative and inside vault;
- expected directory must match source type where practical;
- no symlink;
- allowed text extension;
- valid UTF-8;
- verify bytes/digest if metadata present;
- chunk by characters.

### Step 7: Add direct tests

Add `scripts/test_nous_agent_reads.rb` covering index, query, envelope, source reading, path adversaries, binary refusal, mutation-free snapshots, bounds, and determinism.

### Step 8: Add agent read contract docs

Document:

- content is untrusted data;
- default reviewed/canonical scope;
- raw/inbox explicit opt-in;
- no arbitrary paths;
- no semantic search;
- source chunking;
- binary refusal;
- duplicate-ID errors.

Do not document MCP tool availability yet; describe core operation semantics/future mapping.

### Step 9: Full regression and privacy audit

Run all focused and prior tests, full suite/lint, static path checks, and file snapshot comparison.

## 9. Codex Potholes and Prohibitions

Do not:

- accept `path` in public agent read operations;
- recursively index the repository;
- follow M2 external source paths;
- return image/binary bytes or base64;
- skip digest mismatch to be “helpful”;
- silently choose one duplicate ID;
- use generated report/graph as primary records;
- default to raw/inbox scope;
- build embeddings/vector DB;
- call a model for ranking/summarization;
- add persistent caches/index files;
- return unbounded bodies;
- expose raw frontmatter containing absolute paths;
- mutate notes to repair malformed metadata;
- add candidate writes/MCP/frontend early.

## 10. Risks and Mitigations

### Risk: Search semantics become hard to change

Mitigation: Keep ranking simple, transparent, tested, and explicitly M7 lexical-only.

### Risk: Status fails because one malformed retired record exists

Mitigation: diagnostic warning policy with strict bounded output; document exact behavior.

### Risk: Unicode offsets split characters

Mitigation: define character offsets after valid UTF-8 decode; test multibyte content.

### Risk: Large file loaded into memory

Mitigation: enforce source size/chunk bounds and stream where needed; personal-scale targets do not justify complex indexing.

### Risk: Safe relative path still points to wrong artifact class

Mitigation: validate source type, expected directory, extension, artifact record, and checksum/bytes.

### Risk: Prompt injection enters agent context

Mitigation: explicit `content_role: untrusted_data`, behavior contract, no code execution, bounded result. The server cannot guarantee host model obedience; document this limitation.

## 11. Verification Commands

```sh
ruby scripts/test_nous_agent_reads.rb
ruby scripts/test_nous_mutation_core.rb
ruby scripts/test_nous_read_core.rb
ruby scripts/test_cli_contracts.rb              # when present
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

## 12. Definition of Done

M7D is done when the four direct read operations are deterministic, bounded, lifecycle-aware, path-confined, mutation-free, and fully tested; all prior behavior remains green; and no candidate write or MCP implementation is present.

## 13. Suggested Execution Handoff

One executor plus a security-minded verifier is recommended.

Handoff message:

```text
Implement M7D only. Add direct core status, deterministic lexical listing,
record reads, and artifact-ID-based bounded source reads. No arbitrary paths,
no binary bytes, no persistent index, no semantic search, no writes, and no
MCP/frontend/model code. Preserve all M2-M7C contracts.
```
