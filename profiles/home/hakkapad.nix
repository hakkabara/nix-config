{ ... }:

{
  # Native private workstation:
  #
  # personal-workstation:
  #   private apps, browsers, bookmarks, SSH, AI, theme
  #
  # niri-workstation:
  #   shared Niri/DMS session, keybindings and rice
  imports = [
    ./personal-workstation.nix
    ./niri-workstation.nix
  ];

  hakkabara = {
    # Unlike the WorkVM, a physical laptop must retain normal
    # lock/idle/power-management behavior.
    desktop.dms.alwaysOn.enable = false;
  };
}
