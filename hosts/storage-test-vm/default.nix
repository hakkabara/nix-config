{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/storage/disko-btrfs-luks.nix
    ../../modules/nixos/virtualization/vmware.nix
  ];

  hakkabara.storage.disko = {
    enable = true;
    device = "/dev/sda";
    allowDiscards = true;

    # Swap lives inside the LUKS-encrypted Btrfs filesystem.
    swap = {
      enable = true;
      size = "8G";
    };
  };

  networking = {
    hostName = "storage-test-vm";
    networkmanager.enable = true;
  };

  # Disposable test VM: console autologin makes post-install verification easy
  # without committing a test password to Git.
  users.users.hakkabara = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };
  services.getty.autologinUser = "hakkabara";
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    btrfs-progs
    cryptsetup
    git
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "26.05";
}
