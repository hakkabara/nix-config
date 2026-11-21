{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.ai;
  codeCfg = cfg.claude.code;
  tokenCfg = codeCfg.oauthToken;
  isoCfg = codeCfg.isolation;

  # Path lists may start with "~"; they are expanded at runtime, so they
  # travel as files instead of shell variables.
  listFile = name: items: pkgs.writeText "claude-${name}" (lib.concatLines items);
  orEmpty = value: if value == null then "" else value;

  # Managed settings inside the sandbox. They rank above every user and
  # project setting, so nothing Claude writes into the project can relax them.
  basePolicy = lib.recursiveUpdate isoCfg.policy isoCfg.extraPolicy;

  # Without command execution Claude can still read, answer and write files
  # into the project, but no tool runs anything.
  executionDeny = lib.optionals (!isoCfg.allowCommands) [
    "Bash"
    "Monitor"
  ];

  policyFile = pkgs.writeText "claude-code-managed-settings.json" (
    builtins.toJSON (
      lib.recursiveUpdate basePolicy {
        permissions.deny = (basePolicy.permissions.deny or [ ]) ++ executionDeny;
      }
    )
  );

  launcher = pkgs.writeShellApplication {
    name = "claude";

    runtimeInputs = [
      pkgs.coreutils
    ];

    runtimeEnv = {
      CLAUDE_REAL = lib.getExe codeCfg.package;
      TOKEN_FILE = orEmpty tokenCfg.file;
      EXPIRES_FILE = orEmpty tokenCfg.expiresFile;
      ISOLATE = if isoCfg.enable then "1" else "0";
      BWRAP = lib.getExe pkgs.bubblewrap;
      POLICY_FILE = policyFile;
      PROJECT_ROOTS_FILE = listFile "project-roots" isoCfg.projectRoots;
      RO_PATHS_FILE = listFile "read-only-paths" isoCfg.readOnlyPaths;
      RW_PATHS_FILE = listFile "read-write-paths" isoCfg.readWritePaths;
      PASS_ENV_FILE = listFile "pass-env" isoCfg.passEnv;
    };

    text = builtins.readFile ./launcher.sh;
  };

  # Same package, but bin/claude is the launcher above.
  wrapped = pkgs.symlinkJoin {
    name = "claude-code-launcher-${codeCfg.package.version}";
    paths = [ codeCfg.package ];

    postBuild = ''
      rm "$out/bin/claude"
      ln -s ${lib.getExe launcher} "$out/bin/claude"
    '';

    inherit (codeCfg.package) meta;
  };

  needsLauncher = tokenCfg.file != null || isoCfg.enable;
in
{
  options.hakkabara.ai.claude.code = {
    enable = lib.mkEnableOption "Claude Code CLI";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.claude-code;
      defaultText = lib.literalExpression "pkgs.claude-code";
      description = ''
        Claude Code package. The API rejects clients that are too old, so
        hosts on a stable channel may need a newer one from unstable.
      '';
    };

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

    isolation = {
      enable = lib.mkEnableOption ''
        an allowlist sandbox for Claude Code. It runs in bubblewrap and sees
        only the Nix store, a filtered /etc, the current project, its own
        state (~/.claude, ~/.claude.json) and the paths listed below. Every
        command it runs inherits that view
      '';

      projectRoots = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "~/projects" ];
        example = [
          "~/projects"
          "~/nix-config"
        ];
        description = ''
          Directories in which claude may be started, including their
          subdirectories. Anywhere else it refuses to start. The start
          directory becomes the only writable project path.
        '';
      };

      readOnlyPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "~/.gitconfig"
          "~/.config/git"
        ];
        description = "Additional paths visible read-only; missing ones are skipped.";
      };

      readWritePaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional paths visible read-write; missing ones are skipped.";
      };

      allowCommands = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether Claude may run shell commands (Bash and Monitor tools).
          When false, it can still read the project, answer questions and
          write files such as scripts, which you review and run yourself.
        '';
      };

      passEnv = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "EDITOR" ];
        description = ''
          Environment variables passed into the sandbox in addition to a
          minimal set (HOME, USER, PATH, TERM, locale, TZ and the token).
          Everything else is removed.
        '';
      };

      policy = lib.mkOption {
        type = lib.types.attrs;
        default = {
          permissions = {
            # File tools refuse to touch anything outside the project, in
            # every mode.
            blockReadsOutsideWorkingDirectories = true;
            blockWritesOutsideWorkingDirectories = true;

            # No --dangerously-skip-permissions.
            disableBypassPermissionsMode = "disable";

            # Typical secrets that may still sit inside a project.
            deny = [
              "Read(**/.env)"
              "Read(**/.env.*)"
              "Read(**/*.pem)"
              "Read(**/*.key)"
              "Read(**/id_rsa*)"
              "Read(**/id_ed25519*)"
              "Read(**/*.kdbx)"
            ];
          };
        };
        description = ''
          Claude Code managed settings applied inside the sandbox. The default
          keeps file tools inside the project, forbids bypass mode and denies
          reading common secret files.
        '';
      };

      extraPolicy = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Merged recursively over policy.";
      };
    };
  };

  config = lib.mkIf (cfg.enable && cfg.claude.enable && codeCfg.enable) {
    home.packages = [
      (if needsLauncher then wrapped else codeCfg.package)
    ];

    # Make sure the allowed project roots exist.
    home.activation.claudeProjectRoots = lib.mkIf isoCfg.enable (
      lib.hm.dag.entryAfter [ "writeBoundary" ] (
        lib.concatMapStrings (root: ''
          mkdir -p ${
            if lib.hasPrefix "~/" root then
              ''"$HOME"/${lib.escapeShellArg (lib.removePrefix "~/" root)}''
            else
              lib.escapeShellArg root
          }
        '') isoCfg.projectRoots
      )
    );
  };
}
