---
name: automations
description: Show, explain, edit, pause, test, create or delete the user's launchd automations on this Mac (e.g. the daily "brew upgrade", "claude restart") — the jobs listed in ~/.config/automations/automations.json and shown in the "Automations" section of the Herdr sidebar. Use whenever the user asks about an automation, a scheduled job, its schedule, prompt, script, log or last run, or wants a new one.
---

# Automations

The user's automations are launchd agents. launchd is the timer; Herdr only shows them.
Answer the user in German, short and plain.

## Where everything is

| What | Where |
|---|---|
| The list (one entry per automation) | `~/.config/automations/automations.json` |
| Status of all, as JSON | `~/bin/automations-status.sh` |
| Scripts | `~/bin/` |
| Schedules (plists) | `~/Library/LaunchAgents/<label>.plist` |
| Logs | the entry's `log` path (usually in `~/brew-reports/`) |
| Sidebar section in Herdr | `~/.config/herdr-app/mods/automations/` (reads the status script every 60 s) |

Entry fields: `name` (shown in the sidebar), `label` (launchd label), `plist`, `script`,
`log`, and optionally `space` + `tab` (the Herdr tab where its result appears; a click
on the sidebar row goes there).

`automations-status.sh` adds per entry: `enabled` (loaded in launchd), `running`,
`last_exit` (null = never ran via launchd, 0 = ok), `schedule` (text), `last_line` (last log line).

## Show an automation

1. Run `~/bin/automations-status.sh` and pick the entry (by `label` or `name`).
2. Read its script, its plist and the last ~20 lines of its log. Read helper scripts it calls.
3. Summarise, in this order, only what applies:
   - **Was sie tut** (one or two sentences)
   - **Wann sie läuft** (schedule from the plist) and whether it is active or paused
   - **Letzter Lauf**: when, and whether it worked (log + `last_exit`)
   - **Wo das Ergebnis erscheint**: Herdr space/tab, or the log file
   - **Prompt**: if the script sends one to a Claude session, quote it in full
   - **Einstellungen**: model/effort/permissions if it starts Claude (often a
     `.claude/settings.json` in the session's folder), other knobs at the top of the script
   - **Dateien**: script, plist, log
   - **Einschränkungen** you can see in the code (what it skips, what needs the Mac awake, …)
4. Then ask what the user wants to change. **Change nothing before they answer.**

## Edit

- **Script:** edit it, then `zsh -n <script>`.
- **Schedule or anything else in the plist:** edit it, `plutil -lint <plist>`, then reload,
  because launchd keeps the old schedule until then:
  ```sh
  launchctl bootout gui/$(id -u)/<label>; launchctl bootstrap gui/$(id -u) <plist>
  ```
  Daily time: `StartCalendarInterval` with `Hour`/`Minute` (an array of dicts for several
  times, add `Weekday` 0–7 for certain days). On file change: `WatchPaths`. Every n seconds:
  `StartInterval`.
- **Name, paths, label:** keep `automations.json` in step. A changed label needs the plist
  file renamed, its `Label` key changed, and a bootout of the old label first.
- Finish with `~/bin/automations-status.sh` and tell the user what changed and from when it applies.

## Test run

`launchctl kickstart gui/$(id -u)/<label>` really runs the automation (a brew upgrade
upgrades packages, a prompt lands in the live Claude pane). **Ask first.** Many scripts have
a dry mode (`DRY=1`, `NOPROMPT=1`); read the script's header and prefer that.

## Pause, enable, delete

```sh
launchctl bootout gui/$(id -u)/<label>            # pause (sidebar: grey, "pausiert")
launchctl bootstrap gui/$(id -u) <plist>          # enable
```
Delete only after the user confirms: bootout, then remove the plist, the script (if nothing
else uses it) and the entry in `automations.json`.

## Create a new one

1. Ask what it should do and when, if not clear.
2. Script in `~/bin/<name>.sh` (zsh, `chmod +x`). launchd gives a minimal environment: set
   `PATH` at the top (`$HOME/.local/bin:/opt/homebrew/bin:/usr/bin:/bin`), log with timestamps
   (`YYYY-MM-DD HH:MM:SS text`, the sidebar reads the date from the last line).
3. Plist `~/Library/LaunchAgents/com.tom.<name>.plist`:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
     <key>Label</key><string>com.tom.NAME</string>
     <key>ProgramArguments</key>
     <array><string>__HOME__/bin/NAME.sh</string></array>
     <key>StartCalendarInterval</key>
     <dict><key>Hour</key><integer>7</integer><key>Minute</key><integer>30</integer></dict>
     <key>StandardOutPath</key><string>__HOME__/brew-reports/NAME.out</string>
     <key>StandardErrorPath</key><string>__HOME__/brew-reports/NAME.err</string>
   </dict>
   </plist>
   ```
4. Add the entry to `automations.json`, `plutil -lint`, `launchctl bootstrap`, check with
   the status script. The sidebar shows it within a minute.

## Automations that drive Claude in Herdr

`~/bin/brew-morning-herdr.sh` is the pattern to copy: it finds or creates a Herdr space and
tab by name, makes sure a Claude session runs there, and sends it a prompt. Things learned
the hard way:

- `herdr-app ls` / `herdr-app do` need the Herdr window; the script opens it hidden first.
- Run Claude **inside a shell pane** (start `zsh -l`, then type `claude`). If Claude is the
  pane's own program, the pane closes when Claude exits.
- `hc send <t> "text"` wraps the text in `<hc from="…">…</hc>`; fine for prompts, but slash
  commands like `/exit` are then read as chat. `~/bin/herdr-type.sh <t> "text"` types real
  keys instead (letters, digits, space and `- . / _ : =` only).
- A terminal's agent status is `hc get <t> --json | jq -r '.status.state'`; send only when
  it is `idle` or `done`.
- Model, effort and allowed commands for such a session go into `.claude/settings.json` in
  the folder Claude starts in (see `~/brew-reports/.claude/settings.json`), because special
  characters in command-line flags can't be typed.
- `~/bin/claude-restart-idle.sh` restarts idle Claude sessions in Herdr shell panes after a
  Claude Code upgrade (`/exit`, then `claude --resume <id>`).
