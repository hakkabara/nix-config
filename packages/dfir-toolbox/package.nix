{
  lib,
  linkFarm,
  # Base tools from nixpkgs
  chainsaw,
  hayabusa-sec,
  evtx,
  # Locally built tools
  libevt,
  libvshadow,
  libesedb,
  notatin,
  sidr,
  cryptnet-url-cache-parser,
  hackbrowserdata,
  dfir-ntfs,
  kstrike,
  esetlogparser,
  eventtranscriptparser,
  srum-dump,
  loki-scanner,
  takajo,
  hindsight,
  ez-tools,
  regripper4,
  dexray,
  # Rules / signatures
  chainsaw-rules,
  signature-base,
}:

# Compatibility layer: reproduces a /data/tools layout so the internal tool's
# hardcoded paths resolve. Wired up via systemd.tmpfiles.rules in modules/dfir.nix
# ("L+ /data/tools - - - - ${pkgs.dfir-toolbox}").
#
# NOTE: the exact layout depends on the internal tool (not part of this repo).
# Until its expected paths are verified this is a flat, best-effort layout keyed
# by tool name. The passthru test ensures no symlink dangles (linkFarm does not
# validate that itself).
let
  entries = [
    # Windows event / artifact parsers
    {
      name = "chainsaw";
      path = "${chainsaw}/bin/chainsaw";
    }
    {
      name = "hayabusa";
      path = "${hayabusa-sec}/bin/hayabusa";
    }
    {
      name = "evtx_dump";
      path = "${evtx}/bin/evtx_dump";
    }
    {
      name = "evtexport";
      path = lib.getExe libevt;
    }
    {
      name = "vshadowinfo";
      path = lib.getExe libvshadow;
    }
    {
      name = "esedbexport";
      path = lib.getExe libesedb;
    }
    {
      name = "reg_dump";
      path = lib.getExe notatin;
    }
    {
      name = "sidr";
      path = lib.getExe sidr;
    }
    {
      name = "cryptnet_url_cache_parser";
      path = lib.getExe cryptnet-url-cache-parser;
    }
    {
      name = "hack-browser-data";
      path = lib.getExe hackbrowserdata;
    }
    {
      name = "ntfs_parser";
      path = lib.getExe dfir-ntfs;
    }
    {
      name = "kstrike";
      path = lib.getExe kstrike;
    }
    {
      name = "esetlogparser";
      path = lib.getExe esetlogparser;
    }
    {
      name = "eventtranscriptparser";
      path = lib.getExe eventtranscriptparser;
    }
    {
      name = "srum-dump";
      path = lib.getExe srum-dump;
    }
    {
      name = "loki";
      path = lib.getExe loki-scanner;
    }
    {
      name = "takajo";
      path = lib.getExe takajo;
    }
    {
      name = "hindsight";
      path = lib.getExe hindsight;
    }
    {
      name = "JLECmd";
      path = lib.getExe' ez-tools "JLECmd";
    }
    {
      name = "LECmd";
      path = lib.getExe' ez-tools "LECmd";
    }
    {
      name = "regripper4";
      path = lib.getExe regripper4;
    }
    {
      name = "dexray";
      path = lib.getExe dexray;
    }
    # Rules / signatures as directories
    {
      name = "chainsaw-rules";
      path = "${chainsaw-rules}/share/chainsaw";
    }
    {
      name = "signature-base";
      path = "${signature-base}/share/signature-base";
    }
  ];
in
(linkFarm "dfir-toolbox" entries).overrideAttrs (old: {
  # Data package without a binary, so no mainProgram (orchestrator: metaExempt).
  meta = (old.meta or { }) // {
    description = "Compatibility link farm exposing all DFIR tools under a /data/tools layout";
    homepage = "https://github.com/NixOS/nixpkgs";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };

})
