{
  config,
  lib,
  pkgs,
  pkgsDfir,
  ...
}:

# HackTricks (packages/hacktricks, German) served locally, like upstream's
# `docker run -p 3337:3000 ...` but from a pinned, prebuilt site: works
# offline, search included (ht_searcher.js uses the local index on localhost).
let
  cfg = config.hakkabara.services.hacktricks;

  url = "http://localhost:${toString cfg.port}/";

  launcher = pkgs.makeDesktopItem {
    name = "hacktricks";
    desktopName = "HackTricks";
    comment = "Lokales HackTricks-Wiki (Deutsch)";
    exec = "xdg-open ${url}";
    icon = "${cfg.package}/share/hacktricks/favicon.png";
    categories = [
      "Development"
      "Security"
    ];
  };
in
{
  options.hakkabara.services.hacktricks = {
    enable = lib.mkEnableOption "local HackTricks wiki";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgsDfir.hacktricks;
      defaultText = lib.literalExpression "pkgsDfir.hacktricks";
      description = "Built HackTricks site (share/hacktricks).";
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Listen address; localhost keeps the search offline-capable.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3337;
      description = "Listen port (upstream's local setup uses 3337).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.hacktricks = {
      description = "Local HackTricks wiki";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = lib.concatStringsSep " " [
          (lib.getExe pkgs.static-web-server)
          "--host ${cfg.address}"
          "--port ${toString cfg.port}"
          "--root ${cfg.package}/share/hacktricks"
          "--page404 ${cfg.package}/share/hacktricks/404.html"
          "--directory-listing false"
          "--log-level warn"
        ];
        DynamicUser = true;
        Restart = "on-failure";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
      };
    };

    environment.systemPackages = [ launcher ];
  };
}
