#!/bin/zsh
# Prints the automations from ~/.config/automations/automations.json as JSON, with launchd status.
export PATH="/opt/homebrew/bin:/usr/bin:/bin"
LIST="$HOME/.config/automations/automations.json"
uid=$(id -u)
out='[]'
for i in $(jq -r 'keys[]' "$LIST"); do
  e=$(jq -c --arg h "$HOME" ".[$i] | with_entries(if (.value|type)==\"string\" then .value |= sub(\"^~\"; \$h) else . end)" "$LIST")
  label=$(jq -r .label <<<"$e"); plist=$(jq -r '.plist // empty' <<<"$e"); logf=$(jq -r '.log // empty' <<<"$e")
  if p=$(launchctl print "gui/$uid/$label" 2>/dev/null); then
    enabled=true
    last=$(sed -n 's/.*last exit code = \([0-9-]*\).*/\1/p' <<<"$p" | head -1)
    running=$([[ $p == *"state = running"* ]] && echo true || echo false)
  else
    enabled=false; last=""; running=false
  fi
  schedule=""
  if [[ -f $plist ]]; then
    schedule=$(plutil -convert json -o - "$plist" | jq -r '
      def two: tostring | if length < 2 then "0" + . else . end;
      if .StartCalendarInterval then (.StartCalendarInterval | "täglich \(.Hour // 0 | two):\(.Minute // 0 | two)")
      elif .WatchPaths then "bei Änderung: \(.WatchPaths[0] | split("/") | last)"
      elif .StartInterval then "alle \(.StartInterval) s"
      else "manuell" end')
  fi
  last_line=""
  [[ -f $logf ]] && last_line=$(grep -v '^[[:space:]]*$' "$logf" | tail -1 | cut -c1-200)
  out=$(jq -c --argjson e "$e" --argjson en "$enabled" --argjson run "$running" --arg last "$last" --arg s "$schedule" --arg l "$last_line" \
    '. + [$e + {enabled:$en, running:$run, last_exit:(if $last=="" then null else ($last|tonumber) end), schedule:$s, last_line:$l}]' <<<"$out")
done
print -r -- "$out"
