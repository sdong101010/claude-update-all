#!/usr/bin/env bash
# install.sh — set up claude-update-all on this machine.
#
# Default behavior (recommended): symlinks the script + skill, AND installs
# the daily launchd job so updates run automatically every morning.
#
# Idempotent. Re-running just refreshes the symlinks and re-applies the plist.
#
# Usage:
#   ./install.sh                # symlink script + skill, install daily launchd job
#   ./install.sh --no-schedule  # symlink only — no launchd job (manual runs only)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

SCHEDULE=1
if [ "${1:-}" = "--no-schedule" ]; then
  SCHEDULE=0
elif [ "${1:-}" = "--launchd" ]; then
  # Backward-compat: --launchd was the old opt-in flag, now redundant.
  SCHEDULE=1
fi

SCRIPTS_DIR="$HOME/.claude/scripts"
SKILLS_DIR="$HOME/.claude/skills/update-all-tools"

mkdir -p "$SCRIPTS_DIR" "$SKILLS_DIR"

# Script
ln -sfn "$REPO_DIR/update-all.sh" "$SCRIPTS_DIR/update-all.sh"
chmod +x "$REPO_DIR/update-all.sh"
echo "✓ symlinked $SCRIPTS_DIR/update-all.sh → $REPO_DIR/update-all.sh"

# Skill (Claude Code auto-discovers skills under ~/.claude/skills/, no extra step needed)
ln -sfn "$REPO_DIR/skill/SKILL.md" "$SKILLS_DIR/SKILL.md"
echo "✓ symlinked $SKILLS_DIR/SKILL.md → $REPO_DIR/skill/SKILL.md"
echo "  (Claude will discover the update-all-tools skill automatically.)"

# Launchd job
if [ "$SCHEDULE" = "1" ]; then
  echo ""
  "$REPO_DIR/update-all.sh" --install-launchd
fi

# Friendly summary
echo ""
echo "═════════════════════════════════════════════════════════════"
echo " Done. Here's what's set up:"
echo "═════════════════════════════════════════════════════════════"
echo "  • Script:        $SCRIPTS_DIR/update-all.sh"
echo "  • Skill:         $SKILLS_DIR/SKILL.md"
if [ "$SCHEDULE" = "1" ]; then
  # Read the actual scheduled time from config (if any), falling back to defaults
  LAUNCHD_HOUR=7; LAUNCHD_MINUTE=30
  CFG="$HOME/.claude/update-all.config"
  if [ -f "$CFG" ]; then
    # shellcheck disable=SC1090
    source "$CFG"
  fi
  printf "  • Daily run:     %02d:%02d local time (via launchd)\n" "$LAUNCHD_HOUR" "$LAUNCHD_MINUTE"
fi
echo ""
echo " Run a one-off update now:"
echo "   ~/.claude/scripts/update-all.sh"
echo ""
if [ "$SCHEDULE" = "1" ]; then
  echo " Change the schedule (e.g. 09:30 instead of 07:30):"
  echo "   echo 'LAUNCHD_HOUR=9'  >> ~/.claude/update-all.config"
  echo "   echo 'LAUNCHD_MINUTE=30' >> ~/.claude/update-all.config"
  echo "   ~/.claude/scripts/update-all.sh --install-launchd   # regen plist"
  echo ""
fi
echo " Add extra repos / toggle sections (optional):"
echo "   cp $REPO_DIR/update-all.config.example ~/.claude/update-all.config"
echo "   \$EDITOR ~/.claude/update-all.config"
echo ""
if [ "$SCHEDULE" = "1" ]; then
  echo " Stop the daily run later:"
  echo "   ~/.claude/scripts/update-all.sh --uninstall-launchd"
else
  echo " Daily run is NOT scheduled. To enable later:"
  echo "   ~/.claude/scripts/update-all.sh --install-launchd"
fi
echo "═════════════════════════════════════════════════════════════"
