{
  lib,
  ...
}:

{
  # VMware hardware baseline.
  #
  # This intentionally contains only hardware discovery information that is
  # already known to be valid for our VMware guests.
  #
  # Final WorkVM filesystem/storage declarations will be added separately
  # before the first real deployment.
  boot = {
    initrd = {
      availableKernelModules = [
        "ata_piix"
        "mptspi"
        "uhci_hcd"
        "ehci_pci"
        "ahci"
        "sd_mod"
        "sr_mod"
      ];

      kernelModules = [ ];
    };

    kernelModules = [ ];
    extraModulePackages = [ ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
