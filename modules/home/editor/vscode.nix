{
  config,
  lib,
  pkgsUnstable,
  ...
}:

let
  cfg = config.hakkabara.editor;
in
{
  config = lib.mkIf (cfg.enable && cfg.vscode.enable) {
    programs.vscode = {
      enable = true;

      # Extensions are managed declaratively by Nix/Home Manager.
      mutableExtensionsDir = false;

      profiles.default = {
        enableUpdateCheck = false;
        enableExtensionUpdateCheck = false;

        # Extensions come from the pinned nixos-unstable package set so they
        # track upstream releases; VS Code itself stays on stable.
        extensions = with pkgsUnstable.vscode-extensions; [
          jnoortheen.nix-ide
        ];

        userSettings = {
          "editor.formatOnSave" = true;

          "[nix]" = {
            "editor.defaultFormatter" = "jnoortheen.nix-ide";
            "editor.formatOnSave" = true;
          };

          "nix.enableLanguageServer" = true;
          "nix.serverPath" = "nixd";

          "nix.serverSettings" = {
            nixd = {
              formatting.command = [ "nixfmt" ];
            };
          };
        };
      };
    };
  };
}
