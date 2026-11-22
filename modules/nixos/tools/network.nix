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
    inherit (pkgs) mtr;
    inherit (pkgs) netexec;
    inherit (pkgs) openldap;
    inherit (pkgs) nmap;
    proxychains = pkgs.proxychains-ng;
    inherit (pkgs) rclone;
    inherit (pkgs) samba;
    inherit (pkgs) remmina;
    inherit (pkgs) responder;
    inherit (pkgs) rustscan;
    inherit (pkgs) smbmap;
    inherit (pkgs) tcpdump;
    inherit (pkgs) traceroute;
    inherit (pkgs) whois;
    inherit (pkgs) openiscsi;
    inherit (pkgs) socat;
    inherit (pkgs) sshfs;
    inherit (pkgs) sshpass;

    # Pivoting
    ligoloNg = pkgs.ligolo-ng;
    inherit (pkgs) chisel;
    # AD / Windows
    bloodhoundPy = pkgs.bloodhound-py;
    rusthoundCe = pkgs.rusthound-ce;
    ldapdomaindump = pkgs.python3Packages.ldapdomaindump;
    inherit (pkgs) ldeep;
    smbclientNg = pkgs.smbclient-ng;
    inherit (pkgs) pretender;
    inherit (pkgs) ntlmrecon;
    inherit (pkgs) nbtscan;
    # DNS / recon
    inherit (pkgs) dnsrecon;
    inherit (pkgs) dnsenum;
    inherit (pkgs) fierce;
    inherit (pkgs) dnsx;
    inherit (pkgs) naabu;
    theHarvester = pkgs.theharvester;
    # Web / TLS / SNMP
    inherit (pkgs) gowitness;
    inherit (pkgs) wafw00f;
    inherit (pkgs) testssl;
    inherit (pkgs) sslscan;
    inherit (pkgs) onesixtyone;
    inherit (pkgs) snmpcheck;
    inherit (pkgs) bettercap;
  };

  enabledTools = lib.filterAttrs (name: _: cfg.${name}.enable) tools;
in
{
  options.hakkabara.tools.network =
    lib.mapAttrs (name: _: {
      enable = lib.mkEnableOption "Install ${name}";
    }) tools
    // {
      enabled = lib.mkOption {
        type = lib.types.attrsOf lib.types.package;
        readOnly = true;
        description = "Enabled network tools by name, as installed into the system PATH.";
      };
    };

  config = {
    hakkabara.tools.network.enabled = enabledTools;
    environment.systemPackages = lib.attrValues enabledTools;

    # NetExec replaced CrackMapExec; its command is `nxc`. Keep the old names
    # working in the interactive shell for muscle memory.
    environment.shellAliases = lib.mkIf cfg.netexec.enable {
      crackmapexec = "nxc";
      cme = "nxc";
    };
  };
}
