# M8 Local Application Adapter Contract

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## 1. Status and ownership

**Every route, DTO and human operation below is proposed M8 behavior, not an existing API.** The existing operations cited in the mapping table are verified only to the extent described in the source register. M8A freezes this contract before production frontend work. M8B implements the read/control plane; M8D/E/F add only their approved operation families.

The adapter may deserialize, authenticate, authorize a session, bound a transport request, invoke core and serialize an approved DTO. It may not allocate record IDs, choose final vault destinations, parse Markdown, decide evidence eligibility, implement review transitions or bypass core locks. Shared core input bounds remain authoritative even when repeated in a transport schema for rejection at the boundary.

## 2. Envelope and versioning

Use UTF-8 JSON and `/api/v1`. Each JSON object has a closed property set (`additionalProperties: false` in the eventual schema), including nested objects. Reject duplicate JSON keys, invalid Unicode, nonfinite numbers, malformed dates, wrong primitive types and unsupported enums. Do not coerce `"false"` to true or an array to a string.

Authenticated content requests carry `Authorization: Bearer <in-memory-token>`, `X-Nous-Session`, and `X-Nous-Vault-Epoch`. Content mutations also carry `X-Nous-Request-ID`. The native chooser is available before an active vault, but still requires authorization and exact-origin protection. No arbitrary `vault_root`, output `path`, shell command or executable argument appears in a client request.

Success envelope:

```json
{
  "api_version": "1",
  "session_id": "opaque-session",
  "vault_epoch": 3,
  "correlation_id": "random-diagnostic-id",
  "data": {}
}
```

Error envelope:

```json
{
  "api_version": "1",
  "correlation_id": "random-diagnostic-id",
  "error": {
    "code": "NOUS_STALE_RECORD",
    "message": "This record changed. Reload before saving.",
    "retryable": false,
    "outcome": "not_committed"
  }
}
```

The displayed stale error is a **proposed** new core code. Existing `NOUS_*` codes survive unchanged. Only allowlisted safe details may cross the boundary; do not return an exception object, backtrace, filesystem path, query body or request arguments. Correlation IDs are random, not record slugs.

## 3. Authentication, startup and sessions

The backend binds a loopback socket before the browser opens. Choose a port using an actual bound socket, not check-then-bind. The launcher validates readiness and process identity. Another application occupying a configured port causes a clear startup error or a newly bound random port, never reuse of an unverified listener.

A private launcher rendezvous record may let a second launch request a fresh one-use bootstrap nonce from the existing instance. Use restrictive ownership/permissions, process-start identity, expiry and bounded framing. A stale PID alone is insufficient. No vault bodies or copied payloads go in this record. The bootstrap nonce is exchanged for a per-launch session token; no token is fetched from an unauthenticated GET. Scrub the browser fragment immediately. After a full reload, an authorization screen explains that the launcher must reopen the session; the draft does not secretly persist credentials in sessionStorage.

Every sensitive response is no-store. The static shell has no personal data. Verify Host against the exact bound address and port. Mutations require exact Origin and JSON/custom-header requests; deny form-based and cross-site requests, including null Origin. Content GETs still require bearer authorization; deny a supplied foreign/null Origin and cross-site Fetch Metadata. CORS is absent for the same-origin deployment. No wildcard origins are used for development against a personal vault.

Proposed CSP baseline: `default-src 'self'; script-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'`. Add only the narrow image/blob/style allowances proven necessary by the rendering tests. No unsafe-eval or remote script/font/image hosts. Prefer no inline script; a changed CSP must be covered by tests. Set `X-Content-Type-Options: nosniff` and `Referrer-Policy: no-referrer`.

## 4. Route families

Routes below are a closed initial inventory, not generic CRUD over arbitrary files. The request context headers are omitted from each row for readability.

| Stage | Method and route | Request-specific fields | Core/adapter behavior |
| --- | --- | --- | --- |
| B | POST `/api/v1/bootstrap` | one-use nonce | Adapter exchange; no vault access before authorization. |
| B | GET `/api/v1/session` | none | Opaque session, epoch, alias, capability/read-only state; no absolute root. |
| B | POST `/api/v1/vault-selections` | none | Authenticated foreground native folder dialog; returns opaque handle or cancelled. |
| B | POST `/api/v1/vault-session` | selection_handle OR recent_vault_id | Consume server-owned handle, validate existing root, switch only when safe, increment epoch. |
| B | GET `/api/v1/health` | none | Core health and compatibility; zero record repairs or generated writes. |
| B | POST `/api/v1/refresh` | none | Invalidate and rebuild disposable state, not a vault mutation. |
| B/C | POST `/api/v1/records/query` | query, scopes, types, filters, sort, page_size, cursor | Human core query; body avoids putting personal search text in URLs/logs. |
| B/C | POST `/api/v1/records/read` | id, offset_chars, max_chars | Human bounded detail, version, completeness, protected metadata, resolved references. |
| B/C | POST `/api/v1/sources/read-text` | artifact_id, offset_chars, max_chars | Bounded source read via validated record, never an arbitrary path. |
| B/C | POST `/api/v1/sources/read-payload` | artifact_id | Authenticated bounded copied-payload bytes after core validation; no external original. |
| E | POST `/api/v1/review/query` | sort, kinds, review_statuses, page_size, cursor | Core pending-queue query; sort is priority/created/confidence, using established review ordering. |
| E | POST `/api/v1/candidates/read-edit` | id | Complete editable body within size limit, protected metadata, expected-version token. |
| D | POST `/api/v1/captures` | confirmed_user_authored, user_text, title?, user_context?, represented_date? | Proposed human capture core; raw only, app provenance, durable app receipt. |
| D | POST `/api/v1/imports` | multipart metadata + exactly one file | Spool bounded bytes privately, validate source descriptor, create import job. |
| D | GET `/api/v1/operations/{operation_id}` | opaque operation_id | Current phase or durable result reconciliation; requires same vault epoch. |
| D | POST `/api/v1/operations/lookup` | request_id, operation | Core app-namespace outcome lookup when the initial response, including operation_id, was lost. |
| D | POST `/api/v1/operations/{operation_id}/cancel` | none | Cooperative cancel before commit barrier; no false rollback promise. |
| E | PATCH `/api/v1/candidates/{id}` | expected_version, body, candidate_type? | Core conditional body/type save; preserve protected/unknown metadata. |
| E | POST `/api/v1/review/{id}` | decision, expected_version, note_type?, target_id?, target_version?, reviewer_note? | Closed decision union: approve/reject/deprecate/merge, human authority only. |
| F | GET `/api/v1/outputs/{kind}` | kind = report OR graph | Current verified output metadata; report may expose explicitly labeled prior snapshot. |
| F | POST `/api/v1/outputs/graph/query` | node_types, relationship_types, focus_id?, max_nodes, max_edges | Core projection of the verified-current export; hard caps 500 nodes/1,000 edges; too-large is explicit, not silent truncation. |
| F | POST `/api/v1/outputs/{kind}/regenerate` | expected_input_revision | Direct reviewed-only build and atomic replace with derived freshness manifest. |
| D/H | GET `/api/v1/recovery` | none | Core interrupted-operation inspection; no automatic repairs. |
| D/H | POST `/api/v1/recovery/{operation_id}` | expected_recovery_revision, action = reconcile | Explicit core recovery with under-lock byte checks; externally changed bytes are preserved. |
| H | POST `/api/v1/shutdown` | confirmation = true | Stop accepting writes, drain/resolve commit state, revoke session, release process resources. |

Strict response DTOs are required for every route, including binary response headers. Unsupported methods/routes return a generic safe error, not a static-file fallback into the vault. A POST used for a read remains domain-read-only and does not require a record-mutation receipt; auth/origin protections still apply.

## 5. Human query and detail contracts

`query` is optional lexical text, at most 500 characters. `scopes` is a nonempty unique array from reviewed, canonical, raw, inbox; `filters.include_retired` is an explicit boolean extension, default false, for the human API and must not leak into default queries. `types` uses verified core type constants. `filters` is a closed object supporting created/represented date ranges where that metadata exists, review status, confidence range and tags. An unavailable field is not inferred from prose. Date/confidence filters exclude records missing that field; selected tags must all match. `sort` is a closed enum: relevance (descending core lexical score), created (newest first), confidence (descending, absent last), type (lexical). Stable ID then relative path break ties. Review-queue ordering is separate and retains the existing priority/created/confidence rules. Page size is 1-50, default 20.

The core returns records, total matching count when safely computed, has_more, opaque next_cursor and snapshot_revision. Ties are explicit (stable ID then vault-relative path); a cursor binds query/filter/sort/epoch/revision. Expired or changed snapshot returns `NOUS_CURSOR_STALE`, not missing/duplicated pages. Never fetch the first 50 from MCP and implement the rest of search in TypeScript.

A record DTO contains id, type, kind, normalized lifecycle_class, status, review_status, label, bounded body, body_complete, body_total_chars, offset/next_offset, version_sha256, source metadata, evidence/counterevidence, confidence, interpretation_level, basis, review metadata and optional app history. Fields absent on legacy records remain absent/null as schema permits, never fabricated. Source/evidence links include resolution status (resolved, missing, duplicate, redacted, unsupported). Path presentation is vault-relative only. Normalize M7 `lifecycle` versus write-result `lifecycle_class` intentionally in the human DTO; do not alter MCP output keys.

`version_sha256` hashes exact stored record bytes, not a rendered or truncated projection. Candidate edit envelopes include the complete stored body, including headings, or declare editing unavailable. The body limit is proposed at 1 MiB UTF-8. Reading larger records remains bounded/paged. The UI cannot save incomplete content.

## 6. Health and vault compatibility

Health separates raw/inbox/reviewed/canonical counts from generated-file counts; generated outputs are not indexed knowledge records. It returns schema version/compatibility, pending review count, parse/duplicate diagnostics, lock availability, read-only status, output presence/freshness and interrupted-operation state. Agent state is `external_client_not_observed` in M8, not a guessed online/offline heartbeat.

A valid existing vault has the approved lifecycle directories and supported record schema. Empty optional type subdirectories may remain absent until a permitted core write creates them; missing lifecycle roots are invalid, not automatically initialized. No silent migration. Validate local guidance/schema before finalizing the exact required-folder list in M8A.

Read-only storage can be inspected only through a safe coherent-read strategy. If an existing lock cannot be acquired without writing or a stable snapshot cannot be established, show `inspection_unavailable` rather than create directories, delete locks or pretend the read was coordinated. An explicit writable session may establish ignored runtime lock state as documented; health itself never repairs record data.

## 7. Capture and import

Capture fields mirror established content bounds where applicable: confirmation must literally be true; user_text must be nonblank and at most 1 MiB in characters and bytes; title/context/date reuse core validation, not guessed frontend limits. Server time is authoritative and injected in tests; represented_date is separate from capture/import date. Preserve all supplied text bytes through encoding rules, including non-ASCII and leading/trailing whitespace. No automatic classification or canonical write.

Import permits one file with the exact M6 type/extension allowlists. Proposed app bounds: 32 MiB maximum binary payload, 8 MiB maximum text-like payload, 64 KiB metadata part, 2 MiB other JSON request bodies, and 1 active import. Streaming limits apply before a complete body is buffered; reject excessive chunked requests and inflated multipart counts. The server determines actual byte count and digest; client MIME/length/checksum is advisory only. Reject path separators, traversal components, nulls and hidden basenames rather than silently reinterpret them. Preserve an accepted original filename in audit metadata and choose final paths in core.

Import phases: receiving -> validating -> staged -> committing -> committed. Before committing, cancellation removes only this operation's spool/staging state and creates no records. During/after committing, return `cancel_too_late` or committed result, never an untrue cancelled state. A dropped connection is not cancellation. No progress percentage is shown without measurable bytes/steps. Result contains artifact_id, draft_id, vault-relative payload metadata, digest, bytes, operation_id and replayed state. The deterministic draft is visible and still requires human approval.

## 8. Review union and concurrency

`approve` requires expected_version. Notes also require one of the nine explicit note_type values; claim/relationship requests must reject note_type. `reject` and `deprecate` accept pending items only. `merge` requires target_id and target_version, rejects self-merge and invalid/unaccepted targets, appends evidence and archives source without synthesizing or replacing the target body. Notes target active supported reviewed notes; claims target active canonical claims; relationships target active canonical relationships with the same ordered from/type/to tuple. This app-specific eligibility belongs to the new human core operation, not a silent legacy CLI rewrite. Optional reviewer_note is bounded using approved core validation.

Inside one exclusive context: resolve unique IDs, compare source/target bytes, validate pending state and endpoint eligibility, allocate/check the final destination, stage and commit. Endpoint readiness shown in a card is advisory; approval rechecks it. Never resolve an ID to a path in the adapter, release the read lock and call an unconditioned write. Prefer new structured human core operations using shared already-locked helpers.

Every source mutation commits its receipt with the record change. Resolve an exact committed receipt before rechecking an old expected_version, so a legitimate replay after movement/approval succeeds without reapplying the mutation. Unknown outcome lookup is not proof that a request never executed; do not automatically mint a replacement key. A replay after later review returns the original operation outcome and current record location/lifecycle separately; it never restores old content. Exactly-once replay depends on retaining the receipt-bearing vault records. Manual deletion of receipts or rollback to an older vault snapshot is outside that guarantee and requires human reconciliation, not automatic resubmission.

## 9. Error and retry mapping

| Condition | HTTP status | Code / outcome |
| --- | --- | --- |
| Missing/bad session capability | 401 | APP_UNAUTHORIZED; no data returned |
| Foreign origin/host or forbidden operation | 403 | APP_ORIGIN_REJECTED / APP_FORBIDDEN |
| Malformed envelope/content type | 400 / 415 | APP_INVALID_REQUEST / APP_UNSUPPORTED_MEDIA_TYPE |
| Bound exceeded | 413 | APP_REQUEST_TOO_LARGE |
| Missing unique record | 404 | Existing NOUS_RECORD_NOT_FOUND |
| Semantic input/evidence failure | 422 | Preserve existing NOUS_* code |
| Stale record, cursor, vault epoch, replay conflict | 409 | NOUS_STALE_RECORD / NOUS_CURSOR_STALE / NOUS_SESSION_CHANGED / existing NOUS_IDEMPOTENCY_CONFLICT |
| Lock contention | 423 | Existing NOUS_LOCK_TIMEOUT; may retry same key after backoff |
| Unresolved interrupted operation | 409 | Proposed NOUS_RECOVERY_REQUIRED; inspect/reconcile |
| Unexpected server failure | 500 | APP_INTERNAL_ERROR plus random correlation; outcome may be unknown |
| Backend unavailable | UI transport state | Outcome unknown until reconnected/reconciled |

New codes are explicitly proposed; existing code meanings are not renamed. `outcome` is one of not_committed, committed, unknown. A client never converts unknown into failed or success. Lock retry is bounded; a semantic conflict waits for user review. Cancellation and session-control retries use operation state, not arbitrary new write IDs.

## 10. Outputs and recovery

Output regeneration takes an expected eligible-input revision. If inputs changed before the locked build, return a conflict for explicit refresh rather than generate from an unnoticed older state. The core controls fixed default output destinations; no output path in HTTP. Graph/report run independently: a graph success and report failure are two explicit statuses, not an all-or-nothing claim.

Derived regeneration is retry-safe replacement of a reproducible view, not a new canonical event. Coalesce in-flight/last completed request keys in its derived manifest. Replaying an older generation after input changes is refused by the input revision. Do not grow a second authoritative record ledger for disposable outputs.

An output is fresh only if its eligible-input fingerprint, generator identity and actual output digest match its manifest. The graph JSON remains compatible with R06. A manually edited/corrupt output is unknown/invalid. Legacy output without a manifest can be shown as an unverified report snapshot but is not a current accepted graph. Rebuilding failure preserves the last valid file.

Recovery reads a bounded versioned manifest under the vault lock. Compare all affected existing/staged bytes with declared hashes. Deterministic owned states may reconcile; external modifications remain untouched and require manual conflict resolution. Health never executes recovery. Test kill points before/after every multi-file finalization and after commit before response, not only raised Ruby exceptions.

## 11. Existing versus proposed operation mapping

| Use | Existing inspected core | New behavior required |
| --- | --- | --- |
| Status | `Nous.status` | Rich health/compatibility and private session DTO |
| Query | `Nous.list_records` | Human pagination, explicit retired scope and metadata filters |
| Detail/source | `Nous.read_record`, `Nous.read_source_text` | Complete human edit/read envelope; safe binary access by artifact ID |
| Capture | `Nous::CandidateWrites.capture_user_text` | Human capture provenance/receipts using shared neutral helpers |
| Import | `Nous::ArtifactIngestion.ingest` | Bounded IO source descriptor, app receipt/recovery and progress hooks |
| Review | `Nous::ReviewMutation` actions | ID-based conditional human operations, edit save and audit |
| Derived | Existing graph/report builders and CLI orchestration | Direct core build+write operations if not already public; freshness manifest |

The implementation agent must inspect the rest of each relevant module before choosing helper boundaries. The names of new Ruby classes are not prescribed here. All domain extensions belong to core and are tested directly; no MCP class is required to use them.

Sources: R04-R19 and E04/E08; all application routes and new error/metadata contracts are proposals.
