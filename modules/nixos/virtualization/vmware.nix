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

  # Keep VMware's Xorg video driver available for X11/XWayland compatibility.
  #
  # The actual kernel graphics driver is vmwgfx; this package is the Xorg
  # userspace driver and is especially useful for the X11 fallback session.
  environment.systemPackages = with pkgs; [
    xf86-video-vmware
  ];
}
