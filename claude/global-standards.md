# Global Coding Standards — My Safe Spaces Platform

These standards apply to ALL new code across all MSS repositories.

> **Cross-repo architecture reference**: See `.github/docs/platform-architecture.md` (source of truth) for repo map, integration points, backend service inventory, shared patterns (email, uploads, CSV, RBAC), and the checklist for adding new modules end-to-end.

## Workflow

- **Inspect first** — read existing files to understand conventions, utilities, and abstractions before changing anything
- Reuse existing helpers, hooks, services, and patterns — don't reinvent what exists
- Match naming, formatting, and style of the surrounding code — but do not copy bad architecture or anti-patterns
- Make the **smallest possible change** that satisfies the request
- Do not refactor, reformat, or rename beyond what was requested
- If unsure about approach or requirements, ask concise clarifying questions — do not guess or fabricate behavior
- If a request introduces technical debt, security risk, or architectural inconsistency — call it out and propose a safer alternative
- **After responding to a request**, proactively highlight what may be missing — gaps, edge cases, overlooked concerns, or a better approach. Be concise and actionable, not hypothetical.
- **Update user guides** — when modifying a module that has a user guide (in `docs/user-guides/`), update the guide to reflect the changes.
- **Communication style**: concise and direct. No filler, no over-explaining.

## Language & Types

- **TypeScript** for all new files (backend and frontend). No new `.js` files.
- Strict mode (`"strict": true`), no `any` — use `unknown` and narrow, or define proper types
- Export types/interfaces from dedicated `types.ts` files
- `const` by default, `let` only when needed, never `var`

## Validation & Error Handling

- **Zod** for all external input validation (API requests, form data, URL params, env vars)
- Define schemas once in shared libraries, import everywhere
- Validate at system boundaries — internal functions trust typed args
- Typed error classes extending `Error` (e.g., `ValidationError`, `NotFoundError`, `ConflictError`)
- Structured JSON error responses: `{ error: { code, message, details? } }`
- No bare `console.log` — all logs must be structured JSON objects (not bare strings). Use `console.error`/`console.warn`/`console.info` by severity. Migrate to shared logger when available (see backlog).
- Never swallow errors — log and re-throw or return error response
- try/catch at handler level, not scattered throughout business logic
- Explicitly handle: `null`/`undefined`, empty collections, failed external calls

## Testing

- **Jest** for all test suites
- **Tests must catch issues before the user does** — if tests pass but the app breaks, the tests are wrong. A passing test suite should mean the feature actually works end-to-end.
- **Test real behavior, not mocked fantasies** — if a test mocks so much that it can't fail when the real code is broken, it's useless. Mock only external boundaries (DB, network, third-party APIs), not internal modules or the code under test.
- **Test the contract, not the implementation** — test inputs → outputs and side effects, not how the code is structured internally. This allows safe refactoring.
- **Test failure modes** — don't just test the happy path. Test what happens with missing fields, invalid input, null values, empty arrays, network errors, and auth failures. These are what break in production.
- **Integration tests for API handlers** — test the actual handler with realistic event objects, not just the helper functions in isolation. Verify status codes, response shapes, headers (CORS), and error responses.
- Unit tests for business logic with real (not mocked) dependencies where feasible
- Colocated `*.test.ts` or `__tests__/` directory
- Cover critical paths — don't test trivial getters/setters
- When adding behavior: add tests that cover the change, including edge cases that could break in production
- When modifying behavior: walk through what tests need to change and why before modifying them
- Prefer existing test frameworks and patterns — don't introduce snapshot tests unless already used
- If tests are missing or unclear, explain what should be tested rather than inventing arbitrary tests

## Code Organization

- **Single responsibility** — each file/module does one thing
- Keep files under 300 lines — split into focused modules if larger
- Group by feature, not by file type (e.g., `scheduling/` not `controllers/`)
- Break down large pages into composed components
- Extract shared logic into hooks (frontend) or utility modules (backend)
- Don't copy-paste between services — shared code belongs in shared libs (`mss-journipro-core`, `mss-scheduling-core`)

## API Design

- RESTful: GET (read), POST (create/action), PUT/PATCH (update), DELETE (remove)
- Consistent response shape: `{ data }` for success, `{ error: { code, message } }` for failure
- Correct HTTP status codes (200, 201, 400, 401, 403, 404, 409, 500)
- Parameterized SQL queries — never string interpolation
- Paginate list endpoints (limit/offset or cursor-based)

## Frontend Patterns

- Functional components with hooks, no class components
- React Query for all server state — no manual `useEffect` + `useState` for API calls
- Form validation: React Hook Form + Zod resolver
- Loading, error, and empty states for every async operation
- Component structure: hooks first, derived state, handlers, then JSX return
- Avoid prop drilling — use composition, context, or state management

> **Admin UI standards** (toolbar, detail modal, CSS classes): See `mysafespaces-admin/CLAUDE.md` → "Shared UI Patterns"

## CSS & Styling

- Design tokens (CSS custom properties) — never hardcode colors, spacing, shadows
- One CSS file per component, named to match
- Semantic class names (`.booking-card` not `.blue-box`), `mss-` prefix for shared utilities
- Shared component CSS lives in `src/components/` — import and reuse, don't duplicate

## Database

- `snake_case` for all table/column names, `mss_{module}_*` prefix
- UUID primary keys for entity tables; composite keys (FKs) for junction/relationship tables where natural keys exist
- Audit columns on every table: `created_at`, `updated_at`, and `created_by`/`updated_by` where applicable (user-initiated actions)
- Soft deletes where appropriate (`is_deleted`, `deleted_at`)
- Use constraints (NOT NULL, CHECK, UNIQUE, FK, EXCLUDE) — don't rely solely on app-level validation
- Indexes for frequent query patterns

### Schema Design (Plan Phase)

- **Walk through schema before coding** — in the plan phase, present the schema design (new columns, tables, indexes, constraints) and explain how it fits with existing tables. This reduces redesign after implementation starts.
- **Extend before creating** — if the data fits into an existing table (even with new columns), prefer extending that table over creating a new one. Always surface this choice for discussion before proceeding.
- **Follow established naming in each platform** — use the column/FK naming conventions already established in the codebase. In JourniPro, the established foreign key pattern is `user_id` (not `practitioner_id` or role-specific names). New tables and columns must follow the existing convention, not introduce synonyms.

## Configuration & Naming

- **No hardcoding** — config from SSM Parameter Store, env vars, or constants files
- Define once in common code, use everywhere — no magic strings
- **SSM is the source of truth** — Lambda handlers should read config from SSM at runtime (cached per container via `getSecureParam`), not from env vars baked in by `{{resolve:ssm:...}}` at deploy time. This ensures SSM updates take effect without redeploying CloudFormation stacks.
- **No fallbacks for SSM** — if an SSM parameter is missing or wrong, fail loudly (throw). Silent fallbacks mask misconfiguration and cause hard-to-debug issues.
- **One env var per Lambda** to derive SSM paths — no additional env vars for config that belongs in SSM:
  - MSS Admin platform: `ENVIRONMENT` (value: `dev` or `prod`)
  - JourniPro platform: `APP_CONFIG_PREFIX` (value: `/mss/dev/` or `/mss/prod/`)
- Shared constants in shared libs, not duplicated per service

### Domain Convention

- **Prod**: `mysafespaces.org` — clean subdomain name (e.g., `book.mysafespaces.org`, `api-sessions.mysafespaces.org`)
- **Dev**: `mysafespaces.net` — same subdomain with `-dev` suffix (e.g., `book-dev.mysafespaces.net`, `api-sessions-dev.mysafespaces.net`)
- Pattern: prod = `{name}.mysafespaces.org`, dev = `{name}-dev.mysafespaces.net`

> **Resource naming tables & custom domain convention**: See `.github/docs/ci-cd-reference.md` → "Resource Naming Conventions"

## Security

- Encrypt PII at rest (AES-256-GCM), hash emails for lookup (SHA-256)
- Auth tokens in HttpOnly cookies where possible; if localStorage, validate domain
- RBAC checks at API handler level, not just UI
- No secrets in code — use SSM Parameter Store / Secrets Manager
- Follow existing security patterns in the repository
- **Never**: log secrets, tokens, passwords, or PII
- **Never**: hardcode credentials or environment-specific values
- **Never**: disable security checks to make code "work"

## CORS (Cross-Origin Resource Sharing)

All Lambda services use a **standardized CORS pattern**:

- **SSM is the single source of truth** for allowed origins — `/mss/{env}/allowed_origins` (CSV string)
- **No env var fallbacks** — if SSM fails, the request fails (don't silently degrade CORS)
- **No API Gateway CORS config** — Lambda handlers own CORS entirely. Remove `CorsConfiguration` from SAM templates.
- Cache allowed origins for the Lambda container lifetime (lazy load on first request)
- `Access-Control-Allow-Origin` set only when the request `Origin` matches the allowed list; omitted otherwise
- Always set `Vary: Origin` and `Access-Control-Allow-Credentials: true`
- Lambda handlers respond to `OPTIONS` with `204 No Content` + CORS headers
- For internal service-to-service calls with `X-Internal-Token`, set `Access-Control-Allow-Origin: *`

**Reference implementation**: `mss-journipro-core/src/session/session.js` (`corsHeadersForEvent`, `resolveAllowedOrigin`)

## Git & CI/CD

- **Branches**: `develop` → dev deploy, `main` → prod deploy
- **Feature branches**: create from `develop`, merge back into `develop` when complete, then `develop` → `main` for prod releases
- Branch naming: `feature/short-description`, `fix/short-description`
- Keep feature branches focused on a single change — don't mix unrelated work
- Commit messages: concise imperative form describing the "why"
- **Deploy via git, not manually**: Always deploy by committing and pushing to the appropriate branch (`develop` for dev, `main` for prod) so CI/CD pipelines handle deployment. **Never deploy Lambda code manually from your machine** — no running `aws lambda update-function-code` or `sam deploy` by hand. These commands belong in CI/CD workflows only. Manual deploys bypass tests, break dependency packaging, and skip smoke tests.
- **SAM/CloudFormation is the single source of truth for all infrastructure**: Never use `aws lambda update-function-configuration`, `aws iam put-role-policy`, or any direct AWS CLI/console change as a permanent fix. Every env var, IAM policy, Lambda config, EventBridge rule, and API Gateway route must live in `template.yaml` (SAM) or a CloudFormation template and be deployed via CI/CD. Manual changes are invisible to other engineers, get silently overwritten by future deploys, and leave dev/prod out of sync. If an emergency manual change is made to unblock production, it is tech debt — immediately create a follow-up task to encode it in the template and deploy properly.

> **Workflow templates, infra deploy rules, amplify triggers**: See `.github/docs/ci-cd-reference.md` for detailed job tables and reference implementations.

### Post-Deploy Tests

Every deploy workflow must verify the deployed service works. Two tiers, run in order:

**Tier 1 — Smoke tests** (is it up?):
- Lightweight `curl` checks that the service is reachable — e.g., health endpoint returns 200, CDN responds, known route doesn't 503
- Fast, no auth required, no test data created
- Fail the workflow immediately if the service is unreachable

**Tier 2 — Functional tests** (does it work?):
1. **Auth & CORS enforcement** — unauthenticated requests get 401, invalid tokens rejected, `OPTIONS` preflight returns 204, `Access-Control-Allow-Origin` matches expected value
2. **API contract tests** — hit real endpoints with auth, verify response shapes match `{ data }` / `{ error: { code, message } }`, correct status codes (400 for bad input, 404 for missing resources, 403 for unauthorized access)
3. **End-to-end CRUD flows** — create → read → update → delete using test data, verify data round-trips correctly through the deployed stack. Clean up test data after.
4. **Error handling** — POST with missing required fields, invalid JSON, empty body, oversized payload — verify the service returns structured errors, not 500s or stack traces

**Rules**:
- Tests run against the actual deployed API URL (from SSM or workflow outputs), not localhost
- Use a dedicated test auth token or test user — never hardcode real credentials in tests
- Test data must be clearly identifiable (e.g., prefixed with `test_`) and cleaned up after the test run
- Fail the workflow if any test fails — a deploy that passes smoke but fails functional tests is not healthy
- Log test results to `$GITHUB_STEP_SUMMARY` in markdown table format with endpoint, expected status, actual status, and pass/fail

## Logging

- Write **well-thought-out logs** that tell the full story — gather all relevant info, compute derived values (durations, counts, deltas), then log once with everything a reader needs
- **Compute before logging**: if you need duration, calculate it and include it in the log — don't make the reader do mental math across two timestamps
- **One rich log > many sparse logs**: prefer a single log line with all context (`{ action, entity, id, duration, result, count }`) over scattered `console.log("step 1")`, `console.log("step 2")`
- Include: operation name, entity identifiers, outcome (success/failure), timing, and any relevant counts or sizes
- For errors: log the operation that failed, the input that caused it, and the error — all in one statement
- For external calls (DB, API, S3): log what was called, how long it took, and the result summary
- Never log secrets, tokens, passwords, or PII (see Security section)

## Debugging Approach

- **Start with logs, then go to code** — read CloudWatch / log output first to understand what actually happened before diving into source
- Reproduce the issue → read the logs → form a hypothesis → verify in code → fix → confirm via logs
- When adding debug logging, make it useful enough to keep (structured, with context) — not throwaway `console.log("here")`

## Performance

- No O(n^2) logic where O(n) is feasible
- Don't load entire datasets into memory if pagination/streaming is available
- No blocking operations in async paths

### Lambda / Serverless Performance

- **Parallelize independent async calls** — use `Promise.all()` for SSM fetches, DB queries, and API calls that don't depend on each other. Sequential `await`s for independent operations are a bug.
- **Minimize sequential DB queries** — combine related queries (e.g., use subselects instead of separate queries), use `COUNT(*) OVER()` window functions instead of separate count queries, and collapse multi-step lookup-then-insert patterns into single `INSERT ... ON CONFLICT ... RETURNING` UPSERTs.
- **Cold start awareness** — initialization code (SSM fetches, pool creation, SDK clients) runs once per container. Parallelize init operations and cache results at module scope, not per-request.
- **Index for query patterns** — when adding DB queries, verify that the WHERE/JOIN/ORDER BY columns have appropriate indexes. Add partial indexes (`WHERE status = ...`) for filtered queries.

## Comments

- Only when intent is not obvious from the code
- No redundant comments, tutorial-style explanations, or restating what the code says
