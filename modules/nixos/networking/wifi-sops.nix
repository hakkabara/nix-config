{
  config,
  lib,
  ...
}:

let
  cfg = config.hakkabara.networking.wifiSops;

  mkSecrets = name: [
    {
      name = "wifi/${name}/ssid";
      value = {
        inherit (cfg) sopsFile;
        key = "wifi/${name}/ssid";

        owner = "root";
        group = "root";
        mode = "0400";
      };
    }

    {
      name = "wifi/${name}/password";
      value = {
        inherit (cfg) sopsFile;
        key = "wifi/${name}/password";

        owner = "root";
        group = "root";
        mode = "0400";
      };
    }
  ];

  mkEnvironment =
    name:
    let
      upper = lib.toUpper name;
    in
    ''
      ${upper}_SSID="${config.sops.placeholder."wifi/${name}/ssid"}"
      ${upper}_PASSWORD="${config.sops.placeholder."wifi/${name}/password"}"
    '';

  mkProfile =
    name:
    let
      upper = lib.toUpper name;
    in
    {
      connection = {
        # Keep the real network name out of the Nix store.
        # envsubst replaces this only in the runtime keyfile.
        id = "$" + upper + "_SSID";
        type = "wifi";
        autoconnect = true;
        permissions = "";
      };

      wifi = {
        mode = "infrastructure";
        ssid = "$" + upper + "_SSID";
      };

      wifi-security = {
        key-mgmt = "wpa-psk";
        psk = "$" + upper + "_PASSWORD";
      };

      ipv4 = {
        method = "auto";
      };

      ipv6 = {
        method = "auto";
        addr-gen-mode = "stable-privacy";
      };
    };
in
{
  options.hakkabara.networking.wifiSops = {
    enable = lib.mkEnableOption "SOPS-backed NetworkManager WiFi profiles";

    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "SOPS YAML file containing WiFi SSIDs and passwords.";
    };

    networks = lib.mkOption {
      type = lib.types.listOf lib.types.str;

      default = [ ];

      example = [
        "wifi1"
        "wifi2"
      ];

      description = "Neutral WiFi profile identifiers.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.networks != [ ];
        message = "wifiSops.networks must contain at least one WiFi profile.";
      }

      {
        assertion = lib.length cfg.networks == lib.length (lib.unique cfg.networks);

        message = "wifiSops.networks must not contain duplicates.";
      }
    ];

    sops.secrets = lib.listToAttrs (lib.concatMap mkSecrets cfg.networks);

    # This file is rendered by sops-nix under /run.
    # The actual SSIDs/passwords therefore never become Nix store strings.
    sops.templates."networkmanager-wifi.env" = {
      content = lib.concatMapStringsSep "\n" mkEnvironment cfg.networks;

      owner = "root";
      group = "root";
      mode = "0400";

      restartUnits = [
        "NetworkManager-ensure-profiles.service"
      ];
    };

    networking.networkmanager.ensureProfiles = {
      environmentFiles = [
        config.sops.templates."networkmanager-wifi.env".path
      ];

      profiles = lib.genAttrs cfg.networks mkProfile;
    };
  };
}
