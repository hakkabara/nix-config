{ pkgs }:

''
  scratchpads {
    // Persistent floating shell.
    //
    // Alt+s toggles the scratch shell for the current Zellij tab.
    // Its process and terminal state stay alive while the scratchpad is hidden.
    shell {
      command "${pkgs.zsh}/bin/zsh"

      width "80%"
      height "70%"
      origin "center"

      title "Scratch Shell"

      keybinds {
        shared_among "normal" "locked" {
          bind "Alt s" {
            Toggle;
            SwitchToMode "locked";
          }
        }
      }
    }

    // Persistent general-purpose Neovim scratchpad.
    //
    // Alt+v toggles the Neovim scratchpad for the current Zellij tab.
    // No file is forced, so it can be used for arbitrary editing,
    // temporary notes, JSON, configs, etc.
    nvim {
      command "nvim"

      width "92%"
      height "88%"
      origin "center"

      title "Scratch Nvim"

      keybinds {
        shared_among "normal" "locked" {
          bind "Alt v" {
            Toggle;
            SwitchToMode "locked";
          }
        }
      }
    }
  }
''
