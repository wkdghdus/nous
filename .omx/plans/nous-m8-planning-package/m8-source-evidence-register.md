# M8 Source and Evidence Register

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## How to interpret evidence

**Binding inherited contract** means a current instruction or inherited product boundary that M8 must preserve. **Verified current implementation fact** means a fact observed in the pinned source, not a claim that its tests passed. **Proposed M8 decision** is new design requiring approval. **Open product question** remains unresolved. **Deferred future scope** is not implementation authorization.

Repository observations refer only to `14e2a00af439024be853d4aba47acd7184829de5`. Newer commits, a laptop worktree, a local recovery branch and an active Coordinator session may differ. Links below are immutable commit permalinks. A source reference such as R13 elsewhere in this package refers to this register.

The user-supplied `m8-app-planning-agent-handoff(2).md` is the primary planning request (H01). It authorizes a draft, not code changes. Its SHA-256 is `dc2926a1870d3f0cc2d52ff15016022d03ea7843e66bd1d546dd03898fb0c994`.

## Repository coverage

| Ref | Source | Inspection coverage | What it supports |
| --- | --- | --- | --- |
| R01 | [AGENT.md](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/AGENT.md) | Read | Root engineering and current product guardrails. |
| R02 | [nous_requirements_and_user_flows.md](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/nous_requirements_and_user_flows.md) | Partial | Original v0.1 product thesis, requirements, and broad future scope; later portions not exhaustively inspected. |
| R03 | [README.md](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/README.md) | Read | Operator capabilities, exact MCP tools, M6 allowlists and review/output behavior. |
| R04 | [docs/architecture/vault-schema.md](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/docs/architecture/vault-schema.md) | Read | Implemented lifecycle, provenance, review, filesystem, graph/report and candidate contracts. |
| R05 | [schemas/note-frontmatter.schema.yaml](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/schemas/note-frontmatter.schema.yaml) | Read | Version 0.1 descriptive frontmatter schema; optional generation and review metadata. |
| R06 | [schemas/graph.schema.json](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/schemas/graph.schema.json) | Read | Strict graph JSON shape; shape alone does not establish reviewed lifecycle eligibility. |
| R07 | [Makefile](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/Makefile) | Read | Eleven current test programs and aggregate targets. |
| R08 | [scripts/lint.sh](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/scripts/lint.sh) | Read | Root package.json prohibition, text/schema checks, directory signposts. |
| R09 | [Gemfile.lock](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/Gemfile.lock) | Read | Pinned MCP dependency tree and Bundler version; not a Ruby-version support declaration. |
| R10 | [lib/nous.rb](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/lib/nous.rb) | Partial | Require wiring, graph setup, shared records, and review inspection sections; not every builder line. |
| R11 | [lib/nous/agent_reads.rb](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/lib/nous/agent_reads.rb) | Partial | Public operations, bounds, source extraction/status and source/envelope sanitization through line 500; tail not fully inspected. |
| R12 | [lib/nous/candidate_writes.rb](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/lib/nous/candidate_writes.rb) | Partial | Capture/proposals and persistence/replay sections through line 280 and lines 360-640. |
| R13 | [lib/nous/review_mutation.rb](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/lib/nous/review_mutation.rb) | Read | Pending review actions, routing, merge behavior, edit-path resolution, exception rollback. |
| R14 | [lib/nous/artifact_ingestion.rb](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/lib/nous/artifact_ingestion.rb) | Partial | Import public operation, validation, transaction and provenance through line 210. |
| R15 | [lib/nous/file_transaction.rb](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/lib/nous/file_transaction.rb) | Read | In-memory staging/finalization tracking and handled-error rollback. |
| R16 | [lib/nous/idempotency.rb](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/lib/nous/idempotency.rb) | Read | MCP generation-based replay, operation allowlist and interface validation. |
| R17 | [lib/nous/path_guard.rb](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/lib/nous/path_guard.rb) | Read | Root and component symlink rejection, confinement, operator source validation. |
| R18 | [lib/nous/mcp/server.rb](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/lib/nous/mcp/server.rb) | Read | Explicit protocol, tools-only configuration and successful result validation. |
| R19 | [scripts/test_nous_mcp.rb](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/scripts/test_nous_mcp.rb) | Partial | Real-server harness and exact input/output assertions through line 110; not executed. |
| R20 | [docs/decisions/0003-mcp-ruby-sdk-preflight.md](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/docs/decisions/0003-mcp-ruby-sdk-preflight.md) | Read | Historical Ruby 3.4.2/Bundler 2.6.3 and SDK evidence; explicitly does not close every release gate. |
| R21 | [docs/agent/mcp-setup.md](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/docs/agent/mcp-setup.md) | Read | Current setup and version-dependent client verification instructions, not proof of all client gates. |
| R22 | [.omx/plans/nous-m7-six-stage-draft/prd-m7-agent-ready-core-and-mcp.md](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/.omx/plans/nous-m7-six-stage-draft/prd-m7-agent-ready-core-and-mcp.md) | Partial | Umbrella objective, six stages and source-of-truth decisions through line 140. |
| R23 | [.omx/plans/nous-m7-six-stage-draft/m7-shared-contract.md](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/.omx/plans/nous-m7-six-stage-draft/m7-shared-contract.md) | Read | Core/CLI/MCP boundary, lifecycle, safety, errors, idempotency and change control. |
| R24 | [.omx/plans/nous-m7-six-stage-draft/m7-execution-map.md](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/.omx/plans/nous-m7-six-stage-draft/m7-execution-map.md) | Read | M7 dependencies and final release gates; M8 entry conditions. |
| R25 | [.omx/plans/nous-m7-six-stage-draft/m7-final-acceptance-matrix.md](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/.omx/plans/nous-m7-six-stage-draft/m7-final-acceptance-matrix.md) | Read | Complete M7 acceptance categories and independent/manual requirements. |
| R26 | [.omx/plans/nous-m7-six-stage-draft/m7f-mcp-adapter-and-release-plan.md](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/.omx/plans/nous-m7-six-stage-draft/m7f-mcp-adapter-and-release-plan.md) | Substantial | Scope, mapping, tests, release gates; final command tail was truncated. |
| R27 | [.omx/plans/nous-m7-six-stage-draft/test-spec-m7f-mcp-adapter-and-release.md](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/.omx/plans/nous-m7-six-stage-draft/test-spec-m7f-mcp-adapter-and-release.md) | Read | Inspector, Codex, raw/SDK protocol, privacy and lifecycle gates. |
| R28 | [.omx/plans/AGENT.md](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/.omx/plans/AGENT.md) | Read | Existing planning index; append-only proposed additions supplied separately. |
| R29 | [scripts/AGENT.md](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/scripts/AGENT.md) | Read | Dependency-free CLI policy with narrow MCP exception; requires intentional app-runtime exception. |
| R30 | [lib/AGENT.md](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/lib/AGENT.md) | Read | Core remains dependency-free and adapter dependencies isolated. |
| R31 | [lib/nous/AGENT.md](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/lib/nous/AGENT.md) | Read | Core ownership and no network, provider or editor/shell execution. |
| R32 | [docs/architecture/AGENT.md](https://github.com/wkdghdus/nous/blob/14e2a00af439024be853d4aba47acd7184829de5/docs/architecture/AGENT.md) | Read | Architecture documentation signpost. |

## Coverage deliberately not overstated

The complete source pack was not exhaustively read. Earlier M7A-M7E plan/test leaves, the M7 execution-handoffs file, all implementation/test programs, several directory-local AGENT files and the remainder of the partially inspected files must be read in M8A before any implementation. The recursive tree and Makefile establish discovery leads, not successful verification. M8A must resolve every actual directory instruction for its own worktree.

## External architecture references

Research date: 2026-09-12. These references inform alternatives only. They do not alter the vault contract or prove platform compatibility.

| Ref | Primary documentation | Planning use |
| --- | --- | --- |
| E01 | [Vite guide](https://vite.dev/guide/) | Static build output and React/TypeScript template; documented Node floor is not an exact approved toolchain. |
| E02 | [Next.js static exports](https://nextjs.org/docs/app/guides/static-exports) | Next.js also supports static output; rejection is about unnecessary application conventions, not inability to deploy statically. |
| E03 | [Ruby downloads](https://www.ruby-lang.org/en/downloads/) | Ruby 3.4.10 was listed when researched; proposed M8 runtime, not tested against Nous in this session. |
| E04 | [MDN file input](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input/file) | File input exposes user-selected File objects, not a trusted absolute workstation path. |
| E05 | [Tauri sidecars](https://v2.tauri.app/develop/sidecar/) | External binary sidecars are possible; this is not a Ruby-bundling proof. |
| E06 | [Electron security](https://www.electronjs.org/docs/latest/tutorial/security) | Desktop wrapper introduces an additional privileged security boundary. |
| E07 | [Apple AppleScript commands](https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/reference/ASLR_cmds.html) | Native folder-selection primitive; local helper feasibility still requires a macOS spike. |
| E08 | [MDN Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP) | Reference for proposed browser content restrictions; security tests remain required. |
| E09 | [Rack project](https://github.com/rack/rack) | Candidate Ruby HTTP application interface; exact version and license must be recorded from the selected release. |
| E10 | [Puma project](https://github.com/puma/puma) | Candidate Ruby server; local native build and threading behavior require preflight. |

## Execution evidence

No Nous product tests were executed in this session. The sandbox has Ruby 3.3.8 on Linux and no `bundle` command. Public GitHub content was readable through the GitHub connector; a local clone failed because the execution environment could not resolve GitHub. Archive download attempts did not provide a runnable checkout. No workaround altered source or dependency pins.

The commit status query returned an empty `statuses` list. This is not proof that every possible CI/check-run source is empty or failed, and is not a green test result. Gajae Coordinator durable status could not be accessed; searching for the integration returned no available plugin. Active work is **unknown**, not absent.

Only planning-file consistency checks described in `m8-package-validation.md` are run locally. They are not M7 or M8 application verification.
