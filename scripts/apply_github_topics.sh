#!/usr/bin/env bash
# Apply GitHub topics for the current repo using the GitHub CLI (gh) or the API.
# Usage: ./scripts/apply_github_topics.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOPICS_FILE="$REPO_ROOT/.github/topics.txt"

if [[ ! -f "$TOPICS_FILE" ]]; then
  echo "No topics file found at $TOPICS_FILE"
  exit 1
fi

# Read topics into a JSON array
mapfile -t topics < "$TOPICS_FILE"
# filter empty lines
filtered=()
for t in "${topics[@]}"; do
  if [[ -n "$t" ]]; then
    filtered+=("$t")
  fi
done

if [[ ${#filtered[@]} -eq 0 ]]; then
  echo "No topics to apply"
  exit 0
fi

# Detect origin remote and parse owner/repo
remote_url=$(git -C "$REPO_ROOT" remote get-url origin || true)
if [[ -z "$remote_url" ]]; then
  echo "Cannot detect git remote 'origin'. Please run this inside a git repo with an 'origin' remote."
  exit 1
fi

# Convert SSH or HTTPS remote to owner/repo
if [[ "$remote_url" =~ github.com[:/](.+)/(.+)(\.git)?$ ]]; then
  owner_repo="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
else
  echo "Unable to parse remote URL: $remote_url"
  echo "Please ensure your remote is a GitHub URL like git@github.com:owner/repo.git or https://github.com/owner/repo.git"
  exit 1
fi

# Use gh CLI if available and authenticated
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    echo "Applying topics to $owner_repo via gh..."
    # Build JSON body
    json_body=$(printf '%s\n' "${filtered[@]}" | jq -R -s -c 'split("\n")[:-1]')
    # Use gh api to set topics (requires repo scope)
    gh api -X PUT /repos/$owner_repo/topics -f names="$json_body" -H "Accept: application/vnd.github+json"
    echo "Topics applied with gh."
    exit 0
  else
    echo "gh is installed but not authenticated. Run 'gh auth login' first."
  fi
fi

# Fallback: use curl and GITHUB_TOKEN
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  echo "Applying topics via GitHub API using GITHUB_TOKEN..."
  json_body=$(printf '%s\n' "${filtered[@]}" | jq -R -s -c 'split("\n")[:-1]')
  response=$(curl -s -o /dev/stderr -w "%{http_code}" -X PUT \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    https://api.github.com/repos/$owner_repo/topics \
    -d "{\"names\":$json_body}")
  if [[ "$response" -ge 200 && "$response" -lt 300 ]]; then
    echo "Topics applied via API."
    exit 0
  else
    echo "GitHub API responded with status $response"
    exit 1
  fi
fi

echo "No way to authenticate to GitHub automatically. Install & login with the GitHub CLI (https://cli.github.com/) or set GITHUB_TOKEN environment variable."
exit 1
