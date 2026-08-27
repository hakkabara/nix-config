{ lib, ... }:

{
  imports = [
    ./workstation-base.nix

    ../../modules/home/desktop/niri
    ../../modules/home/desktop/dms
  ];

  # WorkVM desktop baseline.
  #
  # Niri and DMS implementation details live in reusable modules.
  # WorkVM-specific applications and customer tooling will remain in
  # separate profiles/modules.
  hakkabara.desktop = {
    niri = {
      enable = lib.mkDefault true;
      dmsIntegration.enable = lib.mkDefault true;
    };

    dms.enable = lib.mkDefault true;
  };
}
