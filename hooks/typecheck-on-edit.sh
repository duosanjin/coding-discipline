#!/usr/bin/env bash
# PostToolUse hook: run `tsc --noEmit` for the package owning the edited TS file. Generic across
# single-package and monorepo layouts -- walks up from the file to the nearest tsconfig.json (the
# owning package), then up from there to the nearest node_modules/.bin/tsc (monorepos hoist to root).
# Exit 2 (blocking feedback) on type errors; 0 on success / non-TS / no tsconfig / no tsc. Silent on success.

set -u
input="$(cat)"
file=$(printf '%s' "$input" | /usr/bin/python3 -c \
  'import json,sys; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' \
  2>/dev/null) || exit 0

# Only .ts/.tsx; skip declaration files -- we don't author those.
case "$file" in
  *.d.ts) exit 0 ;;
  *.ts|*.tsx) : ;;
  *) exit 0 ;;
esac
[ -f "$file" ] || exit 0

# Nearest tsconfig.json walking up from the edited file's directory = the owning package.
pkg_dir=""
d=$(dirname "$file")
while [ -n "$d" ] && [ "$d" != "/" ]; do
  if [ -f "$d/tsconfig.json" ]; then pkg_dir="$d"; break; fi
  d=$(dirname "$d")
done
[ -n "$pkg_dir" ] || exit 0

# Nearest tsc binary walking up from the package dir.
tsc=""
d="$pkg_dir"
while [ -n "$d" ] && [ "$d" != "/" ]; do
  if [ -x "$d/node_modules/.bin/tsc" ]; then tsc="$d/node_modules/.bin/tsc"; break; fi
  d=$(dirname "$d")
done
[ -n "$tsc" ] || exit 0

cd "$pkg_dir" || exit 0
# Incremental buildinfo in TMPDIR (keyed by package path) -- never write into the repo or the plugin dir.
hash=$(printf '%s' "$pkg_dir" | cksum | cut -d' ' -f1)
bi="${TMPDIR:-/tmp}/cc-discipline-tsc-$hash.tsbuildinfo"
out=$("$tsc" --noEmit --incremental --tsBuildInfoFile "$bi" 2>&1)
status=$?
if [ "$status" -ne 0 ]; then
  {
    printf 'tsc --noEmit failed in %s after editing %s:\n' "$pkg_dir" "$file"
    printf '%s\n' "$out" | head -60
  } >&2
  exit 2
fi
exit 0
