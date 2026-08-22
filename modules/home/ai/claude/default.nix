{ lib, ... }:

{
  imports = [
    ./code.nix
  ];

  options.hakkabara.ai.claude.enable =
    lib.mkEnableOption "Claude tools and integrations";
}
