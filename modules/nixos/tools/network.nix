{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.tools.network;

  tools = {
    arpScan = pkgs.arp-scan;
    inherit (pkgs) fping;
    inherit (pkgs) netdiscover;
    inherit (pkgs) dnsutils;
    enum4linux = pkgs.enum4linux-ng;
    inherit (pkgs) freerdp;
    inherit (pkgs) kerbrute;
    inherit (pkgs) masscan;
    inherit (pkgs) netexec;
    inherit (pkgs) nmap;
    proxychains = pkgs.proxychains-ng;
    inherit (pkgs) rclone;
    inherit (pkgs) remmina;
    inherit (pkgs) responder;
    inherit (pkgs) rustscan;
    inherit (pkgs) smbmap;
    inherit (pkgs) tcpdump;
    inherit (pkgs) whois;
  };
in
{
  options.hakkabara.tools.network = lib.mapAttrs (name: _: {
    enable = lib.mkEnableOption "Install ${name}";
  }) tools;

  config.environment.systemPackages = lib.attrValues (
    lib.filterAttrs (name: _: cfg.${name}.enable) tools
  );
}
