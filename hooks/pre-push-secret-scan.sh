#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash): before a `git push`, scan every git-TRACKED file in the active
# project for high-signal secrets and BLOCK (exit 2) if any are found. Non-push Bash commands pass
# through (exit 0). Generic patterns -- API keys, DB connection creds, private keys, high-entropy
# *_SECRET/_TOKEN/_PASSWORD assignments. Guards against a secret accidentally landing in a tracked file.

set -u
input="$(cat)"
cmd=$(printf '%s' "$input" | /usr/bin/python3 -c \
  'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' \
  2>/dev/null) || exit 0

case "$cmd" in
  *"git push"*) : ;;
  *) exit 0 ;;
esac

root="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$root" || exit 0

# High-signal, low-false-positive shapes. No single quotes inside so the whole thing single-quotes cleanly.
secret_re='sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{36,}|(postgres(ql)?|mysql|mongodb(\+srv)?)://[^:@/[:space:]]+:[^@/[:space:]]+@|(SECRET|TOKEN|PASSWORD|PRIVATE_KEY|API_KEY|APIKEY|ACCESS_KEY)[[:space:]]*[=:][[:space:]]*[^[:space:]]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----'

# Env-var references / placeholders are not embedded literals: ${VAR}, $(cmd), process.env.X, import.meta.env, os.getenv(), <YOUR_TOKEN>.
ref_re='\$\{|\$\(|process\.env\.|import\.meta\.env|os\.environ|os\.getenv\(|System\.getenv\(|<[A-Za-z0-9_.-]+>'

# Scan tracked files line-by-line; drop env-ref lines and placeholder/template files, then reduce to the offending filenames.
hits=$(git ls-files -z 2>/dev/null | xargs -0 grep -nHE "$secret_re" 2>/dev/null \
         | grep -vE '\.(example|sample|template|dist):|(^|/)\.env\.(example|sample|template):' \
         | grep -vE "$ref_re" \
         | cut -d: -f1 | sort -u)

[ -z "$hits" ] && exit 0
{
  echo "PRE-PUSH SECRET SCAN blocked the push -- tracked files contain secret-looking values:"
  echo ""
  printf '      %s\n' $hits
  echo ""
  echo "Move the value into an ignored .env, or re-run the push intentionally after confirming"
  echo "these are placeholders / safe."
} >&2
exit 2
