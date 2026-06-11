#!/usr/bin/env bash
# Blocks blanket git staging so a session can't sweep up another parallel session's dirty files.
in=$(cat)
cmd=$(/usr/bin/jq -r '.tool_input.command // empty' <<<"$in")

# blanket staging: 'git' must directly precede the subcommand (modulo flags) so prose mentioning both can't fire
if echo "$cmd" | grep -Eq '\bgit([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+add\b.*(-A\b|--all\b|-u\b| \.( |$)|\*)'; then
  echo "Blocked: blanket 'git add' stages other parallel sessions' files. Stage the explicit paths you changed this session." >&2
  exit 2
fi

# 'git commit -a / -am' — auto-stages all tracked dirty files
if echo "$cmd" | grep -Eq '\bgit\b +commit\b[^|&]*( -a\b| --all\b| -[a-zA-Z]*a[a-zA-Z]*\b)'; then
  echo "Blocked: 'git commit -a' auto-stages everything. Run 'git add <your files>' then 'git commit'." >&2
  exit 2
fi

exit 0
