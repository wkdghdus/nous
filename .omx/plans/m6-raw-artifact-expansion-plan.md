# M6 Raw Artifact Expansion Plan

## Requirements Summary

M6 extends the local ingestion path from direct text capture to three additional source classes: long-form writing, images, and project artifacts. The roadmap names those three classes and defines success as different raw data types producing source-backed notes (`nous_requirements_and_user_flows.md:519-528`). The corresponding functional requirements call for photo/screenshot records with context, writing imports that do not overwrite originals, and project artifacts that can become project evidence (`nous_requirements_and_user_flows.md:132-142`).

The user-selected preservation contract is:

- Copy every accepted source file into the matching `vault/00_raw_artifacts/<type>/` area.
- Never rename, rewrite, delete, change permissions on, or otherwise modify the original file.
- Make the copied payload—not an external absolute path—the portable source referenced by the artifact record.
- Record enough local metadata to audit the copy: original filename, byte count, and SHA-256 digest.

This matches the existing vault lifecycle, in which raw evidence precedes interpretation and generated drafts remain reviewable (`docs/architecture/vault-schema.md:7-21`), and strengthens the recoverability requirement that imports be additive and originals be preserved or linked (`nous_requirements_and_user_flows.md:213-225`).

### Proposed M6 scope

- Add a dependency-free, single-file Ruby CLI: `scripts/ingest_artifact.rb`.
- Require an explicit semantic type with `--type writing|image|project`; file extensions alone cannot distinguish a journal Markdown file from a project README.
- Copy payloads into type-specific `files/` directories and write their artifact records into sibling `notes/` directories:
  - `vault/00_raw_artifacts/writing/files/` and `writing/notes/`
  - `vault/00_raw_artifacts/images/files/` and `images/notes/`
  - `vault/00_raw_artifacts/projects/files/` and `projects/notes/`
- Create one `type: artifact` Markdown record and one generic reviewable inbox note for every successful import. The inbox note continues to cite the artifact record, preserving the review/export/report provenance chain.
- Extract conservative, source-backed lines only from supported UTF-8 text-like writing/project files. Image and binary project imports produce metadata/context-only drafts and never claim visible content, identity, emotion, or meaning.
- Accept optional `--context TEXT` and `--represented-date YYYY-MM-DD`; context is placed in the body as user-authored context, not as observed content or a model hypothesis.
- Keep `scripts/ingest_text.rb` and its M2 behavior backward compatible. M6 does not silently reroute existing direct-text capture.

### Closed file allowlists

- `writing`: `.txt`, `.md`
- `image`: `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`, `.heic`
- `project`: `.txt`, `.md`, `.json`, `.yaml`, `.yml`, plus `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp` for prototype screenshots

Classification is case-insensitive. M6 copies supported binary formats byte-for-byte but does not parse image metadata or validate media signatures. PDF, DOCX, PPTX, archives, directories/repositories, extensionless files, hidden files, symlinks, OCR, EXIF extraction, face recognition, semantic link suggestions, and batch import are explicitly deferred. Batch import is only a `Could` requirement and is not part of M6's success condition (`nous_requirements_and_user_flows.md:138-142`).

### Metadata and provenance contract

- The artifact record remains a Markdown note with `type: artifact`, `review_status: needs_review`, and `interpretation_level: none`, consistent with the M2 record shape (`scripts/ingest_text.rb:180-200`).
- Artifact `source.type` is `writing`, `image`, or `project`; all are already legal schema values (`schemas/note-frontmatter.schema.yaml:48-67`).
- Artifact `source.path` is the vault-relative copied payload path, such as `00_raw_artifacts/images/files/photo.jpg`.
- Artifact `source.original_filename`, `source.sha256`, and `source.bytes` describe the imported source. The absolute external source path is not persisted by default, avoiding a non-portable path and unnecessary disclosure of workstation directory names.
- The generated inbox note's `source.path` and `evidence[].path` point to the artifact Markdown record, not directly to the copied payload. Existing review queue output reads those provenance paths (`scripts/review_queue.rb:74-86`), while graph/report generation continues to consume reviewed notes rather than raw binary payloads (`docs/architecture/vault-schema.md:138-158`).
- Duplicate content is permitted in M6. Repeated imports create suffixed payload, artifact-note, and inbox-note names; content-based deduplication or a skip/warn policy is deferred.

## Acceptance Criteria

### CLI and classification

- `ruby scripts/ingest_artifact.rb --type writing SOURCE_PATH`, `--type image`, and `--type project` each import one supported regular file.
- `--vault-root PATH` directs every created file under that vault root.
- `--date YYYY-MM-DD` and `NOUS_INGEST_DATE` deterministically set IDs and `created`/`updated` metadata; the explicit option takes precedence.
- `--context TEXT` records the text only under `User-Provided Context` in the artifact and draft bodies.
- `--represented-date YYYY-MM-DD` records source temporal context separately from import date.
- Missing/unknown types, invalid dates, missing paths, directories, symlinks, hidden files, extensionless files, and type/extension mismatches fail with actionable errors before final output is created.

### Preservation and auditability

- A supported external source is copied byte-for-byte into `00_raw_artifacts/<type>/files/`.
- SHA-256 of the final copied payload equals `source.sha256` and the source digest calculated before the copy.
- `source.bytes` equals both the source and copied payload byte size.
- Source bytes, source filename, source location, and source permissions are unchanged after success and after any handled failure.
- Artifact metadata uses a vault-relative copied payload path and never requires the original external path to resolve.
- After the external fixture is removed, the copied payload, artifact record, and inbox evidence chain remain internally resolvable within the fixture vault.

### Output records and interpretation boundary

- Every successful import creates a Markdown artifact record under `00_raw_artifacts/<type>/notes/` with stable ID, schema version `0.1`, `status: draft`, `review_status: needs_review`, source type/path/audit metadata, `interpretation_level: none`, and empty tags.
- Every successful import creates a generic Markdown draft under `01_agent_inbox/notes/` with `review_status: agent_generated`, `interpretation_level: low`, evidence pointing to the artifact record, and the existing confidence/counterevidence/related fields expected by the review flow.
- UTF-8 `.txt`, `.md`, `.json`, `.yaml`, and `.yml` inputs generate at most three bounded extractive source-backed facts without inventing claims.
- Invalid UTF-8 in a text-like writing/project source fails before any final output is committed.
- Binary image/project payloads do not undergo UTF-8 validation and are never embedded in Markdown.
- An image draft without `--context` contains only import metadata. It has no visible-content, person-identification, emotional, thematic, or psychological assertions, matching the photo safety rules (`nous_requirements_and_user_flows.md:295-325`).
- User context remains visibly separate from observed/import metadata and tentative hypotheses, matching FR-011 (`nous_requirements_and_user_flows.md:146-153`).

### Collision and failure safety

- Re-importing a source never overwrites an existing payload, artifact record, or inbox note.
- Collisions use one shared suffix allocation for the import set (`name.ext`, `name-2.ext`; matching `artifact_<date>_<slug>.md`, `artifact_<date>_<slug>-2.md`, and `note_<date>_<slug>-2.md`) so all emitted paths agree.
- Payload copies and Markdown records are first written to unique temporary files in their destination directories, verified, and then moved to final paths.
- If any copy, validation, note serialization, or finalization step fails, temporary files and final files created by that invocation are removed; pre-existing files remain byte-identical.
- A forced destination failure after payload staging leaves no orphaned copied payload or artifact record.

### Existing-system compatibility

- `scripts/ingest_text.rb` retains its current command, accepted extensions, output locations, frontmatter, extractive facts, duplicate suffix behavior, and errors (`scripts/ingest_text.rb:18-71`, `scripts/ingest_text.rb:87-126`, `scripts/ingest_text.rb:169-227`).
- M6 inbox notes appear in `review_queue.rb list` and `show`, and display evidence paths pointing to the M6 artifact record.
- Approving an M6 project-derived inbox note with `review_queue.rb approve ... --as project` produces a reviewed project note without mutating either the artifact record or copied payload.
- Existing graph export and Nous report behavior remains reviewed-only; raw payload files and artifact records do not become active graph/report records merely because they were imported (`docs/architecture/vault-schema.md:138-158`).
- `ruby scripts/test_ingest_artifact.rb`, the existing ingestion/review/export/report tests, `make test`, and `make lint` pass.

## Implementation Steps

1. **Lock the preservation and record contracts in focused tests before implementing the importer.**
   - Add `scripts/test_ingest_artifact.rb`, following the dependency-free fixture and subprocess style in `scripts/test_ingest_text.rb:1-32`.
   - Build separate writing, image, text-project, and binary-project fixtures. Capture original bytes, path, mode, size, and digest before each invocation.
   - Assert the exact output paths, copied bytes, frontmatter, body-section separation, inbox evidence chain, and absence of unsupported interpretations.
   - Add negative fixtures for every rejected source category and a blocked destination fixture that proves rollback after staging.
   - Add duplicate imports and alternate-vault-root coverage. Keep dates deterministic as the M2 tests do (`scripts/test_ingest_text.rb:9-16`, `scripts/test_ingest_text.rb:89-137`).

2. **Implement the new single-file importer without changing the M2 CLI.**
   - Add `scripts/ingest_artifact.rb` using only Ruby standard-library components: `Date`, `Digest::SHA256`, `FileUtils`, `OptionParser`, `Pathname`, `Psych`, `SecureRandom`, and filesystem primitives.
   - Follow the established CLI conventions: a custom error type, options struct, explicit parsing, `--vault-root`, `--date`, help output, clear stderr, and non-zero exit on validation failure (`scripts/ingest_text.rb:14-51`).
   - Require `--type`; validate against the closed per-type allowlists before creating destination directories.
   - Reject non-regular files and symlinks. Read text-like content only after classification; stream/copy binary payloads without decoding them.
   - Slug IDs using the current lowercase ASCII convention and `untitled` fallback (`scripts/ingest_text.rb:74-78`).

3. **Create a coordinated, atomic three-output import transaction.**
   - Resolve one collision suffix that is available for the payload, artifact note, and inbox note before staging any output. Never use a destructive overwrite flag.
   - Stage the copied payload in its final directory, calculate and compare source/staged SHA-256 and byte counts, then stage the two Markdown files.
   - Serialize frontmatter through `Psych`, matching current note generation (`scripts/ingest_text.rb:100-106`).
   - Move staged files to final destinations only after all validation and serialization succeed. Track files created by the invocation and roll them back on failure.
   - Print machine-readable-enough path lines consistent with M2: `copied_source:`, `artifact:`, and `draft_note:`.

4. **Render type-aware artifact and inbox bodies without interpretation creep.**
   - Use a common artifact structure based on `templates/obsidian/artifact.md`: Source Metadata, Observed Content, User-Provided Context, Notes Created From This Artifact, and Review Notes.
   - For writing and text-like project inputs, preserve an auditable excerpt in Observed Content and create no more than three bounded extractive facts using the existing M2 approach (`scripts/ingest_text.rb:109-126`). The copied payload remains the complete source of truth.
   - For binary inputs, place only filename, type, size, checksum, represented date, and import date in source metadata. Leave Observed Content empty.
   - Create generic inbox notes so the existing `review_queue.rb approve --as TYPE` boundary remains authoritative rather than auto-canonicalizing a guessed note type (`README.md:47-70`).
   - Put `--context` content under User Context and leave Tentative Hypotheses empty by default.

5. **Extend the documented schema for portable copied-source metadata.**
   - Update `schemas/note-frontmatter.schema.yaml:48-68` so the `source` object documents optional `original_filename`, `sha256`, and `bytes` fields while retaining its existing required fields and enum values.
   - Update `templates/obsidian/artifact.md` so manual artifact records can express the copied-source path, original filename, checksum, bytes, represented date, and import date consistently.
   - Add an M6 section to `docs/architecture/vault-schema.md` after the report contract (`docs/architecture/vault-schema.md:152-158`) defining `files/` versus `notes/`, source-path semantics, audit fields, collision policy, and the no-interpretation rule for binary artifacts.
   - Update the four raw-artifact signposts to list the new child directories and clarify that payloads are immutable evidence while artifact notes are metadata/provenance records (`vault/00_raw_artifacts/AGENT.md:1-10` and the type-specific `AGENT.md` files).

6. **Verify integration with the existing review boundary.**
   - In `scripts/test_ingest_artifact.rb`, invoke `scripts/review_queue.rb list` and `show` against the fixture vault and verify that M6 evidence paths resolve to artifact records.
   - Approve one generated project note as `project`; verify the copied payload and artifact record hashes do not change and the reviewed note retains evidence.
   - Do not modify graph/report discovery to scan raw artifacts. Their documented trust boundary begins with reviewed notes and canonical records (`docs/architecture/vault-schema.md:138-158`).

7. **Wire checks and user-facing documentation.**
   - Add `ruby scripts/test_ingest_artifact.rb` to `Makefile:6-10`, directly after the existing ingestion test.
   - Add `ingest_artifact.rb` and its test to `scripts/AGENT.md:5-15`.
   - Update `README.md:37-45` with an M6 section containing one command example per type, supported extension tables, output paths, optional context/date flags, audit metadata, and the guarantee that originals are not modified.
   - Replace the README's broad “text-only” current-scope wording with a precise distinction: direct capture remains text-only, while artifact import supports the closed M6 allowlists. Retain the explicit exclusion of voice/audio/transcript features.

8. **Run narrow-to-broad verification and inspect privacy-sensitive output.**
   - Run the new test first, then the full test and lint targets.
   - Manually import a temporary writing file and binary image into a temporary vault; compare source/copy digests and inspect both generated Markdown records.
   - Confirm the fixture external absolute path does not appear anywhere in the generated vault.
   - Confirm no raw payload or generated fixture is written into the repository's default vault during tests.
   - Review `git status --short` and ensure no private raw data, temp files, or unintended generated reports are present.

## Risks and Mitigations

- **Copied Markdown and artifact Markdown can collide or be confused.** Keep payloads under `files/` and provenance notes under `notes/`; allocate a shared suffix across the entire import set.
- **A multi-output failure can leave an orphaned payload or misleading record.** Stage all three outputs, verify the copied bytes, finalize only after all are valid, and roll back files created by the failed invocation.
- **Absolute source paths can leak workstation details and break portability.** Persist the vault-relative copied path, original basename, digest, and size; omit the external absolute path by default.
- **“Photo import” can grow into OCR, EXIF, face recognition, or emotional inference.** Keep image handling copy-and-metadata-only; context must be explicitly user-authored and hypotheses remain empty.
- **“Project artifact” can grow into repository crawling or archive/document conversion.** Require one explicit regular file from the closed allowlist and defer directories, archives, office formats, and PDFs.
- **The new script may duplicate M2 ingestion helpers.** Prefer a small self-contained M6 script initially so legacy behavior stays locked. Extract a shared ingestion library only in a later cleanup with regression coverage for both CLIs.
- **Checksums may be expensive for large personal files.** Stream SHA-256 and copying rather than loading binary files into memory; personal single-file imports remain within NFR-011's interactive scope (`nous_requirements_and_user_flows.md:221-225`).
- **Allowing duplicate content can pollute the vault.** Preserve current additive suffix behavior for consistency; checksum-based deduplication can be a separate product decision after real usage evidence.
- **Project screenshots fit both image and project categories.** Require explicit `--type`; the selected semantic type controls folder and provenance even when extensions overlap.

## Verification Steps

1. `ruby scripts/test_ingest_artifact.rb`
2. `ruby scripts/test_ingest_text.rb`
3. `ruby scripts/test_review_queue.rb`
4. `ruby scripts/test_export_graph.rb`
5. `ruby scripts/test_generate_nous_report.rb`
6. `make test`
7. `make lint`
8. Run writing, image, and project imports against a temporary vault and verify:
   - source and copy SHA-256 values match;
   - source metadata remains unchanged;
   - all generated paths are vault-relative and resolve after the external source is removed;
   - image/binary notes contain no invented observed content;
   - a reviewed project note retains its artifact evidence;
   - no failed import leaves temp or partial final files.
9. Run `git status --short` and inspect every added raw/generated file before completion.

## Suggested Execution Handoff

This plan is large enough for parallel implementation only after the output contract and tests are owned clearly.

- **Executor:** own `scripts/ingest_artifact.rb`, transactional file handling, frontmatter/body rendering, and focused fixes. Medium reasoning is sufficient; elevate to high if atomic rollback behavior becomes platform-sensitive.
- **Test engineer:** own `scripts/test_ingest_artifact.rb` and `Makefile` wiring, including original-preservation, collision, rollback, and review-queue integration fixtures. Medium reasoning.
- **Writer:** own `README.md`, `docs/architecture/vault-schema.md`, schema/template updates, and raw-artifact signposts after the implementation contract stabilizes. Medium reasoning.
- **Verifier:** independently run narrow and broad checks, compare source/copy hashes, inspect generated Markdown, and audit the worktree for private payloads. High reasoning because preservation and privacy are the milestone's primary risks.

For a single-owner path, `$ralph .omx/plans/m6-raw-artifact-expansion-plan.md` should implement test-first and use a verifier pass before completion. For a coordinated path, `$team .omx/plans/m6-raw-artifact-expansion-plan.md` should assign the non-overlapping ownership above and keep final integration/verification with the leader.
