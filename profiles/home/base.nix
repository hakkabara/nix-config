{ lib, ... }:

{
  # Minimal shared Home Manager baseline.
  #
  # Keep this intentionally small. Anything that is only useful on
  # workstations, development systems, or servers belongs in a more
  # specific profile.
  hakkabara = {
    shell.enable = lib.mkDefault true;
    git.enable = lib.mkDefault true;
  };
}
