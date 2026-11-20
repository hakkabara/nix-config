{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.ai;

  omc = pkgs.buildNpmPackage {
    pname = "oh-my-claudecode";
    version = "5.8.6";

    src = pkgs.fetchzip {
      url = "https://github.com/Yeachan-Heo/oh-my-claudecode/archive/refs/tags/v5.8.6.tar.gz";
      hash = "sha256-OhKIlTH5gl+qXGI1K+5jSIvHUcawel5xwoKTum+g9f4=";
    };

    npmDepsHash = "sha256-bK4yldreVBtKxLpWGHdBW6ZeyAfSCNYlDQnyKrzUOtw=";

    nodejs = pkgs.nodejs_22;

    nativeBuildInputs = [
      pkgs.python3
      pkgs.pkg-config
    ];

    # Upstream defines prepack = "npm run build".
    # buildNpmPackage already runs the build phase, so do not rebuild
    # everything again while npm determines the package contents.
    npmPackFlags = [
      "--ignore-scripts"
    ];

    meta = {
      description = "Multi-agent orchestration system for Claude Code";
      homepage = "https://github.com/Yeachan-Heo/oh-my-claudecode";
      license = lib.licenses.mit;
      mainProgram = "omc";
      platforms = lib.platforms.linux;
    };
  };
in
{
  options.hakkabara.ai.claude.omc.enable = lib.mkEnableOption "Oh My Claude Code CLI runtime";

  config = lib.mkIf (cfg.enable && cfg.claude.enable && cfg.claude.omc.enable) {
    home.packages = [
      omc
    ];
  };
}
