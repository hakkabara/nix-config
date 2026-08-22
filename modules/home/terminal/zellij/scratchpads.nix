{ pkgs }:

''
  scratchpads {
    // Persistent floating shell.
    //
    // Alt+s toggles the same pane instead of spawning a new shell every time.
    // The pane can follow the user between Zellij tabs while keeping its
    // process and terminal state alive.
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
  }
''
