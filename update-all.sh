#!/usr/bin/env bash
# update-all.sh — mass-update Claude Code, plugins, and dev tools.
#
# Idempotent. Safe to re-run. Logs to ~/.claude/logs/update-all-YYYY-MM-DD.log.
# Exit code 0 = all green, 1 = at least one section failed.
#
# Run manually:        ~/.claude/scripts/update-all.sh
# Install launchd job: ~/.claude/scripts/update-all.sh --install-launchd
# Uninstall:           ~/.claude/scripts/update-all.sh --uninstall-launchd
#
# Optional config: ~/.claude/update-all.config (sourced bash). See
# update-all.config.example for the shape. If absent, only the universal
# sections run (Claude Code CLI, plugins, ~/.claude/skills, etc.).

set -uo pipefail

LAUNCHD_LABEL="com.claude.update-all"
LAUNCHD_HOUR=7
LAUNCHD_MINUTE=30

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/update-all-$(date +%Y-%m-%d).log"

# Load optional user config
CONFIG_FILE="$HOME/.claude/update-all.config"
EXTRA_GIT_REPOS=()
SKILL_DIRS=("$HOME/.claude/skills")
ENABLE_HOMEBREW=1
ENABLE_SF_CLI=1
ENABLE_UV=1
ENABLE_NPM_REPORT=1
ENABLE_DISK_CHECK=1
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

# Colors only when stdout is a TTY (so launchd logs stay clean).
if [ -t 1 ]; then
  GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  GREEN=""; RED=""; YELLOW=""; DIM=""; RESET=""
fi

FAIL_COUNT=0
SECTION_RESULTS=()

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

section() {
  local name="$1" cmd="$2"
  log ""
  log "${DIM}─── $name ───${RESET}"
  if eval "$cmd" 2>&1 | tee -a "$LOG_FILE"; then
    log "${GREEN}✓ $name${RESET}"
    SECTION_RESULTS+=("✓ $name")
  else
    log "${RED}✗ $name${RESET}"
    SECTION_RESULTS+=("✗ $name")
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# --- Handle --install-launchd flag ----------------------------------------
if [ "${1:-}" = "--install-launchd" ]; then
  PLIST="$HOME/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"
  SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LAUNCHD_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${SCRIPT_PATH}</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>${LAUNCHD_HOUR}</integer>
    <key>Minute</key><integer>${LAUNCHD_MINUTE}</integer>
  </dict>
  <key>RunAtLoad</key>
  <false/>
  <key>StandardOutPath</key>
  <string>${HOME}/.claude/logs/launchd-stdout.log</string>
  <key>StandardErrorPath</key>
  <string>${HOME}/.claude/logs/launchd-stderr.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>${HOME}/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
</dict>
</plist>
EOF
  DOMAIN="gui/$(id -u)"
  launchctl bootout "$DOMAIN/${LAUNCHD_LABEL}" 2>/dev/null || true
  launchctl bootstrap "$DOMAIN" "$PLIST"
  echo "✓ launchd job installed at $PLIST"
  echo "  Runs daily at ${LAUNCHD_HOUR}:$(printf '%02d' $LAUNCHD_MINUTE)."
  echo "  Disable:  launchctl bootout $DOMAIN/${LAUNCHD_LABEL}"
  echo "  Test now: launchctl start ${LAUNCHD_LABEL}"
  exit 0
fi

if [ "${1:-}" = "--uninstall-launchd" ]; then
  PLIST="$HOME/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"
  DOMAIN="gui/$(id -u)"
  launchctl bootout "$DOMAIN/${LAUNCHD_LABEL}" 2>/dev/null || true
  rm -f "$PLIST"
  echo "✓ launchd job removed"
  exit 0
fi

# --- Run updates ----------------------------------------------------------
log "═══ update-all started: $(date) ═══"
log "Log: $LOG_FILE"
[ -f "$CONFIG_FILE" ] && log "Config: $CONFIG_FILE"

# Homebrew (system package manager — updates many tools system-wide)
if [ "$ENABLE_HOMEBREW" = "1" ]; then
section "Homebrew" '
  if command -v brew >/dev/null 2>&1; then
    FAILED=0
    brew update 2>&1 | sed "s/^/  /" || FAILED=1
    brew upgrade 2>&1 | sed "s/^/  /" || FAILED=1
    brew cleanup 2>&1 | sed "s/^/  /" || FAILED=1
    exit $FAILED
  else
    echo "  brew not on PATH"
  fi
'
fi

# 1. Claude Code CLI
section "Claude Code CLI" '
  if command -v claude >/dev/null 2>&1; then
    BEFORE=$(claude --version 2>/dev/null | head -1)
    claude update 2>&1 || claude --version
    AFTER=$(claude --version 2>/dev/null | head -1)
    echo "  $BEFORE → $AFTER"
  else
    echo "claude CLI not on PATH"
    false
  fi
'

# Salesforce CLI
if [ "$ENABLE_SF_CLI" = "1" ]; then
section "Salesforce CLI" '
  if command -v sf >/dev/null 2>&1; then
    BEFORE=$(sf --version 2>/dev/null | head -1)
    sf update 2>&1 | sed "s/^/  /" || echo "  (sf update unavailable — try: npm i -g @salesforce/cli)"
    AFTER=$(sf --version 2>/dev/null | head -1)
    echo "  $BEFORE"
    echo "  $AFTER"
  else
    echo "  sf not on PATH"
  fi
'
fi

# uv (Python package manager)
if [ "$ENABLE_UV" = "1" ]; then
section "uv" '
  if command -v uv >/dev/null 2>&1; then
    BEFORE=$(uv --version 2>/dev/null)
    uv self update 2>&1 | sed "s/^/  /" || true
    AFTER=$(uv --version 2>/dev/null)
    echo "  $BEFORE → $AFTER"
  else
    echo "  uv not on PATH"
  fi
'
fi

# 2. context-mode plugin (has its own upgrade CLI)
section "context-mode plugin" '
  CTX_DIR=$(ls -d ~/.claude/plugins/cache/context-mode/context-mode/*/ 2>/dev/null | sort -V | tail -1)
  if [ -n "$CTX_DIR" ] && [ -f "$CTX_DIR/cli.bundle.mjs" ]; then
    node "$CTX_DIR/cli.bundle.mjs" upgrade 2>&1 | tail -30
  else
    echo "context-mode not found, skipping"
  fi
'

# 3. Other Claude plugins (best-effort: git pull where possible, auto-stash local edits)
section "Claude plugins (git pull)" '
  COUNT=0; FAILED=0
  STAMP=$(date +%Y-%m-%d)
  for git_dir in $(find ~/.claude/plugins/cache -maxdepth 5 -name ".git" -type d 2>/dev/null); do
    plugin_dir=$(dirname "$git_dir")
    name=$(basename "$plugin_dir")
    echo "  pulling $name..."
    STASHED=0
    if [ -n "$(git -C "$plugin_dir" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
      if git -C "$plugin_dir" stash push -m "auto-stash update-all $STAMP" >/dev/null 2>&1; then
        STASHED=1
        echo "    (auto-stashed local edits)"
      fi
    fi
    if ! git -C "$plugin_dir" pull --ff-only 2>&1 | sed "s/^/    /"; then
      echo "    (pull failed)"
      FAILED=1
    fi
    if [ "$STASHED" -eq 1 ]; then
      if ! git -C "$plugin_dir" stash pop 2>&1 | sed "s/^/    /"; then
        echo "    (stash pop failed — edits remain in stash drawer; resolve manually)"
        FAILED=1
      fi
    fi
    COUNT=$((COUNT + 1))
  done
  echo "  pulled $COUNT plugin git repo(s)"
  exit $FAILED
'

# 4. Skill directories (configured via SKILL_DIRS, defaults to ~/.claude/skills)
for SKILL_ROOT in "${SKILL_DIRS[@]}"; do
  # Expand ~ if present
  SKILL_ROOT="${SKILL_ROOT/#\~/$HOME}"
  [ -d "$SKILL_ROOT" ] || continue
  section "$SKILL_ROOT" "
    COUNT=0; DIRTY=0; FAILED=0
    STAMP=\$(date +%Y-%m-%d)
    for git_dir in \$(find '$SKILL_ROOT' -maxdepth 3 -name '.git' -type d 2>/dev/null); do
      skill_dir=\$(dirname \"\$git_dir\")
      name=\$(basename \"\$skill_dir\")
      if [ -n \"\$(git -C \"\$skill_dir\" status --porcelain 2>/dev/null)\" ]; then
        echo \"  \$name: skipping — local uncommitted changes\"
        DIRTY=\$((DIRTY + 1))
        continue
      fi
      if ! git -C \"\$skill_dir\" remote | grep -q .; then
        echo \"  \$name: local-only (no remote) — skipping\"
        continue
      fi
      echo \"  pulling \$name...\"
      if ! git -C \"\$skill_dir\" pull --ff-only 2>&1 | sed 's/^/    /'; then
        echo '    (pull failed)'
        FAILED=1
      fi
      COUNT=\$((COUNT + 1))
    done
    echo \"  \$COUNT pulled, \$DIRTY skipped (dirty working tree)\"
    exit \$FAILED
  "
done

# 5. Extra user-configured git repos (optional, from EXTRA_GIT_REPOS)
for REPO in "${EXTRA_GIT_REPOS[@]:-}"; do
  [ -n "$REPO" ] || continue
  REPO="${REPO/#\~/$HOME}"
  REPO_NAME=$(basename "$REPO")
  section "$REPO_NAME" "
    FAILED=0
    if [ -d '$REPO/.git' ]; then
      cd '$REPO'
      STAMP=\$(date +%Y-%m-%d)
      STASHED=0
      if [ -n \"\$(git status --porcelain --untracked-files=no 2>/dev/null)\" ]; then
        if git stash push -m \"auto-stash update-all \$STAMP\" >/dev/null 2>&1; then
          STASHED=1
          echo '  (auto-stashed local edits)'
        fi
      fi
      if ! git remote | grep -q .; then
        echo '  local-only repo (no remote) — nothing to pull'
      else
        git pull --ff-only 2>&1 | sed 's/^/  /' || FAILED=1
      fi
      if [ \"\$STASHED\" -eq 1 ]; then
        if ! git stash pop 2>&1 | sed 's/^/  /'; then
          echo '  (stash pop failed — edits remain in stash drawer; resolve manually)'
          FAILED=1
        fi
      fi
      if [ -f pyproject.toml ] && command -v uv >/dev/null 2>&1; then
        uv sync 2>&1 | tail -5 | sed 's/^/  /' || FAILED=1
      fi
    else
      echo '  not a git repo: $REPO'
    fi
    exit \$FAILED
  "
done

# Global npm packages (report only — auto-bumping globals is risky)
if [ "$ENABLE_NPM_REPORT" = "1" ]; then
section "npm globals (report)" '
  if command -v npm >/dev/null 2>&1; then
    OUTDATED=$(npm outdated -g --depth=0 2>/dev/null || true)
    if [ -n "$OUTDATED" ]; then
      echo "$OUTDATED" | sed "s/^/  /"
      echo "  (review then bump manually with: npm i -g <name>)"
    else
      echo "  all global packages up to date"
    fi
  else
    echo "  npm not on PATH"
  fi
'
fi

# Disk space sanity check (~ partition)
if [ "$ENABLE_DISK_CHECK" = "1" ]; then
section "Disk space" '
  STATS=$(df -hP "$HOME" | awk "NR==2 {print \$5, \$4}")
  USED=$(echo "$STATS" | cut -d" " -f1)
  AVAIL_H=$(echo "$STATS" | cut -d" " -f2)
  AVAIL_G=$(df -gP "$HOME" | awk "NR==2 {print \$4}")
  echo "  $USED used, $AVAIL_H free"
  if [ "${AVAIL_G:-0}" -lt 10 ]; then
    echo "  WARNING: less than 10 GB free on $HOME partition"
    exit 1
  fi
'
fi

# Log rotation — drop update-all logs older than 30 days
section "Log rotation" '
  DELETED=$(find "$HOME/.claude/logs" -name "update-all-*.log" -mtime +30 -print -delete 2>/dev/null | wc -l | tr -d " ")
  echo "  deleted $DELETED log file(s) older than 30 days"
'

# --- Summary --------------------------------------------------------------
log ""
log "═══ summary ═══"
for r in "${SECTION_RESULTS[@]}"; do log "  $r"; done
log ""
if [ "$FAIL_COUNT" -eq 0 ]; then
  log "${GREEN}all green${RESET}"
  exit 0
else
  log "${YELLOW}$FAIL_COUNT section(s) failed — see $LOG_FILE${RESET}"
  exit 1
fi
