_:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings."*" = {
      ForwardAgent = false;
      AddKeysToAgent = "yes";
      IdentitiesOnly = true;
    };
  };
}
