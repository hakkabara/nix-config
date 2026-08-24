{
  nix = {
    gc = {
      automatic = true;
      dates = "Sun 03:00";
      options = "--delete-older-than 14d";
      persistent = true;
      randomizedDelaySec = "30min";
    };

    optimise = {
      automatic = true;
      dates = "Sun 05:00";
      persistent = true;
      randomizedDelaySec = "30min";
    };
  };
}
