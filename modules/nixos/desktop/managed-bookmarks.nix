{
  config,
  lib,
  pkgs,
  ...
}:

# Chromium-family browsers get the same bookmark document the Gecko browsers
# read, as a read-only ManagedBookmarks folder in the bookmarks bar.
#
# The source is a decrypted runtime secret (for example sops-nix
# /run/secrets/browser/bookmarks), so the policy is generated at activation,
# after the secrets are installed, into /run and linked from /etc. Nothing of
# the bookmark content enters the Nix store.
#
# The policy file must be readable by the browsing user, so every local user
# can read the bookmark URLs. Fine for single-user workstations.
let
  cfg = config.hakkabara.browsers.managedBookmarks;

  policyFile = "/run/managed-bookmarks/policy.json";

  converter = pkgs.writeShellApplication {
    name = "browser-bookmarks-policy";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${../../home/apps/browsers/scripts/browser-bookmarks.py} chrome-policy "$@"
    '';
  };

  policyDirs = {
    chrome = "opt/chrome/policies/managed";
    chromium = "chromium/policies/managed";
  };
in
{
  options.hakkabara.browsers.managedBookmarks = {
    enable = lib.mkEnableOption "bookmarks as a Chromium ManagedBookmarks policy";

    sourceFile = lib.mkOption {
      type = lib.types.str;
      example = "/run/secrets/browser/bookmarks";
      description = "Decrypted Netscape bookmark document (runtime path).";
    };

    folderName = lib.mkOption {
      type = lib.types.str;
      default = "Bookmarks";
      description = "Name of the managed folder in the bookmarks bar.";
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

  config = lib.mkIf cfg.enable {
    # After sops-nix installed the secrets; a missing source only warns, so a
    # host without the secret still activates.
    system.activationScripts.managedBookmarks = {
      deps = lib.optional (config.system.activationScripts ? setupSecrets) "setupSecrets";
      text = ''
        if [ -r ${lib.escapeShellArg cfg.sourceFile} ]; then
          ${lib.getExe converter} ${lib.escapeShellArg cfg.sourceFile} ${policyFile} \
            --toplevel-name ${lib.escapeShellArg cfg.folderName} \
            || echo "managed-bookmarks: policy generation failed" >&2
        else
          echo "managed-bookmarks: ${cfg.sourceFile} missing, no policy" >&2
        fi
      '';
    };

    environment.etc = lib.listToAttrs (
      map (
        browser:
        lib.nameValuePair "${policyDirs.${browser}}/managed-bookmarks.json" { source = policyFile; }
      ) cfg.browsers
    );
  };
}
