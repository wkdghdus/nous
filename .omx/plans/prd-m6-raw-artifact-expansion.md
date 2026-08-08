# PRD: M6 Raw Artifact Expansion

## Objective

Extend local ingestion from direct text capture to writing, image, and project files while preserving every original, keeping copied evidence portable inside the vault, and producing conservative source-backed records that remain behind the existing review boundary.

## Scope

- Add a dependency-free single-file Ruby importer with explicit semantic type selection.
- Copy one supported regular file into a type-specific raw-artifact `files/` directory.
- Create a sibling artifact record and a generic reviewable inbox note with a resolvable evidence chain.
- Record original filename, byte count, SHA-256 digest, represented date, import date, and optional user context without persisting the external absolute path.
- Provide coordinated collision handling, staged writes, checksum verification, and rollback.
- Extend tests, schema/template/docs/signposts, and repository checks.

## Out of scope

- Changes to M2 direct-text capture behavior.
- Directories, repositories, symlinks, hidden/extensionless files, archives, PDF/Office files, batch import, and content deduplication.
- OCR, EXIF parsing, media-signature validation, face recognition, image interpretation, or semantic link suggestions.
- Changes that let raw payloads or unreviewed artifact records enter graph/report outputs.

## User stories

### US-001: Import portable raw evidence

As a Nous user, I want writing, image, and project files copied into my vault so that their evidence remains available after the external source moves or is removed.

Acceptance criteria:

- `ruby scripts/ingest_artifact.rb --type writing|image|project SOURCE_PATH` accepts exactly the planned allowlists.
- `--vault-root`, `--date`, `NOUS_INGEST_DATE`, `--context`, and `--represented-date` follow the approved precedence and validation rules.
- The copied payload is byte-identical, has matching size and SHA-256 metadata, and uses a vault-relative `source.path`.
- The original bytes, filename, location, and permissions remain unchanged on success and handled failure.

### US-002: Preserve interpretation and review boundaries

As a Nous user, I want generated records to distinguish imported evidence from my context and from machine interpretation so that unsupported claims never become accepted self-knowledge.

Acceptance criteria:

- Each import creates an artifact record with `interpretation_level: none` and a generic inbox note with `interpretation_level: low`.
- Text-like inputs yield at most three bounded extractive facts; binary/image inputs yield metadata-only drafts.
- User context appears only in explicitly labeled context sections and tentative hypotheses remain empty.
- Inbox evidence points to the artifact record, and review approval can create a project note without mutating payload or artifact bytes.
- Graph and Nous report discovery remain reviewed-only.

### US-003: Make multi-output imports recoverable

As a maintainer, I want every import to behave as one coordinated transaction so that collisions and failures cannot overwrite prior evidence or leave orphaned records.

Acceptance criteria:

- One shared suffix is allocated across payload, artifact note, and inbox note.
- All three files are staged in their destination directories and finalized only after validation and serialization succeed.
- A handled failure removes temporary files and invocation-created final files while preserving pre-existing files byte-for-byte.
- Invalid inputs fail actionably before final output is created.

### US-004: Keep the contract documented and regression-protected

As a maintainer, I want fixture-driven tests and clear schema/docs so that the preservation, privacy, and review contracts remain auditable.

Acceptance criteria:

- Focused tests cover all source classes, validation, collisions, rollback, alternate vaults, privacy, provenance resolution, and review integration.
- Existing ingestion, review, graph, and report tests remain green.
- Schema, template, architecture, README, Makefile, and directory signposts describe the M6 contract.
- Focused tests, `make test`, and `make lint` pass before and after the required changed-files cleanup pass.

## Verification contract

The canonical verification artifact is `.omx/plans/test-spec-m6-raw-artifact-expansion.md`. Completion additionally requires manual digest/privacy inspection, STANDARD-or-higher architect approval, changed-files-only deslop, and a green post-deslop regression run.
