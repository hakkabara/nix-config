{
  config,
  lib,
  pkgs,
  ...
}:

# Browsers trust an internal (company) CA, so internal HTTPS sites open
# without certificate warnings. One switch per host:
#
#   hakkabara.browsers.internalCa = {
#     enable = true;
#     sourceFile = config.sops.secrets."internal/ca".path;
#   };
#
# The source is a decrypted runtime secret: a PEM bundle with one or more CA
# certificates. Nothing of it enters the Nix store. At activation, after the
# secrets are installed, the bundle is split into /run/internal-ca (tmpfs,
# readable by the browsing user only):
#   - ca-N.crt, one certificate each, for Firefox and Floorp
#     (Certificates.Install takes one certificate per file);
#   - chromium-policy.json for Chrome and Chromium (policy CACertificates,
#     Chrome 132+), linked from their managed policy directories.
#
# Firefox and Floorp copy an installed CA into the certificate database of
# their profile (cert9.db, on disk). Chrome and Chromium keep it in memory.
# Turn `gecko.enable` off where the CA must not be stored outside the secret.
#
# With `domainsFile` (runtime file, one DNS name per line) Chrome and Chromium
# trust the CA for those names and their subdomains only
# (CACertificatesWithConstraints). Firefox has no such limit.
let
  cfg = config.hakkabara.browsers.internalCa;

  runDir = "/run/internal-ca";
  policyFile = "${runDir}/chromium-policy.json";

  policyDirs = {
    chrome = "opt/chrome/policies/managed";
    chromium = "chromium/policies/managed";
  };

  split = pkgs.writeShellApplication {
    name = "internal-ca-split";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.jq
      pkgs.openssl
    ];
    text = builtins.readFile ./internal-ca-split.sh;
  };
in
{
  options.hakkabara.browsers.internalCa = {
    enable = lib.mkEnableOption "trust in an internal CA for the browsers";

    sourceFile = lib.mkOption {
      type = lib.types.str;
      example = "/run/secrets/internal/ca";
      description = "Decrypted PEM bundle with the CA certificates (runtime path).";
    };

    domainsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/internal/ca-domains";
      description = ''
        Runtime file with one DNS name per line. When set, Chrome and Chromium
        trust the CA only for these names and their subdomains.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = config.hakkabara.accounts.primary.username;
      defaultText = lib.literalExpression "config.hakkabara.accounts.primary.username";
      description = "Browsing user; the only one who can read the split files.";
    };

    maxCertificates = lib.mkOption {
      type = lib.types.ints.between 1 16;
      default = 6;
      description = ''
        Certificate slots announced to Firefox and Floorp. Their policy is
        fixed at build time while the bundle is only known at runtime; unused
        slots are skipped by the browser, certificates beyond the limit are
        reported at activation.
      '';
    };

    gecko.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the CA in Firefox and Floorp (stored in the profile).";
    };

    chromium = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install the CA in Chrome and Chromium (policy, in memory).";
      };

      browsers = lib.mkOption {
        type = lib.types.listOf (lib.types.enum (lib.attrNames policyDirs));
        default = [
          "chrome"
          "chromium"
        ];
        description = "Browsers whose managed policy directory gets the file.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # After sops-nix installed the secrets; a missing source only warns, so a
    # host without the secret still activates.
    system.activationScripts.internalCa = {
      deps = [
        "users"
      ]
      ++ lib.optional (config.system.activationScripts ? setupSecrets) "setupSecrets";
      text = ''
        ${lib.getExe split} \
          ${lib.escapeShellArg cfg.sourceFile} \
          ${lib.escapeShellArg runDir} \
          ${lib.escapeShellArg cfg.user} \
          ${toString cfg.maxCertificates} \
          ${lib.escapeShellArg (if cfg.domainsFile == null then "" else cfg.domainsFile)} \
          || echo "internal-ca: setup failed" >&2
      '';
    };

    environment.etc = lib.mkIf cfg.chromium.enable (
      lib.listToAttrs (
        map (
          browser: lib.nameValuePair "${policyDirs.${browser}}/internal-ca.json" { source = policyFile; }
        ) cfg.chromium.browsers
      )
    );

    home-manager.users.${cfg.user}.hakkabara.browsers.gecko.certificateFiles =
      lib.mkIf cfg.gecko.enable
        (map (n: "${runDir}/ca-${toString n}.crt") (lib.range 1 cfg.maxCertificates));
  };
}
