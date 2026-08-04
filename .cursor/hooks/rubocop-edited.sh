#!/usr/bin/env bash
# Cursor afterFileEdit: safe RuboCop autocorrect on the edited Ruby file.
# Always exit 0 — this event fires after the write; do not failClosed.

set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 0

INPUT="$(cat)"

if command -v jq >/dev/null 2>&1; then
  FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.file_path // empty')"
else
  FILE_PATH="$(printf '%s' "$INPUT" | ruby -rjson -e 'puts JSON.parse(STDIN.read)["file_path"].to_s')"
fi

[[ -z "$FILE_PATH" ]] && exit 0

# Canonicalize (follows .. and symlinks); only lint files inside this repo.
RESOLVED="$(realpath "$FILE_PATH" 2>/dev/null)" || exit 0
case "$RESOLVED" in
  "$ROOT"/*) ;;
  *) exit 0 ;;
esac

[[ "$RESOLVED" == *.rb ]] || exit 0
[[ -f "$RESOLVED" ]] || exit 0

bin/rubocop -a --force-exclusion -- "$RESOLVED" >/dev/null 2>&1 || true
exit 0
