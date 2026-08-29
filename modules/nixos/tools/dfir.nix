{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.tools.dfir;

  tools = {
    inherit (pkgs) acquire;
    inherit (pkgs) afflib;
    inherit (pkgs) apfsprogs;
    inherit (pkgs) autopsy;
    inherit (pkgs) binwalk;
    bmcTools = pkgs.bmc-tools;
    bulkExtractor = pkgs.bulk_extractor;
    inherit (pkgs) chainsaw;
    inherit (pkgs) chntpw;
    inherit (pkgs) cyberchef;
    inherit (pkgs) dc3dd;
    inherit (pkgs) ddrescue;
    inherit (pkgs) dislocker;
    dissectTarget = pkgs.python3Packages.dissect-target;
    inherit (pkgs) evtx;
    exiftool = pkgs.perlPackages.ImageExifTool;
    inherit (pkgs) ext4magic;
    inherit (pkgs) extundelete;
    flowRecord = pkgs.python3Packages.flow-record;
    inherit (pkgs) foremost;
    inherit (pkgs) fq;
    inherit (pkgs) hayabusa;
    inherit (pkgs) hivex;
    inherit (pkgs) libbde;
    inherit (pkgs) libewf;
    inherit (pkgs) libpff;
    inherit (pkgs) lnav;
    macRobber = pkgs.mac-robber;
    inherit (pkgs) ntfs3g;
    inherit (pkgs) scalpel;
    sigmaCli = pkgs.sigma-cli;
    inherit (pkgs) sleuthkit;
    inherit (pkgs) testdisk;
    inherit (pkgs) unfurl;
    inherit (pkgs) volatility3;
    inherit (pkgs) yara;
    yaraX = pkgs.yara-x;
    inherit (pkgs) zircolite;
  };
in
{
  options.hakkabara.tools.dfir = lib.mapAttrs (name: _: {
    enable = lib.mkEnableOption "Install ${name}";
  }) tools;

  config.environment.systemPackages = lib.attrValues (
    lib.filterAttrs (name: _: cfg.${name}.enable) tools
  );
}
