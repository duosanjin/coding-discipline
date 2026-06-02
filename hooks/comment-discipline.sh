#!/usr/bin/env bash
# PreToolUse hook (Edit|Write|MultiEdit): DENY the write when newly-added code carries a multi-line
# comment -- enforces "one physical // line, why-only; no /** */ JSDoc". Blocking PRE (exit 2) beats a
# post-hoc nag: the bad comment never reaches disk, so it can't survive a missed follow-up. Scans ONLY
# newly-added text, so legacy multi-line comments don't fire. Catches: 2+ consecutive // lines, any
# JSDoc /** */, and any /* */ block spanning 2+ physical lines. Silent on clean edits.

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

    # block comments: any JSDoc /** */ (banned outright), or any /* */ spanning 2+ physical lines
    for m in re.finditer(r"/\*.*?\*/", block, re.DOTALL):
        seg = m.group(0)
        is_jsdoc = seg.startswith("/**")
        spanned = seg.count("\n") + 1
        if is_jsdoc or spanned >= 2:
            kind = "JSDoc /** */" if is_jsdoc else "%d-line /* */ block" % spanned
            flags.append("%s: %s ..." % (kind, seg.strip().split("\n")[0][:70]))

if not flags:
    sys.exit(0)
print(
    "COMMENT GUARD blocked this write (one physical // line, why-only; no /** */ JSDoc) in %s:\n%s\n\n"
    "Collapse to ONE // capturing the load-bearing why, then retry the edit. If it can't fit one\n"
    "physical line, it's documentation -- distill it harder or move it to docs/, don't split a\n"
    "sentence across lines or reach for a /* */ block to dodge the rule."
    % (path, "\n".join("  - " + f for f in flags)),
    file=sys.stderr,
)
sys.exit(2)
PY
