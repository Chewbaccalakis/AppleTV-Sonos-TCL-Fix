#!/bin/bash
TV="${TV_IP:?TV_IP env var is required}:${TV_PORT:-5555}"
INTERVAL="${INTERVAL:-900}"      # flush every 15 min while the TV sleeps
RETRY="${RETRY:-60}"             # wait this long after a failure

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

# Sleep in the background so a stop signal can interrupt it.
nap() { sleep "$1" & wait $!; }

trap 'log "stopping"; kill $! 2>/dev/null; exit 0' TERM INT

log "starting: TV=$TV interval=${INTERVAL}s retry=${RETRY}s"

while true; do
  log "$(timeout 15 adb connect "$TV" 2>&1)"
  state=$(timeout 15 adb -s "$TV" shell dumpsys power 2>&1 | grep -o 'mWakefulness=[A-Za-z]*' | cut -d= -f2)

  if [ -z "$state" ]; then
    status=$(adb devices | awk -v d="$TV" '$1==d {print $2}')
    log "could not read power state (adb status: ${status:-not connected}) - retrying in ${RETRY}s"
    [ "$status" = "offline" ] && adb disconnect "$TV" >/dev/null 2>&1
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
