# herdr-mac-brew-automation

Daily `brew update && brew upgrade` on a Mac, run by a Claude Code session inside
[Herdr](https://herdr.dev), with a short report each morning. Plus an "Automations"
section in the Herdr sidebar to see, run, pause and edit such jobs.

launchd is the timer. Herdr shows the result. Claude does the work and writes the report.

## What it does

- **brew upgrade** (`com.tom.brew-morning`, daily 07:30): makes sure Herdr has a space
  `auto` with a tab `brew up2date` and a Claude session in it, then sends that session a
  prompt. Claude runs `brew update && brew upgrade` and reports in at most 10 lines:
  upgraded packages, errors, and warnings that need you. Every run lands in the same pane
  and the same session.
- **claude restart** (`com.tom.claude-restart`, when the `claude-code` cask changes): after
  a Claude Code upgrade, every idle Claude session that runs in a Herdr shell pane gets
  `/exit` typed into it and is started again with `claude --resume <session>`. Busy
  sessions are retried every minute for up to three hours.
- **Automations sidebar section**: a Herdr mod listing the automations with status dot,
  schedule and last run. Click a row to go to its tab. Hover for buttons: run now,
  pause/enable, edit script and schedule in your editor, or open a Claude session that
  summarises the automation and asks what to change. The `+` opens a Claude session that
  creates a new automation.
- **`automations` skill** for Claude Code: where everything is and how to show, edit, test,
  pause, create and delete an automation.

## Requirements

- macOS with [Homebrew](https://brew.sh)
- [Herdr](https://herdr.dev) with `herdr-app` and `hc` on the PATH (or in `~/.local/bin`)
- [Claude Code](https://claude.com/claude-code), installed as the Homebrew cask `claude-code`
  and logged in
- `jq` (ships with recent macOS), zsh

## Install

```sh
git clone https://github.com/Squantomas/herdr-mac-brew-automation
cd herdr-mac-brew-automation
./install.sh
```

Herdr must be open. The script keeps files that already exist (`FORCE=1` overwrites),
clones Herdr's `main` layout to `main-auto` with the extra sidebar section, and loads both
launchd agents.

| From | To |
|---|---|
| `bin/` | `~/bin/` |
| `launchd/` | `~/Library/LaunchAgents/` |
| `automations/` | `~/.config/automations/` (the list, and Claude settings for edit sessions) |
| `brew-reports/` | `~/brew-reports/` (logs, and Claude settings for the brew session) |
| `skills/automations/` | `~/.claude/skills/automations/` |
| `mods/automations/` | `~/.config/herdr-app/mods/automations/` |

Try it without waiting for the morning:

```sh
~/bin/brew-morning-herdr.sh                        # a real run
NOPROMPT=1 ~/bin/brew-morning-herdr.sh             # only create space, tab and session
DRY=1 NEW=9.9.9 ~/bin/claude-restart-idle.sh       # show which sessions would be restarted
```

## Change it

- **Time:** `Hour`/`Minute` in `~/Library/LaunchAgents/com.tom.brew-morning.plist`, then
  pause and enable it once (sidebar buttons) so launchd reads the new time.
- **Prompt, space and tab names:** top of `~/bin/brew-morning-herdr.sh`.
- **Model, effort, allowed commands of the brew session:** `~/brew-reports/.claude/settings.json`
  (default: Haiku, low effort, `brew update` and `brew upgrade` allowed without asking).
- **More automations:** press `+` in the sidebar, or add a script, a plist and an entry in
  `~/.config/automations/automations.json`.

## Good to know

- A run is skipped when the Claude session is busy or waiting on a dialog at that moment.
  The reason is in `~/brew-reports/launchd.err`.
- Cask upgrades that ask for an admin password fail unattended and show up in the report.
- If the Mac is asleep at 07:30, launchd runs the job after wake-up.
- The restart only covers Claude sessions started in a Herdr shell pane (you typed
  `claude`). Sessions in other terminal apps are skipped and noted in
  `~/brew-reports/claude-restart.log`. Start-up flags are not repeated on restart, and text
  typed but not sent in an idle session is lost.
- `main-auto` is a clone of Herdr's layout, so later changes Herdr makes to `main` do not
  reach it.
- The launchd labels use the prefix `com.tom.`. To rename them, change the plist file
  names, their `Label` keys and the `label` fields in `automations.json`.

## Uninstall

```sh
for l in com.tom.brew-morning com.tom.claude-restart; do
  launchctl bootout gui/$(id -u)/$l; rm ~/Library/LaunchAgents/$l.plist
done
```

Then remove the files listed under Install, and switch Herdr back with `ctrl-shift-l`.

## Credits

The play, pause, power and sparkles icons are from [Lucide](https://lucide.dev) (ISC license).
