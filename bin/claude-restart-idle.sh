#!/bin/zsh
# After a Claude Code upgrade: in every Herdr shell pane where an idle, older claude runs,
# type /exit and then "claude --resume <session>". DRY=1: only report. NEW=x.y.z: pretend version.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
LOG="$HOME/brew-reports/claude-restart.log"
mkdir -p "${LOG:h}"
log() { print -r -- "$(date '+%F %T') $*" | tee -a "$LOG" >&2; }

LOCK="${TMPDIR:-/tmp}/claude-restart-idle.lock"
mkdir "$LOCK" 2>/dev/null || { log "already running"; exit 0; }
trap 'rmdir "$LOCK"' EXIT

: ${NEW:=$(claude --version 2>/dev/null | awk '{print $1}')}
[[ -n $NEW ]] || { log "can't read claude version"; exit 1; }

typeset -A SKIPPED
for round in {1..180}; do
  pending=0
  typeset -A TPID=()
  for t in $(hc ls --json | jq -r '.terminals[] | select(.state=="live") | .address'); do
    p=$(hc get "$t" --json | jq -r '.pid // empty'); [[ -n $p ]] && TPID[$p]=$t
  done

  for f in ~/.claude/sessions/*.json(N); do
    j=$(<"$f")
    [[ $(jq -r .kind <<<"$j") == interactive ]] || continue
    [[ $(jq -r .version <<<"$j") != "$NEW" ]] || continue
    pid=$(jq -r .pid <<<"$j"); sid=$(jq -r .sessionId <<<"$j")
    kill -0 "$pid" 2>/dev/null || continue
    ppid=$(ps -o ppid= -p "$pid" | tr -d ' ')
    t=${TPID[$ppid]}
    if [[ -z $t || $(ps -o comm= -p "$ppid") != *zsh* ]]; then
      [[ -z ${SKIPPED[$pid]} ]] && log "skip pid $pid ($sid, $(jq -r .cwd <<<"$j")): not claude in a Herdr shell pane"
      SKIPPED[$pid]=1; continue
    fi
    [[ -n $ONLY && $t != "$ONLY" ]] && continue
    hstat=$(hc get "$t" --json | jq -r '.status.state // .status // empty')
    if [[ $(jq -r .status <<<"$j") != idle || $hstat != (idle|done) ]]; then pending=1; continue; fi

    if [[ -n $DRY ]]; then log "would restart $t (pid $pid, session $sid)"; continue; fi
    ~/bin/herdr-type.sh "$t" "/exit"
    for i in {1..20}; do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
    if kill -0 "$pid" 2>/dev/null; then log "$t: /exit didn't end claude, retry later"; pending=1; continue; fi
    sleep 1
    ~/bin/herdr-type.sh "$t" "claude --resume $sid"
    log "restarted $t, session $sid"
  done
  [[ -n $DRY || $pending == 0 ]] && break
  sleep 60
done
[[ -z $DRY ]] && (( pending )) && log "gave up waiting for busy instances"
exit 0
