{ lib, ... }:

{
  imports = [
    ./code.nix
    ./omc.nix
  ];

  options.hakkabara.ai.claude.enable =
    lib.mkEnableOption "Claude tools and integrations";
}
