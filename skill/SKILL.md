---
name: update-all-tools
description: Mass-update Claude Code CLI, plugins (context-mode et al), Homebrew packages, Salesforce CLI, uv, and git-managed skills under ~/.claude/skills (and any extra repos configured by the user). TRIGGER when user says "update everything", "mass update", "update my tools", "update CC", "is everything up to date", or asks about the daily update job. DO NOT TRIGGER for updating a single specific tool (run that tool's own update directly).
---

# update-all-tools

Drives `~/.claude/scripts/update-all.sh` — a mass-update script for the Claude Code ecosystem and surrounding dev tools.

## What it updates (default sections)

1. **Homebrew** — `brew update && brew upgrade && brew cleanup` (toggle: `ENABLE_HOMEBREW`)
2. **Claude Code CLI** — `claude update`
3. **Salesforce CLI** — `sf update` (toggle: `ENABLE_SF_CLI`)
4. **uv** (Python package manager) — `uv self update` (toggle: `ENABLE_UV`)
5. **context-mode plugin** — runs the plugin's own `cli.bundle.mjs upgrade` (rebuilds native modules, updates hooks)
6. **Other Claude plugins** under `~/.claude/plugins/cache/` — git pull where `.git` exists, with auto-stash of local edits
7. **`~/.claude/skills/`** — git pull any skill that's a git repo, skipping dirty trees
8. **Extra git repos** from user config — git pull, plus `uv sync` if `pyproject.toml` is present
9. **npm globals (report only)** — surfaces outdated globals without auto-upgrading (toggle: `ENABLE_NPM_REPORT`)
10. **Disk space check** — warns if < 10 GB free on `$HOME` partition (toggle: `ENABLE_DISK_CHECK`)
11. **Log rotation** — deletes `update-all-*.log` older than 30 days

## How to run

**On demand:**
```bash
~/.claude/scripts/update-all.sh
```

**Trigger the launchd job manually (uses same env as scheduled run):**
```bash
launchctl start com.claude.update-all
```

**Check schedule status:**
```bash
launchctl print "gui/$(id -u)/com.claude.update-all"
```

**View today's log:**
```bash
cat ~/.claude/logs/update-all-$(date +%Y-%m-%d).log
```

## Daily auto-run

Installed via launchd at `~/Library/LaunchAgents/com.claude.update-all.plist`. Runs every day at **07:30 local time**. RunAtLoad is false (only fires on schedule).

**Disable temporarily:**
```bash
launchctl bootout "gui/$(id -u)/com.claude.update-all"
```

**Re-enable:**
```bash
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.claude.update-all.plist
```

**Uninstall completely:**
```bash
~/.claude/scripts/update-all.sh --uninstall-launchd
```

## Configuration

Optional config at `~/.claude/update-all.config` (sourced as bash). Lets the user add their own git repos, point at additional skill directories, and toggle individual sections. See `update-all.config.example` in the repo for the shape. Without a config file, only the universal sections run.

## Common questions

**"Is everything up to date?"** → Run the script. Exit 0 = all green. Exit 1 = at least one section failed; tell the user which.

**"Why did context-mode break?"** → Native module mismatch (`better_sqlite3.node` compiled for older Node ABI than current). The script's context-mode section runs the plugin's own upgrade, which calls `npm rebuild` on the native module.

**"Can I add my own tool to the script?"** → Edit `~/.claude/update-all.config` and add the repo path to `EXTRA_GIT_REPOS`. For more invasive changes, fork the script — sections are independent, so one failure doesn't stop the rest.

**"A skill was skipped — why?"** → Dirty working tree. The script skips skills with uncommitted changes rather than clobbering them. Cd into the skill, commit/stash/discard, then re-run.

## What this skill does NOT do

- Does not update Node.js itself (use `brew upgrade node` or your version manager).
- Does not rebuild MCP servers configured in `~/.claude/settings.json` (those install per-server; out of scope).
- Does not update Cursor, VS Code, or other editors themselves.
- Does not modify `settings.json` or hooks (the context-mode upgrade does its own hook config).
- Does not auto-upgrade npm globals (only reports them) — too risky to bump globals unattended.

## When to suggest changes vs. just run

- User asks "update everything" → just run the script, report summary.
- User says "I'm seeing a Node version mismatch" → run the script (its context-mode section rebuilds native modules).
- User asks "what got updated yesterday?" → read `~/.claude/logs/update-all-YYYY-MM-DD.log`.
- User says "stop the daily updates" → run `--uninstall-launchd`, confirm before doing it.
