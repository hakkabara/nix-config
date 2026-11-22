{
  config,
  lib,
  pkgs,
  ...
}:

# KDE Connect reduced to media control between two VMs.
#
# The "player" side shares its local MPRIS players (browser, Spotify), the
# "remote" side shows them as local MPRIS players on D-Bus, so the shell's
# media widget, media keys and playerctl control them.
#
# KDE Connect loads every plugin it finds in lib/qt-6/plugins/kdeconnect and
# keeps the on/off state per paired device at runtime. Instead of relying on
# that state, the package is rebuilt with only the one media plugin: clipboard,
# share, run command, remote input, sftp and the rest do not exist on disk.
#
# Network: inbound KDE Connect traffic is accepted only from the peer address
# on one interface. Discovery (UDP broadcast on 1716, mDNS on 5353) and
# outgoing KDE Connect connections are dropped on every other interface, so
# the device is never announced on the internet-facing networks.
let
  cfg = config.hakkabara.apps.kdeconnectMedia;

  keptPlugin =
    {
      player = "kdeconnect_mpriscontrol";
      remote = "kdeconnect_mprisremote";
    }
    .${cfg.role};

  package = pkgs.kdePackages.kdeconnect-kde.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      pluginDir="$out/lib/qt-6/plugins/kdeconnect"
      test -e "$pluginDir/${keptPlugin}.so"
      find "$pluginDir" -mindepth 1 ! -name '${keptPlugin}.so' -delete
      test "$(ls "$pluginDir")" = "${keptPlugin}.so"
    '';
  });

  ports = "1714:1764";
  egressChain = "kdeconnect-egress";
in
{
  options.hakkabara.apps.kdeconnectMedia = {
    enable = lib.mkEnableOption "KDE Connect limited to media control between two hosts";

    role = lib.mkOption {
      type = lib.types.enum [
        "player"
        "remote"
      ];
      description = ''
        "player" shares the local media players (kdeconnect_mpriscontrol),
        "remote" controls the peer's players (kdeconnect_mprisremote).
      '';
    };

    interface = lib.mkOption {
      type = lib.types.str;
      description = "Only interface on which KDE Connect may talk to the peer.";
    };

    peerAddress = lib.mkOption {
      type = lib.types.str;
      description = "IPv4 address of the peer host.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.networking.firewall.enable && !config.networking.nftables.enable;
        message = "hakkabara.apps.kdeconnectMedia expects the iptables-based NixOS firewall.";
      }
    ];

    # The package's XDG autostart entry starts kdeconnectd in Plasma and
    # in Niri (niri.service wants xdg-desktop-autostart.target).
    environment.systemPackages = [ package ];

    networking.firewall = {
      extraCommands = ''
        iptables -A nixos-fw -i ${cfg.interface} -s ${cfg.peerAddress} -p tcp --dport ${ports} -j nixos-fw-accept
        iptables -A nixos-fw -i ${cfg.interface} -s ${cfg.peerAddress} -p udp --dport ${ports} -j nixos-fw-accept

        ip46tables -N ${egressChain} 2>/dev/null || true
        ip46tables -F ${egressChain}
        ip46tables -C OUTPUT -j ${egressChain} 2>/dev/null || ip46tables -A OUTPUT -j ${egressChain}
        iptables -A ${egressChain} ! -o ${cfg.interface} -p udp -m multiport --dports 1716,5353 -j DROP
        iptables -A ${egressChain} ! -o ${cfg.interface} -p tcp --dport ${ports} -j DROP
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
