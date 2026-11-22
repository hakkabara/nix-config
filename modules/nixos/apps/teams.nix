{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.apps.teams;

  appId = "com.github.IsmaelMartinez.teams_for_linux";

  # Nested option names (teams-for-linux 2.x); the old flat names are
  # deprecated upstream and scheduled for removal.
  baseSettings = {
    window.closeOnCross = false;
    appearance.followSystemTheme = true;
    tray.enabled = true;

    cacheManagement.enabled = false;

    # Off by default upstream; pinned so an update cannot turn them on.
    # They open downloads automatically, expose remote control (D-Bus,
    # MQTT), enable web debugging or submit the login form by themselves.
    download.openWhenDone = false;
    dbusControl.enabled = false;
    mqtt.enabled = false;
    development.webDebug = false;
    auth.webLogin.autoSubmit = false;
  };

  chatOnlySettings = lib.optionalAttrs cfg.chatOnly {
    notifications = {
      enabled = true;
      sound.enabled = false;
      method = "electron";
      electron.clickAction = "restore";
    };

    incomingCalls.toast = false;

    idleDetection.setAwayOnIdle = false;

    # Start in the tray; ask for the target of every download.
    window.minimized = true;

    download = {
      enabled = true;
      alwaysAskWhereToSave = true;
      notifyOnDownloadComplete = true;
      showTitlePrefix = false;
    };

    platform.spellCheckerLanguages = [
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

    filesystemAccess = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "home"
        "/data"
      ];
      description = ''
        Extra Flatpak filesystem permissions (flatpak --filesystem syntax,
        e.g. "home", "/data:ro") on top of the chat-only sandbox, for drag
        and drop from the file manager. Granting "home" lifts the default
        "!home". Everything listed is reachable by the Teams web content.
      '';
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

          filesystems =
            lib.optional (!lib.elem "home" cfg.filesystemAccess) "!home"
            ++ [
              "!xdg-run/pipewire-0"
              "xdg-download"
            ]
            ++ cfg.filesystemAccess;

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
