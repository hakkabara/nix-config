{
  config,
  lib,
  ...
}:

let
  cfg = config.hakkabara.apps.keepassxc;
in
{
  options.hakkabara.apps.keepassxc.enable = lib.mkEnableOption "KeePassXC password manager";

  config = lib.mkIf cfg.enable {
    programs.keepassxc = {
      enable = true;
      autostart = false;

      # KeePassXC is intentionally only used as a local KDBX vault viewer.
      # Do not expose it as a desktop keyring, SSH agent, or browser backend.
      settings = {
        FdoSecrets.Enabled = false;
        SSHAgent.Enabled = false;

        Browser = {
          Enabled = false;
          UpdateBinaryPath = false;
        };
      };
    };
  };
}
