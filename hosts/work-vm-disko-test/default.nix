{ lib, ... }:

{
  # Reuse the complete permanent WorkVM configuration.
  imports = [
    ../work-vm
  ];

  # Keep the installation target clearly distinguishable.
  networking.hostName = lib.mkForce "work-vm-disko-test";

  # First installation/boot uses the normal LUKS passphrase.
  #
  # After the system has booted successfully, enroll the YubiKey with
  # systemd-cryptenroll and switch to the permanent work-vm target where
  # FIDO2 unlocking is enabled.
  hakkabara.storage.disko.encryption.yubikey.enable = lib.mkForce false;
}
