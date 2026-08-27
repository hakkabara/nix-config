{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.python;
in
{
  options.hakkabara.python = {
    python3.enable = lib.mkEnableOption "Python 3 runtime";

    python2.enable = lib.mkEnableOption "legacy Python 2 runtime";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.python3.enable {
      environment.systemPackages = [
        pkgs.python3
      ];
    })

    (lib.mkIf cfg.python2.enable {
      # Python 2 reached end-of-life in 2020.
      # Keep this exception tightly scoped to the exact package required
      # for legacy compatibility.
      nixpkgs.config.permittedInsecurePackages = [
        "python-2.7.18.12"
      ];

      environment.systemPackages = [
        pkgs.python2
      ];
    })
  ];
}
