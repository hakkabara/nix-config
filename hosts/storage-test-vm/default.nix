{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/storage/disko.nix
    ../../modules/nixos/virtualization/vmware.nix
  ];

  hakkabara.storage.disko = {
    enable = true;
    device = "/dev/sda";
    filesystem = "btrfs";

    partition.systemSize = "100%";

    encryption = {
      enable = true;
      allowDiscards = true;

      # Enable only after the normal LUKS password boot has been validated
      # and a YubiKey has been enrolled with systemd-cryptenroll.
      yubikey.enable = false;
    };

    btrfs.prepareForImpermanence = true;

    # Swap lives inside Btrfs and therefore inside LUKS on this test VM.
    swap = {
      enable = true;
      sizeMiB = 8192;
    };

    trim.enable = true;
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
