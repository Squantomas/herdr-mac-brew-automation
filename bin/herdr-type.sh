#!/bin/zsh
# herdr-type.sh <terminal> <text>: type text as real keys (no <hc> wrapper) and press Enter.
# Only letters, digits, space and - . / _ : = are supported by hc keys.
export PATH="$HOME/.local/bin:$PATH"
t=$1; text=$2; keys=()
for c in ${(s::)text}; do [[ $c == ' ' ]] && keys+=(space) || keys+=("$c"); done
hc keys "$t" "${keys[@]}" >/dev/null && sleep 1 && hc keys "$t" enter >/dev/null
