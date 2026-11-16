#!/bin/zsh
# Daily brew run in Herdr: space "auto", tab "brew up2date", a shell pane with claude typed into it.
# NOPROMPT=1: only make sure the pane exists.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
WORKDIR="$HOME/brew-reports"
mkdir -p "$WORKDIR"
exec 2>>"$WORKDIR/launchd.err"
log() { print -r -- "$(date '+%F %T') $*" >&2; }

SPACE_NAME="auto"
TAB_NAME="brew up2date"
PROMPT='Run `brew update && brew upgrade` now, non-interactively. Do not trust or untap anything or change files. Report only on today'"'"'s run, max 10 lines: date; upgraded packages (old -> new) or "nothing to upgrade"; errors; warnings that need my action (shadowed executables, untrusted taps, disabled packages, casks needing --greedy).'

ls_json() { herdr-app ls 2>/dev/null; }
status_of() { hc get "$1" --json | jq -r '.status.state // .status // empty'; }

if ! ls_json | jq -e . >/dev/null 2>&1; then
  open -gja Herdr
  for i in {1..60}; do ls_json | jq -e . >/dev/null 2>&1 && break; sleep 1; done
fi
ls_json | jq -e . >/dev/null 2>&1 || { log "Herdr window not reachable"; exit 1; }

space_id() { ls_json | jq -r --arg n "$SPACE_NAME" '[.spaces[] | select(.name==$n and .machine==null)][0].id // empty'; }
tab_id() { ls_json | jq -r --arg s "$1" --arg n "$TAB_NAME" '[.spaces[] | select(.id==$s) | .tabs[] | select(.name==$n)][0].id // empty'; }
term_in_tab() { ls_json | jq -r --arg s "$1" --arg t "$2" --arg a "$3" '[.spaces[] | select(.id==$s) | .tabs[] | select(.id==$t) | .terminals[] | select((.app // "") == $a)][0].terminal // empty'; }
wait_for() { for i in {1..${3:-30}}; do v=$(eval "$1"); [[ -n $v ]] && { print -r -- "$v"; return; }; sleep 1; done; }

SPACE=$(space_id)
if [[ -z $SPACE ]]; then
  herdr-app do space.new "$(jq -nc --arg n "$SPACE_NAME" --arg f "$WORKDIR" '{name:$n, folder:$f}')" >/dev/null || { log "space.new failed"; exit 1; }
  SPACE=$(wait_for space_id)
  [[ -n $SPACE ]] || { log "space $SPACE_NAME not found after create"; exit 1; }
  FIRST_TAB=$(wait_for "ls_json | jq -r --arg s $SPACE '[.spaces[] | select(.id==\$s) | .tabs[]][0].id // empty'")
  [[ -n $FIRST_TAB ]] && herdr-app do tab.rename "$(jq -nc --arg i "$FIRST_TAB" --arg n "$TAB_NAME" '{id:$i, name:$n}')" >/dev/null
fi

TAB=$(wait_for "tab_id $SPACE" 3)
if [[ -z $TAB ]]; then
  herdr-app do tab.new "$(jq -nc --arg n "$TAB_NAME" --arg s "$SPACE" --arg f "$WORKDIR" '{name:$n, space:$s, folder:$f, focus:false}')" >/dev/null \
    || { log "tab.new failed"; exit 1; }
  TAB=$(wait_for "tab_id $SPACE")
  [[ -n $TAB ]] || { log "tab $TAB_NAME not found after create"; exit 1; }
fi

T=$(term_in_tab "$SPACE" "$TAB" claude-code)
if [[ -z $T ]]; then
  SH=$(term_in_tab "$SPACE" "$TAB" "")
  if [[ -z $SH ]]; then
    SH=$(hc run --json --bg --keep --no-parent --cwd "$WORKDIR" --label "herdr.space=$SPACE" --label "herdr.tab=$TAB" -- zsh -l | jq -r '.address // empty')
    [[ -n $SH ]] || { log "starting shell failed"; exit 1; }
    sleep 2
  fi
  ~/bin/herdr-type.sh "$SH" "cd $WORKDIR"
  ~/bin/herdr-type.sh "$SH" "claude"
  for i in {1..60}; do [[ $(status_of "$SH") == idle ]] && break; sleep 2; done
  T=$SH
  log "started claude in shell $T"
fi

[[ -n $NOPROMPT ]] && exit 0
STATUS=$(status_of "$T")
if [[ $STATUS != (idle|done) ]]; then
  log "skipped: $T is ${STATUS:-silent}"
  exit 1
fi
hc send "$T" "$PROMPT" >/dev/null && log "prompt sent to $T" || { log "send to $T failed"; exit 1; }
