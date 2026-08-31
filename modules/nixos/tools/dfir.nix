{
  config,
  lib,
  pkgs,
  pkgsDfir,
  pkgsUnstable,
  ...
}:

let
  cfg = config.hakkabara.tools.dfir;

  customTools = {
    chainsawRules = pkgsDfir.chainsaw-rules;
    cryptnetUrlCacheParser = pkgsDfir.cryptnet-url-cache-parser;
    inherit (pkgsDfir) dexray;
    dfirNtfs = pkgsDfir.dfir-ntfs;
    esetLogParser = pkgsDfir.esetlogparser;
    eventTranscriptParser = pkgsDfir.eventtranscriptparser;
    ezTools = pkgsDfir.ez-tools;
    hackBrowserData = pkgsDfir.hackbrowserdata;
    inherit (pkgsDfir) hindsight;
    inherit (pkgsDfir) kstrike;
    inherit (pkgsDfir) libesedb;
    inherit (pkgsDfir) libevt;
    inherit (pkgsDfir) libvshadow;
    lokiScanner = pkgsDfir.loki-scanner;
    inherit (pkgsDfir) notatin;
    inherit (pkgsDfir) plaso;
    rdpCacheStitcher = pkgsDfir.rdpcachestitcher;
    inherit (pkgsDfir) recuperabit;
    inherit (pkgsDfir) regipy;
    regRipper4 = pkgsDfir.regripper4;
    sharpHound = pkgsDfir.sharphound;
    inherit (pkgsDfir) sidr;
    signatureBase = pkgsDfir.signature-base;
    srumDump = pkgsDfir.srum-dump;
    inherit (pkgsDfir) takajo;
    inherit (pkgsDfir) velociraptor;
    vmfsTools = pkgsDfir.vmfs-tools;
    yaraForge = pkgsDfir.yara-forge;
  };

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
    inherit (pkgs) gptfdisk;
    inherit (pkgs) imhex;
    mupdf = pkgs.mupdf-headless;
    inherit (pkgs) qpdf;
    sg3Utils = pkgs.sg3_utils;
    popplerUtils = pkgs.poppler-utils;
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
    zircolite = pkgs.zircolite.overridePythonAttrs (oldAttrs: {
      dependencies = (oldAttrs.dependencies or [ ]) ++ [
        pkgs.python3Packages.chardet
        pkgs.python3Packages.restrictedpython
      ];
    });
  }
  // customTools;
in
{
  options.hakkabara.tools.dfir = lib.mapAttrs (name: _: {
    enable = lib.mkEnableOption "Install ${name}";
  }) tools;

  config = {
    environment.systemPackages = lib.attrValues (lib.filterAttrs (name: _: cfg.${name}.enable) tools);

    environment.pathsToLink =
      lib.optionals cfg.chainsawRules.enable [ "/share/chainsaw" ]
      ++ lib.optionals cfg.signatureBase.enable [ "/share/signature-base" ]
      ++ lib.optionals cfg.sharpHound.enable [ "/share/sharphound" ]
      ++ lib.optionals cfg.yaraForge.enable [ "/share/yara-forge" ];
  };
}
