#!/usr/bin/env bash
# install.sh — symlink update-all.sh and SKILL.md into ~/.claude/.
#
# Idempotent. Re-running just refreshes the symlinks.
#
# Usage:
#   ./install.sh             # symlink script + skill, no launchd
#   ./install.sh --launchd   # also install the daily launchd job

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

SCRIPTS_DIR="$HOME/.claude/scripts"
SKILLS_DIR="$HOME/.claude/skills/update-all-tools"

mkdir -p "$SCRIPTS_DIR" "$SKILLS_DIR"

# Script
ln -sfn "$REPO_DIR/update-all.sh" "$SCRIPTS_DIR/update-all.sh"
chmod +x "$REPO_DIR/update-all.sh"
echo "✓ symlinked $SCRIPTS_DIR/update-all.sh → $REPO_DIR/update-all.sh"

# Skill
ln -sfn "$REPO_DIR/skill/SKILL.md" "$SKILLS_DIR/SKILL.md"
echo "✓ symlinked $SKILLS_DIR/SKILL.md → $REPO_DIR/skill/SKILL.md"

# Config example
if [ ! -f "$HOME/.claude/update-all.config" ]; then
  echo ""
  echo "  No config at ~/.claude/update-all.config — that's fine, defaults will run."
  echo "  To add extra repos / skill dirs, copy:"
  echo "    cp $REPO_DIR/update-all.config.example ~/.claude/update-all.config"
fi

if [ "${1:-}" = "--launchd" ]; then
  echo ""
  "$REPO_DIR/update-all.sh" --install-launchd
fi

echo ""
echo "Run a one-off update:  ~/.claude/scripts/update-all.sh"
