# 0002. Keep Nous Core Below CLI and MCP Adapters

## Decision

Adopt M7 with a reusable Nous Core as the product backend beneath existing CLI adapters, the future local app adapter, and the future MCP adapter.

- Nous Core owns vault, lifecycle, provenance, safety, and review-boundary rules.
- MCP is an agent integration boundary, not the frontend/backend for ordinary product actions.
- Agent writes are candidate-only and remain subject to human review authority.
- The M7 MCP surface is local stdio and tools-only.
- Nous does not embed a model runtime or provider SDK for inference.

## Context

M7 adds an agent-facing interface to a file-first system whose main risks are behavior drift, private-data exposure, arbitrary file access, duplicate writes, and erosion of the human review boundary. The umbrella PRD and shared M7 contract both require business rules to live in the core so that existing CLIs, a future local app surface, and a later MCP adapter all enforce the same constraints.

This boundary also keeps MCP in its intended role. An external agent may read bounded vault data, preserve verbatim user text, and propose source-backed candidates, but it must not become the control plane for deterministic local UI actions or a path around review. M7A defines and verifies this architecture before M7B-M7F implement later stages.

## Consequences

- Existing scripts, a future local app adapter, and the future MCP adapter can share one authority for vault and lifecycle rules.
- Later MCP work must map to core operations instead of reimplementing business logic in protocol handlers.
- Agent-created records land in inbox/candidate states only; reviewed and canonical states remain human-controlled.
- Local-first/offline scope stays intact because Nous does not host model inference, network listeners, or remote API behavior.
- M7A can verify the boundary through characterization, ADRs, and SDK preflight without claiming that M7B-M7F implementation already exists.

## Alternatives Considered

- Use MCP as the main frontend/backend boundary for all future product actions.
  - Rejected because ordinary local app behavior should call the core through a deterministic local adapter, not through an LLM-controlled tool loop.
- Let the agent write directly to reviewed or canonical locations.
  - Rejected because it would collapse the human review boundary and weaken provenance and approval guarantees.
- Embed model/runtime concerns inside Nous.
  - Rejected because M7 is a local tools layer over vault rules, not an inference host or model orchestration runtime.

## Verification

- `.omx/plans/nous-m7-six-stage-draft/prd-m7-agent-ready-core-and-mcp.md` defines the core-as-backend, local-stdio, candidate-only, and no-model-runtime decisions.
- `.omx/plans/nous-m7-six-stage-draft/m7-shared-contract.md` assigns authority to the core, limits MCP to an adapter role, and preserves human review.
- `.omx/plans/nous-m7-six-stage-draft/m7-execution-map.md` places the product MCP server in M7F, not M7A-M7E.
- `.omx/plans/nous-m7-six-stage-draft/m7a-baseline-characterization-and-preflight-plan.md` requires this ADR in M7A and limits M7A to boundary/preflight verification rather than later-stage implementation.
