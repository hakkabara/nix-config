set -euo pipefail

STATE_DIR="/var/lib/homelab-vpn"
MODE_FILE="$STATE_DIR/mode"

FULL="wg-quick-homelab-full.service"
SPLIT="wg-quick-homelab-split.service"

FULL_CONFIG="/run/secrets/wireguard/homelab-full"
SPLIT_CONFIG="/run/secrets/wireguard/homelab-split"

PROBE="wgprobe"
PROBE_SOURCE="/run/wgprobe.conf"
PROBE_STRIPPED="/run/wgprobe-stripped.conf"

HEALTH_TARGET="192.168.189.1"
FULL_INTERFACE="homelab-full"
INTERNET_ROUTE_TARGET="1.1.1.1"
INTERNET_TEST_URL="https://cache.nixos.org/nix-cache-info"

CHECK_INTERVAL=10
FAILURE_LIMIT=2
RECOVERY_LIMIT=3

auto_failures=0
auto_successes=0
FULL_HEALTH_REASON=""


log() {
    printf 'homelab-vpn-manager: %s\n' "$*"
}


require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo "This command must run as root." >&2
        exit 1
    fi
}


ensure_state() {
    install \
        -d \
        -m 0755 \
        -o root \
        -g root \
        "$STATE_DIR"

    if [[ ! -e "$MODE_FILE" ]]; then
        printf '%s\n' "auto" > "$MODE_FILE"
        chmod 0644 "$MODE_FILE"
    fi
}


read_mode() {
    local mode

    mode="$(
        cat "$MODE_FILE" \
            2>/dev/null ||
            printf '%s\n' "auto"
    )"

    case "$mode" in
        auto|full|split|off)
            printf '%s\n' "$mode"
            ;;

        *)
            log "invalid stored mode '$mode'; using auto" >&2
            printf '%s\n' "auto"
            ;;
    esac
}


write_mode() {
    local mode="$1"
    local tmp

    case "$mode" in
        auto|full|split|off)
            ;;
        *)
            echo "Invalid VPN mode: $mode" >&2
            exit 2
            ;;
    esac

    ensure_state

    tmp="$(
        mktemp \
            "$STATE_DIR/.mode.XXXXXX"
    )"

    printf '%s\n' "$mode" > "$tmp"
    chmod 0644 "$tmp"
    mv -f -- "$tmp" "$MODE_FILE"

    log "desired mode set to $mode"
}


service_active() {
    systemctl \
        is-active \
        --quiet \
        "$1"
}


stop_service() {
    local unit="$1"

    if service_active "$unit"; then
        log "stopping $unit"
        systemctl stop "$unit"
    fi
}


start_service() {
    local unit="$1"

    if ! service_active "$unit"; then
        log "starting $unit"
        systemctl start "$unit"
    fi
}


probe_exists() {
    ip link show "$PROBE" \
        >/dev/null 2>&1
}


stop_probe() {
    if probe_exists; then
        log "removing isolated probe"

        ip route del \
            "$HEALTH_TARGET/32" \
            dev "$PROBE" \
            2>/dev/null ||
            true

        ip link del \
            "$PROBE" \
            2>/dev/null ||
            true
    fi

    rm -f \
        "$PROBE_SOURCE" \
        "$PROBE_STRIPPED"
}


start_probe() {
    local address
    local peer
    local -a peers

    if probe_exists; then
        ip route replace \
            "$HEALTH_TARGET/32" \
            dev "$PROBE"

        return 0
    fi

    if [[ ! -r "$SPLIT_CONFIG" ]]; then
        log "split secret is not available yet"
        return 1
    fi

    log "creating isolated probe for $HEALTH_TARGET/32"

    umask 077

    install \
        -m 0600 \
        -o root \
        -g root \
        "$SPLIT_CONFIG" \
        "$PROBE_SOURCE"

    address="$(
        awk -F= '
            /^[[:space:]]*Address[[:space:]]*=/ {
                value=$2
                gsub(/[[:space:]]/, "", value)
                split(value, addresses, ",")
                print addresses[1]
                exit
            }
        ' "$PROBE_SOURCE"
    )"

    if [[ -z "$address" ]]; then
        log "could not determine probe interface address"
        stop_probe
        return 1
    fi

    wg-quick strip \
        "$PROBE_SOURCE" \
        > "$PROBE_STRIPPED"

    ip link add \
        dev "$PROBE" \
        type wireguard

    wg setconf \
        "$PROBE" \
        "$PROBE_STRIPPED"

    mapfile -t peers < <(
        wg show "$PROBE" peers
    )

    if [[ "${#peers[@]}" -ne 1 ]]; then
        log "probe requires exactly one WireGuard peer"
        stop_probe
        return 1
    fi

    peer="${peers[0]}"

    # Defense in depth:
    # the normal split profile contains several Homelab networks,
    # but the monitor may encrypt traffic only for the health target.
    wg set \
        "$PROBE" \
        peer "$peer" \
        allowed-ips "$HEALTH_TARGET/32"

    ip address add \
        "$address" \
        dev "$PROBE"

    ip link set \
        mtu 1420 \
        up \
        dev "$PROBE"

    ip route replace \
        "$HEALTH_TARGET/32" \
        dev "$PROBE"

    rm -f \
        "$PROBE_SOURCE" \
        "$PROBE_STRIPPED"

    log "isolated probe ready"
}


probe_healthy() {
    probe_exists &&
    ping \
        -I "$PROBE" \
        -c 1 \
        -W 2 \
        "$HEALTH_TARGET" \
        >/dev/null 2>&1
}


route_uses_interface() {
    local target="$1"
    local interface="$2"

    ip -4 route get "$target" \
        2>/dev/null |
        grep -Eq \
            "dev ${interface}([[:space:]]|$)"
}


full_dns_server() {
    awk -F= '
        /^[[:space:]]*DNS[[:space:]]*=/ {
            value=$2
            gsub(/[[:space:]]/, "", value)
            split(value, servers, ",")
            print servers[1]
            exit
        }
    ' "$FULL_CONFIG"
}


dns_config_healthy() {
    local dns

    dns="$(
        full_dns_server
    )" || return 1

    [[ -n "$dns" ]] ||
        return 1

    awk \
        -v dns="$dns" \
        '
            $1 == "nameserver" &&
            $2 == dns {
                found=1
            }

            END {
                exit(found ? 0 : 1)
            }
        ' \
        /etc/resolv.conf
}


internet_route_healthy() {
    route_uses_interface \
        "$INTERNET_ROUTE_TARGET" \
        "$FULL_INTERFACE"
}


internet_egress_healthy() {
    curl \
        --fail \
        --silent \
        --show-error \
        --connect-timeout 3 \
        --max-time 5 \
        --output /dev/null \
        "$INTERNET_TEST_URL" \
        >/dev/null 2>&1
}


full_healthy() {
    FULL_HEALTH_REASON=""

    if ! service_active "$FULL"; then
        FULL_HEALTH_REASON="service inactive"
        return 1
    fi

    if ! route_uses_interface \
        "$HEALTH_TARGET" \
        "$FULL_INTERFACE"
    then
        FULL_HEALTH_REASON="Homelab route is not on $FULL_INTERFACE"
        return 1
    fi

    if ! ping \
        -c 1 \
        -W 2 \
        "$HEALTH_TARGET" \
        >/dev/null 2>&1
    then
        FULL_HEALTH_REASON="Homelab target $HEALTH_TARGET is unreachable"
        return 1
    fi

    if ! dns_config_healthy; then
        FULL_HEALTH_REASON="Homelab DNS is not active in /etc/resolv.conf"
        return 1
    fi

    if ! internet_route_healthy; then
        FULL_HEALTH_REASON="Internet route is not on $FULL_INTERFACE"
        return 1
    fi

    return 0
}


full_healthy_deep() {
    full_healthy ||
        return 1

    if ! internet_egress_healthy; then
        FULL_HEALTH_REASON="full-tunnel HTTPS egress failed"
        return 1
    fi

    return 0
}


enter_fallback() {
    log "entering fail-open fallback"

    stop_service "$FULL"
    stop_service "$SPLIT"

    if ! start_probe; then
        log "WARNING: could not create probe; direct Internet remains available"
    fi

    auto_failures=0
    auto_successes=0
}


try_full_from_auto() {
    stop_service "$SPLIT"
    stop_probe

    log "trying full tunnel"

    if ! systemctl start "$FULL"; then
        log "full tunnel service failed to start"
        enter_fallback
        return 1
    fi

    sleep 2

    if full_healthy_deep; then
        log "full tunnel is healthy"
        auto_failures=0
        auto_successes=0
        return 0
    fi

    log "full tunnel healthcheck failed: $FULL_HEALTH_REASON"
    enter_fallback
    return 1
}


auto_step() {
    if service_active "$FULL"; then
        stop_probe
        stop_service "$SPLIT"

        if full_healthy; then
            auto_failures=0
            auto_successes=0
            return
        fi

        auto_failures=$((auto_failures + 1))

        log \
            "full tunnel healthcheck failed: " \
            "$FULL_HEALTH_REASON " \
            "($auto_failures/$FAILURE_LIMIT)"

        if [[ "$auto_failures" -ge "$FAILURE_LIMIT" ]]; then
            enter_fallback
        fi

        return
    fi

    stop_service "$SPLIT"

    if ! probe_exists; then
        try_full_from_auto || true
        return
    fi

    if probe_healthy; then
        auto_successes=$((auto_successes + 1))

        log \
            "Homelab probe healthy " \
            "($auto_successes/$RECOVERY_LIMIT)"

        if [[ "$auto_successes" -ge "$RECOVERY_LIMIT" ]]; then
            log "Homelab is stable again; restoring full tunnel"

            stop_probe
            auto_successes=0

            try_full_from_auto || true
        fi

    else
        if [[ "$auto_successes" -ne 0 ]]; then
            log "Homelab probe lost again; recovery counter reset"
        fi

        auto_successes=0
    fi
}


full_step() {
    stop_probe
    stop_service "$SPLIT"

    start_service "$FULL"
}


split_step() {
    stop_probe
    stop_service "$FULL"

    start_service "$SPLIT"
}


off_step() {
    stop_probe
    stop_service "$FULL"
    stop_service "$SPLIT"

    auto_failures=0
    auto_successes=0
}


configs_ready() {
    [[ -r "$FULL_CONFIG" ]] &&
    [[ -r "$SPLIT_CONFIG" ]]
}


run_manager() {
    local mode
    local previous_mode=""

    require_root
    ensure_state

    log "manager started"

    while true; do
        mode="$(read_mode)"

        if [[ "$mode" != "$previous_mode" ]]; then
            log "desired mode: $mode"
            previous_mode="$mode"

            auto_failures=0
            auto_successes=0
        fi

        case "$mode" in
            off)
                off_step
                ;;

            auto|full|split)
                if ! configs_ready; then
                    log "waiting for WireGuard secrets"
                    sleep "$CHECK_INTERVAL"
                    continue
                fi

                case "$mode" in
                    auto)
                        auto_step
                        ;;
                    full)
                        full_step
                        ;;
                    split)
                        split_step
                        ;;
                esac
                ;;
        esac

        sleep "$CHECK_INTERVAL"
    done
}


check_health() {
    local mode

    mode="$(read_mode)"

    echo "Desired mode: $mode"

    if service_active "$FULL"; then
        echo "Runtime: full"

        if full_healthy_deep; then
            echo "Full health: healthy"
            exit 0
        fi

        echo "Full health: degraded"
        echo "Reason: $FULL_HEALTH_REASON"
        exit 1
    fi

    if service_active "$SPLIT"; then
        echo "Runtime: split"

        if ping \
            -c 1 \
            -W 2 \
            "$HEALTH_TARGET" \
            >/dev/null 2>&1
        then
            echo "Homelab health: reachable"
            exit 0
        fi

        echo "Homelab health: unreachable"
        exit 1
    fi

    if probe_exists; then
        echo "Runtime: fail-open probe"

        if probe_healthy; then
            echo "Homelab health: reachable"
            exit 0
        fi

        echo "Homelab health: unreachable"
        exit 1
    fi

    echo "Runtime: direct"

    if [[ "$mode" == "off" ]]; then
        echo "Homelab health: not checked (VPN intentionally off)"
        exit 0
    fi

    echo "Homelab health: no tunnel/probe active"
    exit 1
}


case "${1:-run}" in
    run)
        run_manager
        ;;

    set-mode)
        require_root

        if [[ "$#" -ne 2 ]]; then
            echo "Usage: homelab-vpn-manager set-mode MODE" >&2
            exit 2
        fi

        write_mode "$2"
        ;;

    get-mode)
        ensure_state
        read_mode
        ;;

    check)
        ensure_state
        check_health
        ;;

    cleanup-probe)
        require_root
        stop_probe
        ;;

    *)
        echo "Usage:"
        echo "  homelab-vpn-manager run"
        echo "  homelab-vpn-manager set-mode auto|full|split|off"
        echo "  homelab-vpn-manager get-mode"
        echo "  homelab-vpn-manager check"
        echo "  homelab-vpn-manager cleanup-probe"
        exit 2
        ;;
esac
