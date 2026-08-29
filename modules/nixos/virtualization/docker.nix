{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.virtualization.docker;
in
{
  options.hakkabara.virtualization.docker = {
    enable = lib.mkEnableOption "Docker container runtime";

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "mko" ];
      description = ''
        Users that may access the rootful Docker daemon without sudo.

        Membership in the docker group is effectively root-equivalent.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      enableOnBoot = true;
      extraPackages = [ pkgs.nftables ];
    };

    users.users = lib.genAttrs cfg.users (_: {
      extraGroups = [ "docker" ];
    });
  };
}
