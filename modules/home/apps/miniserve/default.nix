{ config, lib, pkgs, ... }:

let
  cfg = config.hakkabara.apps.miniserve;

  profileDefaults = {
    "surf-vm" = {
      port = 8443;
      upload = true;
      username = "wiesel";
    };

    "work-vm" = {
      port = 9443;
      upload = false;
      username = "wiesel";
    };

    "desktop" = {
      port = 8443;
      upload = true;
      username = "wiesel";
    };
  };

  defaults =
    profileDefaults.${cfg.profile};

in
{
  options.hakkabara.apps.miniserve = {

    enable = lib.mkEnableOption "miniserve secure file sharing";

    profile = lib.mkOption {
      type = lib.types.enum [
        "surf-vm"
        "work-vm"
        "desktop"
      ];

      default = "desktop";
    };

  };


  config = lib.mkIf cfg.enable {

    home.packages = [
      pkgs.miniserve
      pkgs.openssl
      pkgs.pwgen
      pkgs.wl-clipboard
    ];


    home.file.".local/bin/share" = {

      executable = true;

      text = ''
        #!/usr/bin/env bash

        set -euo pipefail


        LOGDIR="$HOME/.local/state/share"

        mkdir -p "$LOGDIR"


        if [ $# -lt 1 ]; then
          echo "Usage:"
          echo "  share <directory>"
          exit 1
        fi


        DIR="$1"


        if [ ! -d "$DIR" ]; then
          echo "Directory does not exist:"
          echo "$DIR"
          exit 1
        fi


        PORT="${toString defaults.port}"
        USER="${defaults.username}"

        PASSWORD="$(pwgen -s 8 1)"

        IP=""

        for iface in homelab-full homelab-split wg0 wg1 tun0; do
          CANDIDATE="$(
            ip -4 addr show "$iface" 2>/dev/null |
              awk '/inet / {print $2}' |
              cut -d/ -f1 |
              head -1
          )"

          if [ -n "$CANDIDATE" ]; then
            IP="$CANDIDATE"
            break
          fi
        done


        if [ -z "$IP" ]; then
          IP="$(hostname -I | awk '{print $1}')"
        fi


        if [ -z "$IP" ]; then
          echo "Could not determine share IP"
          exit 1
        fi


        SHARE_ID="$(date +%Y%m%d-%H%M%S)-$(openssl rand -hex 3)"


        LOGFILE="$LOGDIR/share.log"


        {
          echo "$(date -Is) START"
          echo "id=$SHARE_ID"
          echo "path=$DIR"
          echo "ip=$IP"
          echo "port=$PORT"
          echo "upload=${if defaults.upload then "true" else "false"}"
        } >> "$LOGFILE"


        URL="https://$IP:$PORT"


        echo
        echo "━━━━━━━━━━━━━━━━━━━━━━"
        echo " Miniserve Share"
        echo "━━━━━━━━━━━━━━━━━━━━━━"
        echo
        echo "Directory:"
        echo "$DIR"
        echo
        echo "URL:"
        echo "$URL"
        echo
        echo "Username:"
        echo "$USER"
        echo
        echo "Password:"
        echo "$PASSWORD"
        echo
        echo "Direct:"
        echo "https://$USER:$PASSWORD@$IP:$PORT"
        echo
        echo "━━━━━━━━━━━━━━━━━━━━━━"


        echo "$URL" | wl-copy


        cleanup() {

          echo "$(date -Is) STOP id=$SHARE_ID" >> "$LOGFILE"

        }


        trap cleanup EXIT INT TERM


        ARGS=(
          "$DIR"
          "--interfaces"
          "$IP"
          "--port"
          "$PORT"
          "--auth"
          "$USER:$PASSWORD"
          "--pastebin"
          "--verbose"
          "--tls-cert"
          "$HOME/.config/miniserve/cert.pem"
          "--tls-key"
          "$HOME/.config/miniserve/key.pem"
        )


        ${lib.optionalString defaults.upload ''
        ARGS+=(
          "--upload-files"
        )
        ''}


        exec ${pkgs.miniserve}/bin/miniserve "''${ARGS[@]}"
      '';
    };
  };
}
