{ config, lib, ... }:

let
  cfg = config.hakkabara.accounts.primary;
in
{
  options.hakkabara.accounts.primary = {
    enable = lib.mkEnableOption "declarative primary user password management";

    username = lib.mkOption {
      type = lib.types.str;
      description = "Existing NixOS user whose password is managed declaratively.";
    };

    password = {
      sopsFile = lib.mkOption {
        type = lib.types.path;
        description = "SOPS file containing the password hash.";
      };

      secretName = lib.mkOption {
        type = lib.types.str;
        description = "Runtime sops-nix secret name.";
      };

      key = lib.mkOption {
        type = lib.types.str;
        description = "Key inside the SOPS file containing the password hash.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Keep user passwords reproducible. Imperative passwd changes are
    # intentionally replaced by the declarative password configuration.
    users.mutableUsers = false;

    sops.secrets.${cfg.password.secretName} = {
      sopsFile = cfg.password.sopsFile;
      key = cfg.password.key;
      neededForUsers = true;
    };

    users.users.${cfg.username}.hashedPasswordFile =
      config.sops.secrets.${cfg.password.secretName}.path;
  };
}
