{
  config,
  lib,
  ...
}:

# Chromium-family browsers get the search shortcuts of the Gecko browsers as
# a SiteSearchSettings policy (Chrome/Chromium 128 and later).
#
# Source of truth is modules/home/apps/browsers/gecko/search.nix: every
# engine with a URL becomes one policy entry per alias, "@vt" in Firefox is
# "vt" (or "@vt") in Chrome. Engines that Firefox ships itself have no URL in
# that file; their Chrome counterparts are listed in builtinEngines below.
let
  cfg = config.hakkabara.browsers.managedSiteSearch;

  geckoSearch = import ../../home/apps/browsers/gecko/search.nix {
    inherit (lib.trivial) release;
  };

  builtinEngines = {
    ddg = {
      name = "DuckDuckGo";
      urls = [ { template = "https://duckduckgo.com/?q={searchTerms}"; } ];
      definedAliases = [ "@ddg" ];
    };
    google = {
      name = "Google";
      urls = [ { template = "https://www.google.com/search?q={searchTerms}"; } ];
      definedAliases = [ "@g" ];
    };
    youtube = {
      name = "YouTube";
      urls = [ { template = "https://www.youtube.com/results?search_query={searchTerms}"; } ];
      definedAliases = [ "@yt" ];
    };
    "wikipedia-de" = {
      name = "Wikipedia (de)";
      urls = [ { template = "https://de.wikipedia.org/w/index.php?search={searchTerms}"; } ];
      definedAliases = [ "@wiki" ];
    };
  };

  searchTerms = "{searchTerms}";

  toUrl =
    url:
    let
      query = lib.concatMapStringsSep "&" (
        param:
        "${param.name}=${if param.value == searchTerms then searchTerms else lib.escapeURL param.value}"
      ) (url.params or [ ]);
    in
    url.template + lib.optionalString (query != "") "?${query}";

  toEntries =
    engine:
    map (alias: {
      inherit (engine) name;
      shortcut = lib.removePrefix "@" alias;
      url = toUrl (lib.head engine.urls);
    }) engine.definedAliases;

  engines = lib.filterAttrs (_: engine: engine ? urls) (geckoSearch.engines // builtinEngines);

  # Same order as the Gecko configuration, so the policy file is stable.
  entriesFor = id: lib.optionals (engines ? ${id}) (toEntries engines.${id});
  entries = lib.concatMap entriesFor geckoSearch.order;

  policyDirs = {
    chrome = "opt/chrome/policies/managed";
    chromium = "chromium/policies/managed";
  };
in
{
  options.hakkabara.browsers.managedSiteSearch = {
    enable = lib.mkEnableOption "the Gecko search shortcuts as a Chromium SiteSearchSettings policy";

    browsers = lib.mkOption {
      type = lib.types.listOf (lib.types.enum (lib.attrNames policyDirs));
      default = [
        "chrome"
        "chromium"
      ];
      description = "Browsers whose managed policy directory gets the file.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.length entries == lib.length (lib.unique (map (entry: entry.shortcut) entries));
        message = "gecko/search.nix defines an alias twice; Chromium ignores duplicate shortcuts.";
      }
      {
        assertion = lib.all (entry: lib.hasInfix searchTerms entry.url) entries;
        message = "gecko/search.nix has an engine URL without {searchTerms}.";
      }
      {
        assertion = lib.all (id: lib.elem id geckoSearch.order) (lib.attrNames engines);
        message = "gecko/search.nix has an engine that is missing in its order list.";
      }
    ];

    environment.etc = lib.listToAttrs (
      map (
        browser:
        lib.nameValuePair "${policyDirs.${browser}}/managed-site-search.json" {
          text = builtins.toJSON { SiteSearchSettings = entries; };
        }
      ) cfg.browsers
    );
  };
}
