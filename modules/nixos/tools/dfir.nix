{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:

let
  cfg = config.hakkabara.tools.dfir;

  tools = {
    extractMsg = pkgsUnstable.python3Packages.extract-msg;
    inherit (pkgs) acquire;
    inherit (pkgs) afflib;
    inherit (pkgs) apfsprogs;
    inherit (pkgs) autopsy;
    inherit (pkgs) binwalk;
    bmcTools = pkgs.bmc-tools;
    bulkExtractor = pkgsUnstable.bulk_extractor;
    inherit (pkgsUnstable) chainsaw;
    inherit (pkgs) chntpw;
    inherit (pkgs) cyberchef;
    inherit (pkgs) dc3dd;
    inherit (pkgs) ddrescue;
    inherit (pkgs) dislocker;
    dissectTarget = pkgs.python3Packages.dissect-target;
    inherit (pkgsUnstable) evtx;
    exiftool = pkgs.perlPackages.ImageExifTool;
    inherit (pkgs) ext4magic;
    inherit (pkgs) extundelete;
    flowRecord = pkgs.python3Packages.flow-record;
    inherit (pkgs) foremost;
    inherit (pkgs) fq;
    hayabusa = pkgsUnstable.hayabusa-sec;
    inherit (pkgs) hivex;
    inherit (pkgs) libbde;
    inherit (pkgs) libewf;
    inherit (pkgs) libpff;
    inherit (pkgs) lnav;
    macRobber = pkgs.mac-robber;
    inherit (pkgs) ntfs3g;
    inherit (pkgs) scalpel;
    sigmaCli = pkgsUnstable.sigma-cli;
    inherit (pkgs) sleuthkit;
    inherit (pkgs) testdisk;
    inherit (pkgs) unfurl;
    inherit (pkgs) volatility3;
    inherit (pkgsUnstable) yara;
    yaraX = pkgsUnstable.yara-x;
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
