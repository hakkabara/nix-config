{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.tools.development;

  tools = {
    inherit (pkgs) binutils;
    inherit (pkgs) cargo;
    inherit (pkgs) clang;
    inherit (pkgs) cryptsetup;
    inherit (pkgs) csvkit;
    dotnet9 = pkgs.dotnetCorePackages.aspnetcore_9_0;
    inherit (pkgs) go;
    inherit (pkgs) parted;
    inherit (pkgs) perl;
    inherit (pkgs) powershell;
    inherit (pkgs) sqlite;
  };
in
{
  options.hakkabara.tools.development = lib.mapAttrs (name: _: {
    enable = lib.mkEnableOption "Install ${name}";
  }) tools;

  config.environment.systemPackages = lib.attrValues (
    lib.filterAttrs (name: _: cfg.${name}.enable) tools
  );
}
