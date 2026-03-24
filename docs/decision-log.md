# Architecture Decision Log — JourniPro Platform

This document records key architectural decisions, the context behind them, alternatives considered, and current status. It serves as institutional memory so decisions aren't relitigated without new information.

**Format**: Each decision includes context (why it came up), the choice made, alternatives rejected, tradeoffs accepted, and current status.

---

## ADR-001: Server-Side Sessions over JWTs

**Status**: Active
**Date**: Established at platform inception

**Context**: Need session management for authenticated users across practitioner app and booking portal. Two standard approaches: stateless JWTs in browser storage, or server-side sessions with opaque cookies.

**Decision**: Server-side sessions stored in DynamoDB, referenced by HttpOnly cookie.

**Why**:
- Tokens never exposed to browser JavaScript — eliminates XSS token theft
- Immediate session invalidation on logout (no waiting for JWT expiry)
- Session can be enriched server-side with RBAC context from DB without inflating token size
- Aligns with HIPAA-adjacent threat model for healthcare data

**Alternatives rejected**:
- **JWTs in localStorage**: Vulnerable to XSS, can't revoke without blacklist, payload visible to client
- **JWTs in HttpOnly cookies**: Still can't revoke without server-side state, so you end up with server state anyway

**Details**:
- Session cookies: `__Host-mss-session` (practitioner), `__Host-mss-booking` (client)
- TTL: 12h practitioner, 7d booking client
- DynamoDB TTL handles automatic expiry

**Tradeoffs accepted**: Requires DynamoDB table and read on every request. Acceptable given Lambda + DynamoDB latency is <10ms.

---

## ADR-002: Field-Level Encryption for PII

**Status**: Active (with known improvement needed — see ADR-002a)

**Context**: Platform handles healthcare data — patient names, emails, phone numbers, SOAP notes. Need encryption at rest beyond what RDS provides at the volume level.

**Decision**: AES-256-GCM field-level encryption for PII columns + SHA-256 hash of email for lookup.

**Why**:
- Defense in depth — even if DB credentials leak, PII is encrypted
- Field-level granularity means non-sensitive queries don't pay decryption cost
- Email hash enables lookup/deduplication without decrypting

**Details**:
- Wire format: `[12-byte IV][16-byte auth tag][ciphertext]` base64-encoded
- Encrypted fields: emails, phone numbers, addresses, SOAP notes, patient names
- Email identity: SHA-256 of normalized (lowercase, trimmed) email → `email_hash` column

**Known issue (ADR-002a)**: Key derivation uses SHA-256 of SSM parameter instead of a proper KDF (PBKDF2/HKDF). Planned remediation.

**People service exception**: Uses versioned format `[1-byte version][IV][tag][ciphertext]` with separate crypto module. Planned consolidation with core.

---

## ADR-003: Microservices (Lambda per Service) + Shared Libraries

**Status**: Active

**Context**: Platform has distinct functional domains — auth, admin provisioning, clinical sessions, scheduling, people directory. Need to decide monolith vs. microservices.

**Decision**: One Lambda function per service domain, shared logic in `mss-journipro-core` and `mss-scheduling-core`.

**Why**:
- Independent deployment — scheduling changes don't risk breaking auth
- Clear ownership boundaries aligned to functional domains
- Lambda per service keeps cold starts focused (smaller bundles)
- Shared libs prevent duplication without coupling deploys

**Services**:
- `mss-journipro-auth` — OAuth2 BFF (Cognito)
- `mss-journipro-admin` — User/patient/practice provisioning
- `mss-journipro-patient-sessions` — SOAP notes, review workflow
- `mss-journipro-people` — Read-only people directory
- `mss-journipro-scheduling` — Booking system
- `mss-journipro-reviews` — AI-assisted session review
- `mss-journipro-web` — Next.js practitioner/admin app
- `mss-journipro-booking-portal` — Next.js client booking portal

**Shared libraries** (consumed via `file:` dependency, CI checks out matching branch):
- `mss-journipro-core` — Session, encryption, DB pool, AWS params, logging, constants
- `mss-scheduling-core` — Availability engine, assignment engine, Zod schemas, types

**Tradeoffs accepted**: Cross-service calls add latency and failure modes. Mitigated by keeping services coarse-grained (not nano-services) and using SNS for fire-and-forget notifications.

---

## ADR-004: Single Aurora PostgreSQL Cluster for All Services

**Status**: Active

**Context**: Multiple services need relational data. Options: DB per service, single shared DB, or mixed.

**Decision**: Single Aurora PostgreSQL Serverless v2 cluster shared by all services.

**Why**:
- Cost efficiency — Serverless v2 scales to zero, one cluster is cheaper than many
- Simpler operations — one backup strategy, one connection endpoint
- Cross-service queries possible where needed (e.g., scheduling queries patient-sessions tables)
- Table prefix (`mss_`) provides logical separation

**Alternatives rejected**:
- **DB per service**: Overhead of managing multiple clusters, cross-service joins impossible, cost multiplied
- **DynamoDB for everything**: Poor fit for relational data (supervision relationships, scheduling constraints with EXCLUDE)

**Schema conventions**:
- `mss_` table prefix, `snake_case` columns
- UUID primary keys for entities, composite keys for junction tables
- Audit columns: `created_at`, `updated_at`, `created_by`/`updated_by`
- Soft deletes where appropriate
- EXCLUDE constraints for non-overlapping date ranges

**People service exception**: Uses RDS Data API instead of direct pg pool (different access pattern).

---

## ADR-005: SSM Parameter Store as Single Source of Truth

**Status**: Active

**Context**: Lambda functions need configuration (DB endpoints, feature flags, CORS origins, encryption keys). Options: env vars baked at deploy, SSM at runtime, or config files.

**Decision**: SSM Parameter Store read at runtime, cached per Lambda container. No fallbacks — fail loudly on missing params.

**Why**:
- SSM updates take effect without redeploying CloudFormation stacks
- Single place to audit all config across services
- No risk of stale env vars after config changes
- Loud failures catch misconfiguration early instead of silent degradation

**Rules**:
- One env var per Lambda to derive SSM paths: `APP_CONFIG_PREFIX` (e.g., `/mss/dev/`, `/mss/prod/`)
- No additional env vars for config that belongs in SSM
- Cache for Lambda container lifetime (lazy load on first request)
- Secrets Manager for DB credentials; SSM stores the ARN pointer

**Tradeoffs accepted**: First request per container pays SSM latency. Mitigated by parallelizing SSM fetches with `Promise.all()` and caching.

---

## ADR-006: Lambda Owns CORS (Not API Gateway)

**Status**: Active

**Context**: Need CORS handling for browser-based frontends calling Lambda APIs. API Gateway offers built-in CORS config, but it's limited.

**Decision**: Lambda handlers own CORS entirely. No `CorsConfiguration` in SAM templates.

**Why**:
- Full control over origin validation logic
- Can vary `Access-Control-Allow-Origin` per request based on SSM-managed allowed origins list
- Handles credential-mode CORS correctly (`Allow-Credentials: true`)
- Internal service-to-service calls with `X-Internal-Token` get `Allow-Origin: *`

**Pattern**:
- SSM `allowed_origins` (CSV) is single source of truth
- `OPTIONS` → `204 No Content` + CORS headers
- `Vary: Origin` always set
- Reference implementation: `mss-journipro-core/src/session/session.js` (`corsHeadersForEvent`)

---

## ADR-007: Supervisor as Capability Flag, Not Separate Role

**Status**: Active

**Context**: Supervisors need to view/approve supervisee sessions. Could model as a separate role or as a flag on existing PRACTITIONER role.

**Decision**: `is_supervisor = true` flag on PRACTITIONER, not a separate SUPERVISOR role.

**Roles**: ADMIN, CLINICAL_ADMIN, PRACTITIONER

**Why**:
- A supervisor is a practitioner who also supervises — they still have their own caseload
- Separate role would require role-switching or dual-role complexity
- Flag + `mss_supervision_relationships` table (with date ranges and EXCLUDE constraints) is simpler and more flexible
- CLINICAL_ADMIN always has `is_supervisor = true` by design

**Enforcement**: Handler role check + SQL `WHERE therapist_id = $userId` for own sessions. Supervisors require active relationship in `mss_supervision_relationships` to access supervisee data.

---

## ADR-008: Consolidated API Gateway + Single Lambda per Service

**Status**: Active

**Context**: Each service could have its own API Gateway, or all routes could live on a single consolidated gateway.

**Decision**: Single consolidated API Gateway dispatching to service Lambdas. Each Lambda uses internal route dispatching.

**Why**:
- Fewer AWS resources to manage
- Single base URL for all APIs simplifies frontend config
- Custom domain mapping is simpler (one gateway)
- Route-level dispatch in Lambda code is more testable than API Gateway config

**Known issue**: Routes were created via AWS CLI, not in IaC (CloudFormation). Planned remediation to move to SAM templates.

---

## ADR-009: IST API Contract, UTC Storage, Conversion at Boundary

**Status**: Active

**Context**: Platform serves India-based practices. Need consistent timezone handling across frontend, API, and database.

**Decision**: API contract uses IST (Asia/Kolkata, UTC+05:30). Database stores UTC. Conversion happens at the handler boundary.

**Why**:
- India-focused product — IST is the only timezone clients see
- UTC in DB is standard practice for storage, enables future multi-timezone support
- Single conversion point (handler boundary) prevents scattered timezone bugs
- Availability engine (`mss-scheduling-core`) is pure UTC — no timezone awareness, fully testable

**Details**:
- Conversion via `istToUtc()` / `utcToIst()` in `src/lib/ist-utc.ts`
- Frontend display: `Intl.DateTimeFormat` with `Asia/Kolkata`

**Tradeoff accepted**: If platform expands beyond India, conversion boundary needs to become timezone-aware (accept timezone param). Current design makes this a localized change.

---

## ADR-010: Zod for Validation (Incremental Migration)

**Status**: In progress

**Context**: Need runtime validation at system boundaries. Older services use inline null checks. New code needs a standard.

**Decision**: Zod for all external input validation. Migrate incrementally — new code uses Zod, existing code migrates as touched.

**Why**:
- Runtime type safety that TypeScript alone can't provide
- Schemas are composable and shareable across services
- Integrates with React Hook Form on frontend
- Single schema defines validation + TypeScript type (no duplication)

**Current state**:
- `mss-scheduling-core`: Zod schemas shared across scheduling
- `mss-journipro-reviews`: Zod throughout
- Auth, admin, sessions, people: Not yet migrated

---

## ADR-011: Jest + Real Boundaries Testing

**Status**: Active

**Context**: Need testing strategy that catches real bugs, not just confirms mocks work.

**Decision**: Jest for all tests. Mock only external boundaries (DB, network, AWS services). Test real behavior.

**Why**:
- Tests that mock internal modules can pass while prod is broken — useless
- Testing at handler level with realistic event objects catches integration issues
- Testing failure modes (missing fields, invalid input, auth failures) catches what breaks in production

**Rules**:
- Mock: DB connections, AWS SDK calls, external HTTP calls
- Don't mock: internal modules, the code under test, business logic
- Cover: happy path, error paths, edge cases, auth failures
- Integration tests for API handlers with realistic event objects

---

## ADR-012: Structured JSON Logging

**Status**: Active (migration in progress)

**Context**: Lambda logs go to CloudWatch. Unstructured `console.log` strings are hard to search and correlate.

**Decision**: Structured JSON logging with correlation IDs. One rich log per operation, not many sparse logs.

**Why**:
- Machine-parseable for CloudWatch Insights queries
- Correlation IDs (from API Gateway request context) enable request tracing
- Single log with all context (`action, entity, id, duration, result`) is more useful than scattered breadcrumbs

**Current state**: Core has structured logger (`src/logging/logger.js`). Services still use `console.log()` directly — migration in progress.

---

## ADR-013: GitHub Actions CI/CD + SAM for Infrastructure

**Status**: Active

**Context**: Need automated deployment pipeline. SAM (Serverless Application Model) for Lambda infrastructure.

**Decision**: GitHub Actions with branch-conditional deploy. `develop` → dev, `main` → prod. SAM templates are source of truth for all infrastructure.

**Why**:
- No manual deploys — eliminates "works on my machine" and forgotten config
- SAM templates make infrastructure reviewable in PRs
- Branch-based deployment is simple and auditable
- Post-deploy smoke tests catch deployment failures immediately

**Critical rule**: Never deploy Lambda code manually (`aws lambda update-function-code`, `sam deploy` by hand). Never use `aws lambda update-function-configuration` as a permanent fix. Everything goes through CI/CD.

---

## ADR-014: SES Direct for OTP, SNS for Everything Else

**Status**: Active

**Context**: Platform sends emails — OTP codes for booking portal auth, booking confirmations, cancellations, etc.

**Decision**: Direct SES for OTP emails (latency-sensitive, simple template). SNS publish for all other emails, consumed by centralized notification service.

**Why**:
- OTP emails are time-critical — direct SES avoids extra hop
- Booking emails need templates, retry logic, and may expand to other channels — centralized service handles this
- Fire-and-forget SNS publish keeps scheduling Lambda fast (errors logged, not thrown)
- Single notification service is the place to add SMS, push notifications later

---

## ADR-015: Next.js App Router + React Query + Zustand

**Status**: Active

**Context**: Two frontend apps (practitioner web, booking portal). Need modern React stack with server-side rendering capability.

**Decision**: Next.js 16 with App Router. React Query for server state. Zustand for client state (auth, org selection). Tailwind CSS + shadcn/ui for styling.

**Why**:
- App Router enables server components (reduce client JS bundle)
- React Query handles caching, refetching, loading/error states — eliminates manual `useEffect` + `useState` for API calls
- Zustand is minimal and doesn't require provider wrapping (unlike Redux)
- Cookie-based auth via BFF means no manual token management in frontend

**Build constraints**:
- `useSearchParams()` requires Suspense boundary (except dynamic routes)
- Static routes cannot use async server components with dynamic context

---

## ADR-016: Single Region (us-east-2), Mumbai Migration Planned

**Status**: Active, migration in progress

**Context**: Platform serves India-based users. Initially deployed to us-east-2 (Ohio). Latency to India is suboptimal.

**Decision**: Start with us-east-2, migrate to ap-south-1 (Mumbai) when ready.

**Why**:
- us-east-2 was expedient for initial development
- Mumbai will reduce latency significantly for India-based users
- Migration is infrastructure work, not application logic change

**Known issue**: RDS Data API client region hardcoded to us-east-2 — needs `AWS_REGION` env var.

---

## ADR-017: Standardized Response Shape

**Status**: In progress (inconsistent across services)

**Target**: `{ data }` for success, `{ error: { code, message } }` for failure.

**Context**: Services evolved independently and adopted different response shapes.

**Current state**:
- Auth: `{ error: { code, message } }` (compliant)
- Scheduling: `{ data }` (compliant)
- Sessions: Mixed (`{ ok, session }`, `{ success, data }`, `{ sessionId, reviewStatus }`)
- Admin: Generic Error with statusCode property
- People: `{ success: true, data: [...] }`

**Plan**: Standardize as services are touched. Breaking changes coordinated with frontend.

---

## ADR-018: Email Hash as Identity Anchor

**Status**: Active

**Context**: Users exist in both Cognito and the database. Need a stable identity that works across both systems.

**Decision**: SHA-256 hash of normalized email (`email_hash` column) as the reconciliation key.

**Why**:
- Email is globally unique and user-memorable
- Hash avoids plaintext email storage in the identity column
- Enables deduplication and cross-system lookup without decryption
- Normalization (lowercase, trim) prevents duplicate accounts from formatting differences

---

## Outstanding Issues

These are tracked separately but relevant to architectural integrity:

| Issue | Severity | Status |
|-------|----------|--------|
| Weak KDF (SHA-256 instead of PBKDF2) for encryption key | High | Open |
| Patient encryption commented out — PII in plaintext | P0 | Open |
| Web app 33K LOC with zero tests | High | Open |
| Consolidated API Gateway routes not in IaC | Medium | Open |
| Hardcoded Cognito credentials in web app (legacy, unused) | Medium | Open |
| PII leakage in admin service logs | High | Open |
| Crypto module duplication (people vs core) | Medium | Open |
| Response shape inconsistency across services | Medium | In progress |
| `console.log()` migration to structured logger | Medium | In progress |
| TypeScript migration (incremental) | Medium | In progress |
