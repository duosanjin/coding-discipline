#!/usr/bin/env bash
# PreToolUse hook (matcher: Write): when CREATING a new component under components/, surface the
# existing component inventory and ask the user to confirm -- so an existing one gets reused instead
# of a near-duplicate. Allows silently for edits to existing files and any non-component path.
# Uses exit-0 JSON "ask" (PreToolUse ignores exit-2 JSON, and "ask" can't deadlock on retry).

set -u
input="$(cat)"
HOOK_INPUT="$input" PROJ="${CLAUDE_PROJECT_DIR:-$PWD}" /usr/bin/python3 - <<'PY'
import json, os, sys

data = json.loads(os.environ.get("HOOK_INPUT", "") or "{}")
ti = data.get("tool_input", {}) or {}
path = ti.get("file_path", "") or ""

# Only guard NEW component files under components/; edits to existing files pass silently.
if "/components/" not in path or not path.endswith((".tsx", ".jsx")) or os.path.exists(path):
    sys.exit(0)

root = os.environ.get("PROJ", "") or ""
def listing(sub):
    try:
        return sorted(f for f in os.listdir(os.path.join(root, sub)) if f.endswith((".tsx", ".jsx")))
    except OSError:
        return []
prim = listing("components/ui")
comp = listing("components")

reason = (
    "Creating a NEW component (%s). Reuse-first: check existing components before writing a near-duplicate --\n"
    "  components/ui/: %s\n"
    "  components/: %s\n"
    "If an existing one fits, reuse it; if a new component is genuinely needed, confirm."
    % (os.path.basename(path), ", ".join(prim) or "(none)", ", ".join(comp) or "(none)")
)
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": reason,
}}))
sys.exit(0)
PY
