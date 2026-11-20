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
    version = "git-aed7e9f";

    src = pkgs.fetchzip {
      url = "https://github.com/Jayy-Dev/Plasma-Tokyo-Night/archive/aed7e9faf9bc7ea6b6bbc8e21b5475bdda2412c7.tar.gz";
      hash = "sha256-lt7hjym2Pg5xGf9ecDpU11hMmWTtmXBwbiwou93nA3A=";
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

  # Compact Plasma 6 / Wayland virtual desktop indicator.
  virtualDesktopBar = pkgs.stdenv.mkDerivation {
    pname = "virtual-desktop-bar";
    version = "1.0.2";

    src = pkgs.fetchzip {
      url = "https://github.com/lenonk/virtual-desktop-bar/archive/refs/tags/v1.0.2.tar.gz";
      hash = "sha256-zVdXXi0JbQ8e/99ZF+K5ySPN4csTzur6Fmkoxe56NHI=";
    };

    nativeBuildInputs = [
      pkgs.cmake
      pkgs.kdePackages.extra-cmake-modules
      pkgs.qt6.wrapQtAppsHook
    ];

    buildInputs = [
      pkgs.kdePackages.qtbase
      pkgs.kdePackages.qtdeclarative
      pkgs.kdePackages.ki18n
      pkgs.kdePackages.kservice
      pkgs.kdePackages.kwindowsystem
      pkgs.kdePackages.kwin
      pkgs.kdePackages.libplasma
      pkgs.kdePackages.plasma-activities
    ];

    meta = {
      description = "Compact virtual desktop bar for Plasma 6 Wayland";
      homepage = "https://github.com/lenonk/virtual-desktop-bar";
      license = lib.licenses.gpl3Plus;
      platforms = lib.platforms.linux;
    };
  };
in
{
  options.hakkabara.desktop.plasma.rice.enable = lib.mkEnableOption "minimal Tokyo Night Plasma rice";

  config = lib.mkIf (cfg.enable && cfg.rice.enable) {
    home.packages = [
      tokyoNight
      virtualDesktopBar
      pkgs.papirus-icon-theme
    ];

    # The applet contains a native QML plugin. Make its QML import tree
    # available to Plasma when the user session starts.
    home.sessionVariables.QML_IMPORT_PATH = "${virtualDesktopBar}/lib/qt-6/qml";

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
