#!/usr/bin/env bash
# check-deploy-status.sh — Cross-repo deploy status checker for MSS platform
#
# Usage: ./check-deploy-status.sh [develop|main] [--amplify]
#
# Checks all platform repos for:
#   - Latest GH Actions workflow run: status, conclusion, headSha vs local HEAD
#   - Optionally (--amplify), Amplify build status for frontend repos
#
# Prerequisites: gh CLI authenticated, git repos cloned locally
# For Amplify checks: AWS CLI configured with ap-south-1 access

set -euo pipefail
export MSYS_NO_PATHCONV=1  # Windows Git Bash: prevent path mangling in AWS CLI args

BRANCH="develop"
CHECK_AMPLIFY=false

for arg in "$@"; do
  case "$arg" in
    develop|main) BRANCH="$arg" ;;
    --amplify) CHECK_AMPLIFY=true ;;
  esac
done

ORG="NxtGen-Technologies"
GH="gh"
if ! command -v gh &>/dev/null && [ -f "/c/Program Files/GitHub CLI/gh.exe" ]; then
  GH="/c/Program Files/GitHub CLI/gh.exe"
fi

# Python command — test actual execution, not just presence (Windows has a python3 stub)
PY="python"
if python3 -c "pass" &>/dev/null 2>&1; then
  PY="python3"
fi

# Repo config: github_repo|local_path|workflow_name (empty = no workflow expected)
REPOS=(
  "mysafespaces-admin|$HOME/GitHub2/nxtgen-mysafespaces-admin|Deploy Frontend"
  "mss-journipro-admin|$HOME/GitHub/mss-journipro-admin|Deploy mss-journipro-admin"
  "mss-journipro-auth|$HOME/GitHub/mss-journipro-auth|Deploy mss-journipro-auth"
  "mss-journipro-patient-sessions|$HOME/GitHub/mss-journipro-patient-sessions|Deploy mss-journipro-patient-sessions"
  "mss-journipro-people|$HOME/GitHub/mss-journipro-people|Deploy mss-journipro-people"
  "mss-journipro-scheduling|$HOME/GitHub/mss-journipro-scheduling|Deploy mss-journipro-scheduling"
  "mss-journipro-web|$HOME/GitHub/mss-journipro-web|ci"
  "mss-journipro-booking-portal|$HOME/GitHub/mss-journipro-booking-portal|"
  "mysafespaces-blog-service|$HOME/GitHub2/nxtgen-mysafespaces-blog-service|deploy"
  "mysafespaces-website|$HOME/GitHub2/nxtgen-mysafespaces-website|"
  "mysafespaces-assets|$HOME/GitHub2/mysafespaces-assets|Deploy Assets"
  "mysafespaces-webinar|$HOME/GitHub2/mysafespaces-webinar|Deploy Webinar"
)

# Amplify apps: app_id|display_name|branch
AMPLIFY_APPS=(
  "dsx2kmu3y4i1p|mysafespaces-admin|${BRANCH}"
  "drrqvxvmu5f7h|mss-journipro-web|${BRANCH}"
)

echo ""
echo "## Deploy Status — branch: \`${BRANCH}\`"
echo ""
echo "| Repo | Local | Run | Status | Synced |"
echo "|------|-------|-----|--------|--------|"

for entry in "${REPOS[@]}"; do
  IFS='|' read -r repo local_path workflow_name <<< "$entry"

  # Local HEAD (short sha)
  local_sha="—"
  if [ -d "$local_path" ]; then
    local_sha=$(cd "$local_path" && git rev-parse --short "origin/${BRANCH}" 2>/dev/null || echo "—")
  fi

  if [ -z "$workflow_name" ]; then
    echo "| ${repo} | \`${local_sha}\` | — | no workflow | — |"
    continue
  fi

  # Get latest workflow run via gh --jq
  run_sha=$("$GH" run list \
    --repo "${ORG}/${repo}" \
    --branch "${BRANCH}" \
    --limit 1 \
    --json headSha \
    --jq '.[0].headSha // empty' 2>/dev/null | head -c 7 || true)

  run_status=$("$GH" run list \
    --repo "${ORG}/${repo}" \
    --branch "${BRANCH}" \
    --limit 1 \
    --json conclusion,status \
    --jq '.[0] | (.conclusion // .status // "?")' 2>/dev/null || echo "?")

  if [ -z "$run_sha" ]; then
    echo "| ${repo} | \`${local_sha}\` | — | no runs | — |"
    continue
  fi

  # Sync check
  if [ "$local_sha" = "—" ]; then
    synced="—"
  elif [ "$local_sha" = "$run_sha" ]; then
    synced="yes"
  else
    synced="**no** (${run_sha})"
  fi

  echo "| ${repo} | \`${local_sha}\` | \`${run_sha}\` | ${run_status} | ${synced} |"
done

# Amplify builds
if [ "$CHECK_AMPLIFY" = true ]; then
  echo ""
  echo "### Amplify Builds"
  echo ""
  echo "| App | Branch | Status | Started |"
  echo "|-----|--------|--------|---------|"

  for entry in "${AMPLIFY_APPS[@]}"; do
    IFS='|' read -r app_id app_name branch_name <<< "$entry"

    job_json=$(aws amplify list-jobs \
      --app-id "$app_id" \
      --branch-name "$branch_name" \
      --max-results 1 \
      --region ap-south-1 \
      --output json 2>/dev/null || echo '{"jobSummaries":[]}')

    job_status=$(echo "$job_json" | "$PY" -c "
import sys, json
d = json.load(sys.stdin)
jobs = d.get('jobSummaries', [])
print(jobs[0].get('status', '?') if jobs else 'no builds')
" 2>/dev/null || echo "error")

    job_time=$(echo "$job_json" | "$PY" -c "
import sys, json
d = json.load(sys.stdin)
jobs = d.get('jobSummaries', [])
print(str(jobs[0].get('startTime', ''))[:19] if jobs else '')
" 2>/dev/null || echo "—")

    echo "| ${app_name} | ${branch_name} | ${job_status} | ${job_time} |"
  done
fi

echo ""
echo "_Checked at $(date -u '+%Y-%m-%d %H:%M UTC')_"
