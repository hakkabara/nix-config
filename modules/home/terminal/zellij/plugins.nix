{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  zellij-tools,
  ...
}:

let
  cfg = config.hakkabara.terminal;
  plugins = cfg.zellij.plugins;

  zellijToolsPlugin =
    zellij-tools.packages.${pkgs.stdenv.hostPlatform.system}.default;

  zellijToolsCli =
    zellij-tools.packages.${pkgs.stdenv.hostPlatform.system}.cli;

  # Declarative zellij-tools configuration.
  #
  # We inject this inline into the plugin configuration. External config
  # files are useful for hot reload, but Home Manager already owns our
  # configuration lifecycle.
  scratchpadConfig =
    import ./scratchpads.nix { inherit pkgs; };


  mkPluginEnableOption =
    description:
    lib.mkOption {
      type = lib.types.bool;
      default = false;
      inherit description;
    };

  # Harpoon does not publish a pre-built WASM release. Build the pinned
  # upstream v0.3.0 source reproducibly for wasm32-wasip1.
  harpoonPlugin =
    pkgsUnstable.pkgsCross.wasm32-wasip1.callPackage
      (
        {
          fetchFromGitHub,
          rustPlatform,
          lld,
        }:
        rustPlatform.buildRustPackage {
          pname = "zellij-harpoon";
          version = "0.3.0";

          src = fetchFromGitHub {
            owner = "Nacho114";
            repo = "harpoon";
            tag = "v0.3.0";
            hash = "sha256-JmYcbzxIF6qZs2/RKuspHqNpyDibGp9CVQJj47y/BOQ=";
          };

          cargoHash = "sha256-lsv5Wssakni18jif++fPo3Z5WyBtvPsGpWwG3abR7jQ=";

          env.RUSTFLAGS = "-C linker=wasm-ld";

          nativeBuildInputs = [
            lld
          ];

          # Cross-compiled WASM cannot run as a native test binary.
          doCheck = false;

          installPhase = ''
            runHook preInstall

            mkdir -p "$out"

            cp \
              target/wasm32-wasip1/release/harpoon.wasm \
              "$out/harpoon.wasm"

            runHook postInstall
          '';
        }
      )
      { };

  # Lightweight CPU/RAM source for zjstatus. Linux already exposes everything
  # required through procfs, so no monitoring daemon is needed.
  zjstatusSystem = pkgs.writeShellApplication {
    name = "zjstatus-system";

    runtimeInputs = [
      pkgs.coreutils
    ];

    text = ''
      read_cpu() {
        local -a fields
        local idle_all
        local total
        local i

        read -r -a fields < /proc/stat

        # cpu user nice system idle iowait irq softirq steal ...
        idle_all=$((fields[4] + fields[5]))

        total=0

        for i in {1..8}; do
          total=$((total + fields[i]))
        done

        printf '%s %s\n' "$total" "$idle_all"
      }

      read -r total_before idle_before < <(read_cpu)
      sleep 0.1
      read -r total_after idle_after < <(read_cpu)

      total_delta=$((total_after - total_before))
      idle_delta=$((idle_after - idle_before))

      cpu_pct=0

      if (( total_delta > 0 )); then
        cpu_pct=$((100 * (total_delta - idle_delta) / total_delta))
      fi

      mem_total=0
      mem_available=0

      while read -r key value _; do
        case "$key" in
          MemTotal:)
            mem_total="$value"
            ;;
          MemAvailable:)
            mem_available="$value"
            ;;
        esac
      done < /proc/meminfo

      if (( mem_total <= 0 )); then
        echo "ERROR: MemTotal missing from /proc/meminfo" >&2
        exit 1
      fi

      mem_used=$((mem_total - mem_available))
      mem_pct=$((100 * mem_used / mem_total))

      used_tenths=$((mem_used * 10 / 1048576))
      total_tenths=$((mem_total * 10 / 1048576))

      used_gib="$((used_tenths / 10)).$((used_tenths % 10))G"
      total_gib="$((total_tenths / 10)).$((total_tenths % 10))G"

      printf \
        '#[bg=#7aa2f7,fg=#1a1b26,bold]  CPU %s%% #[bg=#bb9af7,fg=#1a1b26,bold] 󰍛 RAM %s%% %s/%s #[bg=#1a1b26]\n' \
        "$cpu_pct" \
        "$mem_pct" \
        "$used_gib" \
        "$total_gib"
    '';
  };

  pluginDefinitions = lib.concatStringsSep "\n" (
    (lib.optionals plugins.autolock.enable [
      ''
        autolock location="file:${config.xdg.configHome}/zellij/plugins/zellij-autolock.wasm" {
          is_enabled true
          triggers "nvim|vim|fzf"
          reaction_seconds "0.3"
          print_to_log false
        }
      ''
    ])
    ++ (lib.optionals plugins.navigator.enable [
      ''
        vim_zellij_navigator location="file:${config.xdg.configHome}/zellij/plugins/vim-zellij-navigator.wasm"
      ''
    ])
    ++ (lib.optionals plugins.zjstatus.enable [
      ''
        zjstatus location="file:${config.xdg.configHome}/zellij/plugins/zjstatus.wasm"
      ''
    ])
    ++ (lib.optionals plugins.tools.enable [
      ''
        zellij-tools location="file:${config.xdg.configHome}/zellij/plugins/zellij-tools.wasm" {
          ${scratchpadConfig}
        }
      ''
    ])
    ++ (lib.optionals plugins.attention.enable [
      ''
        zellij-attention location="file:${config.xdg.configHome}/zellij/plugins/zellij-attention.wasm" {
          enabled "true"
          waiting_icon "⏳"
          completed_icon "✅"
        }
      ''
    ])
  );

  sharedExceptLockedBindings = lib.concatStringsSep "\n" (
    (lib.optionals plugins.forgot.enable [
      ''
      // Forgot: searchable help for the actual configured keybindings.
      bind "Alt Shift /" {
        LaunchOrFocusPlugin "file:${config.xdg.configHome}/zellij/plugins/zellij-forgot.wasm" {
          floating true
          "LOAD_ZELLIJ_BINDINGS" "true"
        };
      }
      ''
    ])
    ++     (lib.optionals plugins.harpoon.enable [
      ''
        // Harpoon: pinned/favorite panes.
        bind "Alt p" {
          LaunchOrFocusPlugin "file:${config.xdg.configHome}/zellij/plugins/harpoon.wasm" {
            floating true
            move_to_focused_tab true
          };
        }
      ''
    ])
    ++ (lib.optionals plugins.room.enable [
      ''
        // Room: fuzzy tab search.
        bind "Alt r" {
          LaunchOrFocusPlugin "file:${config.xdg.configHome}/zellij/plugins/room.wasm" {
            floating true
            ignore_case true
            quick_jump false
          };
        }
      ''
    ])
    ++ (lib.optionals plugins.navigator.enable [
      ''
        bind "Ctrl h" {
          MessagePlugin "vim_zellij_navigator" {
            name "move_focus";
            payload "left";
            move_mod "ctrl";
            use_arrow_keys "false";
          };
        }

        bind "Ctrl j" {
          MessagePlugin "vim_zellij_navigator" {
            name "move_focus";
            payload "down";
            move_mod "ctrl";
            use_arrow_keys "false";
          };
        }

        bind "Ctrl k" {
          MessagePlugin "vim_zellij_navigator" {
            name "move_focus";
            payload "up";
            move_mod "ctrl";
            use_arrow_keys "false";
          };
        }

        bind "Ctrl l" {
          MessagePlugin "vim_zellij_navigator" {
            name "move_focus";
            payload "right";
            move_mod "ctrl";
            use_arrow_keys "false";
          };
        }

        bind "Alt h" {
          MessagePlugin "vim_zellij_navigator" {
            name "resize";
            payload "left";
            resize_mod "alt";
          };
        }

        bind "Alt j" {
          MessagePlugin "vim_zellij_navigator" {
            name "resize";
            payload "down";
            resize_mod "alt";
          };
        }

        bind "Alt k" {
          MessagePlugin "vim_zellij_navigator" {
            name "resize";
            payload "up";
            resize_mod "alt";
          };
        }

        bind "Alt l" {
          MessagePlugin "vim_zellij_navigator" {
            name "resize";
            payload "right";
            resize_mod "alt";
          };
        }
      ''
    ])
  );

  autolockKeybindings = lib.optionalString plugins.autolock.enable ''
    normal {
      // Make Autolock reassess immediately after launching an application.
      bind "Enter" {
        WriteChars "\u{000D}";
        MessagePlugin "autolock" {};
      }
    }

    locked {
      // Emergency escape: disable Autolock and return to Normal mode.
      bind "Alt z" {
        MessagePlugin "autolock" {payload "disable";};
        SwitchToMode "Normal";
      }
    }

    shared {
      // Re-enable Autolock after using the emergency escape.
      bind "Alt Shift z" {
        MessagePlugin "autolock" {payload "enable";};
      }
    }
  '';

  keybindings = ''
    ${autolockKeybindings}

    ${lib.optionalString (sharedExceptLockedBindings != "") ''
      // Zellij owns these mappings except while applications such as Neovim
      // intentionally keep the terminal in Locked mode.
      shared_except "locked" {
        ${sharedExceptLockedBindings}
      }
    ''}
  '';
in
{
  options.hakkabara.terminal.zellij.plugins = {
    profile = lib.mkOption {
      type = lib.types.enum [
        "common"
        "minimal"
        "none"
      ];

      default = "common";

      description = ''
        Zellij plugin baseline.

        common:
          Full tested workstation plugin set.

        minimal:
          Only zjstatus and Room.

        none:
          No third-party Zellij plugins.

        Individual plugin enable options can override profile defaults.
      '';
    };

    zjstatus.enable = mkPluginEnableOption "Enable the zjstatus status bar.";
    autolock.enable = mkPluginEnableOption "Enable zellij-autolock.";
    navigator.enable = mkPluginEnableOption "Enable vim-zellij-navigator integration.";
    room.enable = mkPluginEnableOption "Enable the Room fuzzy tab switcher.";
    harpoon.enable = mkPluginEnableOption "Enable Harpoon pane bookmarks.";
    forgot.enable = mkPluginEnableOption "Enable Zellij Forgot searchable keybinding help.";
    tools.enable = mkPluginEnableOption "Enable zellij-tools scratchpads and companion CLI.";
    attention.enable = mkPluginEnableOption "Enable Zellij attention notifications.";
  };

  config = lib.mkMerge [
    # -------------------------------------------------------------------------
    # Plugin profiles
    #
    # mkDefault is intentional: host-specific true/false values always win.
    # -------------------------------------------------------------------------

    (lib.mkIf (plugins.profile == "common") {
      hakkabara.terminal.zellij.plugins = {
        zjstatus.enable = lib.mkDefault true;
        autolock.enable = lib.mkDefault true;
        navigator.enable = lib.mkDefault true;
        room.enable = lib.mkDefault true;
        harpoon.enable = lib.mkDefault true;
        forgot.enable = lib.mkDefault true;
        tools.enable = lib.mkDefault true;
        attention.enable = lib.mkDefault true;
      };
    })

    (lib.mkIf (plugins.profile == "minimal") {
      hakkabara.terminal.zellij.plugins = {
        zjstatus.enable = lib.mkDefault true;
        room.enable = lib.mkDefault true;
      };
    })

    # "none" deliberately relies on the per-plugin false defaults.

    (lib.mkIf (cfg.enable && cfg.zellij.enable) {
      home.packages =
        (lib.optionals plugins.zjstatus.enable [
          zjstatusSystem
        ])
        ++ (lib.optionals plugins.tools.enable [
          zellijToolsCli
        ]);

      # Stable plugin paths keep Zellij permission identities consistent even
      # when the immutable Nix store target changes after an update.
      xdg.configFile =
        (lib.optionalAttrs plugins.autolock.enable {
          "zellij/plugins/zellij-autolock.wasm".source =
            pkgsUnstable.zellijPlugins.autolock;
        })
        // (lib.optionalAttrs plugins.navigator.enable {
          "zellij/plugins/vim-zellij-navigator.wasm".source =
            pkgsUnstable.zellijPlugins.vim-zellij-navigator;
        })
        // (lib.optionalAttrs plugins.zjstatus.enable {
          "zellij/plugins/zjstatus.wasm".source =
            pkgsUnstable.zellijPlugins.zjstatus;

          "zellij/layouts/default.kdl".source =
            ./layouts/default.kdl;
        })
        // (lib.optionalAttrs plugins.room.enable {
          "zellij/plugins/room.wasm".source = pkgs.fetchurl {
            url = "https://github.com/rvcas/room/releases/download/v1.2.1/room.wasm";
            hash = "sha256-kLSDpAt2JGj7dYYhYFh6BfvtzVwTrcs+0jHwG/nActE=";
          };
        })
        // (lib.optionalAttrs plugins.harpoon.enable {
          "zellij/plugins/harpoon.wasm".source =
            "${harpoonPlugin}/harpoon.wasm";
        })
        // (lib.optionalAttrs plugins.forgot.enable {
          "zellij/plugins/zellij-forgot.wasm".source = pkgs.fetchurl {
            url = "https://github.com/karimould/zellij-forgot/releases/download/0.4.2/zellij_forgot.wasm";
            hash = "sha256-MRlBRVGdvcEoaFtFb5cDdDePoZ/J2nQvvkoyG6zkSds=";
          };
        })
        // (lib.optionalAttrs plugins.tools.enable {
          "zellij/plugins/zellij-tools.wasm".source =
            "${zellijToolsPlugin}/share/zellij/plugins/zellij-tools.wasm";
        })
        // (lib.optionalAttrs plugins.attention.enable {
          "zellij/plugins/zellij-attention.wasm".source = pkgs.fetchurl {
            url = "https://github.com/KiryuuLight/zellij-attention/releases/download/v0.3.1/zellij-attention.wasm";
            hash = "sha256-QgkzerYacxRI7HMzYvPvaZqQW7tcARKpOm1hY2D9ci8=";
          };
        });

      programs.zellij.extraConfig = lib.concatStringsSep "\n" (
        lib.filter (value: value != "") [
          (lib.optionalString (pluginDefinitions != "") ''
            plugins {
              ${pluginDefinitions}
            }
          '')

          (lib.optionalString (
            plugins.autolock.enable
            || plugins.tools.enable
            || plugins.attention.enable
          ) ''
            // Background plugins stay alive for the whole Zellij session.
            load_plugins {
              ${lib.optionalString plugins.autolock.enable "autolock"}
              ${lib.optionalString plugins.tools.enable "zellij-tools"}
              ${lib.optionalString plugins.attention.enable "zellij-attention"}
            }
          '')

          (lib.optionalString (keybindings != "") ''
            keybinds {
              ${keybindings}
            }
          '')
        ]
      );
    })
  ];
}
