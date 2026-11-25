# waitup – wait until a host answers, then notify once and stop.
# Each watch is a transient systemd user service: it survives a closed
# terminal and ends by itself on the first answer; it does not survive a
# logout/reboot.

usage() {
  cat <<'USAGE'
Usage:
  waitup <host> [check] [seconds]   watch a host in the background
  waitup list                       running watches
  waitup stop <id>|all              cancel a watch (id from "waitup list")

Checks:
  any          ping or SSH, whichever answers first (default)
  ping         ICMP echo
  ssh[:port]   an SSH server answers (port from the SSH config, else 22)
  tcp:<port>   the TCP port accepts a connection

Examples:
  waitup 10.20.30.40
  waitup vm.kunde.example ssh 30
  waitup 10.20.30.40 tcp:3389 5
USAGE
}

die() {
  echo "waitup: $*" >&2
  exit 2
}

units() {
  systemctl --user list-units --plain --no-legend --type=service 'waitup-*' | awk '{print $1}'
}

start_watch() {
  local host="${1##*@}" check=any interval="${WAITUP_INTERVAL:-10}" arg
  shift
  for arg in "$@"; do
    case "$arg" in
    any | ping | ssh) check="$arg" ;;
    ssh:* | tcp:*)
      [[ "${arg#*:}" =~ ^[0-9]+$ ]] && [ "${arg#*:}" -ge 1 ] && [ "${arg#*:}" -le 65535 ] ||
        die "invalid port: $arg"
      check="$arg"
      ;;
    *)
      [[ "$arg" =~ ^[0-9]+$ ]] && [ "$arg" -ge 1 ] || die "unknown check or interval: $arg"
      interval="$arg"
      ;;
    esac
  done
  [[ "$host" =~ ^[A-Za-z0-9:][A-Za-z0-9._:-]*$ ]] || die "invalid host: $host"

  local id
  id="waitup-$(date +%s%N | cut -c1-13)"
  systemd-run --user --quiet --collect \
    --unit="$id" \
    --description="$host  $check  alle ${interval}s" \
    -- "$(readlink -f "$0")" --watch "$host" "$check" "$interval"

  echo "$id  $host  $check  alle ${interval}s"
}

list_watches() {
  local found=0 unit since desc
  while read -r unit; do
    [ -n "$unit" ] || continue
    found=1
    since="$(systemctl --user show "$unit" -P ActiveEnterTimestamp)"
    desc="$(systemctl --user show "$unit" -P Description)"
    printf '%s  seit %s  %s\n' "${unit%.service}" "$(date -d "$since" '+%a %H:%M:%S')" "$desc"
  done < <(units)
  [ "$found" = 1 ] || echo "no watches running"
}

stop_watch() {
  local target="${1:-}"
  if [ -z "$target" ]; then
    usage >&2
    exit 2
  fi
  if [ "$target" = all ]; then
    units | xargs -r systemctl --user stop
  else
    systemctl --user stop "${target%.service}.service"
  fi
}

# One attempt each, bounded so a dead route cannot stall the loop.
probe_ping() {
  # The setuid wrapper where there is one (NixOS); plain ping elsewhere.
  local ping=/run/wrappers/bin/ping
  [ -x "$ping" ] || ping=ping
  "$ping" -n -q -c 1 -W 2 "$1" >/dev/null 2>&1
}

probe_tcp() {
  # shellcheck disable=SC2016 # $1/$2 belong to the inner shell
  timeout 4 "$BASH" -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$1" "$2" 2>/dev/null
}

# An open port is not enough for SSH: wait for the server's banner.
probe_ssh() {
  # shellcheck disable=SC2016 # $1/$2 belong to the inner shell
  timeout 4 "$BASH" -c \
    'exec 3<>"/dev/tcp/$1/$2" && IFS= read -r -t 3 -n 4 banner <&3 && [ "$banner" = SSH- ]' \
    _ "$1" "$2" 2>/dev/null
}

elapsed() {
  local s="$1"
  if [ "$s" -lt 60 ]; then
    echo "${s} s"
  elif [ "$s" -lt 3600 ]; then
    echo "$((s / 60)) min"
  else
    echo "$((s / 3600)) h $((s % 3600 / 60)) min"
  fi
}

# Runs inside the transient service until the host answers once.
watch() {
  local host="$1" check="$2" interval="$3"
  local target="$host" ssh_port=22 conf

  # An alias of the SSH config stands for its HostName and Port.
  if conf="$(ssh -G "$host" 2>/dev/null)"; then
    target="$(awk '$1 == "hostname" {print $2; exit}' <<<"$conf")"
    ssh_port="$(awk '$1 == "port" {print $2; exit}' <<<"$conf")"
    target="${target:-$host}"
    ssh_port="${ssh_port:-22}"
  fi
  case "$check" in ssh:*) ssh_port="${check#ssh:}" ;; esac

  echo "watching $target ($check) every ${interval}s"
  local tries=0 via=
  while :; do
    tries=$((tries + 1))
    case "$check" in
    ping) probe_ping "$target" && via=Ping ;;
    ssh | ssh:*) probe_ssh "$target" "$ssh_port" && via="SSH (Port $ssh_port)" ;;
    tcp:*) probe_tcp "$target" "${check#tcp:}" && via="TCP-Port ${check#tcp:}" ;;
    *)
      if probe_ping "$target"; then
        via=Ping
      elif probe_ssh "$target" "$ssh_port"; then
        via="SSH (Port $ssh_port)"
      fi
      ;;
    esac
    [ -z "$via" ] || break
    sleep "$interval"
  done

  local text
  text="antwortet auf $via nach $(elapsed "$SECONDS") ($tries Versuche)"
  echo "$target: $text"
  notify-send --urgency=critical --app-name=waitup --icon=network-transmit-receive-symbolic \
    "Erreichbar: $host" "$text" || true
  if [ -n "${WAITUP_SOUND:-}" ]; then
    pw-play --volume="${WAITUP_SOUND_VOLUME:-0.5}" "$WAITUP_SOUND" || true
  fi
}

case "${1:-}" in
--watch)
  [ "$#" -eq 4 ] || exit 2
  watch "$2" "$3" "$4"
  ;;
"" | -h | --help | help) usage ;;
list | ls) list_watches ;;
stop | rm | cancel)
  shift
  stop_watch "${1:-}"
  ;;
*) start_watch "$@" ;;
esac
