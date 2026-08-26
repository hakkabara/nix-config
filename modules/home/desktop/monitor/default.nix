{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hakkabara.desktop.monitor;

  sizeType = lib.types.submodule {
    options = {
      width = lib.mkOption {
        type = lib.types.ints.positive;
        description = "Expected physical output width used for profile detection.";
      };
      height = lib.mkOption {
        type = lib.types.ints.positive;
        description = "Expected physical output height used for profile detection.";
      };
    };
  };

  profileType = lib.types.submodule {
    options = {
      label = lib.mkOption {
        type = lib.types.str;
        description = "Human-readable profile label.";
      };
      matchSizes = lib.mkOption {
        type = lib.types.listOf sizeType;
        description = "Two expected physical output sizes used only for detection.";
      };
      tolerance = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 96;
        description = "Pixel tolerance for VMware resize differences during profile detection.";
      };
      leftOutput = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Preferred left output name; falls back to deterministic name order.";
      };
      rightOutput = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Preferred right output name; falls back to deterministic name order.";
      };
      primaryOutput = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Preferred primary output. Placement and primary-display selection are intentionally independent.";
      };
      verticalAlignment = lib.mkOption {
        type = lib.types.enum [
          "top"
          "center"
          "bottom"
        ];
        default = "center";
        description = "Vertical alignment used when outputs have different logical heights.";
      };
    };
  };

  configFile = pkgs.writeText "hakkabara-monitor.json" (
    builtins.toJSON {
      inherit (cfg) backend safeOutput;
      watcher = {
        inherit (cfg.watcher)
          debounceSeconds
          fallbackPollSeconds
          promptTimeoutSeconds
          popupDelayMilliseconds
          ;
      };
      profiles = lib.mapAttrs (_: profile: {
        inherit (profile)
          label
          tolerance
          leftOutput
          rightOutput
          primaryOutput
          verticalAlignment
          ;
        matchSizes = map (size: [
          size.width
          size.height
        ]) profile.matchSizes;
      }) cfg.profiles;
    }
  );

  backendPackages =
    lib.optionals
      (builtins.elem cfg.backend [
        "plasma"
        "auto"
      ])
      [
        pkgs.kdePackages.libkscreen
        pkgs.kdePackages.kscreen
      ]
    ++
      lib.optionals
        (builtins.elem cfg.backend [
          "niri"
          "auto"
        ])
        [
          pkgs.niri
        ];

  monitor = pkgs.writeShellApplication {
    name = "monitor";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.kitty
      pkgs.python3
      pkgs.systemd
    ]
    ++ lib.optionals (builtins.elem cfg.backend [
      "plasma"
      "auto"
    ]) [ pkgs.kdotool ]
    ++ backendPackages;

    text = ''
      export HAKKABARA_MONITOR_BIN="$0"
      exec ${lib.getExe pkgs.python3} ${./monitor.py} --config ${configFile} "$@"
    '';
  };
in
{
  options.hakkabara.desktop.monitor = {
    enable = lib.mkEnableOption "shared compositor-aware monitor profile helper";

    backend = lib.mkOption {
      type = lib.types.enum [
        "auto"
        "plasma"
        "niri"
      ];
      default = "auto";
      description = "Monitor-control backend. Prefer an explicit value on production hosts.";
    };

    safeOutput = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Output kept enabled when entering the safe single-screen state.";
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf profileType;
      default = { };
      description = "Known two-output monitor profiles.";
    };

    watcher = {
      enable = lib.mkEnableOption "event-driven monitor hotplug watcher";

      debounceSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1;
        description = "Maximum seconds to wait for a newly connected second output to expose usable mode data.";
      };

      fallbackPollSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 30;
        description = "Low-frequency safety reconciliation interval if no compositor event arrives.";
      };

      promptTimeoutSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 10;
        description = "Seconds before the selector closes and keeps safe single-screen mode.";
      };

      popupDelayMilliseconds = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 250;
        description = "Short delay after safe-single verification before opening the selector; kept sub-second for fast recovery.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Keep built-in detection profiles as module definitions so hosts can
    # override only placement/primary/alignment without replacing the match sizes.
    hakkabara.desktop.monitor.profiles = {
      homeoffice = {
        label = lib.mkDefault "Home Office";
        matchSizes = lib.mkDefault [
          {
            width = 2560;
            height = 1440;
          }
          {
            width = 1920;
            height = 1080;
          }
        ];
      };

      office = {
        label = lib.mkDefault "Office";
        matchSizes = lib.mkDefault [
          {
            width = 2560;
            height = 1440;
          }
          {
            width = 2560;
            height = 1440;
          }
        ];
      };
    };

    assertions = lib.mapAttrsToList (name: profile: {
      assertion = builtins.length profile.matchSizes == 2;
      message = "monitor profile '${name}' must define exactly two matchSizes";
    }) cfg.profiles;

    home.packages = [ monitor ];

    systemd.user.services.hakkabara-monitor-watcher = lib.mkIf cfg.watcher.enable {
      Unit = {
        Description = "Hakkabara monitor hotplug watcher";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${monitor}/bin/monitor watch";
        Restart = "on-failure";
        RestartSec = 2;
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
