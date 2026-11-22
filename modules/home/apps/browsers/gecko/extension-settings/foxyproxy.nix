{
  config,
  lib,
  pkgs,
  ...
}:

# Declarative FoxyProxy Standard (foxyproxy@eric.h.jung) configuration for the
# Gecko browsers, pushed through the Firefox enterprise policy
# `3rdparty.Extensions.<id>`, which Firefox exposes to the extension as
# browser.storage.managed. FoxyProxy reads managed storage at every start-up
# (since v8.2) and overwrites its settings from it; while managed, its UI is
# read-only. The managed object is the FoxyProxy export format: a top-level
# `{ mode, data }` where `data` is the non-empty proxy array.
#
# Field names verified against the FoxyProxy source (content/app.js default
# pref, content/migrate.js and content/proxy.js for proxy/pattern fields,
# content/sync.js getManaged). Pattern entries use `pattern` (string) and
# `type` ("wildcard" | "regex").
let
  cfg = config.hakkabara.browsers.gecko.extensions.foxyProxy;

  jsonFormat = pkgs.formats.json { };

  extensionId = "foxyproxy@eric.h.jung";

  managedStorage = cfg.settings.managedStorage;

  anyGeckoBrowserEnabled = config.programs.firefox.enable || config.programs.floorp.enable;
in
{
  options.hakkabara.browsers.gecko.extensions.foxyProxy.settings = {
    enable = lib.mkEnableOption "declarative FoxyProxy settings via managed storage";

    managedStorage = lib.mkOption {
      inherit (jsonFormat) type;
      default = {
        mode = "pattern";
        data = [
          {
            active = true;
            title = "sshproxy";
            type = "socks5";
            hostname = "127.0.0.1";
            port = "7779";
            username = "";
            password = "";
            cc = "";
            city = "";
            color = "#504099";
            pac = "";
            pacString = "";
            proxyDNS = true;
            tabProxy = [ ];
            include = [
              {
                active = true;
                title = "lan";
                type = "regex";
                pattern = ''^(http|ws)s?://192\.168\.\d+\.\d+([:/]|$)'';
              }
            ];
            exclude = [ ];
          }
          {
            active = true;
            title = "burp";
            type = "http";
            hostname = "127.0.0.1";
            port = "8080";
            username = "";
            password = "";
            cc = "";
            city = "";
            color = "#e68a00";
            pac = "";
            pacString = "";
            proxyDNS = true;
            tabProxy = [ ];
            include = [
              {
                active = true;
                title = "all";
                type = "wildcard";
                pattern = "*";
              }
            ];
            exclude = [ ];
          }
        ];
      };
      description = ''
        FoxyProxy managed-storage object (export format). `data` must be a
        non-empty array or FoxyProxy ignores it. In "pattern" mode the first
        matching proxy wins, so LAN (192.168.*.*) goes through sshproxy and
        everything else through burp.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.settings.enable && anyGeckoBrowserEnabled) (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = (managedStorage.data or [ ]) != [ ];
            message = "FoxyProxy managedStorage.data must be a non-empty array; FoxyProxy ignores an empty one.";
          }
        ];

        # Human-readable/debug copy of the exact managed configuration.
        xdg.configFile."hakkabara/browser-exports/foxyproxy-managed-storage.json".source =
          jsonFormat.generate "foxyproxy-managed-storage.json" managedStorage;
      }

      (lib.mkIf config.programs.firefox.enable {
        programs.firefox.policies."3rdparty".Extensions.${extensionId} = managedStorage;
      })

      (lib.mkIf config.programs.floorp.enable {
        programs.floorp.policies."3rdparty".Extensions.${extensionId} = managedStorage;
      })
    ]
  );
}
