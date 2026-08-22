{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.desktop.plasma;

  # Plasma 6 port of Jayy-Dev's Tokyo Night theme.
  #
  # We deliberately install/apply only the components we want instead of
  # applying the complete Look-and-Feel package. Upstream's global theme also
  # selects TokyoNight-SE icons and the Klassy widget style, while our desktop
  # intentionally uses Papirus-Dark and the existing Plasma widget style.
  tokyoNight = pkgs.stdenvNoCC.mkDerivation {
    pname = "plasma-tokyo-night";
    version = "git-a3e6c64";

    src = pkgs.fetchzip {
      url = "https://github.com/Jayy-Dev/Plasma-Tokyo-Night/archive/a3e6c64a171dc226d03272a7f6cc97d0c916f3dd.tar.gz";
      hash = "sha256-9BvoDnHwlDo3qe2bhW4tQU858HRXxCL7Rk38IMCRtbA=";
    };

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      mkdir -p \
        "$out/share/aurorae/themes" \
        "$out/share/color-schemes" \
        "$out/share/plasma/desktoptheme"

      cp -a \
        "$src/aurorae/TokyoNight" \
        "$out/share/aurorae/themes/TokyoNight"

      cp \
        "$src/colorscheme/TokyoNight.colors" \
        "$out/share/color-schemes/TokyoNight.colors"

      cp -a \
        "$src/plasma/desktoptheme/Tokyo-Night" \
        "$out/share/plasma/desktoptheme/Tokyo-Night"

      runHook postInstall
    '';

    meta = {
      description = "Tokyo Night theme components for KDE Plasma 6";
      homepage = "https://github.com/Jayy-Dev/Plasma-Tokyo-Night";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.linux;
    };
  };
in
{
  options.hakkabara.desktop.plasma.rice.enable =
    lib.mkEnableOption "minimal Tokyo Night Plasma rice";

  config = lib.mkIf (cfg.enable && cfg.rice.enable) {
    home.packages = [
      tokyoNight
      pkgs.papirus-icon-theme
    ];

    programs.plasma = {
      workspace = {
        # Apply the individual components instead of the upstream Global Theme
        # so it cannot replace our panel layout, icon choice, or widget style.
        theme = "Tokyo-Night";
        colorScheme = "TokyoNight";
        iconTheme = "Papirus-Dark";

        windowDecorations = {
          library = "org.kde.kwin.aurorae";
          theme = "__aurorae__svg__TokyoNight";
        };
      };

      # Floating KRunner in the center instead of the traditional top position.
      krunner.position = "center";

      # Keep workspace switching immediate and i3-like.
      kwin.effects.desktopSwitching.animation = "off";
    };
  };
}
