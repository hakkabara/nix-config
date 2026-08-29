{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.git.githubCli;

  # Preserve the complete upstream gh package (manpages, completions, etc.)
  # while replacing only bin/gh with a small runtime authentication wrapper.
  ghWithSopsAuth = pkgs.symlinkJoin {
    name = "gh-sops-${pkgs.gh.version}";
    paths = [ pkgs.gh ];

    meta.mainProgram = "gh";

    postBuild = ''
            rm "$out/bin/gh"

            cat > "$out/bin/gh" <<'SCRIPT'
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      token_file=${lib.escapeShellArg cfg.tokenFile}

      if [[ ! -r "$token_file" ]]; then
        echo "ERROR: GitHub token is not readable: $token_file" >&2
        exit 1
      fi

      GH_TOKEN="$(${pkgs.coreutils}/bin/cat "$token_file")"

      if [[ -z "$GH_TOKEN" ]]; then
        echo "ERROR: GitHub token file is empty" >&2
        exit 1
      fi

      export GH_TOKEN
      export GH_HOST=${lib.escapeShellArg cfg.host}

      exec ${pkgs.gh}/bin/gh "$@"
      SCRIPT

            chmod +x "$out/bin/gh"
    '';
  };
in
{
  options.hakkabara.git.githubCli = {
    enable = lib.mkEnableOption "GitHub CLI with runtime SOPS authentication";

    tokenFile = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Runtime file containing the GitHub token.
        The token itself must never be included in Nix evaluation.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "github.com";
      description = "GitHub hostname used by gh.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.tokenFile != "";
        message = "hakkabara.git.githubCli.tokenFile must be configured";
      }
    ];

    programs.gh = {
      enable = true;
      package = ghWithSopsAuth;

      # Git itself authenticates independently over SSH.
      gitCredentialHelper.enable = false;

      settings = {
        git_protocol = "ssh";
      };
    };
  };
}
