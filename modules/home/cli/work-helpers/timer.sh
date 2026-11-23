# timer – one-shot desktop reminders as transient systemd user timers.
# They survive a closed terminal; they do not survive a logout/reboot.

usage() {
  cat <<'USAGE'
Usage:
  timer <duration> [message...]   e.g. timer 25m Kunde anrufen, timer 1h30m
  timer at <time> [message...]    e.g. timer at 14:30 Standup
  timer list                      running timers
  timer stop <id>|all             cancel a timer (id from "timer list")
USAGE
}

# Wall-clock time of a timer's next elapse.  Timers from --on-active run on
# the monotonic clock and leave NextElapseUSecRealtime empty, so convert
# NextElapseUSecMonotonic (microseconds since boot) via /proc/uptime.
next_elapse() {
  local unit="$1" real mono up
  real="$(systemctl --user show "$unit" -P NextElapseUSecRealtime 2>/dev/null || true)"
  if [ -n "$real" ]; then
    date -d "$real" '+%a %H:%M:%S'
    return
  fi
  mono="$(systemctl --user show "$unit" -P NextElapseUSecMonotonic 2>/dev/null || true)"
  mono="$(systemd-analyze timespan "$mono" 2>/dev/null | awk '/μs:/ {print $2}')"
  if [ -z "$mono" ]; then
    echo "?"
    return
  fi
  up="$(awk '{printf "%d", $1 * 1000000}' /proc/uptime)"
  date -d "@$(((mono - up) / 1000000 + $(date +%s)))" '+%a %H:%M:%S'
}

start_timer() {
  local kind="$1" spec="$2"
  shift 2
  local message="${*:-Timer abgelaufen ($spec)}"
  local id
  id="timer-$(date +%s%N | cut -c1-13)"

  local -a when
  if [ "$kind" = at ]; then
    if ! systemd-analyze calendar "$spec" >/dev/null 2>&1; then
      echo "timer: invalid time: $spec" >&2
      exit 2
    fi
    when=(--on-calendar="$spec")
  else
    if ! systemd-analyze timespan "$spec" >/dev/null 2>&1; then
      echo "timer: invalid duration: $spec" >&2
      exit 2
    fi
    when=(--on-active="$spec")
  fi

  systemd-run --user --quiet --collect \
    --unit="$id" \
    --description="$message" \
    --timer-property=AccuracySec=1s \
    "${when[@]}" \
    -- "$(readlink -f "$0")" --fire "$message"

  echo "$id  $(next_elapse "$id.timer")  $message"
}

list_timers() {
  local found=0 unit next desc
  while read -r unit; do
    [ -n "$unit" ] || continue
    found=1
    next="$(next_elapse "$unit")"
    desc="$(systemctl --user show "$unit" -P Description)"
    printf '%s  %s  %s\n' "${unit%.timer}" "$next" "$desc"
  done < <(systemctl --user list-units --plain --no-legend --type=timer 'timer-*' | awk '{print $1}')
  [ "$found" = 1 ] || echo "no timers running"
}

stop_timer() {
  local target="${1:-}"
  if [ -z "$target" ]; then
    usage >&2
    exit 2
  fi
  if [ "$target" = all ]; then
    systemctl --user list-units --plain --no-legend --type=timer 'timer-*' |
      awk '{print $1}' | xargs -r systemctl --user stop
  else
    systemctl --user stop "${target%.timer}.timer"
  fi
}

# Runs inside the transient service when the timer elapses: notification
# plus a short, quiet sound (TIMER_SOUND empty = silent).
fire() {
  notify-send --urgency=critical --app-name=Timer --icon=alarm-symbolic "Timer" "$1"
  if [ -n "${TIMER_SOUND:-}" ]; then
    pw-play --volume="${TIMER_SOUND_VOLUME:-0.3}" "$TIMER_SOUND" || true
  fi
}

case "${1:-}" in
--fire)
  shift
  fire "${1:-Timer}"
  ;;
"" | -h | --help | help) usage ;;
list | ls) list_timers ;;
stop | rm | cancel)
  shift
  stop_timer "${1:-}"
  ;;
at)
  shift
  [ "$#" -ge 1 ] || {
    usage >&2
    exit 2
  }
  spec="$1"
  shift
  start_timer at "$spec" "$@"
  ;;
*)
  spec="$1"
  shift
  start_timer in "$spec" "$@"
  ;;
esac
