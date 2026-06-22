#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

issues=$(gh issue list --state open --json number,title,body,comments)
ralph_commits=$(git log --grep="RALPH" -n 10 --format="%H%n%ad%n%B---" --date=short 2>/dev/null || echo "No RALPH commits found")

claude \
  --print \
  "$issues Previous RALPH commits: $ralph_commits $(cat "$SCRIPT_DIR/prompt.md")"
