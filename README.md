# claude-update-all

A daily mass-update script for the [Claude Code](https://claude.com/claude-code) ecosystem and the dev tools that ride along with it. Updates the Claude Code CLI, all installed plugins, your git-managed skills, Homebrew, the Salesforce CLI, `uv`, and any extra repos you care about — all in one go, on a daily launchd schedule.

Ships with an `update-all-tools` skill so Claude Code knows when to run it for you (e.g. when you ask "is everything up to date?").

## Quick start

```bash
git clone https://github.com/sdong101010/claude-update-all.git ~/projects/claude-update-all
cd ~/projects/claude-update-all && ./install.sh
```

That's it. After install you have:

- A daily launchd job at **07:30 local time** that updates everything
- The `update-all-tools` skill installed at `~/.claude/skills/` (Claude auto-discovers it)
- A wrapper at `~/.claude/scripts/update-all.sh` for manual runs

To skip scheduling and just install the script: `./install.sh --no-schedule`.

## What it updates

- **Claude Code CLI** — `claude update`
- **context-mode plugin** — uses the plugin's own `cli.bundle.mjs upgrade` (rebuilds native modules)
- **All other Claude plugins** under `~/.claude/plugins/cache/` — `git pull`, auto-stashing local edits
- **Your skills** under `~/.claude/skills/` (and any other dirs you add) — `git pull`, skipping dirty trees
- **Extra git repos** you list in config — pulled, with `uv sync` if `pyproject.toml` is present
- **Homebrew** — `brew update && upgrade && cleanup` (toggleable)
- **Salesforce CLI** — `sf update` (toggleable)
- **uv** — `uv self update` (toggleable)

Plus reporting-only sections:
- **npm globals** outdated report (no auto-upgrade)
- **Disk space** warning if `$HOME` partition has < 10 GB free
- **Log rotation** — drops `update-all-*.log` files older than 30 days

Each section runs independently — a failure in one doesn't stop the rest. Exit code is 0 if everything succeeded, 1 otherwise.

## Change the schedule

Add to `~/.claude/update-all.config` and re-run the launchd installer:
```bash
echo "LAUNCHD_HOUR=9"   >> ~/.claude/update-all.config
echo "LAUNCHD_MINUTE=0" >> ~/.claude/update-all.config
~/.claude/scripts/update-all.sh --install-launchd   # regenerate the plist
```

## Configure

Optional config at `~/.claude/update-all.config` (sourced as bash). Without it, only the universal sections run.

```bash
cp update-all.config.example ~/.claude/update-all.config
$EDITOR ~/.claude/update-all.config
```

Example:
```bash
EXTRA_GIT_REPOS=(
  ~/Developer/browser-harness    # auto-runs `uv sync` after pull
  ~/Developer/my-other-repo
)

SKILL_DIRS=(
  ~/.claude/skills
  ~/.cursor/skills               # also pull Cursor-side skills
)

ENABLE_HOMEBREW=1
ENABLE_SF_CLI=0                  # I don't use Salesforce
ENABLE_UV=1
ENABLE_NPM_REPORT=1
ENABLE_DISK_CHECK=1
```

## Manage the daily job

```bash
# Trigger it now (uses the same env launchd will at 07:30)
launchctl start com.claude.update-all

# Status
launchctl print "gui/$(id -u)/com.claude.update-all"

# Today's log
cat ~/.claude/logs/update-all-$(date +%Y-%m-%d).log

# Disable temporarily
launchctl bootout "gui/$(id -u)/com.claude.update-all"

# Re-enable
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.claude.update-all.plist

# Uninstall completely
~/.claude/scripts/update-all.sh --uninstall-launchd
```

The launchd plist runs at 07:30 local time daily. Edit `LAUNCHD_HOUR` / `LAUNCHD_MINUTE` at the top of `update-all.sh` and re-run `--install-launchd` to change.

## Auto-stash behavior

For any repo with uncommitted changes (excluding plugin dirs and skill dirs marked clean-only), the script:

1. `git stash push -m "auto-stash update-all YYYY-MM-DD"`
2. `git pull --ff-only`
3. `git stash pop`

If pop fails (real conflict), the section is marked failed and edits remain in the stash drawer for you to resolve.

`~/.claude/skills/` and any user `SKILL_DIRS` use a stricter rule — dirty working trees are **skipped, not stashed** — to avoid surprising users who are mid-edit on a skill.

## Uninstall

```bash
cd ~/projects/claude-update-all
./uninstall.sh
```

Removes the symlinks and the launchd job. Leaves logs and your config in place.

## License

MIT
