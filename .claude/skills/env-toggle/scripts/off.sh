#!/usr/bin/env bash
# turn OFF global confounders before a controlled run (backs up current state first).
# Idempotent: safe to run even if already "off".
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
CLAUDE_JSON="$HOME/.claude.json"
STATE_FILE="$CLAUDE_DIR/.env-toggle-state"
SETTINGS="$CLAUDE_DIR/settings.json"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
CAVEMAN_ACTIVE="$CLAUDE_DIR/.caveman-active"

BAK_SETTINGS="$CLAUDE_DIR/settings.json.env-toggle-backup"
BAK_CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md.env-toggle-backup"
BAK_CAVEMAN="$CLAUDE_DIR/.caveman-active.env-toggle-backup"
BAK_MCP="$CLAUDE_DIR/.claude.json.mcpServers.env-toggle-backup"

# caveman's real default-mode source (NOT .caveman-active — see caveman-config.js
# getDefaultMode(): env var > this config file > hardcoded 'full' fallback).
# Deleting .caveman-active alone does NOT make a new session start "off" — it
# just removes the override and the plugin falls back to 'full'. Confirmed by
# reading src/hooks/caveman-config.js in the installed plugin after off/on
# leaked into supposedly-clean "off" pilot runs.
CAVEMAN_CONFIG_DIR="$HOME/AppData/Roaming/caveman"
CAVEMAN_CONFIG="$CAVEMAN_CONFIG_DIR/config.json"
BAK_CAVEMAN_CONFIG="$CLAUDE_DIR/.caveman-config.env-toggle-backup"
BAK_CAVEMAN_CONFIG_EXISTED="$CLAUDE_DIR/.caveman-config-existed.env-toggle-backup"

if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "off" ]; then
  echo "Already off (state file says so). Nothing to do."
  exit 0
fi

echo "Backing up current state..."
cp "$SETTINGS" "$BAK_SETTINGS"
if [ -f "$CLAUDE_MD" ]; then
  cp "$CLAUDE_MD" "$BAK_CLAUDE_MD"
fi
if [ -f "$CAVEMAN_ACTIVE" ]; then
  cp "$CAVEMAN_ACTIVE" "$BAK_CAVEMAN"
else
  rm -f "$BAK_CAVEMAN"
fi

echo "Applying controlled-run settings..."

# 1. Remove PreToolUse/PostToolUse hooks, force effortLevel=medium, disable every
#    plugin except caveman (needed for the token-skill condition), using python.
python3 - "$SETTINGS" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
if "hooks" in data:
    data["hooks"].pop("PreToolUse", None)
    data["hooks"].pop("PostToolUse", None)
    if not data["hooks"]:
        data.pop("hooks")
data["effortLevel"] = "medium"
KEEP_PLUGINS = {"caveman@caveman"}
if "enabledPlugins" in data:
    for k in list(data["enabledPlugins"].keys()):
        if k not in KEEP_PLUGINS:
            data["enabledPlugins"][k] = False
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PYEOF

# 1b. Wipe MCP servers (gitnexus, obsidian, ...) in ~/.claude.json — back up just
#     the mcpServers value (not the whole file, which has volatile unrelated state).
if [ -f "$CLAUDE_JSON" ]; then
  python3 - "$CLAUDE_JSON" "$BAK_MCP" <<'PYEOF'
import json, sys
path, backup_path = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
with open(backup_path, "w", encoding="utf-8") as f:
    json.dump(data.get("mcpServers", {}), f, indent=2, ensure_ascii=False)
data["mcpServers"] = {}
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PYEOF
fi

# 2. Move global CLAUDE.md out of the way (content preserved in backup).
if [ -f "$CLAUDE_MD" ]; then
  rm "$CLAUDE_MD"
fi

# 3. Clear caveman active-state (statusline/mid-session tracking only — NOT the
#    default-mode source, see comment above).
rm -f "$CAVEMAN_ACTIVE"

# 3b. Force caveman's actual default mode to "off" via its config file, so a
#     brand-new session genuinely starts off instead of falling back to "full".
mkdir -p "$CAVEMAN_CONFIG_DIR"
if [ -f "$CAVEMAN_CONFIG" ]; then
  cp "$CAVEMAN_CONFIG" "$BAK_CAVEMAN_CONFIG"
  echo "1" > "$BAK_CAVEMAN_CONFIG_EXISTED"
else
  echo "0" > "$BAK_CAVEMAN_CONFIG_EXISTED"
fi
python3 - "$CAVEMAN_CONFIG" <<'PYEOF'
import json, sys
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}
data["defaultMode"] = "off"
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PYEOF

echo "off" > "$STATE_FILE"
echo "Done. settings.json hooks removed, effortLevel=medium, non-caveman plugins disabled,"
echo "MCP servers (gitnexus/obsidian) wiped, global CLAUDE.md moved out, caveman default mode"
echo "forced to off (config.json, not just the flag file)."
echo "Restore later with: bash \"$CLAUDE_DIR/skills/env-toggle/scripts/restore.sh\""
