{ ... }:
{
  services.xserver.xkb = {
    layout = "eu";
    variant = "";
    model = "pc104";
    options = "terminate:ctrl_alt_bksp";
  };

  # Reuse the same XKB definition on Linux virtual consoles/TTYs.
  console.useXkbConfig = true;
}
