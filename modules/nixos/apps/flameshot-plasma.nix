{ pkgs, ... }:

{
  # Flameshot replaces KDE Spectacle.
  environment.plasma6.excludePackages = [
    pkgs.kdePackages.spectacle
  ];
}
