{ config, lib, ... }:

let
  cfg = config.hakkabara.git;
in
{
  config = lib.mkIf cfg.enable {
    programs.git.settings.user = {
      name = "hakkabara";
      email = "hakkabara@outlook.de";
    };

    programs.git.settings = {
      url."git@github.com:hakkabara/".insteadOf = "https://github.com/hakkabara/";
    };
  };
}
