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

    xwayland.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable X11 application compatibility through xwayland-satellite.";
    };
  };

  config = lib.mkIf cfg.enable {
    # NixOS' native Niri integration provides the compositor, Wayland
    # session, systemd user integration and the recommended XDG portals.
    programs.niri.enable = true;

    # Polkit itself runs system-wide. A graphical authentication agent
    # will be provided later by the Home Manager Niri desktop module.
    security.polkit.enable = true;

    # Modern Niri automatically detects xwayland-satellite in PATH and
    # starts it on demand when an X11 client connects.
    environment.systemPackages = lib.optionals cfg.xwayland.enable [
      pkgs.xwayland-satellite
    ];
  };
}
