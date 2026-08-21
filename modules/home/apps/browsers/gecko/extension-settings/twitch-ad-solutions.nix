{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.browsers.gecko.extensions.twitchAdSolutions;

  extensions = config.hakkabara.browsers.gecko.extensions;

  jsonFormat = pkgs.formats.json { };

  solutionPaths = {
    vaft = {
      ublock = "vaft/vaft-ublock-origin.js";

      userscript = "vaft/vaft.user.js";
    };

    "video-swap-new" = {
      ublock = "video-swap-new/video-swap-new-ublock-origin.js";

      userscript = "video-swap-new/video-swap-new.user.js";
    };
  };

  rawBaseUrl = "https://raw.githubusercontent.com/" + cfg.repository + "/" + cfg.revision + "/";

  selectedUblockUrl = rawBaseUrl + solutionPaths.${cfg.solution}.ublock;

  selectedUserscriptUrl = rawBaseUrl + solutionPaths.${cfg.solution}.userscript;

  runtimeValues = {
    reloadPlayerAfterAd = cfg.runtime.reloadPlayerAfterAd;

    playerType = cfg.runtime.playerType;

    hideAdOverlay = cfg.runtime.hideAdOverlay;

    pinBackupPlayerType = cfg.runtime.pinBackupPlayerType;

    reloadCooldownSeconds = cfg.runtime.reloadCooldownSeconds;

    disableReloadCap = cfg.runtime.disableReloadCap;

    preferLowQualityBackup = cfg.runtime.preferLowQualityBackup;

    backupSwapFirst = cfg.runtime.backupSwapFirst;
  };

  renderRuntimeSetting =
    name: value:
    let
      key = "twitchAdSolutions_${name}";

      stringValue = if builtins.isBool value then if value then "true" else "false" else toString value;
    in
    if value == null then
      "localStorage.removeItem(${builtins.toJSON key});"
    else
      "localStorage.setItem(${builtins.toJSON key}, ${builtins.toJSON stringValue});";

  renderedRuntime = lib.concatStringsSep "\n  " (
    lib.mapAttrsToList renderRuntimeSetting runtimeValues
  );

  runtimeUserscript = ''
    // ==UserScript==
    // @name         TwitchAdSolutions Configuration
    // @namespace    hakkabara.nix-config
    // @version      1
    // @description  Declarative TwitchAdSolutions runtime configuration
    // @match        https://www.twitch.tv/*
    // @run-at       document-start
    // @grant        none
    // ==/UserScript==

    (() => {
      'use strict';

      ${renderedRuntime}
    })();
  '';

  auditData = {
    inherit (cfg)
      delivery
      repository
      revision
      solution
      ;

    ublock = {
      selected = cfg.delivery == "ublock";

      resourceUrl = selectedUblockUrl;

      filter = "twitch.tv##+js(twitch-videoad)";
    };

    userscript = {
      selected = cfg.delivery == "userscript";

      installUrl = selectedUserscriptUrl;
    };

    runtimeConfig = {
      enabled = cfg.runtimeConfig.enable;

      runtime = runtimeValues;
    };
  };
in
{
  options.hakkabara.browsers.gecko.extensions.twitchAdSolutions = {
    enable = lib.mkEnableOption "TwitchAdSolutions integration";

    solution = lib.mkOption {
      type = lib.types.enum [
        "vaft"
        "video-swap-new"
      ];

      default = "vaft";

      description = ''
        TwitchAdSolutions implementation.

        VAFT is the preferred implementation.
      '';
    };

    delivery = lib.mkOption {
      type = lib.types.enum [
        "ublock"
        "userscript"
      ];

      default = "ublock";

      description = ''
        Delivery backend for TwitchAdSolutions.

        ublock:
          Configure the selected solution through uBlock Origin.

        userscript:
          Use the pinned upstream userscript with Violentmonkey.
      '';
    };

    repository = lib.mkOption {
      type = lib.types.str;
      default = "ryanbr/TwitchAdSolutions";
      description = "GitHub repository containing TwitchAdSolutions.";
    };

    revision = lib.mkOption {
      type = lib.types.str;

      default = "232c5e95f915ccf59eac175044bb19ad24f84227";

      description = ''
        Pinned TwitchAdSolutions Git revision.
      '';
    };

    runtimeConfig.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;

      description = ''
        Generate a Violentmonkey userscript which maintains the
        TwitchAdSolutions localStorage runtime configuration.
      '';
    };

    runtime = {
      reloadPlayerAfterAd = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
      };

      playerType = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "popout"
            "embed"
            "site"
            "autoplay"
          ]
        );

        default = null;
      };

      hideAdOverlay = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
      };

      pinBackupPlayerType = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
      };

      reloadCooldownSeconds = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
      };

      disableReloadCap = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
      };

      preferLowQualityBackup = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
      };

      backupSwapFirst = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = builtins.match "^[0-9a-f]{40}$" cfg.revision != null;

          message = ''
            TwitchAdSolutions revision must be a pinned
            40-character lowercase Git commit SHA.
          '';
        }

        {
          assertion = cfg.runtime.reloadCooldownSeconds == null || cfg.runtime.reloadCooldownSeconds >= 0;

          message = ''
            TwitchAdSolutions reloadCooldownSeconds must be
            null or greater than/equal to zero.
          '';
        }

        {
          assertion =
            cfg.delivery != "ublock"
            || (extensions.uBlockOrigin.enable && extensions.uBlockOrigin.settings.enable);

          message = ''
            TwitchAdSolutions delivery = "ublock" requires both:

              uBlockOrigin.enable = true;
              uBlockOrigin.settings.enable = true;
          '';
        }

        {
          assertion = cfg.delivery != "userscript" || extensions.violentmonkey.enable;

          message = ''
            TwitchAdSolutions delivery = "userscript" requires
            Violentmonkey to be enabled.
          '';
        }

        {
          assertion = !cfg.runtimeConfig.enable || extensions.violentmonkey.enable;

          message = ''
            TwitchAdSolutions runtimeConfig.enable requires
            Violentmonkey to be enabled.
          '';
        }
      ];

      xdg.configFile."hakkabara/browser-exports/twitch-ad-solutions.json".source =
        jsonFormat.generate "twitch-ad-solutions.json" auditData;
    })

    # ----------------------------------------------------------
    # uBlock delivery
    # ----------------------------------------------------------

    (lib.mkIf (cfg.enable && cfg.delivery == "ublock") {
      hakkabara.browsers.gecko.extensions.uBlockOrigin = {
        userFilters = lib.mkAfter [
          "twitch.tv##+js(twitch-videoad)"
        ];

        resourceLocations = lib.mkAfter [
          selectedUblockUrl
        ];
      };
    })

    # ----------------------------------------------------------
    # Userscript delivery
    #
    # We deliberately do NOT download/execute remote JavaScript
    # during Nix evaluation.
    #
    # Instead we produce the immutable pinned install URL.
    # Violentmonkey can install that exact upstream userscript.
    # ----------------------------------------------------------

    (lib.mkIf (cfg.enable && cfg.delivery == "userscript") {
      xdg.configFile."hakkabara/browser-userscripts/twitch-ad-solutions-install-url.txt".text =
        selectedUserscriptUrl + "\n";
    })

    # ----------------------------------------------------------
    # Runtime/localStorage configuration
    # ----------------------------------------------------------

    (lib.mkIf (cfg.enable && cfg.runtimeConfig.enable) {
      xdg.configFile."hakkabara/browser-userscripts/twitch-ad-solutions-config.user.js".text =
        runtimeUserscript;
    })
  ];
}
