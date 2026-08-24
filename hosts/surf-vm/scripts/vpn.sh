set -euo pipefail

MANAGER="homelab-vpn-manager"
MANAGER_SERVICE="homelab-vpn-manager.service"

FULL="wg-quick-homelab-full.service"
SPLIT="wg-quick-homelab-split.service"
AIRVPN="wg-quick-airvpn.service"

STATE_DIR="/var/lib/homelab-vpn"
MODE_FILE="$STATE_DIR/mode"

PROBE="wgprobe"
HEALTH_TARGET="192.168.189.1"


mode() {
    if [[ -r "$MODE_FILE" ]]; then
        cat "$MODE_FILE"
    else
        echo "auto"
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
        if systemctl is-active --quiet "$AIRVPN" && \
           systemctl is-active --quiet "$SPLIT"; then
            runtime="rvpn"
        else
            runtime="rvpn-degraded"
        fi
    elif systemctl is-active --quiet "$AIRVPN"; then
        runtime="unexpected-airvpn"
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
    printf '%s airvpn\n' "$(active_mark "$AIRVPN")"

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
        echo "  vpn check"
        exit 2
        ;;
esac
