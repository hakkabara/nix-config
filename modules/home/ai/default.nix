{ lib, ... }:

{
  imports = [
    ./claude
  ];

  options.hakkabara.ai.enable = lib.mkEnableOption "AI tools and integrations";
}
