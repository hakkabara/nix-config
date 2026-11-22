{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.apps.immich;
  withSecrets = cfg.urlFile != null && cfg.apiKeyFile != null;

  # Wrapper: the CLI reads IMMICH_INSTANCE_URL and IMMICH_API_KEY, so no
  # auth.yml with the key has to live in the home directory.
  immichWrapped = pkgs.writeShellApplication {
    name = "immich";

    text = ''
      IMMICH_INSTANCE_URL="$(<${lib.escapeShellArg cfg.urlFile})"
      IMMICH_API_KEY="$(<${lib.escapeShellArg cfg.apiKeyFile})"
      export IMMICH_INSTANCE_URL IMMICH_API_KEY
      exec ${lib.getExe' pkgs.immich-cli "immich"} "$@"
    '';
  };
in
{
  options.hakkabara.apps.immich = {
    urlFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/immich/url";
      description = "Runtime path of a file holding the Immich server URL (e.g. https://photos.example/api).";
    };

    apiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/immich/api-key";
      description = "Runtime path of a file holding an Immich API key.";
    };
  };

  config = {
    assertions = [
      {
        assertion = (cfg.urlFile == null) == (cfg.apiKeyFile == null);
        message = "hakkabara.apps.immich: set both urlFile and apiKeyFile, or neither.";
      }
    ];

    home.packages = [
      (if withSecrets then immichWrapped else pkgs.immich-cli)
    ];
  };
}
