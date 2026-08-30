{
  config,
  pkgs,
  pkgsUnstable,
  ...
}:

{
  programs.vivaldi = {
    enable = config.hakkabara.browsers.chromium.vivaldi.enable;

    package = pkgs.vivaldi.override {
      proprietaryCodecs = true;
      inherit (pkgsUnstable) vivaldi-ffmpeg-codecs;
    };
  };
}
