#!/usr/bin/env bash
# PostToolUse hook (Edit|Write|MultiEdit): flag a single comment split across 2+ consecutive
# // lines in newly-added code -- enforces the "one physical // line, why-only" discipline.
# Scans ONLY newly-added text so legacy multi-line comments don't fire; this guards what gets
# written now. Exit 2 (blocking feedback) on a hit, 0 when clean. Silent on clean edits.

set -u
input="$(cat)"

# JSON via env var, not stdin: the heredoc below already owns python's stdin (it IS the program).
HOOK_INPUT="$input" /usr/bin/python3 - <<'PY'
import json, os, re, sys

data = json.loads(os.environ.get("HOOK_INPUT", "") or "{}")
ti = data.get("tool_input", {}) or {}
path = ti.get("file_path", "") or ""

if not path.endswith((".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs")):
    sys.exit(0)

blocks = []
if "content" in ti:                       # Write
    blocks.append(ti.get("content") or "")
if "new_string" in ti:                    # Edit
    blocks.append(ti.get("new_string") or "")
for e in (ti.get("edits") or []):         # MultiEdit
    blocks.append(e.get("new_string") or "")

flags = []
for block in blocks:
    lines = block.split("\n")
    run, start = 0, 0
    for i, ln in enumerate(lines):
        if re.match(r"^\s*//", ln):
            if run == 0:
                start = i
            run += 1
        else:
            if run >= 2:
                flags.append("%d consecutive // lines: %s ..." % (run, lines[start].strip()[:70]))
            run = 0
    if run >= 2:
        flags.append("%d consecutive // lines: %s ..." % (run, lines[start].strip()[:70]))

if not flags:
    sys.exit(0)
print(
    "COMMENT GUARD (one physical // line, why-only) in %s:\n%s\n\n"
    "Collapse to ONE // capturing the load-bearing why. If it can't fit one physical line,\n"
    "it's documentation -- distill it harder or move it to docs/, don't split a sentence\n"
    "across two // lines to dodge the rule."
    % (path, "\n".join("  - " + f for f in flags)),
    file=sys.stderr,
)
sys.exit(2)
PY
