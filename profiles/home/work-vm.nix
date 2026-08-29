{
  lib,
  ...
}:

{
  imports = [
    ./workstation-base.nix
    ../../modules/home/desktop/niri
  ];

  hakkabara.apps = {
    obsidian.enable = lib.mkDefault true;
    signal.enable = lib.mkDefault true;
  };

  # WorkVM Wayland compositor configuration.
  #
  # DMS itself is intentionally configured at the NixOS level through the
  # native programs.dms-shell module available in NixOS 26.05.
  hakkabara.desktop.niri = {
    enable = lib.mkDefault true;

    # Keep DMS IPC shortcuts in the generated Niri configuration.
    dmsIntegration.enable = lib.mkDefault true;
  };
}
