---
name: env-toggle
description: Use when preparing the machine for a controlled skill-benchmark experiment run (off/skill condition) — turns off global confounders (PreToolUse/PostToolUse hooks, non-medium effort level, global CLAUDE.md, leftover caveman state) before a run, and restores the most recent prior state afterward. Trigger phrases like "ปิดสภาพแวดล้อมสำหรับรัน experiment", "เตรียมเครื่องสำหรับ pilot/experiment", "คืนค่า settings กลับ", "เปิดกลับที่ล่าสุด".
---

# Environment toggle

Backs up and modifies **global** `~/.claude/settings.json`, `~/.claude/CLAUDE.md`,
and `~/.claude/.caveman-active` — this affects every Claude Code session on this
machine, not just the current project, until restored. Always pair an `off` with a
later `restore` — never leave the machine in the "off" state longer than one run.

## What "off" changes

1. Removes the `PreToolUse`/`PostToolUse` GitNexus hooks from `settings.json`
   (they inject graph-context enrichment on every Grep/Glob/Bash call — a real
   confound for the "off" experimental condition).
2. Forces `effortLevel` to `"medium"` in `settings.json` (the locked control
   variable — the machine default was found to be `"high"`, which would violate
   the control variable if left as-is).
3. Disables every plugin in `enabledPlugins` **except** `caveman@caveman`
   (playwright, frontend-design, feature-dev, claude-md-management, hookify,
   obsidian@obsidian-skills) — each installed plugin's tool/skill definitions
   add to every session's cached prefix regardless of whether it's used, which
   was found to swamp the real token signal between conditions (cache_read hit
   200K–500K+ tokens on a tiny bugfix task in pilot testing). Caveman stays
   enabled because it's one of the two skills under test.
4. Wipes `mcpServers` in `~/.claude.json` (gitnexus, obsidian MCP) — same
   prefix-bloat reason as #3. Only the `mcpServers` *value* is backed up, not
   the whole file, since `~/.claude.json` also holds unrelated volatile state
   (session counts, caches) that shouldn't be rolled back.
5. Removes the global `~/.claude/CLAUDE.md` (it auto-injects a graphify trigger
   into every session).
6. Forces caveman's real default-mode source, `%APPDATA%\caveman\config.json`
   (`defaultMode: "off"`), so a **new** session genuinely starts off. Also
   clears `~/.claude/.caveman-active` (statusline/mid-session tracking only).
   ⚠️ Discovered the hard way: `.caveman-active` alone is NOT the default-mode
   source — `caveman-config.js`'s `getDefaultMode()` resolution order is env
   var → `config.json` → hardcoded `'full'`. Deleting only the flag file left
   every "off" pilot run silently defaulting back to full caveman mode.

Every change is backed up first (`<file>.env-toggle-backup`, or just the
`mcpServers` value for `~/.claude.json`) and a state marker
`~/.claude/.env-toggle-state` is set to `off`, so `restore` can always undo it
exactly — this is "off", not "reset to some fixed default".

⚠️ **Scope limit:** this only touches locally-configured plugins/MCP servers.
Claude.ai account-level connectors (Gmail, Google Calendar, company-internal) and
the Chrome extension are not local config and can't be toggled by this script
— they were not found to be a major contributor to prefix size in pilot
testing (unlike gitnexus/obsidian/playwright), so this is a known, accepted
gap, not an oversight.

## How to run

```bash
bash "$HOME/.claude/skills/env-toggle/scripts/off.sh"
# ... do the run(s) ...
bash "$HOME/.claude/skills/env-toggle/scripts/restore.sh"
```

Both scripts are idempotent — running `off.sh` twice in a row does nothing the
second time, same for `restore.sh` when there is nothing to restore.

## ⚠️ What this does NOT do

- Does not stop caveman mode in a session that is **already** running with it
  active — that only clears the state file so the *next new* session starts
  clean. If caveman is active in your current session, type `/caveman stop`
  yourself before starting the next one.
- Does not touch anything inside `workspace/sample-project*` repos (git state,
  `.claude/skills/verification-before-completion/`) — that's the per-repo
  toggle, handled separately per `workspace/skills/README.md`.
- Does not restart Claude Code for you — some settings (plugin/hook changes)
  only take effect in a fresh session; always open a **new** session after
  running `off.sh`, never resume one that started before it ran.

## When to use each

- Run `off.sh` right before starting the `off` or `accuracy-skill` conditions
  (both need the machine in its clean/controlled state — `accuracy-skill` adds
  the per-repo `.claude/skills/verification-before-completion/` on top of this
  same clean baseline).
- For a command-type skill (e.g. Caveman), still run `off.sh` first (same
  clean baseline), then send the priming command inside that session only.
- Run `restore.sh` once at the very end of a (task, skill) pair's 6 real runs
  (or sooner if you need normal Claude Code behaviour back for other work) —
  don't restore between every single run, that's wasted churn; `off` state is
  safe to stay in across consecutive runs.
