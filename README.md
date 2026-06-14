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

Run the repository lint with:

```sh
make lint
```
