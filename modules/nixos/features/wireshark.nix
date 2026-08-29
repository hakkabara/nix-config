{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.wireshark;
in
{
  options.hakkabara.wireshark = {
    enable = lib.mkEnableOption "Wireshark packet analysis";

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "mko" ];
      description = "Users allowed to capture network traffic through dumpcap.";
    };

    usbCapture = lib.mkEnableOption "USB traffic capture through usbmon";
  };

  config = lib.mkIf cfg.enable {
    programs.wireshark = {
      enable = true;
      package = pkgs.wireshark;

      dumpcap.enable = true;
      usbmon.enable = cfg.usbCapture;
    };

    users.users = lib.genAttrs cfg.users (_: {
      extraGroups = [ "wireshark" ];
    });
  };
}
