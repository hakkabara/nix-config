{ config, pkgs, ... }:

let
  smbOptions = [
    "credentials=${config.sops.secrets."smb/homelab-main".path}"
    "uid=hakkabara"
    "gid=users"
    "file_mode=0660"
    "dir_mode=0770"
    "_netdev"
    "nofail"
    "noauto"
    "x-systemd.automount"
    "x-systemd.idle-timeout=600"
  ];
in
{
  environment.systemPackages = [
    pkgs.cifs-utils
    pkgs.samba
  ];

  fileSystems = {
    "/mnt/smb/deacdeb02/8TB" = {
      device = "//192.168.189.3/8TB";
      fsType = "cifs";
      options = smbOptions;
    };

    "/mnt/smb/deacdeb02/18TB" = {
      device = "//192.168.189.3/18TB";
      fsType = "cifs";
      options = smbOptions;
    };

    "/mnt/smb/deacdeb02/12-1TB" = {
      device = "//192.168.189.3/12-1TB";
      fsType = "cifs";
      options = smbOptions;
    };

    "/mnt/smb/deacdeb02/12-2TB" = {
      device = "//192.168.189.3/12-2TB";
      fsType = "cifs";
      options = smbOptions;
    };

    "/mnt/smb/deacdeb02/Daveshare" = {
      device = "//192.168.189.3/Daveshare";
      fsType = "cifs";
      options = smbOptions;
    };
  };
}
