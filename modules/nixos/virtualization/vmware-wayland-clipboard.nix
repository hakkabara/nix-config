{
  config,
  lib,
  pkgs,
  wl-x11-clipsync,
  ...
}:

let
  cfg = config.hakkabara.vmware.waylandClipboard;

  clipsync = wl-x11-clipsync.packages.${pkgs.stdenv.hostPlatform.system}.default;

  clipboardStatus = pkgs.writeShellApplication {
    name = "vmware-clipboard-status";

    runtimeInputs = [
      pkgs.systemd
    ];

    text = ''
      echo "================================================================"
      echo "VMWARE WAYLAND CLIPBOARD STATUS"
      echo "================================================================"

      printf 'SESSION=%s\n' "''${XDG_SESSION_TYPE:-<unset>}"
      printf 'WAYLAND_DISPLAY=%s\n' "''${WAYLAND_DISPLAY:-<unset>}"
      printf 'DISPLAY=%s\n' "''${DISPLAY:-<unset>}"

      echo
      echo "=== GRAPHICAL SESSION TARGET ==="
      systemctl --user is-active graphical-session.target || true

      echo
      echo "=== SERVICES ==="

      for service in \
        wl-x11-clipsync.service \
        wl-paste.service
      do
        echo
        echo "--- $service ---"

        systemctl --user show "$service" \
          --property=LoadState \
          --property=ActiveState \
          --property=SubState \
          --property=NRestarts \
          --property=CPUUsageNSec \
          --no-pager || true
      done

      echo
      echo "=== RECENT WARNINGS / ERRORS ==="

      journalctl --user -b \
        -u wl-x11-clipsync.service \
        -u wl-paste.service \
        --priority=warning \
        --no-pager \
        -n 20 || true

      echo
      echo "NOTE: Clipboard contents are intentionally never displayed."
    '';
  };
in
{
  options.hakkabara.vmware.waylandClipboard.enable =
    lib.mkEnableOption "Wayland clipboard synchronization for VMware guests";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.vmware.guest.enable;
        message = ''
          hakkabara.vmware.waylandClipboard requires
          virtualisation.vmware.guest.enable = true.
        '';
      }
    ];

    # Make the clipboard tools available for interactive diagnostics as well.
    #
    # Previously wl-paste was only available inside the systemd service PATH,
    # which is why it was not directly callable from the interactive shell.
    environment.systemPackages = [
      clipsync
      pkgs.wl-clipboard
      pkgs.xclip
      pkgs.clipnotify
      clipboardStatus
    ];

    systemd.user.services = {
      # ---------------------------------------------------------------------
      # X11 / VMware -> Wayland
      # ---------------------------------------------------------------------
      #
      # Keep this intentionally close to the known-working Kyubai/Mattes
      # implementation.
      wl-x11-clipsync = {
        description = "Synchronize Wayland and X11 clipboards";

        wantedBy = [
          "graphical-session.target"
        ];

        partOf = [
          "graphical-session.target"
        ];

        after = [
          "graphical-session.target"
        ];

        unitConfig = {
          # Do not start this workaround in a pure X11 session.
          ConditionEnvironment = "WAYLAND_DISPLAY";

          # This feature only makes sense inside a VMware guest.
          ConditionVirtualization = "vmware";

          # Protect against a future crash/restart loop.
          StartLimitIntervalSec = "30s";
          StartLimitBurst = 5;
        };

        serviceConfig = {
          ExecStart = "${clipsync}/bin/clipsync";

          Restart = "on-failure";
          RestartSec = 2;
        };
      };

      # ---------------------------------------------------------------------
      # Wayland -> X11 / VMware host
      # ---------------------------------------------------------------------
      #
      # IMPORTANT:
      #
      # Do not force "-selection clipboard" here.
      #
      # This deliberately preserves the working Kyubai/Mattes data path:
      #
      #   wl-paste -w xclip -i
      #
      # Our first experiment changed this behavior and caused a clipboard
      # feedback loop with very high CPU usage.
      wl-paste = {
        description = "Synchronize Wayland clipboard to VMware host";

        wantedBy = [
          "graphical-session.target"
        ];

        partOf = [
          "graphical-session.target"
        ];

        after = [
          "graphical-session.target"
        ];

        unitConfig = {
          ConditionEnvironment = "WAYLAND_DISPLAY";
          ConditionVirtualization = "vmware";

          StartLimitIntervalSec = "30s";
          StartLimitBurst = 5;
        };

        path = with pkgs; [
          wl-clipboard
          xclip
        ];

        serviceConfig = {
          ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste" + " -w ${pkgs.xclip}/bin/xclip -i";

          Restart = "on-failure";
          RestartSec = 2;
        };
      };
    };
  };
}
