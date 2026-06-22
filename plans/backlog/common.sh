#!/bin/bash

REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_ROOT")
SANDBOX_NAME="claude-$REPO_NAME"

get_docker_user() {
  local creds_store
  creds_store=$(jq -r '.credsStore // empty' ~/.docker/config.json 2>/dev/null)
  if [ -n "$creds_store" ] && command -v "docker-credential-$creds_store" >/dev/null 2>&1; then
    echo "https://index.docker.io/v1/" | "docker-credential-$creds_store" get 2>/dev/null | jq -r '.Username // empty'
    return
  fi
  docker info 2>/dev/null | awk '/Username:/ {print $2}'
}

require_docker_user() {
  DOCKER_USER=$(get_docker_user)
  if [ -z "$DOCKER_USER" ]; then
    echo "Not logged into Docker Hub. Please run: docker login"
    exit 1
  fi
  IMAGE="$DOCKER_USER/claude-sandboxed:v1"
}

require_sandbox() {
  if ! docker sandbox ls 2>/dev/null | grep -q "$SANDBOX_NAME"; then
    echo "Sandbox '$SANDBOX_NAME' not found. Please run: ./plans/backlog/setup.sh"
    exit 1
  fi
}

refresh_oauth_token() {
  local token
  token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('claudeAiOauth',{}).get('accessToken',''))" 2>/dev/null)

  if [ -z "$token" ]; then
    echo "Warning: could not refresh CLAUDE_CODE_OAUTH_TOKEN from keychain"
    return
  fi

  local env_file="$REPO_ROOT/.env"
  if grep -q "^CLAUDE_CODE_OAUTH_TOKEN=" "$env_file" 2>/dev/null; then
    sed -i '' "s|^CLAUDE_CODE_OAUTH_TOKEN=.*|CLAUDE_CODE_OAUTH_TOKEN=$token|" "$env_file"
  else
    echo "CLAUDE_CODE_OAUTH_TOKEN=$token" >> "$env_file"
  fi

  echo "OAuth token refreshed."
}
