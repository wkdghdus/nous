# M8 Core Integration Gap Register

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## Purpose

These are the concrete seams to resolve before building UI around imagined APIs. Suggested new operation names are semantic contracts, not claims that classes or methods already exist. The backend may expose new human-facing core operations, but transport code must not acquire domain authority.

| Gap | Observed implementation | Required M8 resolution | Owner |
| --- | --- | --- | --- |
| GAP-01 | Capture stores `source.capture_channel: mcp`; generation metadata and its replay validator require interface mcp. | New human-capture operation with `capture_channel: app`, app receipts and shared neutral rendering helpers. Preserve existing MCP generation bytes, digests and result schemas. | M8D |
| GAP-02 | Exact embedded-source extraction is conditioned on the mcp capture channel. | Recognize validated app verbatim captures too, with byte-for-byte/Unicode regression tests. Do not silently strip leading/trailing text. | M8D |
| GAP-03 | Review edit resolves a file path for the operator; no structured save-edit API is established. | Core conditional candidate-body save, complete edit envelope, protected frontmatter and app audit event. Never reuse the truncated agent read as an edit buffer. | M8E |
| GAP-04 | Review/import operations do not accept app retry keys or expected source/target versions. | Core app receipt namespace and under-lock version preconditions, with outcome reconciliation. | M8D foundation, M8E review |
| GAP-05 | Multi-file rollback state is in-memory and rescues handled exceptions. | Narrow durable recovery manifests for app import/approve/merge; explicit recovery and conflict preservation after process death. No claim that old rollback already handles SIGKILL. | M8D, extended M8E |
| GAP-06 | Agent list is bounded to 50 with truncated flag, no cursor, and excludes retired records. | Human query operation with stable page cursors, explicit retired view and core-owned filtering/sorting. Preserve MCP limits. | M8B |
| GAP-07 | Status exposes counts and generated presence, not complete schema health or freshness. | Core read-only health/compatibility checks and output-specific freshness manifests. Unknown metadata is not fresh. | M8B/M8F |
| GAP-08 | M6 import expects a filesystem path and derives original filename from it. | App upload IO/source descriptor; share M6 rendering/allocation/copy validation without leaking spool filenames or rewriting CLI semantics. | M8D |
| GAP-09 | `prepare_vault_root` can create a root during import. | Validate an already-open existing vault before app mutation; no accidental initializer through import or health. | M8B/M8D |
| GAP-10 | Review metadata is a current review object, not a full append-only event history. | Render only known historical facts; add optional app audit events going forward. Do not fabricate old decisions. | M8E |
| GAP-11 | Merge validates destination directory/Markdown in inspected code; its body is unchanged while evidence is appended. | New human operation validates an active reviewed/canonical target in core and previews evidence-only merge. Any shared CLI behavior change needs explicit approval and tests. | M8E |
| GAP-12 | Core path guard rejects symlink root and symlink components. | Native selection does not exempt the chosen vault or copied evidence from inherited confinement checks. | M8B/M8D |
| GAP-13 | A graph schema can syntactically represent unreviewed review_status values. | Trust eligibility must come from core discovery/build rules, not schema validation alone. | M8F |

## Proposed additive metadata decision

Keep M7 `generation` unchanged. Do not widen it to cover unrelated human operations or copy one M7 request ID onto three import records. Introduce an optional, versioned `app_operations` list on the operation's owning record. An entry contains namespace/version, request ID, operation, normalized-input SHA-256, committed UTC timestamp and a bounded result reference containing stable IDs, not arbitrary destinations or private absolute paths.

Namespace is `(app-v1, request_id)`; the existing M7 generation namespace remains unchanged. App request IDs are generated once per intentional action and kept for exact retries. The same bare text key in an external MCP request is not an app replay. This is deliberate namespace separation, not a hidden conflict-resolution heuristic.

A capture owns its receipt; an import's artifact record owns the receipt referencing payload/artifact/draft results; a candidate edit or review source owns its receipt, even after moving to reviewed storage or becoming retired. A merge source owns the receipt referencing the target ID and affected before/after hashes. Resolve current paths by stable IDs during replay. Never duplicate receipt authority across the import's three outputs. A missing or ambiguous owner/result is a recovery conflict, not permission to create another record.

Keep provenance and audit separate. New `source.capture_channel: app` is an optional enum extension; old mcp captures remain valid. New candidate edit events identify a human edit, but do not rewrite the original agent's generation object. `review` retains the existing last-decision shape. An optional `app_review_history` list records only new events with action, timestamp, request ID and before/after hashes; it is not a promise to reconstruct previous body text.

M8A must approve the exact optional-field shapes and retention policy. M8D implements capture/import receipts; M8E extends the same approved namespace to review. No SQL database, required search index or vault-wide migration is introduced.

## Proposed crash-recovery decision

An app multi-file write stages final bytes under core control, records a versioned recovery manifest under a private ignored vault runtime directory, flushes required state, then finalizes through existing destination-local writers. The manifest records the exact before/after hashes, owned staging paths, record IDs and operation key. It may temporarily contain backup bytes needed for recovery, with restrictive permissions. It is transaction state, not accepted knowledge or a separate application database.

All participating updated CLI/MCP/app read and mutation entrypoints must detect an unfinished app transaction and fail closed until an explicit core recovery action resolves it; health/recovery inspection are the narrowly allowed exceptions. Otherwise another interface could treat a partially finalized import/approval as normal state. This additive failure mode needs owner approval and regression coverage. Avoid nested public-operation locks: shared helpers accept an already-locked context.

Recovery must compare actual bytes to both expected before/after hashes. Complete or roll back only a proven app-owned state. If a human/external editor changed an affected record, preserve all copies and report `NOUS_RECOVERY_REQUIRED`; never overwrite the newer content or delete files by filename pattern. A health read only reports this condition. App confirmation invokes the recovery operation. Atomic single-file receipts resolve committed-but-response-lost cases without a journal.

Power-loss durability is not inferred from process-death tests. Record filesystem/fsync behavior and explicitly scope the preview guarantee. Do not build a generic transaction engine; add only the import/approve/merge state machines needed by the approved operations.

Sources: R05, R10-R18. Every resolution in this document is proposed, not already implemented.


## Proposed metadata shape and ordering for M8A approval

The following example is an **app-specific optional receipt**, not a replacement for M7 generation. Exact schema implementation is frozen in A; these fields and replay invariants are the proposed baseline.

```yaml
app_operations:
  - schema_version: "1"
    namespace: app-v1
    request_id: "app.synthetic-capture-001"
    operation: capture
    input_sha256: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    committed_at: "2026-09-12T12:00:00Z"
    operation_id: "opaque-synthetic-operation"
    result:
      record_ids: ["artifact_synthetic_001"]
      payload_sha256: null
      payload_bytes: null
```

Operation is one of capture, import, candidate_edit, approve, reject, deprecate, merge. Request IDs obey the existing 1-128 character safe-key pattern. SHA-256 values are 64 lowercase hex characters. UTC timestamps are server-owned. `record_ids` is a closed bounded result list in documented role order: capture [artifact]; import [artifact, draft]; edit/decision [source]; merge [source, target]. Imported payload metadata is nullable for non-import operations and otherwise checked against the committed artifact. Resolve current paths by stable ID; do not store an external original path, body text or auth token in the receipt. Operation IDs are random, nonsemantic and persisted once.

The canonical app input digest includes operation and normalized client fields, preserving content bytes/array order and including expected source/target versions where supplied. Exclude server clock, transport retries and session tokens so exact replay is stable. A completed receipt lookup precedes mutation precondition checks. An import receipt belongs on the artifact only, even though it references three filesystem outputs. The payload itself is identified through that artifact's existing source metadata.

Optional `app_review_history` entries contain schema_version, request_id, action (edited/approved/rejected/deprecated/merged), occurred_at, before_sha256 and after_sha256; merge may include a target_id. Original `review` metadata remains the legacy latest-decision object. The history contains no copied previous body, speculative actor identity or fabricated pre-adoption event.

Proposed bound: at most 1,000 app receipt/history entries per owning record and an explicit bounded metadata size. Reaching the bound blocks further app edits with an explained audit-limit error; it does not silently prune idempotency receipts. Final byte limits and optional properties must be set in A's schema before D implementation. Compaction/history retention is deferred, not a hidden data-loss shortcut.

The current MCP source projection inspected in `agent_reads.rb` deliberately whitelists type, extraction_method, original_filename, represented_date, sha256, bytes and safe path; it does not expose arbitrary frontmatter. Preserve that projection so new optional app receipt/history/channel fields do not force a changed M7 output schema. The human DTO may expose approved app metadata separately. Test both projections explicitly.
