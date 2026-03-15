## Pending / Backlog

**Last Updated:** March 5, 2026

- [ ] **SEO report**
- [ ] **Booking portal — website header & footer** — Replace the booking portal's minimal header/footer (`mss-journipro-booking-portal`) with the full `mysafespaces-website` header (two-row: top utility bar + main nav with dropdowns) and footer (5-column grid with links + contact row). The website uses vanilla CSS + CRA; the booking portal uses Next.js 15 + TypeScript + Tailwind v4 — so the website components need to be adapted (port CSS to Tailwind or import as standalone CSS). Booking-specific nav items (Book a Session, My Bookings, Login/Logout based on auth state) should be integrated into the website-style header. Affects: `mss-journipro-booking-portal` (Header.tsx, Footer.tsx, layout.tsx, globals.css).
- [ ] **Stripe integration**
- [ ] **Newsfeed** — Bring into admin tool
- [ ] **IT & Finance portal** — Adjust links
- [ ] **Website slugs** — Incorporate slugs so links to sections appear as `website|Blog` etc., not just the root domain
- [ ] **Resources section** — Curated list of articles and relevant material from around the world
- [ ] **Scrolling banner** — Home page banner calling out current schools
- [ ] **Emails from admin tool**
- [ ] **Jobs CloudFormation stack** — Currently using colleague's endpoint
- [ ] **Update stack naming convention** — Rename legacy stacks (`mss-rbac-infrastructure`, `mss-swiss-stack`, `mss-hr-api`)
- [ ] **Users page** — Disabled in sidebar, contains sample data
- [ ] **Lambda Layer for shared code** (`ssm-utils.js`, `auth-utils.js`)
- [ ] **CloudWatch dashboards and alerts**
- [ ] **Shared structured logger** — Replace ad-hoc `console.log` across all services with a shared logger module (in `mss-journipro-core` or new shared lib). Structured JSON output, correlation IDs, consistent log levels. Once available, migrate existing Lambda handlers to use it.
- [ ] **Remove hardcoded super admin emails from Lambda handlers**
- [ ] **Unified admin API custom domain** — Single custom domain (`api-admin-dev.mysafespaces.net` / `api-admin.mysafespaces.net`) with path-based routing to all admin Lambda services (CRM, HR, RBAC, SWISS, CN, CP, Customers, Jobs). Eliminates raw API Gateway URLs in browser, simplifies CORS (single origin), and reduces frontend SSM params to one `REACT_APP_ADMIN_API_URL`. Requires: ACM cert, API Gateway custom domain + base path mappings, Route 53 record, update SSM params + Amplify rebuild.

### Shared SSM Parameter Stack

- [ ] **CloudFormation stack for shared SSM parameters** — Create `mss-shared-params-{env}` stack (in `.github` repo or dedicated infra repo) that defines all cross-repo SSM parameters as `AWS::SSM::Parameter` resources. Currently portal URLs, CORS origins, and other shared config are created manually via CLI — no version control, no drift detection, no audit trail. Stack should cover: portal URLs (`/mysafespaces/{env}/portal/*`), CORS allowed origins, and any other params consumed by multiple repos. Deploy via CI/CD with `workflow_dispatch` per environment.

### CI/CD Standardization

Align all repos with the workflow standards in `claude/global-standards.md` → "Git & CI/CD". Reference implementation: `mss-journipro-admin/.github/workflows/deploy-journipro-admin.yml`.

**Workflow naming** — rename to `deploy-{service}.yml`:
- [ ] `mss-journipro-auth`: `deploy-lambda.yml` → `deploy-auth.yml`
- [ ] `mss-journipro-patient-sessions`: `deploy-lambda.yml` → `deploy-sessions.yml`
- [ ] `mss-journipro-people`: `deploy-lambda.yml` → `deploy-people.yml`
- [ ] `mss-journipro-admin`: `deploy-lambda.yml` → `deploy-admin.yml`
- [ ] `mysafespaces-blog-service`: `deploy.yml` → `deploy-blog.yml`
- [ ] `hj-mysafespaces-finance`: `deploy-backend.yml` → `deploy-finance.yml`

**Add SAM infra deploy job** (detect-changes + deploy-infra) — currently only `mss-journipro-admin` has this:
- [ ] `mss-journipro-auth`
- [ ] `mss-journipro-patient-sessions`
- [ ] `mss-journipro-people`

**Add `trigger-amplify` step** after infra deploy — triggers `mss-journipro-web` rebuild (Amplify app `drrqvxvmu5f7h`):
- [ ] `mss-journipro-auth`
- [ ] `mss-journipro-admin`
- [ ] `mss-journipro-patient-sessions`
- [ ] `mss-journipro-people`
- [ ] Add `AMPLIFY_APP_ID` + `AMPLIFY_BRANCH` GitHub secrets to all JourniPro repos

**Add smoke tests** to workflows that lack them:
- [ ] `mysafespaces-blog-service` — test health / public endpoint
- [ ] `mysafespaces-admin` `deploy-infrastructure.yml` — test API endpoints after stack deploy
- [ ] `hj-mysafespaces-finance` — test endpoint returns 401 without auth

**Remove standalone `test.yml`** — merge into deploy workflow:
- [ ] `mysafespaces-assets` — fold test job into `deploy-assets.yml`
- [ ] `mysafespaces-webinar` — fold test job into `deploy-webinar.yml`

### Notification Service — Phase 2

- [ ] **Resend confirmation email** — "Resend Confirmation" button on therapist booking detail view. New endpoint `POST /scheduling/practitioner/bookings/:id/resend` → re-fetches `fetchBookingEmailData()` (picks up latest video link, times, etc.) → fires `notifyBookingConfirmed()`. No new event type needed — reuses existing template. Useful when practitioner updates video link or needs to remind patient.
- [ ] **Session notes reminder** — EventBridge cron (every 15 min), sends reminder to therapist 30 min after session ends if notes not submitted
- [ ] **Daily therapist digest** — 9:00 AM IST, lists sessions needing notes
- [ ] **Daily supervisor digest** — 9:30 AM IST, lists pending reviews
- [ ] **Review workflow notifications** — `SESSION_SUBMITTED_FOR_REVIEW` (→ supervisor), `REVISION_REQUESTED` (→ therapist) from patient-sessions Lambda
- [ ] **Notification preferences table** — opt-out model, `mss_notification_preferences`

### Scheduling — Booking Settings

- [x] **Therapist booking settings page** — `/therapist/booking-settings` with editable profile fields (bio, photo, video link, accepting clients) and read-only admin-managed fields (rate, modalities, advance booking, free sessions). Deployed 2026-03-15.
- [x] **Bookings default filter** — Bookings page defaults to Pending & Confirmed. Dropdown allows all statuses. Deployed 2026-03-15.
- [ ] **Video URL cascade on change** — When therapist changes their Meet link, update all future CONFIRMED bookings with the new URL and optionally re-send notification emails. Currently changes only apply to new bookings.
- [ ] **Backend multi-status filter for bookings** — `GET /scheduling/my/bookings` only supports single `status` param. Add support for comma-separated or `status[]=` to filter server-side (currently "Pending & Confirmed" is filtered client-side).
- [ ] **Practitioner calendar invite with buffer** — Ask practitioner: should their calendar invite block the full time (session + buffer for notes), or just the session time? Currently both patient and practitioner get the same invite showing patient time only. If practitioner prefers buffer included, generate two separate ICS files: patient invite (`start → start + slot`), practitioner invite (`start → start + slot + buffer`). Affects: `mysafespaces-notifications/src/lib/calendar.ts`, scheduling Lambda email/notification calls.

### JourniPro — Session Notes & Scheduling

- [ ] **Availability engine rework** — Rework `mss-scheduling-core` availability engine for reliability and scalability. Design walkthrough needed covering: (1) **Architecture** — pre-computed/cached slots vs on-demand, event-driven invalidation on schedule/booking changes; (2) **Algorithm** — timezone-aware interval arithmetic, interval tree for overlap detection, DST handling, multi-practitioner batch queries; (3) **Scalability** — batch availability for search results, slot pagination, caching layer with invalidation, background pre-computation. Design-only first, then implement.
- [ ] **Internal booking from therapist/admin/supervisor UI** — Allow practitioners to book a session with a patient directly from the web app (e.g., from session notes Treatment Planning section or patient detail page). Requires:
  - `useCreateBooking` hook calling scheduling API `POST /bookings` (currently only used by booking portal)
  - Available slots query: `GET /scheduling/practitioners/{id}/available-slots?date=YYYY-MM-DD` (endpoint exists)
  - Booking dialog: date picker → slot grid → confirm (reuse patterns from booking portal `mss-journipro-booking-portal`)
  - Wire into Treatment Planning section ("Schedule Next Session" button) and patient actions menu
  - Handle: patient already linked (skip linking step), practitioner = current user, modality selection
  - Roles: therapist books own patients, supervisor/admin can book for any practitioner's patients
- [ ] **Next session display in Treatment Planning** — Once internal booking exists, query patient's next confirmed booking and display date/time in the Treatment Planning section (prop already wired, currently shows "No upcoming session scheduled")

### JourniPro — Post-Migration

**Bugs / Incomplete:**
- [ ] **Draft queue endpoint failing** — `GET /patient-sessions/queues/draft` returns errors. Investigate CloudWatch logs for root cause (SQL query, data, or auth issue).
- [ ] **/auth/refresh handler not implemented** — returns 500, route removed from API Gateway. Frontend uses `/me` so not blocking, but should be implemented: fix fallthrough 404 path, add `handleRefresh` function, re-add route to dev + prod API Gateways.
- [ ] **Verify Cognito integration end-to-end** — admin provisioning flow (DB insert → Cognito invite) hasn't been confirmed working in Mumbai.

**Prod deployment:**
- [ ] **Verify prod frontend domains** — `sessions.mysafespaces.org` and `sessions-prod.mysafespaces.net` were pending verification/propagation as of 2026-03-01.
- [ ] **Push all 4 Lambda repos to `main`** — triggers CI/CD prod deploy with correct node_modules + smoke tests.

**Decisions:**
- [ ] **API Gateway naming** — rename `api-sessions.mysafespaces.org` to `api.mysafespaces.org`? Current name implies sessions-only but all JourniPro modules route through it. Check if `api.mysafespaces.org` DNS is available. Confirm with Howard.

**Security / Infrastructure:**
- [ ] **VPC-Private Aurora** — Aurora is `PubliclyAccessible: true`, protected only by password + SSL. Before HIPAA audit: (1) add private subnets + NAT Gateway, (2) add `VpcConfig` to all Lambda SAM templates, (3) set `PubliclyAccessible: false`, (4) restrict Aurora SG to Lambda SG only. Cost: ~$45-90/month.
- [ ] **Delete us-east-2 Aurora clusters** — stopped 2026-03-02, delete after 2026-04-01. Note: stopped clusters auto-restart after 7 days — re-stop if still running.

**Testing improvements (from CORS post-mortem):**
- [ ] **Async mocks must match real signatures** — admin tests mock `corsHeadersForEvent` as sync, hiding async/await bugs. Change mocks to `async` functions.
- [ ] **Response shape assertions** — add helper that rejects Promises in `headers` field to catch this class of bug.
- [x] **Smoke tests for authenticated paths** — expanded: scheduling (5 endpoints), patient-sessions (6 endpoints) now test auth enforcement (401) and validation (400).
- [ ] **Admin Lambda producer-side contract tests** — add contract tests in `mss-journipro-admin` for `provisionPatient` and `assignPatientTherapist` response shapes. Consumer-side tests exist in scheduling (`contracts.test.ts`); producer-side needed to catch drift if admin handlers change.

### JourniPro — SSM Parameter Cleanup
- [ ] **Reorganize flat `/mss/{env}/` params** — Move `backend_base_url`, `cognito_*`, `db_*`, `encryption_key`, `session_*`, `cookie_*` into sub-namespaces (`/mss/{env}/auth/`, `/mss/{env}/db/`, `/mss/{env}/session/`) for better organization
- [ ] **Remove hardcoded Amplify branch env var** — `NEXT_PUBLIC_API_URL` on `develop` branch (now sourced from SSM via `amplify.yml`, branch var is redundant)
- [x] **Add SSM params for JourniPro web** — `/mss/{dev,prod}/journipro/api_url` (done 2/26)
- [x] **Add `amplify.yml` SSM fetch** — Build spec derives `NEXT_PUBLIC_IS_PRODUCTION` from branch, fetches `NEXT_PUBLIC_API_URL` from SSM (done 2/26)
