# Nous

Nous is a local-first personal self-knowledge system. The implemented
file-backed pipeline captures source material, creates reviewable notes and
claims, records human review decisions, exports a reviewed graph, generates a
reviewed report, imports bounded raw artifacts, and exposes reusable read/write
core operations through a local MCP adapter.

## Current Scope

- Preserve provenance from raw evidence through reviewed knowledge.
- Keep generated work in the inbox until a human reviews it.
- Keep direct capture text-only; M6 artifact imports use closed allowlists for
  writing, image, and project files.
- Provide a bounded local agent interface without a frontend or built-in model.

## Top-Level Map

- `docs/` - product, architecture, and decision records.
- `schemas/` - machine-readable schemas for notes and graph data.
- `scripts/` - local ingestion, review, generation, test, and MCP entrypoints.
- `templates/` - Obsidian note templates.
- `vault/` - Obsidian-compatible raw, inbox, reviewed, canonical, and generated
  content.
- `.omx/` - local OMX workflow state and plans; runtime logs/state are ignored.

## Checks

Run the ingestion regression tests with:

```sh
make test
```

Run the repository lint with:

```sh
make lint
```

MCP-specific setup and its focused Bundler test command are documented in
[`docs/agent/mcp-setup.md`](docs/agent/mcp-setup.md).

## Local MCP Server

Install the pinned Ruby dependencies and start the local stdio server:

```sh
bundle install
bundle exec ruby scripts/nous_mcp_server.rb --vault-root /ABSOLUTE/PATH/TO/VAULT
```

Run its focused protocol test with:

```sh
bundle exec ruby scripts/test_nous_mcp.rb
```

The bundle pins the official `mcp` 1.5.1 gem and explicit `base64` 0.3.0
runtime dependency.

Vault-root precedence is `--vault-root`, then `NOUS_VAULT_ROOT`, then this
repository's `vault/`. `NOUS_MCP_TIME` is test-only and must not be set by
production clients.

The server targets MCP protocol `2025-11-25` and exposes exactly:

- `nous_status`
- `nous_list_records`
- `nous_read_record`
- `nous_read_source_text`
- `nous_capture_user_text`
- `nous_propose_note`
- `nous_propose_claim`
- `nous_propose_relationship`

Reads default to reviewed/canonical records; raw source text is available only
through its bounded source operation. Captures create raw user-authored
evidence, and proposals create candidates under `vault/01_agent_inbox/`.
Nothing on the MCP surface approves or canonicalizes a candidate. All vault
content returned to a client is untrusted data, and callers cannot supply
arbitrary paths.

This is a local stdio, tools-only interface. It has no HTTP/SSE transport,
network listener, model or provider integration, frontend, prompts, resources,
roots, sampling, elicitation, or tasks.

## Basic Text Ingestion

Import a local UTF-8 text or Markdown file with:

```sh
ruby scripts/ingest_text.rb path/to/source.txt
```

The command writes a raw artifact note to `vault/00_raw_artifacts/text/` and a reviewable draft note to `vault/01_agent_inbox/notes/`. Repeated imports create suffixed filenames instead of overwriting existing notes. The direct capture path is text-only and does not process voice, audio, dictation, or transcript-specific data.

Use the separate M6 importer below for long-form writing, images, and project evidence.

## Raw Artifact Imports

Import supported writing, image, or project files with `scripts/ingest_artifact.rb`. The command copies the original file into the matching raw-artifact `files/` directory, writes a portable artifact note in the sibling `notes/` directory, and creates a reviewable inbox note that points at the artifact record. The importer never renames, rewrites, deletes, or changes permissions on the original source file.

### Command examples

```sh
ruby scripts/ingest_artifact.rb --type writing path/to/journal.md
ruby scripts/ingest_artifact.rb --type image path/to/photo.png
ruby scripts/ingest_artifact.rb --type project path/to/design-spec.json
```

### Type allowlists and output paths

| Type | Supported extensions | Copied payloads | Artifact notes |
| --- | --- | --- | --- |
| `writing` | `.txt`, `.md` | `vault/00_raw_artifacts/writing/files/` | `vault/00_raw_artifacts/writing/notes/` |
| `image` | `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`, `.heic` | `vault/00_raw_artifacts/images/files/` | `vault/00_raw_artifacts/images/notes/` |
| `project` | `.txt`, `.md`, `.json`, `.yaml`, `.yml`, `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp` | `vault/00_raw_artifacts/projects/files/` | `vault/00_raw_artifacts/projects/notes/` |

### Import flags

- `--vault-root PATH` writes every output under an alternate vault root.
- `--date YYYY-MM-DD` sets the import date used in IDs and frontmatter.
- `NOUS_INGEST_DATE` provides the same import date when `--date` is not supplied.
- `--context TEXT` records user-authored context without folding it into observed content.
- `--represented-date YYYY-MM-DD` records the date the source represents, separate from the import date.

### Audit metadata

Each successful import records the copied payload path, original filename, SHA-256 digest, and byte count in the artifact note frontmatter and body. That copied payload is the portable source of record; the external absolute source path is not needed to resolve the vault record later. Supported binary imports stay metadata-only and do not add inferred visible content, identity, or emotional interpretation.

## Review Queue

List pending generated notes, claims, and relationships with:

```sh
ruby scripts/review_queue.rb list
```

Inspect an item without mutating it:

```sh
ruby scripts/review_queue.rb show vault/01_agent_inbox/notes/example.md
```

Approve inbox notes with an explicit reviewed type:

```sh
ruby scripts/review_queue.rb approve vault/01_agent_inbox/notes/example.md --as memory
```

Approve claims and relationships without `--as`; they move to `vault/03_canonical_model/claims/` and `vault/03_canonical_model/relationships/`. Reject, deprecate, or merge items in place with `reject`, `deprecate`, and `merge --into PATH`; merge targets must already live under `vault/02_notes/` or `vault/03_canonical_model/`. Each decision records review metadata and keeps audit history on disk. Regenerate the Obsidian queue view with:

```sh
ruby scripts/review_queue.rb report
```

## Graph Export

Export reviewed graph records with:

```sh
ruby scripts/export_graph.rb
```

By default, the command writes `vault/04_generated/graph/nous_graph.json`. The export is reviewed-only: it reads reviewed notes from `vault/02_notes/`, canonical claims from `vault/03_canonical_model/claims/`, and canonical relationships from `vault/03_canonical_model/relationships/`. Inbox records are excluded until a reviewer accepts them.

Use `--vault-root PATH` for fixture or alternate vault roots, and `--output PATH` to choose a different JSON destination.

## Nous Report

Generate the reviewed Nous summary with:

```sh
ruby scripts/generate_nous_report.rb
```

By default, the command writes `vault/04_generated/reports/nous.md`. Use `--vault-root PATH` for fixture or alternate vault roots, and `--output PATH` to choose a different Markdown destination.

The report is regenerable and reviewed-only. It reads reviewed notes from `vault/02_notes/`, canonical claims from `vault/03_canonical_model/claims/`, and canonical relationships from `vault/03_canonical_model/relationships/`. Inbox, rejected, deprecated, archived, and unsupported records are excluded.

The report is a source-backed summary, not a new interpretation. It can quote or excerpt reviewed records, but it does not add unsupported psychological conclusions.
