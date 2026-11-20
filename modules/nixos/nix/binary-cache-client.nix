{
  config,
  lib,
  ...
}:

let
  cfg = config.hakkabara.nix.binaryCache;

  publicKey =
    if cfg.publicKeyFile == null then
      ""
    else
      lib.removeSuffix "\n" (builtins.readFile cfg.publicKeyFile);
in
{
  options.hakkabara.nix.binaryCache = {
    enable = lib.mkEnableOption "private Nix binary cache client";

    url = lib.mkOption {
      type = lib.types.str;
      example = "http://192.168.245.10:5000";
      description = "URL of the private Nix binary cache.";
    };

    publicKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "File containing the public binary-cache signing key.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.publicKeyFile != null;
        message = ''
          hakkabara.nix.binaryCache.publicKeyFile must be set.
        '';
      }

      {
        assertion = publicKey != "";
        message = ''
          hakkabara.nix.binaryCache public key must not be empty.
        '';
      }
    ];

    # Use the Nix "extra-" settings rather than replacing the standard
    # substituters. This keeps cache.nixos.org available as the normal
    # public fallback.
    nix.settings = {
      extra-substituters = [
        cfg.url
      ];

      extra-trusted-public-keys = [
        publicKey
      ];
    };
  };
}
