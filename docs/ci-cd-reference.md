# CI/CD Reference — Workflow Templates & Deploy Rules

> Principles live in `claude/global-standards.md` → Git & CI/CD. This file has the detailed reference tables.

## Workflow File Naming

- `deploy-{service}.yml` — one per deployable service (e.g., `deploy-admin.yml`, `deploy-auth.yml`, `deploy-assets.yml`)
- `deploy-frontend.yml` — Amplify frontend trigger (only if repo has a separate frontend deploy)
- Tests run inside the deploy workflow — no separate `test.yml`
- Triggers: `push` to `main`/`develop` + `workflow_dispatch` for manual runs

## Standard Lambda Service Workflow

Every Lambda service workflow (`deploy-{service}.yml`) has these jobs in order:

| # | Job | Purpose | Runs when |
|---|-----|---------|-----------|
| 1 | `detect-changes` | Check if `template.yaml` changed | Every push (fast, parallel with build) |
| 2 | `build-test-deploy` | checkout → install → test → zip → `aws lambda update-function-code` | Every push |
| 3 | `deploy-infra` | `sam deploy` for env vars, IAM, EventBridge | Only when `template.yaml` changed, or `workflow_dispatch` |
| 4 | `trigger-amplify` | `aws amplify start-job` to rebuild dependent frontend | Only after `deploy-infra` ran |
| 5 | `smoke-test` | Post-deploy verification with `curl` + status code checks | After all deploy jobs complete |

**Reference implementation**: `mss-journipro-admin/.github/workflows/deploy-lambda.yml`

## Standard Multi-Service Workflow

For repos that deploy multiple CloudFormation stacks (e.g., `mysafespaces-admin`):

| # | Job | Purpose |
|---|-----|---------|
| 1 | `deploy-shared` | Shared SSM parameters |
| 2 | `deploy-stacks` | CloudFormation stacks (parallel via matrix) |
| 3 | `deploy-lambda` | Lambda code for all services |
| 4 | `update-ssm` | Extract API URLs from CF outputs → SSM |
| 5 | `trigger-amplify` | `aws amplify start-job` — rebuild frontend with new SSM params |
| 6 | `smoke-test` | Post-deploy verification |

## Infra Deploy Rules

- SAM infra deploy runs in CI/CD as a separate job from code deploy — not manually
- No `sam build` — use `sam deploy --template-file template.yaml --resolve-s3` to package directly from source (avoids stale `.aws-sam/build/` cache that can silently drop dependencies)
- Flags: `--no-confirm-changeset --no-fail-on-empty-changeset --capabilities CAPABILITY_IAM`
- Code deploy (`update-function-code`) and infra deploy (`sam deploy`) are separate jobs — infra only runs when `template.yaml` changes or on `workflow_dispatch`
- Never use SAM to deploy Lambda code — code goes through `npm ci` → zip → `update-function-code`

## Amplify Trigger Rules

- Amplify auto-builds on git push (frontend code changes — natural trigger)
- After infra deploy, use `aws amplify start-job` to trigger Amplify rebuild (SSM params may have changed at build time)
- Only trigger Amplify after `deploy-infra` actually ran — code-only deploys do not rebuild the frontend
- Store `AMPLIFY_APP_ID` and `AMPLIFY_BRANCH` as GitHub repo secrets

## Resource Naming Conventions

| Resource | Pattern | Example |
|----------|---------|---------|
| Lambda | `mss-admin-{function}-{env}` | `mss-admin-crm-handler-production` |
| Lambda (JourniPro) | `mss-journipro-{module}-{function}-{env}` | `mss-journipro-scheduling-handler-dev` |
| DB tables | `mss_{module}_*` | `mss_sched_bookings`, `mss_patients` |
| SSM parameters | `/mysafespaces/{env}/{function}/{name}` | `/mysafespaces/production/scheduling/from_email` |
| S3 buckets | `mysafespaces-{module}-{purpose}` | `mysafespaces-finance-docs` |

### Custom Domain Convention
- **Prod gets the clean name**: `assets.mysafespaces.org`, `api.mysafespaces.org`
- **Dev gets the `-dev` suffix**: `assets-dev.mysafespaces.org`, `api-dev.mysafespaces.org`
- When deploying a new service, always set up dev with the `-dev` subdomain first so prod can claim the clean name later
- This applies to CloudFront distributions, API Gateway custom domains, and any other public-facing DNS
