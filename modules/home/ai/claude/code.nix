{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.ai;
in
{
  options.hakkabara.ai.claude.code.enable =
    lib.mkEnableOption "Claude Code CLI";

  config = lib.mkIf (
    cfg.enable
    && cfg.claude.enable
    && cfg.claude.code.enable
  ) {
    home.packages = [
      pkgs.claude-code
    ];
  };
}
