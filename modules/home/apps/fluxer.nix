{
  config,
  lib,
  pkgs,
  fluxer,
  ...
}:

{
  options.hakkabara.apps.fluxer.enable = lib.mkEnableOption "Fluxer chat client";

  config = lib.mkIf config.hakkabara.apps.fluxer.enable {
    home.packages = [
      # Stable channel; the flake also provides `fluxer-canary`.
      fluxer.packages.${pkgs.stdenv.hostPlatform.system}.fluxer
    ];
  };
}
