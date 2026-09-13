# M8 Architecture Decision and Alternatives

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## ADR-M8-001: First product shell

**Status: Proposed M8 decision.** Select a local browser application for the first developer preview. Build the UI with React and TypeScript using Vite; serve its static output from a thin Ruby application adapter. The adapter calls Nous Core directly. Keep the MCP stdio process separate and unchanged.

```text
                    Local browser: static React/TypeScript UI
                                      |
                       authenticated same-origin loopback HTTP
                                      |
                Ruby app adapter + native vault chooser + sessions
                                      |
CLI adapters -------------------- Nous Core -------------------- MCP stdio
                                      |                            |
                       authoritative portable vault          external client
```

The app adapter can load HTTP dependencies. `require "nous"` must not load HTTP, React, MCP or provider dependencies or start a listener. The core receives explicit vault/time/operation inputs and returns domain results.

### Shell decision matrix

This is qualitative planning judgment, not a benchmark.

| Criterion | Browser + Ruby adapter | Desktop web wrapper | Obsidian plugin | Fully native app |
| --- | --- | --- | --- | --- |
| Reuse existing Ruby core | Direct in backend process | Sidecar/RPC bridge needed | Separate Ruby process bridge needed | Bindings/process bridge needed |
| Filesystem boundary | Native vault chooser plus bounded uploads | Native dialogs available, privileged wrapper to secure | Plugin has host filesystem capabilities to constrain | Native access to constrain |
| Initial packaging | Prepared Ruby + static build + launcher | Bundle wrapper and Ruby, process supervision and signing | Obsidian dependency plus plugin/Ruby deployment | New UI stack and Ruby distribution |
| Apple Silicon proof | Runtime/server/native helper spike | Wrapper plus Ruby binary spike | Obsidian and external process proof | Native build/toolchain proof |
| Offline operation | Required after setup | Possible, must prove | Depends on installed Obsidian/plugin | Possible, must prove |
| UI/test iteration | Reusable browser tooling | Browser tooling plus desktop integration | Host-specific UI/E2E tests | Separate native testing investment |
| Obsidian closed | Yes | Yes | No | Yes |
| Windows/Linux path | Replace picker/launcher adapters later | Cross-platform packaging later | Host support plus per-OS Ruby | Additional native work |
| Main risk | Local HTTP and launcher boundaries | Privilege, bundle/update/signing complexity | Host coupling and bypassing core | Duplicating effort before UX is proven |
| Decision | Select for developer preview | Defer | Reject as primary M8 shell | Reject for current stage |

Tauri documents external binary sidecars, but that does not prove a complete Ruby bundle. Electron adds a privileged desktop security boundary. Those are reasons to defer a packaging choice, not claims that either framework is unsuitable forever. Obsidian remains interoperable with the vault and is not removed. [E05-E06]

### Vite versus Next.js

Both can produce static output. Vite supplies a React/TypeScript build path that fits the proposed single local Ruby origin. Next.js static export is technically viable; its server conventions, data-fetching choices and application routing machinery do not solve an M8 requirement that needs a second application server. Prefer the smaller deployment contract, not a fashionable framework. No Next.js server actions, API routes, SSR or Node production process are introduced. [E01-E02]

## ADR-M8-002: Transport

**Status: Proposed M8 decision.** Choose same-origin loopback HTTP, using a minimal Rack-compatible adapter and a pinned Puma server after M8A proves compatibility. Do not hand-roll HTTP parsing, use a production Vite dev server or silently select a server's default bind address.

| Alternative | Strength | Cost for this product | Decision |
| --- | --- | --- | --- |
| Loopback HTTP | Browser-native structured requests; independently testable; direct Ruby core calls | Host/origin/token/CSRF and size limits must be implemented | Select |
| Unix-domain socket | OS filesystem permission boundary; suitable local-process channel | Ordinary browser cannot directly use it; requires another bridge | Defer to a future desktop wrapper |
| Embedded Ruby bindings | Potentially one native process | Runtime ownership and portability risk before UI value exists | Reject for M8 |
| Desktop sidecar RPC | Good future wrapper boundary | Requires desktop-shell choice and packaging work now | Defer |
| MCP as UI backend | Existing agent protocol | Wrong human authority, tool surface and dependency boundary | Prohibited |
| CLI subprocesses | Superficially quick to prototype | Parses human output, duplicates error handling, violates inherited core boundary | Prohibited |

Rack/Puma names are proposed dependencies; no versions have been installed or verified in this session. M8A must select exact releases, inspect licenses/transitives, run the bridge and record native-build risks. Failure stops production adoption; it does not authorize a secret server replacement. [E09-E10]

## ADR-M8-003: Vault and file selection

A browser-selected file does not provide a trusted absolute path. Do not send the file input value to `ArtifactIngestion.ingest`. Choose an existing vault through a narrow backend native-folder dialog that returns an opaque handle to the UI. The app adapter resolves that handle server-side, and core validates the original selected root reference without creating it. Do not canonicalize away a symlink before the inherited root-symlink check. On macOS, prove a fixed OS-folder chooser helper; shell interpolation and caller-supplied scripts are forbidden. [E04/E07]

For imports, a standard browser file picker sends one selected file's bytes and basename. Add a human-import core operation accepting a bounded source descriptor/IO, not a browser pathname. Reuse M6 pure rendering/allocation/copy-validation helpers while retaining CLI behavior. No arbitrary local-file read API is exposed. The native helper is an app adapter, not a core dependency or a business CLI wrapper.

## ADR-M8-004: Runtime and release artifact

Historical repository evidence tested Ruby 3.4.2 and Bundler 2.6.3. The proposed new exact Ruby validation candidate is **3.4.10**, which the official downloads page listed during this review. It is not yet a supported Nous runtime. M8A must rerun M7 plus bridge checks with that Ruby and Bundler 2.6.3. Do not jump to Ruby 4 merely because it is newer. [R09/R20/E03]

Record exact Node, npm, Vite, React, TypeScript, Rack and Puma versions during M8A, then pin them when their stage adopts them. Vite's published Node floor is a compatibility lead, not permission to declare every higher version supported. Node/npm are build/test tools; the prepared application's normal runtime is Ruby plus a browser, not a Node server. Bundler must not silently update the existing MCP lock during app adoption.

The initial delivered artifact is a documented source/developer-preview bundle with static assets and a launcher. A launcher can open/reopen the app without routine terminal commands after setup; it does not make the bundle a self-contained signed installer. No system-wide daemon, login item, automatic updater, global client config edit or background autonomous task is installed.

## ADR-M8-005: State and storage

Vault records remain authoritative. Frontend record caches, query results, cursors and unsaved drafts are memory-only and keyed by vault epoch. Optional recent-vault settings live outside the repository/vault in owner-only local settings, with consent. No sensitive browser storage or service worker is permitted. Core-owned transaction journals are temporary and private; app receipt/history metadata is optional in records. Their exact shapes are in the core-gap and adapter contracts and need explicit approval.

## ADR-M8-006: External changes and editing

Use explicit refresh, focus refresh and a measured visible-tab polling interval before adopting a watcher dependency. Poll only to invalidate/reload; never ingest or interpret. Authoritative hashes and under-lock preconditions guard mutations. The app does not claim to lock out noncooperating editors. M8 edits pending candidate bodies/type only. Accepted-record editing and deprecation remain a future decision, not a hidden extension of pending-only review methods.

## ADR-M8-007: Derived views and agent workspace

Manual generation first. Display the existing report, not a rewritten product thesis. Add a bounded read-only graph plus table in M8F; no graph edits. Output freshness needs input/output fingerprints, not file existence or wall-clock guesses. Integrated agent chat is **Deferred future scope: M9**. M8H documents the external-client handoff and tests real MCP interoperability, without conversation storage, provider ownership or fabricated live connection status.

## Product decisions requiring approval

| Decision | Draft default | Classification |
| --- | --- | --- |
| First platform | macOS Apple Silicon, exact supported OS/browser versions recorded by preflight | Proposed M8 decision |
| Shell | Local browser developer preview | Proposed M8 decision |
| UI | React + TypeScript + Vite | Proposed M8 decision |
| Transport | Loopback same-origin HTTP; Rack/Puma after spike | Proposed M8 decision |
| Local Ruby | Required; test 3.4.10 first | Proposed M8 decision |
| Vaults | One active; consented recent-vault switching | Proposed M8 decision |
| New-vault initialization | Not in M8 | Deferred future scope |
| Integrated chat | M9; no placeholder provider layer | Deferred future scope |
| Provider credentials | External client only in M8 | Binding M8 boundary from handoff |
| Conversation history | No integrated conversation store | Deferred future scope |
| In-app editing | Pending candidate body and candidate type only | Proposed M8 decision |
| Review deprecation | Pending inbox items only; no general accepted-record mutation | Proposed M8 decision |
| Derived refresh | Manual, with freshness/error visibility | Proposed M8 decision |
| Graph | Bounded read-only late stage plus table | Proposed M8 decision |
| Search | Deterministic lexical plus metadata filters | Binding M8 scope from handoff |
| Watcher | Poll/invalidate only | Proposed M8 decision |
| Telemetry | None | Binding M8 boundary from handoff |
| Non-developer installer | Deferred; do not advertise one | Proposed M8 decision |
| Receipts/history/recovery guards | Optional additive metadata and narrow core transaction state | Open product approval: consequential compatibility extension |

None of these defaults has been represented as an answer already supplied by the owner. The most consequential approvals are the browser/runtime choice and the new app mutation metadata/recovery contract. Technical version pins and measured budgets are M8A outputs; no downstream stage can begin with an unresolved incompatible runtime.

References: H01, R03-R09, R13-R27, E01-E10 in `m8-source-evidence-register.md`.
