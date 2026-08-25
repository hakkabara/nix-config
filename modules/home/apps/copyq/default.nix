{ pkgs, ... }:

{
  imports = [
    ./dfir/hashes.nix
  ];

  home.packages = [
    pkgs.copyq
  ];

  xdg.configFile."autostart/copyq.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=CopyQ
    Comment=Clipboard Manager
    Exec=${pkgs.copyq}/bin/copyq
    Icon=copyq
    Terminal=false
    Categories=Utility;
    StartupNotify=false
  '';

  home.file.".local/bin/copyq-dfir-tag" = {
    source = ./scripts/copyq-dfir-tag;
    executable = true;
  };
}
