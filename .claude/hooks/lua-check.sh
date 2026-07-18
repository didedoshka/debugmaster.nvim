#!/usr/bin/env bash
# PostToolUse gate: on any Lua edit, run the whole offline suite + lua-ls check.
# Exit 2 feeds diagnostics back to Claude at the edit that caused the break.
set -u

input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
case "$file" in
  *.lua) ;;
  *) exit 0 ;;
esac

root="$(cd "$(dirname "$0")/../.." && pwd)"

out="$(bash "$root/tests/run.sh" 2>&1)"
if [ $? -ne 0 ]; then
  {
    echo "offline suite failed (tests/run.sh):"
    printf '%s\n' "$out"
  } >&2
  exit 2
fi

check="$(lua-language-server --check "$root" 2>&1)"
if ! printf '%s' "$check" | grep -q "no problems found"; then
  {
    echo "lua-language-server --check found problems (baseline is 0):"
    printf '%s\n' "$check" | tr '\r' '\n' | grep -a '\.lua:[0-9]' | sed 's/\x1b\[[0-9;]*m//g'
  } >&2
  exit 2
fi

exit 0
