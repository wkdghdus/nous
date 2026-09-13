# M7E Plan: Agent Candidate Writes and Idempotency

Status: Draft execution plan

Date: 2026-08-08

Depends on: M7D complete and green

Unlocks: M7F MCP Adapter and Release Gate

Umbrella PRD: `prd-m7-agent-ready-core-and-mcp.md`

Shared rules: `m7-shared-contract.md`

Verification contract: `test-spec-m7e-agent-candidate-writes-and-idempotency.md`

## 1. Objective

Add the direct core operations that let a future external archivist agent preserve verbatim user text and create source-backed candidate notes, claims, and relationships—without adding MCP yet and without allowing the agent to approve itself.

The four operations are:

```text
capture_user_text
propose_note
propose_claim
propose_relationship
```

Every operation is server-rendered, path-confined, lock-protected, atomic, provenance-preserving, and idempotent.

## 2. Requirements Summary

M7E must:

1. add an artifact-only user-text capture operation;
2. add generic inbox note proposals with validated candidate type;
3. add inbox claim proposals;
4. add inbox relationship proposals;
5. enforce evidence eligibility and endpoint validity by stable ID;
6. keep facts, user context, hypotheses, boundaries, and rationale visibly separated;
7. allocate all IDs/paths/filenames on the server side;
8. render YAML and Markdown on the server side;
9. add additive optional candidate/generation/source metadata without migrating existing records;
10. enforce required request IDs, canonical input digests, replay, and conflict behavior;
11. perform idempotency lookup and write under the shared vault lock;
12. recover safely when a process finalized a record but failed before replying;
13. keep pending candidates out of graph/report;
14. preserve human review as the only route to reviewed/canonical state;
15. add no MCP dependency/server yet.

## 3. Scope

### 3.1 In scope

Suggested files:

```text
lib/nous/idempotency.rb
lib/nous/generation_metadata.rb
lib/nous/candidate_validation.rb
lib/nous/candidate_renderer.rb
lib/nous/user_text_capture.rb
lib/nous/note_proposal.rb
lib/nous/claim_proposal.rb
lib/nous/relationship_proposal.rb
scripts/test_nous_candidate_writes.rb
docs/agent/archivist-contract.md
```

Schema/template changes:

```text
schemas/note-frontmatter.schema.yaml
templates/obsidian/note.md
templates/obsidian/claim.md
templates/obsidian/relationship.md
```

Only change templates when necessary to document fields/sections already rendered. Existing records/templates remain valid.

Review display may be updated to show candidate type, generation operation, basis/interpretation, and request ID safely. Do not expose hidden prompts or model chain of thought.

### 3.2 Out of scope

- MCP gem/server/tool classes.
- Approval/reject/deprecate/merge agent operations.
- Direct reviewed/canonical writes.
- Agent import/read of arbitrary local paths.
- Built-in model call or agent loop.
- Automatic proposal generation from all artifacts.
- Semantic search/embeddings/database.
- Identity candidate type until review routing is separately defined.
- Frontend/API/chat/voice/OCR/image interpretation.

## 4. Shared Mutation Contract

All four operations:

- receive an explicit vault root and UTC generation time;
- require a valid `request_id`;
- acquire the M7C exclusive lock once;
- check idempotency inside the lock;
- resolve evidence/endpoints through the M7D record index;
- validate before staging;
- allocate destination and ID under the lock;
- render through `Psych` and fixed Markdown templates;
- stage and atomically finalize;
- return a structured safe result;
- never print;
- never accept output path, filename, frontmatter, full Markdown, or stable ID.

## 5. Request ID and Idempotency

### 5.1 Request ID

Required pattern:

```text
[A-Za-z0-9._:-]{1,128}
```

Reject:

- whitespace;
- slash/backslash;
- newline/control characters;
- non-ASCII confusables;
- empty/overlong values.

Request ID is metadata only. It never becomes a filename, note title, ID slug, path, or Markdown body.

### 5.2 Canonical digest

Compute SHA-256 over deterministic JSON containing:

- operation name;
- normalized validated input excluding request ID and generated time;
- ordered arrays in caller-supplied order after duplicate rejection;
- normalized dates/numbers/booleans/strings;
- no filesystem path derived after validation.

Object keys are sorted deterministically. Array order is semantically meaningful because evidence/body order is preserved; changing order creates a different digest/conflict.

Do not normalize away user wording, punctuation, or case.

### 5.3 Lookup scope

Search generation metadata across all known raw/inbox/reviewed/canonical/retired record locations. A candidate may have moved after human review; retry must still find it.

Duplicate request IDs in existing metadata are corruption and fail clearly; never select one.

### 5.4 Replay

When request ID, operation, and digest match:

- create no file;
- return the existing record ID/current relative path/current lifecycle;
- set `replayed: true`;
- report whether review is currently required based on current lifecycle;
- do not rewrite `generated_at`.

### 5.5 Conflict

Same request ID with different operation or digest:

- fail `NOUS_IDEMPOTENCY_CONFLICT`;
- preserve existing record;
- create nothing.

### 5.6 Crash recovery

Because generation metadata lives in the finalized record, retry after finalize-before-response finds and replays it. No separate idempotency database/index is introduced.

## 6. Optional Additive Metadata

Add optional schema fields:

```yaml
candidate_type: pattern

basis: agent_inferred

generation:
  interface: mcp
  operation: nous_propose_note
  request_id: capture-2026-08-08-001-note-1
  input_sha256: <64 lowercase hex>
  generated_at: "2026-08-08T12:00:00Z"

source:
  authorship: user
  capture_channel: mcp
```

Rules:

- `candidate_type` valid only when persisted `type: note` in inbox.
- Candidate type values match current note review routing:
  - memory;
  - value;
  - belief;
  - project;
  - pattern;
  - decision;
  - person;
  - question;
  - contradiction.
- `identity` is rejected in M7E.
- `basis` is one of `user_asserted`, `extractive`, `agent_inferred`.
- `generation.operation` is one of the four final MCP operation names.
- `input_sha256` is server-calculated lowercase hex.
- Existing records without these fields remain valid.
- No model name, prompt, hidden reasoning, credential, or conversation transcript is persisted.

For `capture_user_text`, keep existing compatible source fields and add:

```yaml
source:
  type: text
  path: 00_raw_artifacts/text/<artifact-file>.md
  extraction_method: manual
  authorship: user
  capture_channel: mcp
```

The source path self-identifies the artifact note because no external source file exists. Do not change current CLI `ingest_text` behavior.

## 7. Operation Contract: `capture_user_text`

Inputs:

```text
request_id                 required
confirmed_user_authored    required true
user_text                  required valid UTF-8, nonblank, <= 1 MiB
title                      optional, <= 120 chars
user_context               optional, <= 2,000 chars
represented_date           optional ISO date
```

Behavior:

- creates exactly one raw text artifact note;
- writes under `00_raw_artifacts/text/` using current date/slug conventions;
- persists verbatim `user_text` under `## Observed Content`;
- keeps `user_context` under `## User-Provided Context`;
- creates no generic inbox note;
- uses `interpretation_level: none`;
- creates no claim/relationship;
- records generation metadata;
- does not follow or persist external path;
- result says `interpretation_created: false`.

Title rules:

- optional title controls label/slug only after normalization;
- blank title falls back to a safe fixed slug such as `reflection` or first bounded line according to documented deterministic rule;
- newlines collapse to spaces;
- path separators/control characters cannot control filename;
- request ID is never used as title/slug.

Result includes:

```text
record_id
record_type: artifact
relative_path
lifecycle_class: source_evidence
input_sha256
replayed
requires_review
interpretation_created: false
```

## 8. Operation Contract: `propose_note`

Inputs:

```text
request_id
candidate_type
title
basis
primary_evidence_id
evidence_ids              1-20 unique
counterevidence_ids       0-20 unique
source_backed_facts       1-10 strings, each <= 500 chars
user_context              0-5 strings, each <= 1,000 chars
tentative_hypotheses      0-5 strings, each <= 500 chars
confidence                0..1
tags                      0-20 normalized tags
```

Validation:

- title nonblank <= 120 chars;
- primary evidence appears in `evidence_ids`;
- evidence/counterevidence unique;
- evidence and counterevidence sets do not overlap;
- every evidence ID resolves uniquely and is eligible;
- pending candidates are not eligible evidence;
- at least one fact;
- `agent_inferred` basis requires at least one tentative hypothesis and uses `interpretation_level: medium`;
- `user_asserted`/`extractive` use `interpretation_level: low`;
- user-context statements are not reclassified as source-backed facts.

Persistence:

```yaml
type: note
candidate_type: <validated type>
status: draft
review_status: agent_generated
```

Destination:

```text
01_agent_inbox/notes/note_<date>_<slug>[-N].md
```

Body has fixed sections:

```markdown
# <safe title>

## Source-Backed Facts

- ...

## User Context

- ...

## Tentative Hypotheses

- ...

## Relationships

## Review Notes
```

Renderer rules:

- server owns headings and list markers;
- title is single-line escaped text;
- each list entry is rendered as one safe logical item with continuation indentation;
- a supplied string cannot create frontmatter or a sibling top-level section;
- NUL/invalid control characters rejected;
- preserve wording except required line-ending/control/section-safety normalization.

Result includes candidate type, evidence IDs, lifecycle, replay, and `requires_review: true` unless replay finds an already reviewed record.

## 9. Operation Contract: `propose_claim`

Inputs:

```text
request_id
title
statement                  nonblank <= 1,000 chars
basis
primary_evidence_id
evidence_ids               1-20 unique
counterevidence_ids        0-20 unique
boundaries                 0-10 strings, each <= 500 chars
confidence                 0..1
tags                       0-20
```

Rules:

- evidence eligibility same as notes;
- statement and boundaries stay separate;
- agent-inferred basis sets medium interpretation;
- no empty evidence;
- no pending candidate evidence;
- claim remains inbox/draft/agent-generated.

Destination:

```text
01_agent_inbox/claims/claim_<date>_<slug>[-N].md
```

Fixed body sections:

```text
Statement
Evidence
Counterevidence
Boundaries
Review Decision
```

The server renders evidence references from resolved IDs/paths. The agent does not supply paths.

## 10. Operation Contract: `propose_relationship`

Inputs:

```text
request_id
from_id
to_id
relationship_type
statement                  nonblank <= 1,000 chars
basis
primary_evidence_id
evidence_ids               1-20 unique
counterevidence_ids        0-20 unique
confidence                 0..1
confidence_rationale       optional <= 1,000 chars
tags                       0-20
```

Endpoint rules:

- `from_id != to_id`;
- each ID resolves uniquely;
- allowed endpoint record kinds: inbox note/claim candidate, active reviewed note, active canonical claim;
- disallowed: artifact, relationship, derived, retired, missing, duplicate;
- relationship type matches current enum;
- evidence independently satisfies evidence eligibility and is not inferred from endpoints;
- pending endpoints are permitted for proposal but reported `approval_ready: false`;
- candidate remains inbox until human review;
- M7C approval gate blocks move until both endpoints are exportable.

Destination:

```text
01_agent_inbox/relationships/edge_<date>_<slug>[-N].md
```

Result includes:

- relationship ID/path/type;
- endpoint IDs and lifecycle classes;
- `approval_ready` per endpoint and overall;
- evidence IDs;
- replay/lifecycle/review requirement.

## 11. Evidence Resolution

Eligible:

- raw artifact record;
- active reviewed note;
- active canonical claim.

Ineligible:

- inbox candidate of any kind;
- relationship record;
- generated output;
- retired record;
- copied payload without artifact record;
- unknown/duplicate ID.

Evidence refs persisted as:

```yaml
evidence:
  - id: <resolved id>
    path: <server-generated vault-relative path>
```

Primary evidence determines `source.path` and `source.type` according to a documented rule; preferred:

```yaml
source:
  type: note
  path: <primary evidence record path>
  extraction_method: archivist_agent
```

For raw artifact primary evidence, `source.type` may retain the artifact source class if current schema supports it, but behavior must be deterministic and tested. Do not invent external paths.

## 12. Review Integration

- `review_queue list/show/report` displays candidate type and useful generation metadata without body leakage in list output.
- Note approval may default `--as` from `candidate_type` only if the user explicitly opts into that product change. M7E default remains current explicit `--as TYPE`; candidate type is a suggestion, not authority.
- Claim approval works through existing workflow.
- Relationship approval observes M7C endpoint gate.
- Rejection/deprecation/merge retain generation metadata.
- Approved/moved record retains request ID/digest so retries replay rather than duplicate.

## 13. Acceptance Criteria

### 13.1 Safety

- Agent controls no path/ID/frontmatter/status.
- All writes remain raw/inbox only.
- Every proposal has eligible evidence and review requirement.
- No frontmatter/section injection.
- No image interpretation or arbitrary file read.

### 13.2 Idempotency

- Same request/operation/input replays one record.
- Changed input/order conflicts.
- Cross-operation request reuse conflicts.
- Concurrent identical calls produce one record.
- Finalize-before-response retry replays.
- Approved/moved record is still found.

### 13.3 Lifecycle

- Pending candidates absent from graph/report.
- Existing review can approve/reject/deprecate/merge them.
- Relationship review ordering remains enforced.

### 13.4 Compatibility

- Current M2/M6 CLIs unchanged.
- Existing records need no migration.
- All M7A-D and M2-M6 tests pass.
- No MCP dependency/server exists.

## 14. Detailed Implementation Sequence

### Phase E0: Lock schemas and constants in tests

Before implementation, encode:

- request pattern/bounds;
- candidate type enum;
- basis enum;
- array/string bounds;
- relationship enum;
- evidence eligibility matrix;
- result shapes;
- generation metadata shape.

Do not write MCP JSON Schemas yet; these are core validation constants that M7F maps directly.

### Phase E1: Add additive schema fields

Update frontmatter schema with optional `candidate_type`, `basis`, `generation`, `source.authorship`, and `source.capture_channel`.

Validate existing fixture records remain valid.

Do not increment schema version or rewrite records unless product owner explicitly approves a migration.

### Phase E2: Implement idempotency service

Add canonical JSON normalization, SHA-256 digest, request ID validation, record metadata lookup, replay/conflict result.

Perform lookup under exclusive lock. Ensure lookup includes moved/retired records.

Test idempotency in isolation before any operation uses it.

### Phase E3: Implement safe renderers

Build fixed renderers for:

- raw user text artifact;
- note proposal;
- claim proposal;
- relationship proposal.

Use `Psych` for frontmatter. Parse rendered Markdown in tests before finalizing.

Add adversarial content tests before write operations.

### Phase E4: Implement capture_user_text

Reuse raw artifact concepts but do not route through old `ingest_text` CLI behavior that also creates a draft.

Checkpoint direct tests, replay/conflict, concurrent calls, and current ingestion regression.

### Phase E5: Implement evidence resolver

Resolve IDs, lifecycle, eligibility, safe paths, primary membership, duplicates/overlap. Return structured refs. Keep operation-specific endpoint resolution separate from evidence resolution.

### Phase E6: Implement propose_note

Validate, render, stage/finalize, return result. Test all candidate types except identity.

### Phase E7: Implement propose_claim

Validate/render/integrate review.

### Phase E8: Implement propose_relationship

Validate endpoints/evidence, render lifecycle readiness, integrate M7C gate tests.

### Phase E9: Update review presentation and agent contract

Add concise metadata visibility. Write archivist contract covering untrusted content, provenance, review, uncertainty, temporal boundaries, duplicate search-before-propose, and image constraints.

Do not write client-specific MCP setup yet.

### Phase E10: End-to-end direct-core lifecycle

Using synthetic vault:

1. capture user text;
2. read artifact through M7D;
3. propose pattern and claim;
4. propose relationship between pending endpoints;
5. confirm graph/report exclude all pending;
6. approve note and claim;
7. confirm relationship now approval-ready and approve;
8. generate graph/report;
9. retry original requests and confirm existing moved records replay;
10. reject a separate candidate and confirm retry returns retired lifecycle rather than duplicate.

## 15. Codex Potholes and Prohibitions

Do not:

- let caller supply ID/path/filename/frontmatter/Markdown;
- reuse old text CLI and accidentally create a generic draft during capture;
- auto-approve based on `candidate_type`;
- allow identity before review routing exists;
- use pending candidates as evidence;
- use endpoints as implicit evidence;
- sort arrays during digest if order affects output;
- include generated time/request ID in digest;
- store idempotency only in memory;
- create a hidden database/index;
- use request ID as slug;
- persist model name, prompt, chain of thought, or API key;
- treat user context as observed fact;
- place hypotheses under facts;
- allow free text to create YAML or headings;
- add MCP/Gemfile/frontend/model calls early;
- change current ingestion or review command behavior.

## 16. Risks and Mitigations

### Risk: Retry after approval cannot find original path

Mitigation: scan generation metadata across all lifecycle directories and return current path/lifecycle.

### Risk: Duplicate request IDs already exist

Mitigation: fail corruption clearly; never choose one.

### Risk: Self-grounding candidate chain

Mitigation: pending candidates categorically ineligible evidence.

### Risk: User-authored capture used for agent-invented text

Mitigation: required `confirmed_user_authored: true`; agent contract requires host clarification when authorship uncertain. Technical confirmation cannot prove truth, so document this residual risk.

### Risk: Markdown injection changes visual meaning

Mitigation: fixed renderer, one-line/bounded field normalization, continuation indentation/escaping, parse tests.

### Risk: Candidate type becomes de facto truth

Mitigation: persisted `type: note`, candidate type labeled suggestion, explicit review mapping remains.

### Risk: Relationship proposed against endpoint later retired

Mitigation: proposal result reports readiness; approval re-resolves current lifecycle.

## 17. Verification Commands

```sh
ruby scripts/test_nous_candidate_writes.rb
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

## 18. Definition of Done

M7E is done when the four direct core mutations are safe, review-bound, evidence-grounded, server-rendered, and idempotent; pending candidates remain excluded from accepted outputs; retries after lifecycle moves do not duplicate; all prior tests pass; and no MCP implementation exists.

## 19. Suggested Execution Handoff

One executor and one adversarial verifier. Implement idempotency/rendering before operations.

Handoff message:

```text
Implement M7E only. Add direct core user-text capture and candidate note,
claim, and relationship proposal operations with server-owned IDs/paths/YAML,
eligible evidence, shared lock/atomic writes, and persisted idempotency. Writes
must remain raw/inbox-only. Do not add MCP, approval tools, frontend, model
calls, semantic search, or identity routing.
```
