{ config, lib, ... }:

let
  cfg = config.hakkabara.git;
in
{
  options.hakkabara.git.enable = lib.mkEnableOption "shared Git configuration";

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;

      settings = {
        init.defaultBranch = "main";
        fetch.prune = true;
        push.autoSetupRemote = true;
      };
    };
  };
}
