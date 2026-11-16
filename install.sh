#!/bin/zsh
# Installs the automations into your home folder. Existing files are kept unless FORCE=1.
# PREFIX=<dir> installs into another folder; NO_LOAD=1 skips launchd and the Herdr layout.
set -e
SRC=${0:A:h}
DEST=${PREFIX:-$HOME}

put() { # put <source> <target> [template]
  local from=$1 to=$2
  if [[ -e $to && -z $FORCE ]]; then print "keep     $to"; return; fi
  mkdir -p "${to:h}"
  if [[ -n $3 ]]; then sed "s#__HOME__#$DEST#g" "$from" > "$to"; else cp "$from" "$to"; fi
  print "install  $to"
}

for f in $SRC/bin/*.sh; do put "$f" "$DEST/bin/${f:t}"; chmod +x "$DEST/bin/${f:t}"; done
for f in $SRC/launchd/*.plist; do put "$f" "$DEST/Library/LaunchAgents/${f:t}" template; done
put "$SRC/automations/automations.json" "$DEST/.config/automations/automations.json"
put "$SRC/automations/.claude/settings.json" "$DEST/.config/automations/.claude/settings.json"
put "$SRC/brew-reports/.claude/settings.json" "$DEST/brew-reports/.claude/settings.json"
put "$SRC/skills/automations/SKILL.md" "$DEST/.claude/skills/automations/SKILL.md" template
for f in $SRC/mods/automations/*; do put "$f" "$DEST/.config/herdr-app/mods/automations/${f:t}"; done

[[ -n $NO_LOAD ]] && exit 0
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

# Herdr's own "main" layout is read-only, so the sidebar section goes into a clone of it.
LAYOUT="$DEST/.config/herdr-app/layouts/main-auto.json"
if [[ ! -e $LAYOUT ]]; then
  herdr-app do layout.clone '{"name":"main","as":"main-auto"}' >/dev/null
  sleep 1
  jq '(.. | objects | select(.id=="sidebar-lists") | .children) += [{"id":"automations","type":"block","size":{"px":150},"min":60,"content":{"mod":"automations"}}]' \
    "$LAYOUT" > "$LAYOUT.tmp" && mv "$LAYOUT.tmp" "$LAYOUT"
  print "layout   main-auto (ctrl-shift-l switches layouts)"
fi

for f in $SRC/launchd/*.plist; do
  label=${f:t:r}
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$DEST/Library/LaunchAgents/${f:t}"
  print "loaded   $label"
done
