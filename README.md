# NxtGen-Technologies Shared Workflows

Reusable GitHub Actions workflow templates for the My Safe Spaces platform.

## Available Workflows

| Workflow | Purpose | Called with |
|----------|---------|-------------|
| `detect-template-changes.yml` | Check if `template.yaml` was modified | `uses: NxtGen-Technologies/.github/.github/workflows/detect-template-changes.yml@main` |
| `deploy-lambda-code.yml` | test → zip → `update-function-code` | `uses: NxtGen-Technologies/.github/.github/workflows/deploy-lambda-code.yml@main` |
| `deploy-sam-infra.yml` | `sam deploy` for env vars, IAM, EventBridge | `uses: NxtGen-Technologies/.github/.github/workflows/deploy-sam-infra.yml@main` |
| `trigger-amplify.yml` | `aws amplify start-job` | `uses: NxtGen-Technologies/.github/.github/workflows/trigger-amplify.yml@main` |
| `smoke-test-lambda.yml` | curl-based status code checks | `uses: NxtGen-Technologies/.github/.github/workflows/smoke-test-lambda.yml@main` |

## Standard Lambda Service Workflow

Each Lambda repo composes these templates into a `deploy-{service}.yml`:

```
detect-changes ──┐
                 ├── deploy-infra ── trigger-amplify ──┐
build-test-deploy┘                                     ├── smoke-test
                 ──────────────────────────────────────┘
```

## Example Calling Workflow

```yaml
name: Deploy mss-journipro-admin

on:
  push:
    branches: [main, develop]
  workflow_dispatch:

jobs:
  detect-changes:
    uses: NxtGen-Technologies/.github/.github/workflows/detect-template-changes.yml@main

  build-test-deploy:
    uses: NxtGen-Technologies/.github/.github/workflows/deploy-lambda-code.yml@main
    secrets: inherit

  deploy-infra:
    needs: [build-test-deploy, detect-changes]
    if: needs.detect-changes.outputs.infra_changed == 'true'
    uses: NxtGen-Technologies/.github/.github/workflows/deploy-sam-infra.yml@main
    with:
      stack-name-dev: mss-journipro-admin-dev
      stack-name-prod: mss-journipro-admin-prod
    secrets: inherit

  trigger-amplify:
    needs: [deploy-infra]
    uses: NxtGen-Technologies/.github/.github/workflows/trigger-amplify.yml@main
    secrets: inherit

  smoke-test:
    needs: [build-test-deploy, deploy-infra, trigger-amplify]
    if: always() && needs.build-test-deploy.result == 'success'
    uses: NxtGen-Technologies/.github/.github/workflows/smoke-test-lambda.yml@main
    with:
      endpoints: |
        OPTIONS /admin 204
        POST /admin/provisionuser 401
        POST /admin/practice 401
      origin-dev: https://sessions-dev.mysafespaces.net
      origin-prod: https://sessions.mysafespaces.org
    secrets: inherit
```

## Required GitHub Secrets

All Lambda repos need these secrets:

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | IAM access key |
| `AWS_SECRET_ACCESS_KEY` | IAM secret key |
| `AWS_REGION` | `ap-south-1` |
| `LAMBDA_FUNCTION_DEV` | Dev Lambda function name |
| `LAMBDA_FUNCTION_PROD` | Prod Lambda function name |
| `SMOKE_URL_DEV` | Dev API base URL |
| `SMOKE_URL_PROD` | Prod API base URL |
| `AMPLIFY_APP_ID` | Amplify app ID (for trigger-amplify) |
