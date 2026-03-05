# NxtGen-Technologies — Shared Platform Resources

Shared workflows, scripts, documentation, and coding standards for the My Safe Spaces platform.

## Structure

```
.github/
├── .github/workflows/     # Reusable CI/CD workflow templates
├── scripts/               # Operational scripts (deploy status, etc.)
├── claude/                # Shared Claude Code instruction modules
├── docs/                  # Cross-repo platform documentation
└── README.md
```

## Shared Workflows

| Workflow | Purpose | Called with |
|----------|---------|-------------|
| `detect-template-changes.yml` | Check if `template.yaml` was modified | `uses: NxtGen-Technologies/.github/.github/workflows/detect-template-changes.yml@main` |
| `deploy-lambda-code.yml` | test → zip → `update-function-code` | `uses: NxtGen-Technologies/.github/.github/workflows/deploy-lambda-code.yml@main` |
| `deploy-sam-infra.yml` | `sam deploy` for env vars, IAM, EventBridge | `uses: NxtGen-Technologies/.github/.github/workflows/deploy-sam-infra.yml@main` |
| `trigger-amplify.yml` | `aws amplify start-job` | `uses: NxtGen-Technologies/.github/.github/workflows/trigger-amplify.yml@main` |
| `smoke-test-lambda.yml` | curl-based status code checks | `uses: NxtGen-Technologies/.github/.github/workflows/smoke-test-lambda.yml@main` |

### Standard Lambda Service Workflow

Each Lambda repo composes these templates into a `deploy-{product}-{service}.yml`:

```
detect-changes ──┐
                 ├── deploy-infra ── trigger-amplify ──┐
build-test-deploy┘                                     ├── smoke-test
                 ──────────────────────────────────────┘
```

### Required GitHub Secrets

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

## Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `check-deploy-status.sh` | Cross-repo deploy + Amplify build status | `bash scripts/check-deploy-status.sh [develop\|main] [--amplify]` |

## Claude Code Instructions

Source of truth for shared coding standards and platform context. Per-repo `CLAUDE.md` files reference these.

| File | Purpose |
|------|---------|
| `claude/global-standards.md` | Global coding standards (TypeScript, Zod, Jest, API design, security, CI/CD, etc.) |

A synced copy of `global-standards.md` is kept at `~/.claude/CLAUDE.md` for Claude Code auto-loading.

## Documentation

Cross-repo platform docs that apply to all repos:

| Document | Purpose |
|----------|---------|
| `docs/platform-architecture.md` | Repo map, integration points, backend service inventory, shared patterns |
| `docs/ci-cd-reference.md` | Workflow templates, resource naming, deploy rules |
| `docs/backlog.md` | Cross-platform feature/tech debt backlog |
