{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.apps.teams;

  appId = "com.github.IsmaelMartinez.teams_for_linux";

  baseSettings = {
    closeAppOnCross = false;
    followSystemTheme = true;
    trayIconEnabled = true;

    cacheManagement.enabled = false;
  };

  chatOnlySettings = lib.optionalAttrs cfg.chatOnly {
    disableNotifications = false;
    disableNotificationSound = true;
    enableIncomingCallToast = false;

    notificationMethod = "electron";

    notifications.electron.clickAction = "restore";

    awayOnSystemIdle = false;

    download = {
      enabled = true;
      notifyOnDownloadComplete = true;
      showTitlePrefix = false;
    };

    spellCheckerLanguages = [
      "de-DE"
      "en-US"
    ];
  };

  effectiveSettings = lib.recursiveUpdate (lib.recursiveUpdate baseSettings chatOnlySettings) cfg.settings;

  configFile = pkgs.writeText "teams-for-linux-config.json" (builtins.toJSON effectiveSettings);

  userHome = config.users.users.${cfg.user}.home;

  appRoot = "${userHome}/.var/app/${appId}";

  configDir = "${appRoot}/config/teams-for-linux";

  configPath = "${configDir}/config.json";
in
{
  options.hakkabara.apps.teams = {
    enable = lib.mkEnableOption "Teams for Linux via Flatpak";

    user = lib.mkOption {
      type = lib.types.str;
      description = "User whose Teams for Linux configuration is managed.";
    };

    chatOnly = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Restrict Teams to chat and downloads and remove direct media permissions.";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Additional Teams for Linux settings overriding the reusable baseline.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.hasAttr cfg.user config.users.users;

        message = "hakkabara.apps.teams.user must reference an existing user";
      }
    ];

    services.flatpak.packages = [
      appId
    ];

    services.flatpak.overrides.settings = lib.mkIf cfg.chatOnly {
      "${appId}" = {
        Context = {
          devices = [
            "!all"
            "dri"
          ];

          filesystems = [
            "!home"
            "!xdg-run/pipewire-0"
            "xdg-download"
          ];

          sockets = [
            "!pulseaudio"
          ];
        };
      };
    };

    system.activationScripts.teamsForLinuxConfig.text = lib.concatStringsSep "\n" [
      "${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg cfg.user} -- ${pkgs.coreutils}/bin/install -d -m 0700 ${lib.escapeShellArg configDir}"
      "${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg cfg.user} -- ${pkgs.coreutils}/bin/install -m 0600 ${configFile} ${lib.escapeShellArg configPath}"
    ];
  };
}
