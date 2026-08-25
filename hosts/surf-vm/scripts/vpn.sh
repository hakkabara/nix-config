set -euo pipefail

MANAGER="homelab-vpn-manager"
MANAGER_SERVICE="homelab-vpn-manager.service"

FULL="wg-quick-homelab-full.service"
SPLIT="wg-quick-homelab-split.service"
RVPN="wg-quick-rvpn.service"

STATE_DIR="/var/lib/homelab-vpn"
MODE_FILE="$STATE_DIR/mode"

PROBE="wgprobe"
HEALTH_TARGET="192.168.189.1"


mode() {
    if [[ -r "$MODE_FILE" ]]; then
        cat "$MODE_FILE"
    else
        echo "full"
    fi
}


active_mark() {
    if systemctl is-active --quiet "$1"; then
        printf '%s' "●"
    else
        printf '%s' "○"
    fi
}


status() {
    local desired
    local runtime

    desired="$(mode)"

    if [[ "$desired" == "rvpn" ]]; then
        if systemctl is-active --quiet "$RVPN" && \
           systemctl is-active --quiet "$SPLIT"; then
            runtime="rvpn"
        else
            runtime="rvpn-degraded"
        fi
    elif systemctl is-active --quiet "$RVPN"; then
        runtime="unexpected-rvpn"
    elif systemctl is-active --quiet "$FULL"; then
        runtime="full"
    elif systemctl is-active --quiet "$SPLIT"; then
        runtime="split"
    elif ip link show "$PROBE" >/dev/null 2>&1; then
        runtime="fail-open"
    elif [[ "$desired" == "off" ]]; then
        runtime="off"
    else
        runtime="direct"
    fi

    echo "VPN Status"
    echo "────────────────────────────"
    echo "Desired mode: $desired"
    echo "Runtime:      $runtime"
    echo
    printf '%s homelab-full\n' "$(active_mark "$FULL")"
    printf '%s homelab-split\n' "$(active_mark "$SPLIT")"
    printf '%s rvpn\n' "$(active_mark "$RVPN")"

    if ip link show "$PROBE" >/dev/null 2>&1; then
        echo "● homelab-probe"
    else
        echo "○ homelab-probe"
    fi

    if systemctl is-active --quiet "$MANAGER_SERVICE"; then
        echo "● vpn-manager"
    else
        echo "○ vpn-manager"
    fi

    echo
    echo "Route to $HEALTH_TARGET:"

    ip -4 route get "$HEALTH_TARGET" \
        2>/dev/null |
        sed -n '1p' ||
        echo "unavailable"
}


set_mode() {
    local requested="$1"

    sudo "$MANAGER" \
        set-mode \
        "$requested"

    sudo systemctl restart \
        "$MANAGER_SERVICE"

    sleep 1

    echo
    status
}



test_vpn() {
    echo "VPN TEST"
    echo "─────────"

    echo
    echo "Mode:"
    mode

    echo
    echo "WireGuard:"

    if systemctl is-active --quiet "$FULL" ||
       systemctl is-active --quiet "$SPLIT" ||
       systemctl is-active --quiet "$RVPN"; then
        echo "✓ WireGuard active"
    else
        echo "✗ WireGuard inactive"
    fi

    echo
    echo "Homelab:"

    if ping -c 1 -W 2 "$HEALTH_TARGET" >/dev/null 2>&1; then
        echo "✓ $HEALTH_TARGET reachable"
    else
        echo "✗ Homelab unreachable"
    fi

    echo
    echo "DNS:"

    if getent hosts google.de >/dev/null 2>&1; then
        echo "✓ DNS works"
    else
        echo "✗ DNS failed"
    fi

    echo
    echo "Internet:"

    if curl -fsS --max-time 5 \
        https://cache.nixos.org/nix-cache-info >/dev/null; then
        echo "✓ Internet works"
    else
        echo "✗ Internet failed"
    fi

    echo
    echo "Public IPv4:"
    curl -4 --max-time 5 -fsS https://ipinfo.io/ip \
        || echo "unavailable"
}


doctor() {
    echo "VPN DOCTOR"
    echo "──────────"

    echo
    echo "Services:"

    systemctl is-active --quiet "$MANAGER_SERVICE" \
        && echo "✓ manager" \
        || echo "✗ manager"

    echo
    echo "Interfaces:"
    ip link show | grep -E "homelab|rvpn" || echo "none"

    echo
    echo "Routes:"
    ip route get "$HEALTH_TARGET" || true

    echo
    echo "WireGuard:"
    sudo sh -c 'wg show | grep -E "interface|latest handshake" || true'

    echo
    echo "Secrets:"

    sudo sh -c '
    for s in /run/secrets/wireguard/*; do
        [[ -e "$s" ]] && echo "✓ $(basename "$s")"
    done
    '
}


case "${1:-status}" in
    auto)
        set_mode auto
        ;;

    full)
        set_mode full
        ;;

    split)
        set_mode split
        ;;

    rvpn)
        set_mode rvpn
        ;;

    off)
        set_mode off
        ;;

    status)
        status
        ;;

    test)
        test_vpn
        ;;

    doctor)
        doctor
        ;;

    check)
        sudo "$MANAGER" check
        ;;

    *)
        echo "Usage:"
        echo "  vpn auto"
        echo "  vpn full"
        echo "  vpn split"
        echo "  vpn rvpn"
        echo "  vpn off"
        echo "  vpn status"
        echo "  vpn test"
        echo "  vpn doctor"
        echo "  vpn check"
        exit 2
        ;;
esac
