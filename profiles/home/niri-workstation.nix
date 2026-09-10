{
  lib,
  ...
}:

{
  # Shared Niri/DMS user-session layer.
  #
  # Imported by:
  #   - WorkVM
  #   - Hakkapad
  #
  # Host-specific monitor/output and hardware settings remain outside.
  imports = [
    ../../modules/home/desktop/dms
    ../../modules/home/desktop/niri
  ];

  hakkabara.desktop = {
    dms.clipboardHistoryPersistence.enable = lib.mkDefault false;

    niri = {
      enable = lib.mkDefault true;
      dmsIntegration.enable = lib.mkDefault true;
    };
  };
}
