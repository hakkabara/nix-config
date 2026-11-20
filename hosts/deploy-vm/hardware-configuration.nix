{
  lib,
  ...
}:

{
  # VMware hardware baseline.
  #
  # Keep the file host-local even though our VMware guests currently share
  # the same virtual hardware. This lets the DeployVM diverge later without
  # coupling its hardware definition to another host.
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
