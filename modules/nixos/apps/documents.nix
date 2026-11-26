{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.apps.documents;

  # Image types opened with swayimg by default (subset of its .desktop file).
  imageTypes = [
    "image/avif"
    "image/bmp"
    "image/gif"
    "image/heif"
    "image/jpeg"
    "image/jxl"
    "image/png"
    "image/svg+xml"
    "image/tiff"
    "image/webp"
    "image/x-portable-anymap"
    "image/x-tga"
  ];
in
{
  options.hakkabara.apps.documents = {
    enable = lib.mkEnableOption "image viewer (swayimg) and office suite (LibreOffice)";
  };

  config = lib.mkIf cfg.enable {
    # swayimg: Wayland-native, keyboard driven, gallery mode with `g`.
    # LibreOffice: native Wayland through its GTK3 backend; it registers
    # its own document types.
    environment.systemPackages = [
      pkgs.swayimg
      pkgs.libreoffice-fresh
    ];

    # System-wide defaults; entries in ~/.config/mimeapps.list still take
    # precedence.
    xdg.mime.defaultApplications = lib.genAttrs imageTypes (_: "swayimg.desktop");
  };
}
