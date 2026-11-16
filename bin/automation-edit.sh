#!/bin/zsh
# automation-edit.sh <label>: open a Claude session in Herdr space "auto" that shows this automation and asks what to change.
# Without a label: a session that creates a new automation.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
LIST="$HOME/.config/automations/automations.json"
WORKDIR="$HOME/.config/automations"
SPACE_NAME="auto"
label=$1
if [[ -n $label ]]; then
  name=$(jq -r --arg l "$label" '[.[] | select(.label==$l)][0].name // empty' "$LIST")
  [[ -n $name ]] || { print -u2 "unknown automation: $label"; exit 1; }
  TAB="edit $name"
  PROMPT="Nutze den Skill automations. Zeige mir die Automatisierung '$name' ($label): fasse alles Wichtige zusammen und frage mich dann, was ich ändern möchte."
else
  TAB="neue Automation"
  PROMPT="Nutze den Skill automations. Ich möchte eine neue Automatisierung anlegen. Lies zuerst die Liste und eine bestehende Automatisierung als Muster. Frag mich dann, was sie tun soll, wann sie laufen soll und wo das Ergebnis erscheinen soll (Herdr-Tab mit Claude oder nur Log). Lege nichts an, bevor ich geantwortet habe."
fi

ls_json() { herdr-app ls 2>/dev/null; }
space_id() { ls_json | jq -r --arg n "$SPACE_NAME" '[.spaces[] | select(.name==$n and .machine==null)][0].id // empty'; }

tab_json() { jq -nc --arg n "$TAB" --arg f "$WORKDIR" --arg p "$PROMPT" --arg s "$1" '{name:$n, folder:$f, argv:["claude"], task:$p} + (if $s=="" then {} else {space:$s} end)'; }

SPACE=$(space_id)
if [[ -z $SPACE ]]; then
  herdr-app do space.new "$(jq -nc --arg n "$SPACE_NAME" --arg f "$WORKDIR" '{name:$n, folder:$f}')" >/dev/null || exit 1
  for i in {1..10}; do SPACE=$(space_id); [[ -n $SPACE ]] && break; sleep 1; done
  [[ -n $SPACE ]] || { print -u2 "space $SPACE_NAME not found after create"; exit 1; }
fi
herdr-app do space.select "$(jq -nc --arg i "$SPACE" '{id:$i}')" >/dev/null
herdr-app do tab.new "$(tab_json "$SPACE")"
