{ pkgs, ... }:

{
  imports = [
    ./dfir/hashes.nix
    ./commands.nix
  ];

  home = {
    packages = [
      pkgs.copyq
    ];

    file = {
      ".local/bin/copyq-dfir-tag" = {
        source = ./scripts/copyq-dfir-tag;
        executable = true;
      };

      ".local/bin/copyq-install-commands" = {
        source = ./scripts/install-commands.sh;
        executable = true;
      };
    };
  };

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

  home.activation.copyqDfirCommands = ''
    $HOME/.local/bin/copyq-install-commands
  '';
}
