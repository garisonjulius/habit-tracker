#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

if [ -z "$1" ]; then
  echo "Usage: $0 <iterations>"
  exit 1
fi

for ((i=1; i<=$1; i++)); do
  echo ""
  echo "=== RALPH iteration $i / $1 ==="
  echo ""

  tmpfile=$(mktemp)
  trap "rm -f $tmpfile" EXIT

  issues=$(gh issue list --state open --json number,title,body,comments)
  ralph_commits=$(git log --grep="RALPH" -n 10 --format="%H%n%ad%n%B---" --date=short 2>/dev/null || echo "No RALPH commits found")

  claude \
    --verbose \
    --print \
    --output-format stream-json \
    "$issues Previous RALPH commits: $ralph_commits $(cat "$SCRIPT_DIR/prompt.md")" \
  | tee "$tmpfile" \
  | grep --line-buffered '^{' \
  | jq --unbuffered -rj 'select(.type == "assistant").message.content[]? | select(.type == "text").text // empty'

  result=$(grep '^{' "$tmpfile" | jq -r 'select(.type == "result").result // empty')

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo ""
    echo "Ralph complete after $i iterations."
    exit 0
  fi
done
