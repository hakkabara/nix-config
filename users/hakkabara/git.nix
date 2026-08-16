_:

{
  imports = [
    ../../modules/home/git
  ];

  programs.git.settings.user = {
    name = "hakkabara";
    email = "hakkabara@outlook.de";
  };
}
