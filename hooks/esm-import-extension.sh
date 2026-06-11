#!/usr/bin/env bash
# PreToolUse hook (Edit|Write|MultiEdit): DENY writes that add extensionless relative imports to a
# Node-run ESM TypeScript package. `tsc --noEmit` passes them (even moduleResolution Bundler) but the
# compiled `node dist/` boot hard-crashes with ERR_MODULE_NOT_FOUND -- only a real prod boot catches it,
# usually as a container crash-loop. Gate: nearest package.json has "type":"module" AND no bundler dep
# (vite/next/webpack/... means the code never runs on raw Node, where extensionless is fine). Silent when clean.

set -u
input="$(cat)"

# JSON via env var, not stdin: the heredoc below already owns python's stdin (it IS the program).
HOOK_INPUT="$input" /usr/bin/python3 - <<'PY'
import json, os, re, sys

data = json.loads(os.environ.get("HOOK_INPUT", "") or "{}")
ti = data.get("tool_input", {}) or {}
path = ti.get("file_path", "") or ""

# .ts/.mts only: .tsx implies a bundler pipeline, .d.ts is never executed.
if path.endswith(".d.ts") or not path.endswith((".ts", ".mts")):
    sys.exit(0)

# Nearest package.json walking up = the owning package.
d = os.path.dirname(os.path.abspath(path))
pkg = None
while d and d != "/":
    cand = os.path.join(d, "package.json")
    if os.path.isfile(cand):
        try:
            pkg = json.load(open(cand))
        except Exception:
            sys.exit(0)
        break
    d = os.path.dirname(d)
if not pkg or pkg.get("type") != "module":
    sys.exit(0)

# A bundler dep means output is bundled, never run as raw Node ESM -- extensionless is safe there.
BUNDLERS = ("vite", "next", "webpack", "rollup", "parcel", "astro", "@remix-run/dev", "react-scripts")
deps = {**(pkg.get("dependencies") or {}), **(pkg.get("devDependencies") or {})}
if any(b in deps for b in BUNDLERS):
    sys.exit(0)

blocks = []
if "content" in ti:                       # Write
    blocks.append(ti.get("content") or "")
if "new_string" in ti:                    # Edit
    blocks.append(ti.get("new_string") or "")
for e in (ti.get("edits") or []):         # MultiEdit
    blocks.append(e.get("new_string") or "")

# Relative specifiers in static import/export-from, side-effect import, and dynamic import().
spec_re = re.compile(
    r"""(?:\bfrom\s*|\bimport\s*\(\s*|\bimport\s+)['"](\.\.?/[^'"]*)['"]"""
)
flags = []
for block in blocks:
    for m in spec_re.finditer(block):
        spec = m.group(1)
        last = spec.rstrip("/").split("/")[-1]
        if "." not in last or spec.endswith("/"):
            flags.append(spec)

if not flags:
    sys.exit(0)
print(
    "ESM IMPORT GUARD blocked this write in %s -- extensionless relative import in a \"type\":\"module\"\n"
    "package that runs on raw Node:\n%s\n\n"
    "tsc and tsx both tolerate these, but the compiled `node dist/` boot crashes with\n"
    "ERR_MODULE_NOT_FOUND (container crash-loop). Add the explicit `.js` extension (yes, .js even in\n"
    ".ts source) and point directory imports at the file, e.g. './routes/index.js'."
    % (path, "\n".join("  - '%s'" % f for f in sorted(set(flags)))),
    file=sys.stderr,
)
sys.exit(2)
PY
