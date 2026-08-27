{
  config,
  dms,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:

let
  cfg = config.hakkabara.desktop.dms;
in
{
  # Official upstream DankMaterialShell Home Manager module.
  imports = [
    dms.homeModules.dank-material-shell
  ];

  options.hakkabara.desktop.dms = {
    enable = lib.mkEnableOption "DankMaterialShell desktop shell";
  };

  config = lib.mkIf cfg.enable {
    programs.dank-material-shell = {
      enable = true;

      # DMS itself comes directly from the official upstream flake.
      #
      # Because the DMS flake follows our nixpkgs-unstable input, its
      # package and the rest of the fast-moving desktop stack use the
      # same pinned unstable package set.
      package = dms.packages.${pkgs.stdenv.hostPlatform.system}.dms-shell;

      # DMS upstream recommends Quickshell >= 0.3.0 and explicitly points
      # NixOS users at nixos-unstable. Keep it aligned with Niri.
      quickshell.package = pkgsUnstable.quickshell;

      # Use the upstream-supported systemd startup mechanism.
      # Niri must not additionally spawn DMS.
      systemd.enable = true;
    };
  };
}
