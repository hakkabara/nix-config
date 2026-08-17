_:

{
  imports = [
    ../../modules/home/git
  ];

  programs.git.settings.user = {
    name = "hakkabara";
    email = "hakkabara@outlook.de";
  };

  programs.git.settings = {
    url."git@github.com:hakkabara/".insteadOf = "https://github.com/hakkabara/";
  };
}
