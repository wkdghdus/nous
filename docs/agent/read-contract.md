# M7D Agent-Safe Read Contract

M7D exposes direct Nous Core read operations only. These methods are intended as the future contract for an external archivist adapter, but this milestone does not add MCP tools or any write capability.

## Operations

- `Nous.status(vault_root:)` scans known record directories tolerantly and returns schema version, lifecycle/kind/scope counts, generated-output presence, and bounded warnings.
- `Nous.list_records(vault_root:, query: nil, scopes: nil, types: nil, limit: 20)` lists deterministic lexical matches from reviewed and canonical records by default. Raw evidence and inbox candidates require explicit scopes. Query length is capped at 500 characters, token scoring is lexical only, and limits must be 1-50.
- `Nous.read_record(vault_root:, id:, max_chars: 12000)` resolves one stable record ID and returns a curated, bounded envelope. `max_chars: 0` returns metadata only; the maximum body cap is 50,000 characters.
- `Nous.read_source_text(vault_root:, artifact_id:, offset_chars: 0, max_chars: 12000)` reads bounded text for one artifact ID. It never accepts arbitrary paths; offsets are Unicode-character offsets and `max_chars` must be 1-50,000.

## Safety Boundaries

- Public read operations take one shared vault lock; `_in_context` helpers are lock-free for callers that already hold an operation lock.
- `Nous::RecordIndex` indexes only known M7D record directories and ignores `AGENT.md`, generated outputs, copied payloads, unknown directories, and non-Markdown files.
- Symlinked known directories, record files, and copied payloads are rejected or diagnosed. Symlinks are rejected even if they resolve back inside the vault.
- Duplicate IDs never choose a winner. Strict operations raise `NOUS_DUPLICATE_ID`; status reports bounded diagnostics.
- Returned user/source text is bounded and labeled `content_role: untrusted_data`.
- Envelopes expose safe vault-relative paths only. External absolute paths and traversal-shaped values are redacted or rejected.
- Strict read operations fail closed on selected malformed records. `status` may continue through safe corruption and report capped, sanitized warnings.
- Read operations are mutation-free except for normal shared-lock runtime state (`.nous.lock`).

## Source Text Rules

- M2 text artifacts read only the embedded `## Observed Content` section in the artifact note. `source.path` is never followed for these artifacts.
- M6 writing and project artifacts may read copied vault-relative text payloads under their matching `files/` directory. Supported text payload extensions are `.txt`, `.md`, `.json`, `.yaml`, and `.yml`.
- If copied payload checksum or byte metadata is present, it must match. Legacy safe text payloads with missing metadata return text with bounded warnings.
- Image artifacts and binary project screenshots return `content_available: false` with a `content_unavailable_reason`; they do not return bytes, base64, text interpretation, or an exception.
- Missing, traversal, symlink, invalid UTF-8, checksum mismatch, and byte-count mismatch cases raise stable sanitized `Nous::Error` values.

## Stable Error Surface

Errors are sanitized and code-first. Callers should branch on `Nous::Error#code`, not message text. Common M7D codes include:

- `NOUS_INVALID_INPUT` for invalid IDs, query/scopes/limits, offsets, and malformed caller arguments.
- `NOUS_RECORD_NOT_FOUND` for unknown records or missing copied payloads.
- `NOUS_DUPLICATE_ID` when a selected operation would otherwise have to choose between duplicate stable IDs.
- `NOUS_PARSE_FAILED` for malformed Markdown frontmatter during strict scans.
- `NOUS_SYMLINK_REJECTED` for symlinked record directories, record files, payload files, or symlinked path components.
- `NOUS_PATH_OUTSIDE_VAULT` for traversal or vault-escape payload metadata.
- `NOUS_UNSUPPORTED_RECORD_TYPE` and `NOUS_UNSUPPORTED_SOURCE` for unsupported selected records or source payloads.

## Audit Expectations

The M7D read surface must remain local, deterministic, and file-first:

- no candidate writes, review mutations, temp-file staging, schema migrations, or generated duplicate truth;
- no request IDs, idempotency stores, MCP files, network/model calls, embeddings, vector stores, databases, frontend/API code, shell execution, or arbitrary file reads;
- no raw frontmatter dumps, external absolute paths, body excerpts in errors, backtraces, environment values, binary bytes, base64, or source interpretation;
- no committed private fixture data. Tests should use synthetic temporary vaults.

## Out of Scope

M7D does not add candidate writes, review mutations, request IDs, idempotency, schema migrations, MCP files, network calls, model calls, embeddings, persistent indexes, databases, frontend/API code, or arbitrary path reads.
