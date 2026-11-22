{
  config,
  lib,
  pkgs,
  ...
}:

# API keys for threat-intel and recon services from one SOPS document.
#
# Every enabled service becomes /run/secrets/api/<service>, readable only by
# `user`. On top of that, per service:
#   - envVars:   exported in interactive shells of `user` (exportToShell)
#   - homeFiles: files below the user's home that the service's CLI reads,
#                linked to the secret (e.g. ~/.config/shodan/api_key)
# and `apikey <service>` prints one key for ad-hoc use:
#   curl -H "Auth-Key: $(apikey abusech)" ...
# `apikey` without argument lists the configured services, never values.
#
# The catalogue below only names services and how their tools take a key; the
# keys themselves live in the (private) sopsFile, one YAML entry per service.
let
  cfg = config.hakkabara.apiKeys;

  secretPath = name: config.sops.secrets."api/${name}".path;

  enabled = lib.filterAttrs (_: service: service.enable) cfg.services;

  serviceType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        enable = lib.mkEnableOption "the ${name} API key";

        key = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Entry in the SOPS document holding this key.";
        };

        description = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "What the key is for (shown by `apikey`).";
        };

        envVars = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Environment variables set to the key in interactive shells (exportToShell).";
        };

        fileEnvVars = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Environment variables set to the key's file path (always; no secret in it).";
        };

        mode = lib.mkOption {
          type = lib.types.str;
          default = "0400";
          description = "Mode of the secret file (some CLIs insist on 0600).";
        };

        homeFiles = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Paths relative to the user's home linked to the key file.";
        };
      };
    }
  );

  apikey = pkgs.writeShellApplication {
    name = "apikey";
    text = ''
      dir=/run/secrets/api
      if [ "$#" -eq 0 ]; then
        echo "Konfigurierte API-Keys (Werte: apikey <dienst>):"
        ${lib.concatMapStrings (
          name:
          let
            service = enabled.${name};
          in
          ''
            printf '  %-16s %s\n' ${lib.escapeShellArg name} ${lib.escapeShellArg service.description}
          ''
        ) (lib.attrNames enabled)}
        exit 0
      fi
      file="$dir/$1"
      if [ ! -r "$file" ]; then
        echo "apikey: kein lesbarer Key für '$1' ($file)" >&2
        exit 1
      fi
      if [ ! -s "$file" ]; then
        echo "apikey: Key für '$1' ist leer (noch nicht eingetragen)" >&2
        exit 1
      fi
      cat "$file"
    '';
  };

  exportLines = lib.concatStrings (
    lib.mapAttrsToList (
      name: service:
      lib.concatMapStrings (var: ''
        if [ -r ${secretPath name} ] && [ -s ${secretPath name} ]; then export ${var}="$(< ${secretPath name})"; fi
      '') service.envVars
    ) enabled
  );
in
{
  options.hakkabara.apiKeys = {
    enable = lib.mkEnableOption "API keys from SOPS for threat-intel CLIs";

    user = lib.mkOption {
      type = lib.types.str;
      description = "Account that owns and uses the keys.";
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "SOPS YAML document with one entry per service.";
    };

    exportToShell = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Export every service's envVars in interactive shells of `user`. Handy,
        but every process started from such a shell inherits all keys.
      '';
    };

    services = lib.mkOption {
      type = lib.types.attrsOf serviceType;
      default = { };
      description = "Services by name; enable the ones the sopsFile holds.";
    };
  };

  # Known services and how their tools take a key (checked 2026-11-22). A host
  # enables the ones its sopsFile holds.
  config = lib.mkMerge [
    {
      hakkabara.apiKeys.services = {
        abuseipdb = {
          description = "AbuseIPDB (abuseipdb-check)";
          # The tool reads ABUSEIPDB_API_KEY (comma-separated for rotation); its
          # wrapper also reads ABUSEIPDB_API_KEY_FILE, one key per line.
          envVars = [ "ABUSEIPDB_API_KEY" ];
          fileEnvVars = [ "ABUSEIPDB_API_KEY_FILE" ];
        };
        abusech = {
          description = "abuse.ch Auth-Key (MalwareBazaar, ThreatFox, URLhaus)";
          # Header Auth-Key; the export downloads take it in the URL path.
          # No tool convention for a variable; the name is our own.
          envVars = [ "ABUSECH_AUTH_KEY" ];
        };
        censys-api-id = {
          description = "Censys Legacy Search API ID (censys CLI 2.x, deprecated)";
          envVars = [ "CENSYS_API_ID" ];
        };
        censys-api-secret = {
          description = "Censys Legacy Search API Secret (censys CLI 2.x, deprecated)";
          envVars = [ "CENSYS_API_SECRET" ];
        };
        censys-platform = {
          description = "Censys Platform personal access token (Bearer)";
          # cencli/censys-platform document no token variable; the name is our own.
          envVars = [ "CENSYS_PLATFORM_TOKEN" ];
        };
        greynoise = {
          description = "GreyNoise (greynoise CLI)";
          envVars = [ "GREYNOISE_API_KEY" ];
        };
        securitytrails = {
          description = "SecurityTrails (header APIKEY)";
          envVars = [ "SECURITYTRAILS_API_KEY" ];
        };
        shodan = {
          description = "Shodan (shodan CLI)";
          # The CLI reads no variable, only this file, and chmods it to 0600.
          homeFiles = [ ".config/shodan/api_key" ];
          mode = "0600";
          envVars = [ "SHODAN_API_KEY" ];
        };
        urlscan = {
          description = "urlscan.io (urlscan-cli, header API-Key)";
          envVars = [ "URLSCAN_API_KEY" ];
        };
        virustotal = {
          description = "VirusTotal (vt CLI)";
          envVars = [ "VTCLI_APIKEY" ];
        };
      };
    }

    (lib.mkIf cfg.enable {
      sops.secrets = lib.mapAttrs' (
        name: service:
        lib.nameValuePair "api/${name}" {
          inherit (cfg) sopsFile;
          inherit (service) key;
          owner = cfg.user;
          inherit (service) mode;
        }
      ) enabled;

      environment = {
        systemPackages = [ apikey ];

        # Shell-independent; other users cannot read the files, so for them
        # every line is a no-op.
        interactiveShellInit = lib.mkIf cfg.exportToShell exportLines;

        variables = lib.listToAttrs (
          lib.concatLists (
            lib.mapAttrsToList (
              name: service: map (var: lib.nameValuePair var (secretPath name)) service.fileEnvVars
            ) enabled
          )
        );
      };

      home-manager.users.${cfg.user} =
        { config, ... }:
        {
          home.file = lib.listToAttrs (
            lib.concatLists (
              lib.mapAttrsToList (
                name: service:
                map (
                  path: lib.nameValuePair path { source = config.lib.file.mkOutOfStoreSymlink (secretPath name); }
                ) service.homeFiles
              ) enabled
            )
          );
        };
    })
  ];
}
