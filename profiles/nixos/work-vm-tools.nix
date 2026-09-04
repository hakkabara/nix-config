{ lib, ... }:

{
  imports = [
    ../../modules/nixos/tools
  ];

  hakkabara.tools = {
    development =
      lib.genAttrs
        [
          "angleGrinder"
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
          "choose"
          "expect"
          "htopVim"
          "imagemagick"
          "jc"
          "jless"
          "nixosAnywhere"
          "openssl"
          "unrar"
          "xxd"
          "xan"
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
          "openiscsi"
          "socat"
          "sshfs"
          "sshpass"
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
          "zeekPcap"
          "gptfdisk"
          "imhex"
          "mupdf"
          "qpdf"
          "sg3Utils"
          "popplerUtils"

          # Custom DFIR packages.
          "chainsawRules"
          "cryptnetUrlCacheParser"
          "dexray"
          "dfirNtfs"
          "esetLogParser"
          "eventTranscriptParser"
          "forensicsim"
          "ezTools"
          "hackBrowserData"
          "hindsight"
          "kstrike"
          "libesedb"
          "libevt"
          "libvshadow"
          "lokiScanner"
          "notatin"
          "plaso"
          "rdpCacheStitcher"
          "regrippy"
          "rifiuti2"
          "recuperabit"
          "regipy"
          "regRipper4"
          "sharpHound"
          "sidr"
          "signatureBase"
          "srumDump"
          "takajo"
          "velociraptor"
          "vmfsTools"
          "whapa"
          "yaraForge"
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
          "flawz"
          "gau"
          "gobuster"
          "hakrawler"
          "hashcat"
          "httpx"
          "impacket"
          "john"
          "katana"
          "lsassy"
          "manspider"
          "metasploit"
          "mitm6"
          "nikto"
          "nuclei"
          "p3u"
          "pypykatz"
          "pwntools"
          "seclists"
          "shodan"
          "sqlmap"
          "subfinder"
          "thcHydra"
          "wfuzz"
          "whatweb"
          "zap"
        ]
        (_: {
          enable = true;
        });
  };
}
