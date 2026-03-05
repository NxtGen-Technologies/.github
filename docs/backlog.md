## Pending / Backlog

**Last Updated:** March 5, 2026

- [ ] **Booking settings → practice level** — Move booking settings (currently per-practitioner in Scheduling) to the Practice Settings page as practice-level defaults. Practitioner booking settings become overrides on the practice defaults. Affects: `mss-journipro-web` (practice settings UI, practitioner scheduling UI), `mss-journipro-scheduling` (backend schema + API to support practice-level settings with practitioner overrides).
- [ ] **SEO report**
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

### CI/CD Standardization

Align all repos with the workflow standards in `claude/global-standards.md` → "Git & CI/CD". Reference implementation: `mss-journipro-admin/.github/workflows/deploy-journipro-admin.yml`.

**Workflow naming** — rename to `deploy-{service}.yml`:
- [ ] `mss-journipro-auth`: `deploy-lambda.yml` → `deploy-auth.yml`
- [ ] `mss-journipro-patient-sessions`: `deploy-lambda.yml` → `deploy-sessions.yml`
- [ ] `mss-journipro-people`: `deploy-lambda.yml` → `deploy-people.yml`
- [ ] `mss-journipro-scheduling`: `deploy-lambda.yml` → `deploy-scheduling.yml`
- [ ] `mss-journipro-admin`: `deploy-lambda.yml` → `deploy-admin.yml`
- [ ] `mysafespaces-blog-service`: `deploy.yml` → `deploy-blog.yml`
- [ ] `hj-mysafespaces-finance`: `deploy-backend.yml` → `deploy-finance.yml`

**Add SAM infra deploy job** (detect-changes + deploy-infra) — currently only `mss-journipro-admin` has this:
- [ ] `mss-journipro-auth`
- [ ] `mss-journipro-patient-sessions`
- [ ] `mss-journipro-people`
- [ ] `mss-journipro-scheduling`

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
- [ ] **Smoke tests for authenticated paths** — current smoke tests only check `OPTIONS 204` and `GET 400`. Add authenticated endpoint checks to verify DynamoDB/IAM are working.

### JourniPro — SSM Parameter Cleanup
- [ ] **Reorganize flat `/mss/{env}/` params** — Move `backend_base_url`, `cognito_*`, `db_*`, `encryption_key`, `session_*`, `cookie_*` into sub-namespaces (`/mss/{env}/auth/`, `/mss/{env}/db/`, `/mss/{env}/session/`) for better organization
- [ ] **Remove hardcoded Amplify branch env var** — `NEXT_PUBLIC_API_URL` on `develop` branch (now sourced from SSM via `amplify.yml`, branch var is redundant)
- [x] **Add SSM params for JourniPro web** — `/mss/{dev,prod}/journipro/api_url` (done 2/26)
- [x] **Add `amplify.yml` SSM fetch** — Build spec derives `NEXT_PUBLIC_IS_PRODUCTION` from branch, fetches `NEXT_PUBLIC_API_URL` from SSM (done 2/26)
