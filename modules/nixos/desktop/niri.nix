{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.desktop.niri;
in
{
  options.hakkabara.desktop.niri = {
    enable = lib.mkEnableOption "Niri Wayland desktop environment";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.niri;
      description = ''
        Niri package used by the native NixOS Niri module.

        This defaults to the package from the system Nixpkgs revision.
        Hosts may explicitly override it with a separately pinned package,
        such as pkgsUnstable.niri.
      '';
    };

    xwayland = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable X11 application compatibility through xwayland-satellite.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.xwayland-satellite;
        description = ''
          xwayland-satellite package exposed to the Niri session.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Keep the NixOS-provided integration for session registration,
    # portals and the compositor service. Only the package itself can
    # optionally come from another pinned Nixpkgs revision.
    programs.niri = {
      enable = true;
      inherit (cfg) package;
    };

    security.polkit.enable = true;

    # Current Niri automatically starts xwayland-satellite on demand
    # when it is available in PATH.
    environment.systemPackages = lib.optionals cfg.xwayland.enable [
      cfg.xwayland.package
    ];
  };
}
