{ pkgsUnstable }:

let
  inherit (pkgsUnstable) lib;
  dir = ./.;

  names = builtins.attrNames (
    lib.filterAttrs (
      name: type: type == "directory" && builtins.pathExists (dir + "/${name}/package.nix")
    ) (builtins.readDir dir)
  );

  packages = lib.genAttrs names (
    name: lib.callPackageWith (pkgsUnstable // packages) (dir + "/${name}/package.nix") { }
  );
in
packages
