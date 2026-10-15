#!/usr/bin/env bash
# restore the most recent pre-"off" global state (undo off.sh).
# Idempotent: safe to run even if nothing was backed up.
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

CAVEMAN_CONFIG_DIR="$HOME/AppData/Roaming/caveman"
CAVEMAN_CONFIG="$CAVEMAN_CONFIG_DIR/config.json"
BAK_CAVEMAN_CONFIG="$CLAUDE_DIR/.caveman-config.env-toggle-backup"
BAK_CAVEMAN_CONFIG_EXISTED="$CLAUDE_DIR/.caveman-config-existed.env-toggle-backup"

if [ ! -f "$STATE_FILE" ] || [ "$(cat "$STATE_FILE")" != "off" ]; then
  echo "State file does not say 'off' — nothing to restore. Doing nothing."
  exit 0
fi

if [ ! -f "$BAK_SETTINGS" ]; then
  echo "ERROR: no backup found at $BAK_SETTINGS — cannot restore safely. Aborting." >&2
  exit 1
fi

echo "Restoring most recent pre-off state..."
cp "$BAK_SETTINGS" "$SETTINGS"
rm -f "$BAK_SETTINGS"

if [ -f "$BAK_CLAUDE_MD" ]; then
  cp "$BAK_CLAUDE_MD" "$CLAUDE_MD"
  rm -f "$BAK_CLAUDE_MD"
fi

if [ -f "$BAK_CAVEMAN" ]; then
  cp "$BAK_CAVEMAN" "$CAVEMAN_ACTIVE"
  rm -f "$BAK_CAVEMAN"
else
  rm -f "$CAVEMAN_ACTIVE"
fi

if [ -f "$BAK_CAVEMAN_CONFIG_EXISTED" ]; then
  if [ "$(cat "$BAK_CAVEMAN_CONFIG_EXISTED")" = "1" ] && [ -f "$BAK_CAVEMAN_CONFIG" ]; then
    cp "$BAK_CAVEMAN_CONFIG" "$CAVEMAN_CONFIG"
  else
    rm -f "$CAVEMAN_CONFIG"
  fi
  rm -f "$BAK_CAVEMAN_CONFIG" "$BAK_CAVEMAN_CONFIG_EXISTED"
fi

if [ -f "$BAK_MCP" ]; then
  python3 - "$CLAUDE_JSON" "$BAK_MCP" <<'PYEOF'
import json, sys
path, backup_path = sys.argv[1], sys.argv[2]
with open(backup_path, encoding="utf-8") as f:
    mcp = json.load(f)
with open(path, encoding="utf-8") as f:
    data = json.load(f)
data["mcpServers"] = mcp
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PYEOF
  rm -f "$BAK_MCP"
fi

rm -f "$STATE_FILE"
echo "Done. settings.json, CLAUDE.md, caveman state (flag + default-mode config), and MCP servers restored to what they were before off.sh ran."
