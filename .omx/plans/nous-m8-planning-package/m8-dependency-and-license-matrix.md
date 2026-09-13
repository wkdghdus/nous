# M8 Dependency and License Decision Matrix

Status: DRAFT FOR PRODUCT-OWNER REVIEW; NOT IMPLEMENTATION AUTHORIZATION

Prepared: 2026-09-12 (America/Toronto) | Baseline: `main@14e2a00` | Package: M8 draft 0.1

## Principle

Core remains dependency-free. New dependencies belong to isolated app adapter or UI/build/test boundaries. Existing pins are observed facts; proposed candidates are not installed or approved by this draft. A framework is not selected merely because a scaffolder uses it. Source/lock/license verification happens before adoption in M8A, then is rechecked at release.

## Observed repository lock and recorded license evidence

| Item | Observed version | Boundary | License evidence available here | Required action |
| --- | --- | --- | --- | --- |
| mcp | 1.5.1 | Existing MCP adapter | Apache-2.0 recorded in R20 | Preserve exact pin and schemas; revalidate source/lock. |
| base64 | 0.3.0 | Existing explicit runtime companion | Ruby OR BSD-2-Clause recorded in R20 | Preserve pin; do not drop because local Ruby happens to provide it. |
| json_schemer | 2.5.0 | Existing MCP dependency | MIT recorded in R20 | App may explicitly reuse approved version without importing MCP; document direct dependency if added. |
| bigdecimal | 4.1.2 | Existing transitive, native-build concern | Ruby OR BSD-2-Clause recorded in R20 | Test target Ruby/platform install; preserve lock absent approved change. |
| hana | 1.3.7 | Existing transitive | MIT recorded in R20 | Verify locked source and license. |
| regexp_parser | 2.12.0 | Existing transitive | MIT recorded in R20 | Verify locked source and license. |
| simpleidn | 0.3.0 | Existing transitive | MIT recorded in R20 | Verify locked source and license. |
| minitest | 5.25.4 | Existing test dependency | License not independently inspected in this session | Verify selected gemspec/license; do not guess approval. |
| Bundler | 2.6.3 | Existing lock tooling | Runtime/tool licensing not independently reviewed here | Use tested candidate with Ruby preflight; avoid accidental lock upgrades. |
| Ruby | 3.4.2 historically tested | Existing core/MCP runtime | R20 test record, not a support-range contract | Evaluate exact 3.4.10 candidate with complete regression. |

This table reports repository-recorded licenses, not legal advice or an independent legal approval. Pin and inspect every actual transitive dependency used by the final artifact.

## Proposed M8 additions

| Candidate | Purpose / owner stage | Proposed version decision | License/compatibility gate | Alternative / restriction |
| --- | --- | --- | --- | --- |
| Ruby 3.4.10 | Local runtime, A/H | Exact preflight candidate from official downloads | Full M7 + bridge regression on target Mac; record build and license | Do not infer support from gem >=2.7 or jump to Ruby 4. |
| Rack | Small application interface, B | Exact stable version selected/locked in A | Inspect upstream release/license and schema/request behavior | No Rails/Sinatra unless explicitly re-approved. |
| Puma | Bound loopback server, B | Exact stable version selected/locked in A | Native build, shutdown/thread/lock behavior, license/transitives | No hand-written HTTP parser or untested server defaults. |
| React / react-dom | UI rendering, C | Exact compatible releases frozen in A | Selected-release LICENSE, source provenance and offline build | No server-side React runtime or provider logic. |
| TypeScript | UI static checking, C | Exact release frozen in A | License and React/tool compatibility | No duplicated domain authority just because types exist. |
| Vite + React plugin | Static UI build/dev tooling, C | Exact compatible versions frozen in A | Node floor, selected-release license and clean build | Dev server is not the product runtime. |
| Node + npm | Build/test tooling, A/C | Exact supported installed versions recorded in A | Match selected Vite/test tools; pin reproducible install process | No mandatory Node server in prepared runtime. |
| Vitest + Testing Library + DOM environment | UI/component tests, C | Exact compatible set frozen in A | Licenses, lock/transitives, no content telemetry | Mocks do not replace real-core E2E. |
| Playwright | Browser E2E, C/H | Exact package/browser set frozen in A | License, browser binary setup and target-browser manual gaps | Tests do not auto-download browsers during offline runtime checks. |
| Markdown renderer/sanitizer | Safe record/report rendering, C/F | Choose smallest maintained compatible pair in A | License, raw-HTML disable, URL policy and adversarial browser tests | No raw HTML passthrough; do not write a bespoke sanitizer. |
| Graph visualization library | Optional implementation aid, F | None by default; prefer simple bounded SVG/table | A new package requires separate justification/license review | No large graph stack, external layout service or graph database. |
| OS native picker helper | Vault selection, A/B | Use installed OS primitive after spike | Fixed arguments, cancellation, no interpolation and target-platform proof | Not a CLI business wrapper and not required by core. |

Unknown version/license cells are deliberate M8A adoption gates, not floating dependencies authorized for production. No exact untested versions are invented in this draft. Store approved exact versions in the relevant lockfile only when the implementation stage is authorized.

## Required dependency preflight record

For each direct/transitive addition record package/source identity, exact release, checksum/lock integrity, license file and notices, purpose, owner boundary, supported runtime, native build needs, install scripts, outbound runtime behavior and removal path. Review registry changes before install. Preserve MCP pins unless an explicitly approved compatibility change proves the old suite again.

Application gems are loaded only by app entrypoints. UI dependency tree stays under `apps/local-ui/`; root package.json remains disallowed unless a later owner decision changes it. No provider SDK, analytics, crash uploader, vector database, desktop wrapper or auto-updater is in the approved default set.

## License and release acceptance

The final preview includes required upstream notices and a reproducible dependency list. A source README or remembered common license is not enough for an unreviewed selected release. An unknown/incompatible license or native build failure blocks that dependency; it does not authorize a silent replacement with another package. Source references: R09/R20 and E01-E03/E09-E10.
