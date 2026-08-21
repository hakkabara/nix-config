{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.browsers.gecko.extensions.uBlockOrigin;

  jsonFormat = pkgs.formats.json { };

  joinLines = values: lib.concatStringsSep "\n" values;

  toManagedString =
    value:
    if builtins.isBool value then
      if value then "true" else "false"
    else if builtins.isInt value then
      toString value
    else if builtins.isString value then
      value
    else
      builtins.toJSON value;

  toManagedPairs =
    values:
    lib.mapAttrsToList (name: value: [
      name
      (toManagedString value)
    ]) values;

  effectiveAdvancedSettings =
    cfg.advancedSettings
    // lib.optionalAttrs (cfg.resourceLocations != [ ]) {
      userResourcesLocation = lib.concatStringsSep " " cfg.resourceLocations;
    };

  adminSettings = {
    inherit (cfg) hiddenSettings;

    dynamicFilteringString = joinLines cfg.dynamicFiltering;

    urlFilteringString = joinLines cfg.urlFiltering;

    hostnameSwitchesString = joinLines cfg.hostnameSwitches;
  };

  managedStorage = {
    userSettings = toManagedPairs cfg.userSettings;

    advancedSettings = toManagedPairs effectiveAdvancedSettings;

    toOverwrite = {
      filterLists = cfg.stockFilterLists ++ cfg.externalFilterLists;

      filters = cfg.userFilters;

      trustedSiteDirectives = cfg.trustedSites;
    };

    adminSettings = builtins.toJSON adminSettings;
  };
in
{
  options.hakkabara.browsers.gecko.extensions.uBlockOrigin = {
    settings.enable = lib.mkEnableOption "declarative uBlock Origin settings";

    userSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "uBlock Origin user settings.";
    };

    advancedSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };

      description = ''
        uBlock Origin advanced settings.

        Use resourceLocations instead of manually setting
        userResourcesLocation.
      '';
    };

    resourceLocations = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];

      description = ''
        uBlock Origin user-resource URLs.

        Multiple modules can append URLs. They are rendered as
        one space-separated userResourcesLocation value.
      '';
    };

    stockFilterLists = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "uBlock Origin built-in filter-list identifiers.";
    };

    externalFilterLists = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "External uBlock Origin filter-list URLs.";
    };

    hiddenSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "uBlock Origin hidden settings.";
    };

    trustedSites = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "uBlock Origin trusted-site directives.";
    };

    dynamicFiltering = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "uBlock Origin dynamic filtering rules.";
    };

    urlFiltering = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "uBlock Origin URL filtering rules.";
    };

    hostnameSwitches = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "uBlock Origin hostname switches.";
    };

    userFilters = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];

      description = ''
        Lines managed in uBlock Origin's "My filters" pane.
      '';
    };
  };

  config = lib.mkIf (config.programs.firefox.enable && cfg.enable && cfg.settings.enable) {
    assertions = [
      {
        assertion = !(cfg.advancedSettings ? userResourcesLocation);

        message = ''
          Do not set uBlockOrigin.advancedSettings.userResourcesLocation
          directly. Use uBlockOrigin.resourceLocations instead.
        '';
      }
    ];

    programs.firefox.policies."3rdparty".Extensions."uBlock0@raymondhill.net" = managedStorage;

    xdg.configFile."hakkabara/browser-exports/ublock-origin-managed-storage.json".source =
      jsonFormat.generate "ublock-origin-managed-storage.json" managedStorage;
  };
}
