set -euo pipefail

FULL="wg-quick-homelab-full.service"
SPLIT="wg-quick-homelab-split.service"

status() {
    echo "VPN Status"
    echo "────────────────────────────"

    if systemctl is-active --quiet "$FULL"; then
        echo "● homelab-full"
    else
        echo "○ homelab-full"
    fi

    if systemctl is-active --quiet "$SPLIT"; then
        echo "● homelab-split"
    else
        echo "○ homelab-split"
    fi
}

switch_to() {
    local target="$1"
    local other="$2"
    local previous=""

    if systemctl is-active --quiet "$other"; then
        previous="$other"
    fi

    sudo systemctl stop "$other"

    if sudo systemctl start "$target"; then
        echo
        echo "VPN switched successfully."
        status
        return
    fi

    echo "Failed to start target VPN." >&2

    if [[ -n "$previous" ]]; then
        echo "Restoring previous VPN..." >&2
        sudo systemctl start "$previous"
    fi

    exit 1
}

case "${1:-status}" in
    full)
        switch_to "$FULL" "$SPLIT"
        ;;

    split)
        switch_to "$SPLIT" "$FULL"
        ;;

    off)
        sudo systemctl stop "$FULL" "$SPLIT"
        echo "VPN disabled."
        ;;

    status)
        status
        ;;

    *)
        echo "Usage:"
        echo "  vpn status"
        echo "  vpn full"
        echo "  vpn split"
        echo "  vpn off"
        exit 2
        ;;
esac
