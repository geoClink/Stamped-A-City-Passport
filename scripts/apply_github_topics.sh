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

# Read topics into an array (portable across macOS bash)
filtered=()
while IFS= read -r line || [[ -n "$line" ]]; do
  # Trim whitespace
  t=$(echo "$line" | awk '{$1=$1;print}')
  if [[ -n "$t" ]]; then
    filtered+=("$t")
  fi
done < "$TOPICS_FILE"

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

# Build JSON payload without jq
joined=""
for t in "${filtered[@]}"; do
  # escape double quotes inside topic if any
  esc=$(printf '%s' "$t" | sed 's/"/\\"/g')
  if [[ -z "$joined" ]]; then
    joined="\"$esc\""
  else
    joined="$joined,\"$esc\""
  fi
done
json_body="{\"names\":[${joined}] }"

# Use gh CLI if available and authenticated
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    echo "Applying topics to $owner_repo via gh api..."
    # Try using gh api to set topics
    if gh api -X PUT /repos/$owner_repo/topics -H "Accept: application/vnd.github+json" -f names='["PLACEHOLDER"]' >/dev/null 2>&1; then
      # gh supports -f names; use curl to actually send the JSON body via gh api
      gh api -X PUT /repos/$owner_repo/topics -H "Accept: application/vnd.github+json" -f names="[$(printf '%s,' "${filtered[@]}" | sed 's/,$//')]
" && echo "Topics applied with gh." || true
      exit 0
    else
      # Fallback: add topics one-by-one using gh repo edit (available in some gh versions)
      echo "gh api JSON method not available; falling back to per-topic 'gh repo edit --add-topic'..."
      for t in "${filtered[@]}"; do
        echo "Adding topic: $t"
        gh repo edit "$owner_repo" --add-topic "$t" || true
      done
      echo "Topics applied (per-topic fallback)."
      exit 0
    fi
  else
    echo "gh is installed but not authenticated. Run 'gh auth login' first."
  fi
fi

# Fallback: use curl and GITHUB_TOKEN
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  echo "Applying topics via GitHub API using GITHUB_TOKEN..."
  response_code=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    https://api.github.com/repos/$owner_repo/topics \
    -d "$json_body")
  if [[ "$response_code" -ge 200 && "$response_code" -lt 300 ]]; then
    echo "Topics applied via API."
    exit 0
  else
    echo "GitHub API responded with status $response_code"
    exit 1
  fi
fi

echo "No way to authenticate to GitHub automatically. Install & login with the GitHub CLI (https://cli.github.com/) or set GITHUB_TOKEN environment variable."
exit 1
