{ lib, ... }:

{
  imports = [
    ../../modules/nixos/tools
  ];

  hakkabara.tools = {
    development =
      lib.genAttrs
        [
          "binutils"
          "cargo"
          "clang"
          "cryptsetup"
          "csvkit"
          "dotnet9"
          "go"
          "parted"
          "perl"
          "powershell"
          "sqlite"
        ]
        (_: {
          enable = true;
        });

    network =
      lib.genAttrs
        [
          "arpScan"
          "fping"
          "netdiscover"
          "dnsutils"
          "enum4linux"
          "freerdp"
          "kerbrute"
          "masscan"
          "netexec"
          "nmap"
          "proxychains"
          "rclone"
          "remmina"
          "responder"
          "rustscan"
          "smbmap"
          "tcpdump"
          "whois"
        ]
        (_: {
          enable = true;
        });

    dfir =
      lib.genAttrs
        [
          "extractMsg"
          "acquire"
          "afflib"
          "apfsprogs"
          "autopsy"
          "binwalk"
          "bmcTools"
          "bulkExtractor"
          "chainsaw"
          "chntpw"
          "cyberchef"
          "dc3dd"
          "ddrescue"
          "dislocker"
          "dissectTarget"
          "evtx"
          "exiftool"
          "ext4magic"
          "extundelete"
          "flowRecord"
          "foremost"
          "fq"
          "hayabusa"
          "hivex"
          "libbde"
          "libewf"
          "libpff"
          "lnav"
          "macRobber"
          "ntfs3g"
          "scalpel"
          "sigmaCli"
          "sleuthkit"
          "testdisk"
          "unfurl"
          "volatility3"
          "yara"
          "yaraX"
          "zircolite"
        ]
        (_: {
          enable = true;
        });

    pentest =
      lib.genAttrs
        [
          "wpscan"
          "adidnsdump"
          "amass"
          "arjun"
          "bloodhound"
          "bloodyad"
          "burpsuite"
          "certipyAd"
          "coercer"
          "dalfox"
          "dirb"
          "dirbuster"
          "donpapi"
          "dploot"
          "feroxbuster"
          "ffuf"
          "gau"
          "gobuster"
          "hakrawler"
          "hashcat"
          "httpx"
          "impacket"
          "john"
          "katana"
          "lsassy"
          "metasploit"
          "mitm6"
          "nikto"
          "nuclei"
          "pypykatz"
          "pwntools"
          "seclists"
          "shodan"
          "sqlmap"
          "subfinder"
          "wfuzz"
          "whatweb"
          "zap"
        ]
        (_: {
          enable = true;
        });
  };
}
