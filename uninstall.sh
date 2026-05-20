#!/usr/bin/env bash
# uninstall.sh — remove symlinks and launchd job installed by install.sh.
#
# Does NOT delete logs (~/.claude/logs/update-all-*.log) or your config
# (~/.claude/update-all.config). Remove those manually if desired.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_LINK="$HOME/.claude/scripts/update-all.sh"
SKILL_LINK="$HOME/.claude/skills/update-all-tools/SKILL.md"
SKILL_DIR="$HOME/.claude/skills/update-all-tools"

# launchd job (best-effort; tolerates already-uninstalled state)
"$REPO_DIR/update-all.sh" --uninstall-launchd 2>/dev/null || true

# Remove symlinks (only if they point at this repo — don't clobber another install)
if [ -L "$SCRIPTS_LINK" ] && [ "$(readlink "$SCRIPTS_LINK")" = "$REPO_DIR/update-all.sh" ]; then
  rm "$SCRIPTS_LINK"
  echo "✓ removed $SCRIPTS_LINK"
fi
if [ -L "$SKILL_LINK" ] && [ "$(readlink "$SKILL_LINK")" = "$REPO_DIR/skill/SKILL.md" ]; then
  rm "$SKILL_LINK"
  echo "✓ removed $SKILL_LINK"
  # Drop the now-empty skill dir
  if [ -d "$SKILL_DIR" ] && [ -z "$(ls -A "$SKILL_DIR")" ]; then
    rmdir "$SKILL_DIR"
    echo "✓ removed empty $SKILL_DIR"
  fi
fi

echo ""
echo "Logs at ~/.claude/logs/update-all-*.log were left in place."
echo "Config at ~/.claude/update-all.config (if present) was left in place."
