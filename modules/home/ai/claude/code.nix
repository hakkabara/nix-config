{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.ai;
  tokenCfg = cfg.claude.code.oauthToken;

  # Thirty days before expiry the wrapper starts to warn on every start.
  warnSeconds = 30 * 24 * 60 * 60;

  readToken = ''
    if [ -z "''${CLAUDE_CODE_OAUTH_TOKEN-}" ] && [ -r ${lib.escapeShellArg tokenCfg.file} ]; then
      CLAUDE_CODE_OAUTH_TOKEN="$(<${lib.escapeShellArg tokenCfg.file})"
      export CLAUDE_CODE_OAUTH_TOKEN
    fi
  '';

  warnExpiry = lib.optionalString (tokenCfg.expiresFile != null) ''
    if [ -r ${lib.escapeShellArg tokenCfg.expiresFile} ]; then
      expires="$(<${lib.escapeShellArg tokenCfg.expiresFile})"
      if expires_at="$(${pkgs.coreutils}/bin/date -d "$expires" +%s 2>/dev/null)" &&
        [ "$(${pkgs.coreutils}/bin/date +%s)" -gt "$((expires_at - ${toString warnSeconds}))" ]; then
        echo "warning: Claude subscription token expires on $expires; renew it with 'claude setup-token'." >&2
      fi
    fi
  '';

  # Same package, but bin/claude loads the token for its own process only.
  # Shells, IDEs and other programs never see it in their environment.
  claudeWithToken = pkgs.symlinkJoin {
    name = "claude-code-with-token-${pkgs.claude-code.version}";
    paths = [ pkgs.claude-code ];
    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      rm "$out/bin/claude"
      makeWrapper ${lib.getExe pkgs.claude-code} "$out/bin/claude" \
        --run ${lib.escapeShellArg (readToken + warnExpiry)}
    '';

    inherit (pkgs.claude-code) meta;
  };
in
{
  options.hakkabara.ai.claude.code = {
    enable = lib.mkEnableOption "Claude Code CLI";

    oauthToken = {
      file = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/run/secrets/claude/oauth-token";
        description = ''
          Runtime path of a file holding a long-lived subscription token
          created with `claude setup-token`. The claude command then reads it
          into CLAUDE_CODE_OAUTH_TOKEN for its own process, so no /login is
          needed and usage stays on the subscription. An already exported
          CLAUDE_CODE_OAUTH_TOKEN wins. The token never enters the store.
        '';
      };

      expiresFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/run/secrets/claude/oauth-token-expires";
        description = ''
          Runtime path of a file holding the token's expiry date
          (YYYY-MM-DD). Claude warns on start during the last 30 days.
        '';
      };
    };
  };

  config = lib.mkIf (cfg.enable && cfg.claude.enable && cfg.claude.code.enable) {
    home.packages = [
      (if tokenCfg.file == null then pkgs.claude-code else claudeWithToken)
    ];
  };
}
