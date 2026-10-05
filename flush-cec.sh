#!/bin/bash
TV_IP="${TV_IP:-}"               # leave empty to find the TV via mDNS
TV_PORT="${TV_PORT:-5555}"       # only used with TV_IP; mDNS reports the port
TV_NAME="${TV_NAME:-}"           # with mDNS, pick the TV whose name contains this
INTERVAL="${INTERVAL:-900}"      # flush every 15 min while the TV sleeps
RETRY="${RETRY:-60}"             # wait this long after a failure

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

# Sleep in the background so a stop signal can interrupt it.
nap() { sleep "$1" & wait $!; }

trap 'log "stopping"; kill $! 2>/dev/null; exit 0' TERM INT

# Sets TV to ip:port of the first ADB device found via mDNS (matching TV_NAME if set).
discover() {
  local devices match
  devices=$(python3 /app/discover-tv.py)
  if [ -z "$devices" ]; then
    log "mDNS: no ADB devices found (is network debugging on, and the container using host networking?)"
    return 1
  fi
  while IFS=$'\t' read -r ip port name; do
    log "mDNS: found $ip:$port ${name:+($name)}"
  done <<< "$devices"

  match=$(awk -F'\t' -v n="${TV_NAME,,}" 'n == "" || index(tolower($3), n) {print; exit}' <<< "$devices")
  if [ -z "$match" ]; then
    log "mDNS: no device name contains '$TV_NAME'"
    return 1
  fi
  TV=$(cut -f1,2 --output-delimiter=: <<< "$match")
  log "mDNS: using $TV"
}

if [ -n "$TV_IP" ]; then
  TV="$TV_IP:$TV_PORT"
  log "starting: TV=$TV interval=${INTERVAL}s retry=${RETRY}s"
else
  TV=""
  log "starting: TV via mDNS${TV_NAME:+ (name contains '$TV_NAME')} interval=${INTERVAL}s retry=${RETRY}s"
fi

while true; do
  if [ -z "$TV" ] && ! discover; then
    nap "$RETRY"
    continue
  fi

  log "$(timeout 15 adb connect "$TV" 2>&1)"
  state=$(timeout 15 adb -s "$TV" shell dumpsys power 2>&1 | grep -o 'mWakefulness=[A-Za-z]*' | cut -d= -f2)

  if [ -z "$state" ]; then
    status=$(adb devices | awk -v d="$TV" '$1==d {print $2}')
    log "could not read power state (adb status: ${status:-not connected}) - retrying in ${RETRY}s"
    [ "$status" = "offline" ] && adb disconnect "$TV" >/dev/null 2>&1
    # The TV may have a new IP; look it up again unless it's waiting for key approval.
    [ -z "$TV_IP" ] && [ "$status" != "unauthorized" ] && TV=""
    nap "$RETRY"
    continue
  fi

  if [ "$state" = "Asleep" ]; then
    timeout 15 adb -s "$TV" shell settings put global hdmi_control_enabled 0
    sleep 3
    timeout 15 adb -s "$TV" shell settings put global hdmi_control_enabled 1
    log "TV asleep - flushed CEC queue"
  fi

  nap "$INTERVAL"
done
