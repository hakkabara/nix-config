{
  config,
  lib,
  ...
}:

{
  # Keep the existing SurfVM disk layout active until this host is explicitly
  # reinstalled with Disko. This makes hakkabara.storage.disko.enable a real
  # migration switch instead of leaving conflicting filesystem declarations.
  config = lib.mkIf (!config.hakkabara.storage.disko.enable) {
    fileSystems."/" = {
      device = "/dev/disk/by-uuid/60a9d808-9611-417d-8792-68410a23d6d6";
      fsType = "ext4";
    };

    swapDevices = [
      { device = "/dev/disk/by-uuid/83389e1b-a240-45d5-bce2-336963c906e7"; }
    ];

    boot.loader.grub = {
      enable = true;
      device = "/dev/sda";
      useOSProber = true;
    };
  };
}
