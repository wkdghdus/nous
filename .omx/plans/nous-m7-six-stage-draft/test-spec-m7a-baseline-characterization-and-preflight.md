# Test Specification: M7A Baseline Characterization and Dependency Preflight

Status: Draft verification contract

Date: 2026-08-08

Plan: `m7a-baseline-characterization-and-preflight-plan.md`

Shared contract: `m7-shared-contract.md`

## 1. Test Strategy

M7A proves that later refactoring has a trustworthy baseline. Tests execute current scripts as subprocesses and assert product-owned behavior. The SDK preflight is a temporary integration proof and is documented separately from the repository product suite.

No M7A test may call a future `Nous` core API or rely on future MCP code.

## 2. Fixture Rules

- Use `Dir.mktmpdir`.
- Use synthetic content only.
- Never read from the user's home directory.
- Never write fixture data into the repository vault.
- Fix times through existing documented environment variables/options.
- Normalize only temporary root prefixes; preserve vault-relative paths exactly.
- End every test program with a repository-vault leak assertion.

Synthetic text:

```text
Synthetic M7 baseline fixture.
I turn uncertainty into small systems.
This text is not personal data.
```

## 3. Pre-Change Baseline

Run before editing:

```sh
ruby scripts/test_ingest_text.rb
ruby scripts/test_ingest_artifact.rb
ruby scripts/test_review_queue.rb
ruby scripts/test_export_graph.rb
ruby scripts/test_generate_nous_report.rb
make test
make lint
```

Pass condition: all exit zero. Any pre-existing failure blocks M7A implementation.

## 4. Cross-Script CLI Characterization

A dedicated `scripts/test_cli_contracts.rb` is recommended for these IDs.

### CHAR-001: Help exits zero

For each script:

```text
ingest_text.rb
ingest_artifact.rb
review_queue.rb
export_graph.rb
generate_nous_report.rb
```

Invoke supported `--help`/subcommand help and assert:

- status zero;
- usage prefix is product-owned and stable;
- stderr empty;
- no file created.

### CHAR-002: Unknown option

Assert nonzero status, command-specific stderr prefix, actionable option error, and no stack trace.

### CHAR-003: Extra positional argument

For commands that accept none/one path, assert exact product-owned positional error and no output file.

### CHAR-004: Missing required positional argument

Assert the current error contract for ingestion and item-targeting review commands.

### CHAR-005: Explicit option beats environment

- `--date` beats `NOUS_INGEST_DATE` for both ingestion scripts.
- explicit output/vault options beat defaults.
- fixed review/graph/report environment time remains honored.

### CHAR-006: Success stdout prefixes

Assert current prefixes exactly:

```text
artifact:
draft_note:
copied_source:
approved:
rejected:
deprecated:
merged:
graph:
report:
```

Only assert prefixes applicable to the current command. Assert no unexpected explanatory lines.

### CHAR-007: Error stderr prefixes

Assert handled failures begin with:

```text
ingest_text:
ingest_artifact:
review_queue:
export_graph:
generate_nous_report:
```

### CHAR-008: Handled failures expose no Ruby stack trace

Test representative invalid input for every script.

### CHAR-009: Default output roots

Verify current default locations under the repository vault using a safe alternative approach that does not persist fixture data there. Prefer checking help/documented resolution through an alternate temporary clone/root or invoking with `--vault-root` where supported.

Do not contaminate the real vault to prove a default.

### CHAR-010: Relative custom output semantics

Lock the current distinction between a path resolved from working directory and a path resolved from vault root, if the current scripts expose that behavior. Assert exact current behavior rather than redesigning it.

## 5. M2 Text Ingestion Baseline

Retain all existing tests and add only missing contracts.

### M2-BASE-001: Valid text import bytes

With fixed date, assert exact frontmatter fields, section headings, source content preservation, and deterministic IDs.

### M2-BASE-002: Markdown import

Assert title extraction and original Markdown preservation.

### M2-BASE-003: Duplicate suffix

Two same-date same-slug imports produce current `-2` behavior without overwrite.

### M2-BASE-004: Invalid inputs

Cover missing, directory, unsupported extension, empty, invalid UTF-8.

### M2-BASE-005: Existing source-path behavior

Lock the current M2 source-path representation without endorsing future agent traversal of it.

## 6. M6 Artifact Ingestion Baseline

Retain the full current M6 suite.

### M6-BASE-001: Type allowlists

Writing, image, text project, and binary project current cases pass.

### M6-BASE-002: Three coordinated outputs

Assert copied payload, artifact note, and inbox note paths/IDs share the collision suffix.

### M6-BASE-003: Source immutability

Bytes, basename, path, mode, size, and digest remain unchanged.

### M6-BASE-004: Portable provenance

No external absolute source path is serialized.

### M6-BASE-005: Binary interpretation boundary

Observed content is empty and no unsupported visible/person/emotion/theme assertion appears.

### M6-BASE-006: Rollback

Forced failure leaves no invocation-created final or temporary file.

## 7. Review Queue Baseline

Retain existing tests.

### REVIEW-BASE-001: List header and ordering

Assert current columns and sort semantics.

### REVIEW-BASE-002: Show is read-only

Assert output sections and byte-identical source file after show.

### REVIEW-BASE-003: Note approval routing

`--as` required; valid type moves to current typed directory with current metadata.

### REVIEW-BASE-004: Claim and relationship approval

Assert current canonical destinations.

### REVIEW-BASE-005: Reject/deprecate/merge

Assert current lifecycle and review metadata.

### REVIEW-BASE-006: Report bytes

For fixed review time and fixture, assert deterministic ordering and content.

### REVIEW-BASE-007: Edit behavior

Assert missing `$EDITOR` and configured editor behavior without launching a real interactive editor.

## 8. Graph Baseline

### GRAPH-BASE-001: Fixed-time byte identity

Generate twice and compare bytes.

### GRAPH-BASE-002: Reviewed-only discovery

Inbox/raw/retired absent.

### GRAPH-BASE-003: Validation

Duplicate IDs, invalid confidence, unsupported types, dangling endpoints, and malformed exportable records retain current errors and no-partial-output behavior.

### GRAPH-BASE-004: Deterministic labels/summaries/evidence

Assert current extraction, truncation, ordering, and deduplication.

## 9. Report Baseline

### REPORT-BASE-001: Fixed-time byte identity

Generate twice and compare bytes.

### REPORT-BASE-002: Fixed section order and empty states

Assert exact section sequence and `No reviewed records found.`

### REPORT-BASE-003: Reviewed-only discovery

Inbox/raw/retired/unsupported absent.

### REPORT-BASE-004: Record rendering

Assert ID, label, source, confidence, excerpt, evidence, and related-record context.

### REPORT-BASE-005: Validation/no replacement

Duplicate/malformed/invalid-time failure preserves previous output.

## 10. Repository Privacy Baseline

### PRIV-BASE-001: Fixture leak scan

Search repository vault and tracked/untracked files for:

- fixed fixture dates;
- fixture titles;
- temp directory prefixes;
- synthetic request IDs;
- secret-shaped fixture values.

Expected: no leak.

### PRIV-BASE-002: No new raw payload tracked

`git status --short` and `git diff --name-only` contain no imported fixture payload.

## 11. SDK Preflight Verification

These checks may be implemented in a temporary script and recorded in the preflight ADR. They are not the product MCP test suite.

### SDK-001: Official identity

Verify gem source/metadata points to the official Model Context Protocol Ruby SDK.

### SDK-002: Exact version and Ruby requirement

Record selected version and prove local runtime satisfies it.

### SDK-003: Dependency resolution

Temporary Bundler install succeeds; dependency tree is recorded; no repository dependency file changes.

### SDK-004: Minimal stdio startup

Server starts and remains alive for initialize/list/call.

### SDK-005: Protocol pin

Initialize negotiates the selected stable protocol exactly.

### SDK-006: Tools-only capability

No prompts/resources/roots/sampling capability is declared by the proof server.

### SDK-007: Structured result

Synthetic tool returns valid structured content and compatibility text content where the SDK/spec requires it.

### SDK-008: Raw framing

A raw JSON-RPC harness completes initialize, initialized, tools/list, and tools/call.

### SDK-009: Stdout purity

Every nonempty stdout frame is valid protocol JSON. No banner, warning, Bundler output, or debug text appears.

### SDK-010: Stderr diagnostics

Synthetic diagnostic goes to stderr and does not corrupt stdout.

### SDK-011: No listener

Process opens no TCP listener as part of stdio operation.

### SDK-012: No API key/network runtime requirement

After dependencies are installed, proof operation requires no model key and makes no outbound application call.

### SDK-013: Codex discovery

When available, Codex discovers the temporary server and calls the synthetic tool. Otherwise the ADR explicitly records this as not tested and why.

### SDK-014: Cleanup

Temporary server, Gemfile, lockfile, config, bundle path, and logs are removed or remain outside the repository.

## 12. Post-Change Verification Order

```sh
ruby scripts/test_cli_contracts.rb              # if added
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

Then perform SDK preflight and privacy audit.

## 13. Pass Conditions

- Every repository command exits zero.
- SDK proof passes or produces a precise blocking incompatibility report.
- No current product behavior changes.
- No product MCP/core code exists.
- No committed dependency file exists.
- No private/test payload leaks.
- ADRs accurately distinguish tested, inferred, and untested items.

## 14. Failure Triage

- Existing test fails before changes: stop M7A.
- Characterization contradicts existing direct test: prefer the more specific current product contract and document the inconsistency.
- SDK cannot install: stop and report runtime/version options.
- Raw client fails while SDK client succeeds: treat as protocol blocker.
- Codex discovery unavailable: do not block M7A if SDK/raw proof succeeds, but carry an explicit M7F gate.
- Any fixture touches repository vault: fail and clean immediately.
