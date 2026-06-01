# coding-discipline

A project-agnostic Claude Code plugin that enforces a few coding guardrails as hooks. Drop it on
any machine / any repo -- nothing inside is tied to one project.

## What it does

| Hook | Event | Behavior |
|---|---|---|
| `comment-discipline` | PostToolUse (Edit/Write/MultiEdit) | Blocks newly-written code that splits one comment across 2+ consecutive `//` lines (enforces "one physical `//` line, why-only"). |
| `typecheck-on-edit` | PostToolUse | After editing a `.ts/.tsx`, runs `tsc --noEmit` for the **owning package** -- walks up to the nearest `tsconfig.json`, then to the nearest `node_modules/.bin/tsc`. Works for single-package and monorepo layouts. Blocks on type errors. |
| `pre-push-secret-scan` | PreToolUse (Bash) | Before `git push`, scans git-tracked files for API keys, DB connection creds, private keys, and high-entropy `*_SECRET/_TOKEN/_PASSWORD=` assignments. Blocks the push if found. |
| `reuse-first-reminder` | PreToolUse (Write) | When creating a NEW `components/**/*.tsx|jsx`, asks you to confirm and lists existing components so you reuse instead of rebuilding a near-duplicate. |

All hooks are silent when clean. Scripts are bash + `python3` only -- no extra deps.

## Install on another machine

**Option A -- local folder (no marketplace):**
```bash
claude --plugin-dir /path/to/coding-discipline
```

**Option B -- marketplace (git repo, updatable):**
```bash
# one-time: point Claude at the repo hosting this plugin
/plugin marketplace add <git-url-or-owner/repo>
/plugin install coding-discipline
```

**Option C -- skills-dir auto-load (your own synced machines):**
Copy this folder into `~/.claude/skills/coding-discipline/` (it has a `.claude-plugin/plugin.json`,
so it auto-loads as `coding-discipline@skills-dir` with no install step). Handy if `~/.claude` is synced.

After installing, `/reload-plugins` (or restart) and confirm hooks fire.

## Notes / tuning

- **typecheck-on-edit blocks on a red baseline.** If a repo's `tsc --noEmit` already has errors, every
  edit will block until they're fixed. Disable just this hook (or fix the baseline) in such repos.
- **secret-scan patterns are generic.** Per-project secrets with an unusual shape (custom token env name)
  won't be caught -- add a project-local `pre-push-secret-scan` for those, or extend `secret_re` here.
- **reuse-first assumes a top-level `components/` (+ `components/ui/`).** Projects that put components
  elsewhere just won't trigger it; it never blocks, only asks.
- Buildinfo cache lives in `$TMPDIR` (the plugin dir is ephemeral across updates -- never written to).
