{
  config,
  lib,
  pkgs,
  ...
}:

# KDE Connect reduced to media control between VMs.
#
# share:   publish the local MPRIS players (browser, Spotify) to the peers
#          (plugin kdeconnect_mpriscontrol).
# control: show the peers' players as local MPRIS players on D-Bus, so the
#          shell's media widget, media keys and playerctl control them
#          (plugin kdeconnect_mprisremote).
#
# KDE Connect loads every plugin it finds in lib/qt-6/plugins/kdeconnect and
# keeps the on/off state per paired device at runtime. Instead of relying on
# that state, the package is rebuilt with only the selected media plugins:
# clipboard, share, run command, remote input, sftp and the rest do not exist
# on disk. New upstream plugins are dropped the same way (allow-list); a
# renamed media plugin fails the build instead of silently shipping more.
#
# Privacy mode: `media-privacy on|off|toggle|status` (both roles) sets a flag
# in $XDG_STATE_HOME/kdeconnect-media/private. While it exists, the share side
# sends "Privat" instead of title/artist/cover, and the control side shows
# "Privat" as well; play/pause/next keep working. The flag survives reboots.
#
# Network: inbound KDE Connect traffic is accepted only from the listed peers
# on one interface. Discovery (UDP broadcast on 1716, mDNS on 5353) and
# outgoing KDE Connect connections are dropped on every other interface, so
# the device is never announced on other (internet-facing) networks. To move
# to a dedicated network, change network.interface and network.peers.
let
  cfg = config.hakkabara.apps.kdeconnectMedia;

  keptPlugins =
    lib.optional cfg.share.enable "kdeconnect_mpriscontrol"
    ++ lib.optional cfg.control.enable "kdeconnect_mprisremote";

  package = pkgs.kdePackages.kdeconnect-kde.overrideAttrs (old: {
    # mpriscontrol: privacy flag. mprisremote: privacy flag and https cover
    # pass-through (see control.httpsCoverArt).
    patches =
      (old.patches or [ ])
      ++ lib.optional cfg.share.enable ./mpriscontrol-privacy.patch
      ++ lib.optional cfg.control.enable ./mprisremote-cover-and-privacy.patch;

    postInstall = (old.postInstall or "") + ''
      pluginDir="$out/lib/qt-6/plugins/kdeconnect"
      keep=(${lib.concatMapStringsSep " " (p: "${p}.so") keptPlugins})
      for plugin in "''${keep[@]}"; do
        test -e "$pluginDir/$plugin"
      done
      for file in "$pluginDir"/*; do
        name="$(basename "$file")"
        case " ''${keep[*]} " in
          *" $name "*) ;;
          *) rm -r "$file" ;;
        esac
      done
      test "$(ls "$pluginDir" | wc -l)" -eq "''${#keep[@]}"

      # Started by the systemd user unit below (or not at all), never by a
      # second XDG autostart path.
      rm "$out/etc/xdg/autostart/org.kde.kdeconnect.daemon.desktop"
    '';
  });

  mediaPrivacy = pkgs.writeShellApplication {
    name = "media-privacy";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.libnotify
    ];
    text = ''
      flag="''${XDG_STATE_HOME:-$HOME/.local/state}/kdeconnect-media/private"

      case "''${1:-toggle}" in
        on) mkdir -p "$(dirname "$flag")" && touch "$flag" ;;
        off) rm -f "$flag" ;;
        toggle)
          if [[ -e "$flag" ]]; then
            rm -f "$flag"
          else
            mkdir -p "$(dirname "$flag")" && touch "$flag"
          fi
          ;;
        status) ;;
        *)
          echo "usage: media-privacy on|off|toggle|status" >&2
          exit 2
          ;;
      esac

      if [[ -e "$flag" ]]; then state="an"; else state="aus"; fi
      if [[ "''${1:-toggle}" == "status" ]]; then
        echo "Medien privat: $state"
        exit 0
      fi

      # Both patched plugins watch the flag directory and re-announce the
      # metadata at once; the connection to the peers stays up.
      notify-send -a "KDE Connect" -i kdeconnect "Medien privat: $state" || true
      echo "Medien privat: $state"
    '';
  };

  # Discovery also goes by unicast to every peer (KDE Connect "customDevices",
  # [General] in the QSettings file ~/.config/kdeconnect/config). The UDP
  # broadcast may leave through another interface and is then dropped by the
  # egress chain; without this, a daemon restart (media-privacy) would not
  # find its peer again until the peer itself restarted.
  setCustomDevices = pkgs.writeShellScript "kdeconnect-media-custom-devices" ''
    config_file="''${XDG_CONFIG_HOME:-$HOME/.config}/kdeconnect/config"
    mkdir -p "$(dirname "$config_file")"
    touch "$config_file"
    ${pkgs.crudini}/bin/crudini --ini-options=nospace --set "$config_file" General customDevices \
      ${lib.escapeShellArg (lib.concatStringsSep ", " (lib.attrValues cfg.network.peers))}
  '';

  # Control side: after a reboot of either VM the link comes back, but the
  # remote player list can stay empty (the peer does not resend it), so the
  # media widget shows nothing. Ask every reachable peer with an empty list
  # for its players; a peer that really plays nothing just answers empty.
  playerRefresh = pkgs.writeShellApplication {
    name = "kdeconnect-media-refresh";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
      package
    ];
    text = ''
      while true; do
        for id in $(kdeconnect-cli -a --id-only 2>/dev/null); do
          path="/modules/kdeconnect/devices/$id/mprisremote"
          list="$(busctl --user get-property org.kde.kdeconnect "$path" \
            org.kde.kdeconnect.device.mprisremote playerList 2>/dev/null || true)"
          if [[ "$list" == "as 0" ]]; then
            busctl --user call org.kde.kdeconnect "$path" \
              org.kde.kdeconnect.device.mprisremote requestPlayerList >/dev/null 2>&1 || true
          fi
        done
        sleep 20
      done
    '';
  };

  ports = "1714:1764";
  egressChain = "kdeconnect-egress";

  peerRules = lib.concatMapStringsSep "\n" (address: ''
    iptables -A nixos-fw -i ${cfg.network.interface} -s ${address} -p tcp --dport ${ports} -j nixos-fw-accept
    iptables -A nixos-fw -i ${cfg.network.interface} -s ${address} -p udp --dport ${ports} -j nixos-fw-accept
  '') (lib.attrValues cfg.network.peers);
in
{
  options.hakkabara.apps.kdeconnectMedia = {
    enable = lib.mkEnableOption "KDE Connect limited to media control between hosts";

    share.enable = lib.mkEnableOption "publishing the local media players to the peers";

    control = {
      enable = lib.mkEnableOption "showing and controlling the peers' media players locally";

      httpsCoverArt = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          KDE Connect only transfers cover art that is a local file on the
          player side; Spotify reports https URLs. When true, those URLs are
          passed through as mpris:artUrl, so the local shell downloads the
          cover itself (this host then contacts the cover CDN directly).
        '';
      };
    };

    autostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Start kdeconnectd with the graphical session (systemd user unit).
      '';
    };

    network = {
      interface = lib.mkOption {
        type = lib.types.str;
        description = "Only interface on which KDE Connect may talk to its peers.";
      };

      peers = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        example = {
          surf-vm = "192.168.245.12";
        };
        description = "Peer hosts (name = IPv4 address) allowed to connect.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.share.enable || cfg.control.enable;
        message = "hakkabara.apps.kdeconnectMedia needs share.enable and/or control.enable.";
      }
      {
        assertion = cfg.network.peers != { };
        message = "hakkabara.apps.kdeconnectMedia.network.peers must list at least one peer.";
      }
      {
        assertion = config.networking.firewall.enable && !config.networking.nftables.enable;
        message = "hakkabara.apps.kdeconnectMedia expects the iptables-based NixOS firewall.";
      }
    ];

    environment.systemPackages = [
      package
      mediaPrivacy
    ]
    ++ lib.optional cfg.control.enable pkgs.playerctl;

    systemd.user.services.kdeconnectd = lib.mkIf cfg.autostart {
      description = "KDE Connect daemon (media only)";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        # --replace takes over an instance started by D-Bus activation.
        ExecStartPre = "${setCustomDevices}";
        ExecStart = "${package}/bin/kdeconnectd --replace";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    systemd.user.services.kdeconnect-media-refresh = lib.mkIf (cfg.autostart && cfg.control.enable) {
      description = "Re-request KDE Connect remote player lists when empty";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [ "kdeconnectd.service" ];
      serviceConfig = {
        ExecStart = lib.getExe playerRefresh;
        Restart = "on-failure";
        RestartSec = 10;
      };
    };

    networking.firewall = {
      extraCommands = ''
        ${peerRules}
        ip46tables -N ${egressChain} 2>/dev/null || true
        ip46tables -F ${egressChain}
        ip46tables -C OUTPUT -j ${egressChain} 2>/dev/null || ip46tables -A OUTPUT -j ${egressChain}
        iptables -A ${egressChain} ! -o ${cfg.network.interface} -p udp -m multiport --dports 1716,5353 -j DROP
        iptables -A ${egressChain} ! -o ${cfg.network.interface} -p tcp --dport ${ports} -j DROP
        ip6tables -A ${egressChain} -p udp -m multiport --dports 1716,5353 -j DROP
        ip6tables -A ${egressChain} -p tcp --dport ${ports} -j DROP
      '';

      extraStopCommands = ''
        ip46tables -D OUTPUT -j ${egressChain} 2>/dev/null || true
        ip46tables -F ${egressChain} 2>/dev/null || true
        ip46tables -X ${egressChain} 2>/dev/null || true
      '';
    };
  };
}
