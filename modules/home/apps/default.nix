{ ... }:

{
  # Reusable application feature modules.
  #
  # Importing this registry should only make application options available.
  # Profiles decide which applications are actually enabled.
  imports = [
    ./browsers
    ./copyq
    ./flameshot.nix
    ./keepassxc.nix
    ./obsidian.nix
    ./signal.nix
    ./pihole
    ./miniserve
  ];
}
