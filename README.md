# Nous

Nous is a local-first personal self-knowledge system scaffold. This repository currently contains product notes, repository signposts, Obsidian vault structure, note templates, and schema placeholders only.

No application project has been created yet.

## Current Scope

- Preserve the product ideation in `nous_requirements_and_user_flows.md`.
- Establish an agent-friendly repository structure with `AGENT.md` signposts.
- Prepare vault, template, and schema locations for future implementation.
- Keep MVP scope text-first and local-first per `AGENT.md`.

## Top-Level Map

- `docs/` - product, architecture, and decision records.
- `schemas/` - machine-readable schema drafts for notes and graph data.
- `scripts/` - dependency-free repository maintenance scripts.
- `templates/` - Obsidian note templates and future prompt/template assets.
- `vault/` - empty Obsidian-compatible vault skeleton for raw, inbox, reviewed, canonical, and generated content.
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

## Basic Text Ingestion

Import a local UTF-8 text or Markdown file with:

```sh
ruby scripts/ingest_text.rb path/to/source.txt
```

The command writes a raw artifact note to `vault/00_raw_artifacts/text/` and a reviewable draft note to `vault/01_agent_inbox/notes/`. Repeated imports create suffixed filenames instead of overwriting existing notes. The MVP ingestion path is text-only and does not process voice, audio, dictation, or transcript-specific data.

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
