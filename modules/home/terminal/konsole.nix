{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.terminal;

  konsolePackage = pkgs.kdePackages.konsole;

  # Official KDE Konsole 26.04.3 default keyboard table.
  #
  # We pin both the exact upstream version and its content hash so this
  # configuration is reproducible and cannot silently change upstream.
  upstreamDefaultKeytab = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/KDE/konsole/v26.04.3/data/keyboard-layouts/default.keytab";
    hash = "sha256-YlIP1OrNyaHXG/atg+NvlutE1Vtgv35IW2a+v7FdwOA=";
  };

  # Official KDE Konsole 26.04.3 session UI definition.
  #
  # Konsole stores custom Copy/Paste action shortcuts in sessionui.rc,
  # not in the [Shortcuts] group of konsolerc.
  upstreamSessionUi = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/KDE/konsole/v26.04.3/desktop/sessionui.rc";
    hash = "sha256-RW8JMM3/qIPUEqZbm7K4z7OENRuK6vRG2gKGoQ6CyY0=";
  };

  # Start with Konsole's official default keyboard table and add only our
  # Ctrl+Shift+C -> traditional terminal Ctrl+C mapping.
  surfvmKeytab = pkgs.runCommand "surfvm-konsole.keytab" { } ''
    cp "${upstreamDefaultKeytab}" "$out"
    chmod u+w "$out"

    sed -i \
      's/^keyboard .*/keyboard "SurfVM"/' \
      "$out"

    cat >> "$out" <<'KEYTAB'

    # SurfVM terminal convention:
    #
    # Ctrl+C       = handled by Konsole as GUI Copy
    # Ctrl+V       = handled by Konsole as GUI Paste
    # Ctrl+Shift+C = send ASCII ETX (0x03), the traditional terminal Ctrl+C
    key C +Shift+Ctrl : "\x03"
    KEYTAB
  '';

  # Keep Konsole's upstream menu/toolbar definition and add only our
  # Windows-like Copy/Paste shortcuts.
  surfvmSessionUi = pkgs.runCommand "surfvm-konsole-sessionui.rc" { } ''
    sed '/<\/gui>/d' "${upstreamSessionUi}" > "$out"

    cat >> "$out" <<'XML'
     <ActionProperties scheme="Default">
      <Action name="edit_copy" shortcut="Ctrl+C; Ctrl+Ins"/>
      <Action name="edit_paste" shortcut="Ctrl+V; Shift+Ins"/>
     </ActionProperties>
    </gui>
    XML
  '';

  kwriteconfig = lib.getExe' pkgs.kdePackages.kconfig "kwriteconfig6";
in
{
  config = lib.mkIf (cfg.enable && cfg.konsole.enable) {
    home.packages = [
      konsolePackage
    ];

    xdg.dataFile = {
      "konsole/SurfVM.profile".text = ''
        [Appearance]
        AntiAliasFonts=true
        BoldIntense=true
        ColorScheme=TokyoNight
        Font=FiraCode Nerd Font Mono,12,-1,5,50,0,0,0,0,0
        UseFontLineChararacters=false

        [General]
        Icon=utilities-terminal
        Name=SurfVM
        Parent=FALLBACK/
        StartInCurrentSessionDir=true

        [Interaction Options]
        AutoCopySelectedText=true
        CopyTextAsHTML=false
        TrimLeadingSpacesInSelectedText=false
        TrimTrailingSpacesInSelectedText=true
        UnderlineFilesEnabled=true

        [Keyboard]
        KeyBindings=SurfVM

        [Scrolling]
        HistoryMode=1
        HistorySize=100000

        [Terminal Features]
        BellMode=3
        BlinkingCursorEnabled=false
        BlinkingTextEnabled=false
      '';

      "konsole/TokyoNight.colorscheme".text = ''
        [Background]
        Color=26,27,38

        [BackgroundFaint]
        Color=26,27,38

        [BackgroundIntense]
        Color=26,27,38

        [Color0]
        Color=21,22,30
        [Color0Faint]
        Color=21,22,30
        [Color0Intense]
        Color=65,72,104

        [Color1]
        Color=247,118,142
        [Color1Faint]
        Color=247,118,142
        [Color1Intense]
        Color=247,118,142

        [Color2]
        Color=158,206,106
        [Color2Faint]
        Color=158,206,106
        [Color2Intense]
        Color=158,206,106

        [Color3]
        Color=224,175,104
        [Color3Faint]
        Color=224,175,104
        [Color3Intense]
        Color=224,175,104

        [Color4]
        Color=122,162,247
        [Color4Faint]
        Color=122,162,247
        [Color4Intense]
        Color=122,162,247

        [Color5]
        Color=187,154,247
        [Color5Faint]
        Color=187,154,247
        [Color5Intense]
        Color=187,154,247

        [Color6]
        Color=125,207,255
        [Color6Faint]
        Color=125,207,255
        [Color6Intense]
        Color=125,207,255

        [Color7]
        Color=169,177,214
        [Color7Faint]
        Color=169,177,214
        [Color7Intense]
        Color=192,202,245

        [Foreground]
        Color=192,202,245

        [ForegroundFaint]
        Color=169,177,214

        [ForegroundIntense]
        Color=192,202,245

        [General]
        Description=Tokyo Night
        Opacity=1
        Wallpaper=
      '';

      "kxmlgui5/konsole/sessionui.rc".source = surfvmSessionUi;
      "konsole/SurfVM.keytab".source = surfvmKeytab;
    };

    home.activation.configureSurfvmKonsole = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${kwriteconfig} \
        --file "$HOME/.config/konsolerc" \
        --group "Desktop Entry" \
        --key "DefaultProfile" \
        "SurfVM.profile"
    '';
  };
}
