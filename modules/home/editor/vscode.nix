{
  config,
  lib,
  pkgs,
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

        extensions = with pkgs.vscode-extensions; [
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
