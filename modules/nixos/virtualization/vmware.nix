{ pkgs, ... }:

{
  # Enable NixOS' official VMware guest integration.
  #
  # This provides open-vm-tools, vmtoolsd and the VMware user integration.
  virtualisation.vmware.guest = {
    enable = true;

    # This module is used for graphical workstation VMs.
    headless = false;
  };

  # Make the VMware graphics driver available already in the initrd.
  #
  # vmwgfx is already loaded successfully on the running SurfVM. Putting it
  # into the initrd gives us early KMS/display support during boot as well.
  boot.initrd.kernelModules = [
    "vmwgfx"
  ];

  # Tell VMware Tools to use KMS for dynamic guest resolution handling.
  #
  # This is relevant when resizing the VMware window, entering fullscreen or
  # changing the monitor topology on the Windows host.
  environment.etc."vmware-tools/tools.conf".text = ''
    [resolutionKMS]
    enable=true
  '';

  # Expose all VMware Shared Folders below /data/<share>.
  #
  # Mounting .host:/ exposes every share configured in VMware as a
  # directory below /data without requiring per-share Nix configuration.
  #
  # Permission/mount behavior follows the proven VMware HGFS setup used by
  # Kyubai, adapted to our mko:users UID/GID (1000:100).
  fileSystems."/data" = {
    device = ".host:/";
    fsType = "fuse./run/current-system/sw/bin/vmhgfs-fuse";

    options = [
      "uid=1000"
      "gid=100"
      "umask=0033"
      "allow_other"
      "auto_unmount"
      "nofail"
    ];
  };

  # Keep VMware's Xorg video driver available for X11/XWayland compatibility.
  #
  # The actual kernel graphics driver is vmwgfx; this package is the Xorg
  # userspace driver and is especially useful for the X11 fallback session.
  environment.systemPackages = with pkgs; [
    xf86-video-vmware
  ];
}
