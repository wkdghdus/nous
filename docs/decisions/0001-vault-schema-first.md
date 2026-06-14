# 0001. Define the Vault Schema Before Application Code

## Decision

Start Nous with a versioned vault schema, Obsidian templates, and graph export shapes before creating application code.

## Context

Nous depends on provenance, review status, and stable IDs more than on any single interface. The first milestone in `nous_requirements_and_user_flows.md` is a vault schema, and root guidance keeps the MVP text-first and local-first.

## Consequences

- Manual capture and review can begin before automation exists.
- Future ingestion code has a concrete file contract to target.
- Schema mistakes are still cheap to revise because no runtime depends on them yet.

## Alternatives Considered

- Start with ingestion scripts first.
  - Rejected because automation without a stable metadata contract would create inconsistent notes.
- Start with a full app shell first.
  - Rejected because the current project goal is a self-knowledge data resource, not a UI-first product.

## Verification

- `docs/architecture/vault-schema.md` defines the lifecycle and required metadata.
- `templates/obsidian/` contains the initial note templates.
- `schemas/` contains draft frontmatter and graph schemas.
