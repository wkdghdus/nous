# M8 Risk Register

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## Risk interpretation

Severity is a planning prioritization, not a statement that the defect already exists. Current implementation observations are cited in the source/core-gap registers. Every mitigation below is required future verification, not a completed fix.

| ID | Severity | Trigger / risk | Owner | Mitigation and evidence | Stop/escalation rule |
| --- | --- | --- | --- | --- | --- |
| RISK-01 | Critical | M7F acceptance inferred from source or old echo proof | M8A | Fresh full suite, actual intended clients, lifecycle and independent evidence at the target SHA. | Missing release evidence blocks new product implementation. |
| RISK-02 | Critical | Active/uncommitted Gajae recovery work is duplicated or reset | M8A/all | Inspect durable Coordinator/session/worktree state; preserve unknown changes; one authorized stage/checkpoint. | Unknown active work blocks duplicate dispatch, not offline draft review. |
| RISK-03 | Critical | App requests bypass core review/path/lock rules | M8B-E | Thin adapter, structured direct core operations, negative tests and independent diff review. | Any bypass blocks the stage; no CLI/MCP shortcut. |
| RISK-04 | Critical | A hostile webpage can read/mutate the local vault | M8B/H | Exact loopback/Host/Origin, private capability, no wildcard CORS, strict schemas, request bounds and hostile-origin tests. | Any unauthorized private read or mutation blocks release. |
| RISK-05 | High | Browser file input is mistaken for a trustworthy local path | M8A/D | Native vault capability plus uploaded File bytes; validated source descriptor and server-owned destinations. | No arbitrary workstation path field or fakepath-to-ingest call. |
| RISK-06 | High | App capture falsely claims MCP origin or breaks exact extraction | M8D | Separate app receipt namespace and optional app capture channel; reuse neutral helpers; preserve M7 projection/digests. | MCP byte/schema regression or changed raw text blocks D. |
| RISK-07 | Critical | Lost response duplicates import or review action | M8D/E | Durable receipt owner, exact-key retry, current-ID reconciliation and unknown-outcome UI. | Any duplicate effect under supported retry conditions blocks writes. |
| RISK-08 | Critical | Process death exposes partial import/approval/merge state | M8D/E/H | Narrow persisted manifests, updated-core guards, explicit hash-checked recovery and real kill tests. | Never claim exception rollback proves crash safety. |
| RISK-09 | Critical | Recovery overwrites an external newer edit | M8D/E | Before/after hashes, owned-file proof, preserve divergent copies and require manual reconciliation. | Ambiguous bytes stop recovery; no broad cleanup. |
| RISK-10 | High | Old loaded CLI/MCP code ignores new recovery state | M8D/H | Support same-release adapters; document/recheck process restart before app writes; test current-release guard behavior. | Do not advertise arbitrary mixed-version process compatibility. |
| RISK-11 | High | Truncated/normalized read is saved as the entire candidate | M8B/E | Complete edit envelope, raw-byte version and oversized read-only mode; round-trip adversarial legacy records. | Incomplete editor input cannot be submitted. |
| RISK-12 | Critical | Cached readiness or stale source/target causes wrong approval | M8E | Under-lock unique-ID/hash/lifecycle/endpoint checks; inspect both merge participants; preserve unsaved draft. | Known stale or dangling approval must change zero product files. |
| RISK-13 | High | New history metadata invents old decisions or loses provenance | M8D/E | Optional forward-only app events; preserve generation/source/unknown frontmatter; label legacy history unavailable. | No fabricated timeline or missing evidence accepted. |
| RISK-14 | High | Generated file existence is labeled current knowledge | M8F | Input/generator/output fingerprints; unknown legacy/torn state; core eligibility plus schema check. | Unknown/stale graph is not displayed as current accepted knowledge. |
| RISK-15 | Critical | Private records leak via Markdown, logs, browser storage or testing | All/H | Disable active HTML/remote embeds, no-store, memory-only bodies, synthetic fixtures, network/storage/log scans. | Any real-data/secret leak blocks and requires containment. |
| RISK-16 | High | Native dependency or Ruby bundle scope derails the product | M8A/H | Exact runtime/server preflight and honest developer-preview packaging; isolate app dependencies. | No unsupported installer/platform claim; do not secretly change stack. |
| RISK-17 | Medium | 10k-record scan/poll or graph exceeds interactive budgets | M8B/C/F/H | Measure documented datasets/hardware; bound pages/rendering; pause hidden-tab polls; preserve authoritative checks. | Revise approved polling budget or defer polish, not stale-write checks. |
| RISK-18 | High | New runtime tooling weakens repository hygiene | M8B/C | Scoped manifest policy, pinned lockfiles, all signposts and old lint checks preserved; no nested-manifest evasion. | Fail unexplained dependency/policy change. |
| RISK-19 | High | Chat, semantic search or desktop packaging expands into every stage | M8A/all | M9 chat deferral, explicit non-goals, current-stage-only handoffs and owner-approved change control. | Stop scope drift; do not land unused provider abstractions. |
| RISK-20 | Medium | Unsaved browser text is lost despite implied autosave | M8C/D/E | Memory-only draft warning, navigation confirmation, preserve live draft on conflicts; no promise after tab crash. | A future encrypted draft store is a separate approved feature. |

## Residual risks that must remain explicit

Local capability/Origin protection is not protection from malware or a privileged browser extension acting as the same OS user. An external editor ignoring advisory locks can still race a final write instruction; the preview promises tested cooperating-interface serialization plus detected-stale conflict protection, not universal filesystem isolation. Replaying a key depends on retaining its receipt-bearing records; manual receipt deletion or a vault rollback requires reconciliation. Process-death tests alone do not prove power-loss behavior on every filesystem.

These limitations must appear in release/setup documentation. They are not excuses to omit the mandatory supported-case tests or to weaken path confinement, source preservation and human review authority.

## Change trigger

A new source, dependency, user goal, runtime incompatibility or failed gate can change risk severity. Update the PRD/shared/API/stage/test/matrix together if mitigation changes behavior. Do not append a workaround only to a session summary. The owner, not the implementation agent, accepts consequential scope or compatibility changes.
