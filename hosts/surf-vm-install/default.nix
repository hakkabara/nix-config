{ lib, ... }:

{
  # Reuse the complete real SurfVM configuration.
  imports = [
    ../surf-vm
  ];

  # Fresh-install storage configuration.
  hakkabara.storage.disko = {
    enable = lib.mkForce true;
    filesystem = lib.mkForce "btrfs";

    partition.systemSize = lib.mkForce "100%";

    encryption = {
      enable = lib.mkForce true;

      # nixos-anywhere uploads this temporary password file before Disko runs.
      installPasswordFile = lib.mkForce "/tmp/disko-luks-password";

      # First boot uses the normal LUKS password.
      # FIDO2 is enrolled and enabled after the baseline boot succeeds.
      yubikey.enable = lib.mkForce false;
    };

    btrfs.prepareForImpermanence = lib.mkForce true;
  };

  # Remote unlock is enabled only after the normal encrypted boot works.
  hakkabara.security.remoteUnlock.enable = lib.mkForce false;

  # The old SurfVM can still be online during installation.
  # Avoid bringing up a cloned WireGuard identity on the new VM.
  systemd.services.homelab-vpn-manager.wantedBy = lib.mkForce [ ];
}
