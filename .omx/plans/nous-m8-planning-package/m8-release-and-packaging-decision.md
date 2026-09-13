# M8 Release and Packaging Decision

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## Decision

**Proposed release: macOS Apple Silicon local-browser developer preview.** One-time developer setup supplies the approved Ruby/Bundler runtime, locked gems, built static frontend and browser. Daily use begins from a launcher. This is not a self-contained signed/notarized desktop installer, a hosted web application or an automatically running service.

A future desktop wrapper/Ruby bundle must pass a separate packaging spike on the target platform before being promised. The browser preview establishes the capture-review product loop first. M9 agent chat is independent of that packaging decision.

## Runtime versus build requirements

The prepared runtime uses Ruby, installed app gems and a supported browser. Node/npm are build/test prerequisites, not a second production server. The first runtime candidate is Ruby 3.4.10 with Bundler 2.6.3; support is conditional on M8A evidence, not granted by this sentence. Record exact macOS/architecture/browser and dependency versions at release. Do not claim Windows/Linux or every Ruby/browser version works.

Default browser compatibility candidates are the target Mac's supported Safari and Chrome versions. M8A records their exact versions and feasibility; M8H must test every browser advertised as supported. Playwright WebKit alone does not prove the native Safari chooser/launcher flow. Unsupported browser detection should explain the tested matrix, not silently weaken security to make it work.

## Prepared startup flow

The launcher verifies its own release/build identity, approved runtime, required locked gems and built static assets. It starts the Ruby adapter with fixed arguments, checks an actual bound loopback listener and safe readiness response, then opens the one-use bootstrap URL. It must not log private roots/tokens or mutate shell startup files. Opening again reuses only a proven owned instance and issues a fresh nonce; an occupied unrelated port is not trusted.

After launch the user selects an existing vault through the native dialog. No terminal command is required for ordinary capture/import/review/browsing/generation. The launcher may be a developer-oriented `.command` file; name it honestly and document initial permissions/quarantine behavior after testing rather than claiming installer polish.

## Process lifecycle

A tab closing does not prove a mutation should be cancelled and must not kill a committing backend. The UI has an explicit Quit action. The backend stops admitting new writes, respects the current commit barrier, records unresolved recovery state when necessary, revokes capabilities and exits. A reconnect/restart does not blindly replay an unknown mutation or reuse an old token.

No automatic infinite restart loop, background model work, login item or scheduled task. External MCP clients run separately; the app does not kill them. All concurrent adapters must use the same approved release so interrupted-app-transaction guards are present. Setup/release notes explicitly require restarting previously loaded MCP/CLI processes after upgrading core.

## Recovery and upgrade

No automatic vault migration in M8. Open unsupported schemas in an explicit blocked/read-only diagnostic state as validated by the core, not with best-effort writes. Optional app metadata remains readable without the app and is never removed by an upgrade/downgrade script. A rollback of code must preserve committed evidence, review decisions, receipts and unresolved recovery manifests.

Upgrade is manual: stop writes, reconcile any interrupted operation, record current vault backup/version under the owner's normal backup practice, install the approved new build/dependencies, restart all participating adapters and rerun health. Do not implement an in-app Git pull or background updater. A backup operation is not silently added to the source pipeline.

## Artifact contents

The developer-preview artifact should contain the approved application source/build identity, static UI assets, launch/setup/quit/removal instructions, dependency lockfiles/notices and artifact checksums. It must not contain a personal vault, provider key, live session token, recent-vault file, upload spool, recovery backup, arbitrary runtime log, node_modules/vendor tree unless explicitly justified for the chosen distribution, or real-data screenshots.

Document which dependencies must be installed first. A source ZIP that downloads dependencies on first setup is not an offline installer. Demonstrate offline deterministic runtime only after setup is complete. H validates the actual assembled artifact, not only a dev checkout with ambient dependencies.

## Removal

Stop the owned app process. With explicit user consent remove app installation/build/runtime settings and recent-vault aliases only. Never delete the selected vault, source payloads, accepted records or metadata. Uninstall must not remove another user's process, all Ruby processes, global client configuration or the shared vault lock pathname to force shutdown.

## Release gate

Every row in `m8-final-acceptance-matrix.md` has final-SHA evidence. The full built-artifact workflow, offline/no-agent mode, real external-MCP interoperability, secure loopback boundary, crash/retry/conflict behavior and accessibility/performance budgets are demonstrated on declared platforms. Independent verifier signs off; owner separately authorizes release/merge.

If packaged distribution is later required for non-developers, create a separate approved spike covering Ruby/gems/native dependencies, Tauri/Electron/native choices, signing/notarization, bundle update/removal, permissions and a clean-machine test. Do not relabel this preview as that deliverable.
