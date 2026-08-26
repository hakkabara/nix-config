{ lib, ... }:

{
  # Reuse the complete real SurfVM configuration.
  imports = [
    ../surf-vm
  ];

  # Keep this installation distinguishable from the real SurfVM.
  networking.hostName = lib.mkForce "surf-vm-disko-test";

  # Fresh-install storage override.
  hakkabara.storage.disko = {
    enable = lib.mkForce true;
    filesystem = lib.mkForce "btrfs";

    partition.systemSize = lib.mkForce "100%";

    encryption = {
      enable = lib.mkForce true;

      # nixos-anywhere uploads this temporary file only for Disko.
      installPasswordFile = lib.mkForce "/tmp/disko-luks-password";

      # First full-system installation is tested with the normal
      # LUKS password. FIDO2 enrollment happens afterwards.
      yubikey.enable = lib.mkForce false;
    };

    btrfs.prepareForImpermanence = lib.mkForce true;
  };

  # Do not automatically bring up the SurfVM VPN manager on the
  # temporary clone. The WireGuard profiles remain available.
  systemd.services.homelab-vpn-manager.wantedBy = lib.mkForce [ ];
}
