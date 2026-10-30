#!/usr/bin/env bash
# Prints {"name","down","up"} for the interface carrying the default route.
# Rates in KB/s, computed against the previous sample kept in $XDG_RUNTIME_DIR.
dev=$(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
[[ -z $dev ]] && { echo '{"name":"Offline","down":0,"up":0}'; exit; }

name=$(nmcli -t -f DEVICE,CONNECTION device 2>/dev/null | awk -F: -v d="$dev" '$1==d{print $2; exit}')
[[ -z $name ]] && name=$dev
name=${name//\"/}

read -r rx tx < <(awk -v d="$dev:" '$1==d{print $2, $10}' /proc/net/dev)
now=$(date +%s%N)
state=${XDG_RUNTIME_DIR:-/tmp}/eww-net.$dev
down=0 up=0
if [[ -f $state ]]; then
  read -r prx ptx pnow < "$state"
  dt=$(( (now - pnow) / 1000000 ))   # ms
  if (( dt > 0 )); then
    down=$(( (rx - prx) * 1000 / dt / 1024 ))
    up=$(( (tx - ptx) * 1000 / dt / 1024 ))
  fi
fi
echo "$rx $tx $now" > "$state"
printf '{"name":"%s","down":%d,"up":%d}\n' "$name" "$down" "$up"
