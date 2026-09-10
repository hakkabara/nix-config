{
  config,
  lib,
  ...
}:

{
  # Minimal bootstrap configuration for the ThinkPad T14s Gen 2.
  # Disk/filesystem layout is managed by Disko.
  #
  # After the first native boot we compare this against
  # nixos-generate-config output from the actual machine.

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "usb_storage"
    "sd_mod"
  ];

  boot.initrd.kernelModules = [ ];

  boot.kernelModules = [
    "kvm-intel"
  ];

  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware.enableRedistributableFirmware = true;

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
